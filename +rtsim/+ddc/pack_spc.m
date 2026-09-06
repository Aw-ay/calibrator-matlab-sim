function packed = pack_spc(serial, samplesPerClock)
    % 连续样点按clock、lane、H/V、量程组织；lane 1为最早样点。
    assert(mod(size(serial, 1), samplesPerClock) == 0, 'rtsim:SPCAlignment', '打包需要完整时钟。');
    packed = permute(reshape(serial, samplesPerClock, [], size(serial, 2), size(serial, 3)), [2, 1, 3, 4]);
end
