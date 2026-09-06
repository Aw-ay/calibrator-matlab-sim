function serial = unpack_spc(packed)
    % 恢复按时间递增的串行复样点，不交换H/V或量程。
    serial = reshape(permute(packed, [2, 1, 3, 4]), [], size(packed, 3), size(packed, 4));
end
