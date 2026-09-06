function [plantBoundary, measuredBoundary, st] = air_adapter_step(st, providers, grid)
    % AIR_ADAPTER_STEP 将物理真值与有误差观测放入互相独立的边界。

    arguments
        st (1, 1) struct
        providers (1, 1) struct
        grid (1, 1) struct
    end

    if ~isfield(providers, 'truth') || ~isfield(providers, 'measurement')
        error('rtsim:airborne:MissingField', 'providers必须包含truth和measurement。');
    end

    plantBoundary = resolve(providers.truth, st, grid);
    measuredBoundary = resolve(providers.measurement, st, grid);
    st.last_grid = grid;
end

function value = resolve(provider, st, grid)
    if isa(provider, 'function_handle')
        value = provider(st, grid);
    else
        value = provider;
    end
end
