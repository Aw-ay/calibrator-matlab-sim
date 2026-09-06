function frame = iq_frame_pack(iq, descriptor, pdw, formatCfg)
    % IQ_FRAME_PACK 封装RAW/CAL IQ、采样网格、版本、长度和CRC32。

    arguments
        iq {mustBeNumeric}
        descriptor (1, 1) struct
        pdw (1, 1) struct
        formatCfg (1, 1) struct
    end

    if size(iq, 2) ~= 2 || ~all(isfield(descriptor, {'id', 'domain', 'sample_grid'})) || ...
            ~all(isfield(formatCfg, {'version', 'pdw_policy'})) || ~isfield(pdw, 'fine_ready')
        error('rtsim:dataflow:MissingField', 'IQ帧字段不完整。');
    end

    if ~any(descriptor.domain == ["RAW", "CAL"])
        error('rtsim:dataflow:InvalidDomain', 'IQ域必须明确为RAW或CAL。');
    end

    if ~pdw.fine_ready && formatCfg.pdw_policy == "wait"
        error('rtsim:dataflow:PdwNotReady', '细PDW未就绪，按策略暂不封帧。');
    end

    frame.header.version = formatCfg.version;
    frame.header.descriptor_id = descriptor.id;
    frame.header.domain = descriptor.domain;
    frame.header.sample_grid = descriptor.sample_grid;
    frame.header.pdw_attached = logical(pdw.fine_ready);
    frame.payload = iq;
    if pdw.fine_ready
        frame.pdw = pdw;
    else
        frame.pdw = struct([]);
    end

    bytes = payloadBytes(iq);
    frame.payload_length_bytes = uint32(numel(bytes));
    frame.crc32 = crc32(bytes);
    frame.size_bytes = double(frame.payload_length_bytes) + 32;
    frame.model_scope = "logical IQ frame, not AXI wire encoding";
end

function bytes = payloadBytes(x)
    bytes = typecast(x(:), 'uint8');
end

function value = crc32(bytes)
    value = uint32(hex2dec('FFFFFFFF'));
    poly = uint32(hex2dec('EDB88320'));
    for b = reshape(bytes, 1, [])
        value = bitxor(value, uint32(b));
        for k = 1:8
            if bitand(value, uint32(1))
                value = bitxor(bitshift(value, -1), poly);
            else
                value = bitshift(value, -1);
            end
        end
    end

    value = bitcmp(value);
end
