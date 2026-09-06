function [out, st] = adc_jitter_inject(in, st, jitterModel, frequencyPlan)
%ADC_JITTER_INJECT 按 ADC 输入载频灵敏度注入复包络等效随机相位。
arguments
    in {mustBeNumeric}
    st struct
    jitterModel struct
    frequencyPlan struct
end
if ~isfield(jitterModel, 'mode') || string(jitterModel.mode) ~= "ENVELOPE_EQUIVALENT"
    error('rtsim:rx:UnsupportedJitterMode', '基础模型只支持已声明的 ENVELOPE_EQUIVALENT 模式。');
end
assert(isfield(jitterModel, 'rms_jitter_s') && isfield(frequencyPlan, 'adc_input_frequency_Hz'), ...
    'rtsim:rx:InvalidJitterSpec', '必须给出 RMS 抖动和 ADC 端实际 RF/IF 输入频率。');
n = size(in, 1);
stream = localStream(st, 1004);
dt = jitterModel.rms_jitter_s * randn(stream, n, 1);
phase = 2*pi*frequencyPlan.adc_input_frequency_Hz .* dt;
out = double(in) .* reshape(exp(1i*phase), [n ones(1, ndims(in)-1)]);
st.sample_count = localField(st, 'sample_count', uint64(0)) + uint64(n);
st.rng_state = stream.State;
st.model_scope = "INDEPENDENT_SAMPLE_EQUIVALENT_PHASE";
end

function value = localField(s, name, defaultValue)
if isfield(s, name), value = s.(name); else, value = defaultValue; end
end

function stream = localStream(st, defaultSeed)
stream = RandStream('mt19937ar', 'Seed', double(localField(st, 'seed', defaultSeed)));
if isfield(st, 'rng_state'), stream.State = st.rng_state; end
end
