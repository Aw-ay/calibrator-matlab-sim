function transfer = adc_make_inl_from_dnl(dnlData, conventions)
    % ADC_MAKE_INL_FROM_DNL 从逐码 DNL 构造单调码宽及转换阈值。

    arguments
        dnlData (1, :) double
        conventions struct
    end

    required = {'bits', 'lsb', 'lower_endpoint'};
    assert(all(isfield(conventions, required)), 'rtsim:rx:InvalidDnlConvention', ...
        '必须明确 bits、lsb 和 lower_endpoint。');
    assert(numel(dnlData) == 2^conventions.bits && conventions.lsb > 0, ...
        'rtsim:rx:InvalidDnlConvention', 'DNL 长度必须为 2^bits，lsb 必须为正。');
    widths = (1 + dnlData) * conventions.lsb;
    assert(all(widths >= 0), 'rtsim:rx:NonMonotonicDnl', 'DNL 产生负码宽，传输函数不单调。');
    thresholds = conventions.lower_endpoint + [0 cumsum(widths(1:end - 1))];
    idealCenters = conventions.lower_endpoint + ((0:numel(widths) - 1) + 0.5) * conventions.lsb;
    centers = thresholds + widths / 2;
    transfer = struct('code_widths', widths, 'thresholds', thresholds, ...
        'inl_lsb', (centers - idealCenters) / conventions.lsb, 'missing_codes', widths == 0, ...
        'scope', "STATIC_MONOTONIC_TRANSFER_FROM_PROVIDED_DNL");
end
