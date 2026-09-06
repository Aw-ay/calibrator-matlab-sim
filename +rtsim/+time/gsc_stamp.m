function stamp = gsc_stamp(sampleGrid, lane, clockObservation)
%GSC_STAMP 按 lane 的零基样点偏移生成 epoch/GSC/分数 tick 标记。
arguments
    sampleGrid struct
    lane (1,1) double {mustBeInteger,mustBePositive}
    clockObservation struct
end
rtsim.time.validate_time_grid(sampleGrid);
assert(lane <= double(sampleGrid.count), 'rtsim:time:LaneOutOfRange', 'lane 超出当前块样点数。');
laneGrid = rtsim.time.advance_time_grid(sampleGrid, uint64(lane - 1));
stamp = struct('epoch_id', sampleGrid.epoch_id, 'clock_id', sampleGrid.clock_id, ...
    'gsc', laneGrid.gsc0, 'fraction_ticks', laneGrid.fraction0_ticks, ...
    'sample_index', laneGrid.index0, 'lane', lane, ...
    'valid', localField(clockObservation, 'valid', false), ...
    'time_quality', string(localField(clockObservation, 'time_quality', "UNKNOWN")));
end

function value = localField(s, name, defaultValue)
if isfield(s, name), value = s.(name); else, value = defaultValue; end
end
