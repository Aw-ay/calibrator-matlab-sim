function y = tx_channel_error(cfg, element_feeds)
    % N×2馈入经过独立Tx复增益；真实误差仅来自物理plant配置。

    y = element_feeds .* cfg.tx_error;
end
