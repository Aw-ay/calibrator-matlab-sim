function gridNext = advance_time_grid(grid, count)
    % ADVANCE_TIME_GRID 用 uint64 商余数推进，避免先转 double 丢失大 GSC。

    arguments
        grid struct
        count (1, 1) uint64
    end

    rtsim.time.validate_time_grid(grid);
    den = grid.step_den;
    stepWhole = idivide(grid.step_num, den, 'floor');
    stepRem = rem(grid.step_num, den);

    wholeA = checkedMultiply(count, stepWhole);
    countWhole = idivide(count, den, 'floor');
    countRem = rem(count, den);
    wholeB = checkedMultiply(countWhole, stepRem);
    smallProduct = checkedMultiply(countRem, stepRem);
    wholeC = idivide(smallProduct, den, 'floor');
    fracNumerator = rem(smallProduct, den);

    % 初始分数只在一个 tick 内以 double 保存，不参与大整数绝对计数。
    frac = grid.fraction0_ticks + double(fracNumerator) / double(den);
    carry = uint64(floor(frac));
    frac = frac - double(carry);
    advanceWhole = checkedAdd(checkedAdd(wholeA, wholeB), checkedAdd(wholeC, carry));

    gridNext = grid;
    gridNext.gsc0 = checkedAdd(grid.gsc0, advanceWhole);
    gridNext.fraction0_ticks = frac;
    gridNext.index0 = checkedAdd(grid.index0, count);
    gridNext.count = grid.count;
end

function y = checkedAdd(a, b)
    if b > intmax('uint64') - a
        error('rtsim:time:CounterOverflow', 'uint64 时间计数器加法溢出。');
    end

    y = a + b;
end

function y = checkedMultiply(a, b)
    if a ~= 0 && b > idivide(intmax('uint64'), a, 'floor')
        error('rtsim:time:CounterOverflow', 'uint64 时间计数器乘法溢出。');
    end

    y = a * b;
end
