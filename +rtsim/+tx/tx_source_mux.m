function [out, st, diag] = tx_source_mux(sources, st, activeMode, gate)
    % 信号源统一选择后才施加发射校准；静音不停止物理时间。

    switch activeMode
        case 'MUTE'
            out = zeros(size(sources.DRFM));
        case {'LIVE', 'DRFM', 'DDS', 'AWG'}
            out = sources.(activeMode);
        otherwise
            error('rtsim:Source', '未知发射源。');
    end

    out = out .* gate;
    st.mode = activeMode;
    diag.muted = ~gate;
end
