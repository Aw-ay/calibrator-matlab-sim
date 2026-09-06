function [iq, st, diag] = radar_rx_step(arrivingSignals, st, cfgRadar, radarClock)
    % 有源与被动回波先按复场相加，然后施加雷达响应、噪声及发射死区。

    if iscell(arrivingSignals)
        iq = complex(zeros(size(arrivingSignals{1})));
        for k = 1:numel(arrivingSignals)
            iq = iq + arrivingSignals{k};
        end
    else
        iq = arrivingSignals;
    end

    iq = iq * cfgRadar.response_matrix.';
    if ~isfield(st, 'stream')
        st.stream = RandStream('mt19937ar', 'Seed', st.seed);
    end

    q = randn(st.stream, 4, size(iq, 1)).';
    iq = iq + sqrt(cfgRadar.noise_power_W / 2) * complex(q(:, 1:2), q(:, 3:4));
    t = (radarClock.index0 + (0:size(iq, 1) - 1)') / radarClock.fs_Hz;
    dead = false(size(t));
    for p = 0:cfgRadar.pulse_count - 1
        start = cfgRadar.start_s + p * cfgRadar.pri_s;
        dead = dead | (t >= start & t < start + cfgRadar.pulse_width_s);
    end

    iq(dead, :) = 0;
    diag.blanked_samples = nnz(dead);
    diag.reference_plane = 'RADAR_RX';
end
