classdef ReplayAnalysisTest < matlab.unittest.TestCase
    % 独立数学公式验证回放、检测以及统计工具。
    methods (Test)
        function fractionalDelaySplit(test)
            x=[1;zeros(19,1)]*[1,1i]; cfg=struct();
            [whole,~]=rtsim.replay.fractional_delay_step(x,struct(),2.5,cfg);
            [a,s]=rtsim.replay.fractional_delay_step(x(1:3,:),struct(),2.5,cfg);
            [b,~]=rtsim.replay.fractional_delay_step(x(4:end,:),s,2.5,cfg);
            test.verifyEqual([a;b],whole,'AbsTol',0);
            test.verifyEqual(whole(3:4,1),[0.5;0.5],'AbsTol',1e-14);
        end
        function causalDetection(test)
            cfg=struct('threshold',1,'end_hold',2);
            [events,s]=rtsim.capture.overgate_detect([0;2;2;0],struct(),cfg,struct('index0',0));
            test.verifyEmpty(events);
            [events,~]=rtsim.capture.overgate_detect(0,s,cfg,struct('index0',4));
            test.verifyEqual(events.start_index,1);
            test.verifyEqual(events.end_index,2);
            test.verifyEqual(events.available_index,4);
        end
        function delaySubtractsPhysicalRange(test)
            plan=rtsim.replay.solve_target_delay(struct('range_m',20000), ...
                struct('roundtrip_delay_s',4000/299792458),struct('fixed_s',1e-6),struct('fs_Hz',20e6));
            test.verifyEqual(plan.device_delay_s,36000/299792458,'AbsTol',1e-15);
        end
        function multiPriIsLegal(test)
            tx=struct('start_s',230e-6,'end_s',240e-6);
            windows=[0,10;100,110;200,210]*1e-6;
            d=rtsim.replay.check_tx_windows(tx,windows,struct('ready_s',20e-6),struct('available',true));
            test.verifyTrue(d.accepted);
        end
        function gainHasSquareRoot(test)
            g=rtsim.replay.solve_target_gain(struct('received_power_W',1e-9), ...
                struct('input_power_W',1e-6,'return_power_gain',1e-4),struct(),struct('max_amplitude_gain',100));
            test.verifyEqual(g.amplitude_gain,sqrt(10),'AbsTol',1e-12);
        end
        function rankOneCannotIdentifyRadar(test)
            test.verifyError(@() rtsim.radar.radar_calibration_solver(ones(4,2),ones(4,2),struct()),'rtsim:Rank');
        end
        function deterministicNoiseEstimator(test)
            [estimate,~]=rtsim.capture.noise_estimator_ewma(ones(100,1),struct(),struct('alpha',0.1,'initial',1,'gate_factor',8));
            test.verifyEqual(estimate,ones(100,1),'AbsTol',1e-14);
        end
    end
end
