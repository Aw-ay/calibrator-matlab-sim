classdef SafetyIntegrationTest < matlab.unittest.TestCase
    % 故障与压力场景补充，采用短窗口降低回归时间。
    methods (Test)
        function ddsGuardConflict(test)
            cfg=SafetyIntegrationTest.shortConfig();
            cfg.instrument.mode='DDS'; cfg.instrument.source_start_s=cfg.radar.start_s;
            a=run_stage_a(cfg);
            test.verifyEqual(a.tx_iq,zeros(size(a.tx_iq)),'AbsTol',0);
        end
        function ddsSafeWindow(test)
            cfg=SafetyIntegrationTest.shortConfig(); cfg.instrument.mode='DDS';
            cfg.instrument.source_start_s=150e-6; a=run_stage_a(cfg);
            test.verifyGreaterThan(max(abs(a.tx_iq(:))),0);
        end
        function bankPressure(test)
            cfg=SafetyIntegrationTest.shortConfig(); cfg.radar.pulse_count=3;
            cfg.radar.pri_s=250e-6; cfg.sim.duration_s=800e-6;
            cfg.capture.bank_count=1; cfg.dataflow.dma_bytes_per_s=0;
            a=run_stage_a(cfg);
            test.verifyEqual(numel(a.pdw),1);
            test.verifyEqual(a.diagnostics.dropped_captures,2);
            test.verifyEqual(a.records.bank_generation,1);
        end
        function pllFaultMutes(test)
            cfg=SafetyIntegrationTest.shortConfig(); cfg.safety.pll_locked=false;
            a=run_stage_a(cfg); test.verifyEqual(a.tx_iq,zeros(size(a.tx_iq)),'AbsTol',0);
        end
        function passiveEchoSurvivesMute(test)
            cfg=SafetyIntegrationTest.shortConfig(); cfg.instrument.mode='MUTE';
            cfg.environment.body_rcs_m2=1; a=run_stage_a(cfg);
            test.verifyEqual(a.tx_iq,zeros(size(a.tx_iq)),'AbsTol',0);
            test.verifyGreaterThan(max(abs(a.radar_iq(:))),0);
        end
        function noisyBlockInvariant(test)
            cfg=SafetyIntegrationTest.shortConfig();
            cfg.instrument.common.noise_power_W=1e-16; cfg.radar.noise_power_W=1e-22;
            cfg.sim.block_size=73; a=run_stage_a(cfg);
            cfg.sim.block_size=256; b=run_stage_a(cfg);
            test.verifyEqual(a.radar_iq,b.radar_iq,'AbsTol',1e-18);
        end
        function phaseOriginInvariant(test)
            task=struct('range_m',20000,'phase0_rad',0,'doppler_Hz',0);
            model=struct('fc_Hz',2.8e9,'phase_rad',-1,'doppler_Hz',10);
            a=rtsim.replay.solve_phase_command(task,model,struct('index0',0,'fs_Hz',1000),[]);
            model.phase_rad=-1+2*pi*10*.1;
            b=rtsim.replay.solve_phase_command(task,model,struct('index0',100,'fs_Hz',1000),[]);
            test.verifyEqual(a.phase0_rad,b.phase0_rad,'AbsTol',1e-9);
        end
        function biasedProviderDoesNotReadTruth(test)
            cfg=SafetyIntegrationTest.shortConfig();
            a=rtsim.sim.simulate_case(cfg,@SafetyIntegrationTest.world,@SafetyIntegrationTest.biasedObservation);
            test.verifyLessThan(abs(a.observables.range_m-19000),30);
        end
        function futureObservationMutes(test)
            cfg=SafetyIntegrationTest.shortConfig();
            a=rtsim.sim.simulate_case(cfg,@SafetyIntegrationTest.world,@SafetyIntegrationTest.futureObservation);
            test.verifyEqual(a.tx_iq,zeros(size(a.tx_iq)),'AbsTol',0);
        end
    end
    methods (Static)
        function cfg=shortConfig()
            cfg=rtsim.config.default_config(); cfg.output.save=false;
            cfg.radar.pulse_count=1; cfg.sim.duration_s=250e-6;
        end
        function truth=world(t)
            truth=struct('time_s',t,'position_m',[2000;0;0],'velocity_mps',zeros(3,1),'roll_deg',0);
        end
        function obs=biasedObservation(t)
            obs=struct('measurement_time_s',t,'available_time_s',t,'position_m',[3000;0;0], ...
                'velocity_mps',zeros(3,1),'roll_deg',0,'quality',1,'available',true);
        end
        function obs=futureObservation(t)
            obs=SafetyIntegrationTest.biasedObservation(t); obs.available_time_s=t+1;
        end
    end
end
