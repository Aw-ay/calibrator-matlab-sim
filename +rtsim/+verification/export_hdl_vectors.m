function manifest = export_hdl_vectors(signals, events, arithmeticCfg, outDir)
    % 导出复包络量化参考向量；不宣称逐级 RTL 一致或硬件时序通过。

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    [i, q, flags] = rtsim.rx.adc_clip_round(signals, arithmeticCfg);
    n = size(signals, 1);
    sample = (0:n - 1)';
    vectors = table(sample, mod(sample, arithmeticCfg.samples_per_clock), i(:, 1), q(:, 1), i(:, 2), q(:, 2), ...
        true(n, 1), 'VariableNames', {'sample', 'lane', 'i_h', 'q_h', 'i_v', 'q_v', 'valid'});
    writetable(vectors, fullfile(outDir, 'iq_vectors.csv'));
    save(fullfile(outDir, 'reference.mat'), 'signals', 'events', 'arithmeticCfg', 'flags');
    manifest = struct('count', n, 'status', 'REFERENCE_ONLY', 'scope', '末级量化向量；未运行 RTL 对照', 'config', arithmeticCfg);
end
