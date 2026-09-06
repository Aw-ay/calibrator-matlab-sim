classdef ExtendedDataflowTest < matlab.unittest.TestCase
    % 延迟校准、慢更新及数据流行为模型测试
    methods (TestClassSetup)
        function addProjectPath(~)
            addpath(fileparts(fileparts(mfilename('fullpath'))));
        end
    end

    methods (Test)
        function delayCalibrationSeparatesKnownPathAndQueueTime(testCase)
            m.delay.input_time_s = [0; 1; 2; 3];
            m.delay.queue_wait_s = [4; 3; 5; 4] * 1e-7;
            m.delay.output_time_s = m.delay.input_time_s + 1.7e-6 + ...
                m.delay.queue_wait_s + [0; 1; -1; 0] * 1e-8;
            ref = struct('known_path_delay_s', 1e-6);
            cal = rtsim.calibration.estimate_delay_cal(m, ref, ...
                struct('max_residual_s', 2e-8));
            testCase.verifyEqual(cal.fixed_delay_s, 0.7e-6, 'AbsTol', 1e-15);
            testCase.verifyEqual(cal.queue_wait_s, m.delay.queue_wait_s);
            testCase.verifyEqual(cal.status, "OK");
        end

        function calibrationUpdateCommitsAtomicallyOnlyAtBoundary(testCase)
            old.coefficients = eye(2);
            old.version = uint32(5);
            monitor.coefficient_delta = [0.2 0; 0 -0.2];
            telemetry.valid = true;
            policy = struct('alpha', .5, 'max_step', .2, 'commit', false);
            [held, diag] = rtsim.calibration.update_calibration( ...
                old, monitor, telemetry, policy);
            testCase.verifyEqual(held.coefficients, eye(2));
            testCase.verifyTrue(diag.pending);
            testCase.verifyEqual(diag.pending_set.coefficients, [1.1 0; 0 .9]);
            policy.commit = true;
            [committed, diag] = rtsim.calibration.update_calibration( ...
                old, monitor, telemetry, policy);
            testCase.verifyEqual(committed.coefficients, [1.1 0; 0 .9]);
            testCase.verifyEqual(committed.version, uint32(6));
            testCase.verifyTrue(diag.committed);
        end

        function pdwQueueSurvivesIndependentIqBackpressure(testCase)
            input = struct('id', num2cell(1:3), 'kind', repmat({'PDW'},1,3));
            cfg = struct('capacity', 2, 'overflow_policy', "drop_newest");
            [out, st, diag] = rtsim.dataflow.pdw_fifo_step(input, ...
                struct('service_count', 1), struct(), cfg);
            testCase.verifyEqual([out.id], 1);
            testCase.verifyEqual([st.queue.id], 2);
            testCase.verifyEqual(diag.dropped_ids, 3);
        end

        function iqFramePreservesDomainMetadataAndCrc(testCase)
            iq = int16([1 -2; 300 -400]);
            descriptor = struct('id', uint32(7), 'domain', "CAL", ...
                'sample_grid', struct('index0', uint64(20), 'fs_Hz', 1e6));
            pdw = struct('fine_ready', false);
            cfg = struct('version', uint16(1), 'pdw_policy', "separate");
            frame = rtsim.dataflow.iq_frame_pack(iq, descriptor, pdw, cfg);
            testCase.verifyEqual(frame.header.domain, "CAL");
            testCase.verifyEqual(frame.header.sample_grid, descriptor.sample_grid);
            testCase.verifyEqual(frame.payload, iq);
            testCase.verifyClass(frame.crc32, 'uint32');
            testCase.verifyFalse(frame.header.pdw_attached);
            changed = rtsim.dataflow.iq_frame_pack(iq+int16([0 0;0 1]), descriptor, pdw, cfg);
            testCase.verifyNotEqual(frame.crc32, changed.crc32);
        end

        function dmaConsumesOneSharedServiceBudget(testCase)
            frames = struct('id',num2cell(1:3),'size_bytes',num2cell([6 6 6]));
            [done, st, diag] = rtsim.dataflow.dma_queue_step(frames, struct(), ...
                struct('total_bytes', 10), struct('capacity_frames', 4));
            testCase.verifyEqual([done.id], 1);
            testCase.verifyEqual([st.queue.id], [2 3]);
            testCase.verifyEqual(diag.bytes_served, 6);
            testCase.verifyEqual(diag.remaining_service_bytes, 4);
        end

        function psBudgetAndConfigCommitAreSingleAndAtomic(testCase)
            queues.pdw = struct('id', num2cell(1:2));
            queues.iq = struct('id', num2cell(10:11));
            [commands, data, ~, diag] = rtsim.dataflow.ps_service_step( ...
                struct('config_request',struct('mode',"DRFM")), queues, struct(), ...
                struct('total_service_items',3,'pdw_priority',true,'command_delay_steps',1));
            testCase.verifyEqual(numel(data.pdw)+numel(data.iq),3);
            testCase.verifyEmpty(commands);
            testCase.verifyEqual(diag.remaining_service_items,0);

            st.activeCfg = struct('mode',"MUTE",'gain',1);
            st.version = uint32(2);
            [active, st, d] = rtsim.dataflow.config_commit_step( ...
                struct('mode',"DRFM",'gain',2), false, st);
            testCase.verifyEqual(active.mode,"MUTE");
            testCase.verifyTrue(d.pending);
            [active, ~, d] = rtsim.dataflow.config_commit_step(struct(), true, st);
            testCase.verifyEqual(active.mode,"DRFM");
            testCase.verifyEqual(active.gain,2);
            testCase.verifyTrue(d.committed);
        end

        function storageKeepsPdwWhenIqPolicyAndCapacityConstrain(testCase)
            records(1)=struct('id',1,'kind',"IQ",'size_bytes',8);
            records(2)=struct('id',2,'kind',"PDW",'size_bytes',2);
            records(3)=struct('id',3,'kind',"IQ",'size_bytes',8);
            storageCfg=struct('capacity_bytes',10,'retain_iq',false);
            radioCfg=struct('budget_bytes',3);
            [saved,sent,st,diag]=rtsim.dataflow.storage_link_step( ...
                records,struct(),storageCfg,radioCfg);
            testCase.verifyEqual([saved.id],2);
            testCase.verifyEqual([sent.id],2);
            testCase.verifyEqual(st.used_bytes,2);
            testCase.verifyEqual(sort(diag.dropped_ids),[1 3]);
        end

        function monostaticScatterAmplitudeUsesTwoWayRange(testCase)
            tx=[1 0]; body=struct('amplitude_gain',1, ...
                'polarization_matrix',eye(2));
            [near,~]=rtsim.airborne.platform_scatter_step(tx, ...
                struct('range_m',10,'phase_rad',0),body,struct());
            [far,~]=rtsim.airborne.platform_scatter_step(tx, ...
                struct('range_m',20,'phase_rad',0),body,struct());
            testCase.verifyEqual(near,4*far,'AbsTol',1e-15);
        end
    end
end
