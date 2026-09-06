classdef ManifestTest < matlab.unittest.TestCase
    %MANIFESTTEST 可重复运行清单和文件哈希测试

    properties
        Root
    end

    methods (TestMethodSetup)
        function makeWorkspace(testCase)
            testCase.Root = tempname;
            mkdir(testCase.Root);
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
        end
    end

    methods (Test)
        function sameContentHasSameHashAndWritesJson(testCase)
            a = fullfile(testCase.Root, 'a.m');
            b = fullfile(testCase.Root, 'b.dat');
            localWrite(a, 'same bytes');
            localWrite(b, 'same bytes');
            outDir = fullfile(testCase.Root, 'results');
            files = struct('paths', {{a, b}}, 'out_dir', outDir, 'project_root', testCase.Root);
            manifest = rtsim.verification.write_run_manifest(struct('case_id', "T"), files, ...
                struct('matlab', version), struct('rx', 10), struct('passed', 3));
            testCase.verifyEqual(manifest.files(1).sha256, manifest.files(2).sha256);
            testCase.verifyEqual(manifest.files(1).status, "HASHED");
            testCase.verifyTrue(isfile(fullfile(outDir, 'run_manifest.json')));
            decoded = jsondecode(fileread(fullfile(outDir, 'run_manifest.json')));
            testCase.verifyEqual(decoded.schema_version, 'rtsim-run-manifest-1');
        end

        function changedContentChangesHash(testCase)
            path = fullfile(testCase.Root, 'input.dat');
            outDir = fullfile(testCase.Root, 'results');
            files = struct('paths', {{path}}, 'out_dir', outDir, 'project_root', testCase.Root);
            localWrite(path, 'first');
            one = rtsim.verification.write_run_manifest(struct(), files, struct(), struct(), struct());
            localWrite(path, 'second');
            two = rtsim.verification.write_run_manifest(struct(), files, struct(), struct(), struct());
            testCase.verifyNotEqual(one.files.sha256, two.files.sha256);
        end

        function missingAndExternalFilesAreNotRead(testCase)
            missing = fullfile(testCase.Root, 'missing.dat');
            external = fullfile(fileparts(testCase.Root), 'external-secret.env');
            files = struct('paths', {{missing, external}}, 'out_dir', fullfile(testCase.Root, 'out'), ...
                'project_root', testCase.Root);
            manifest = rtsim.verification.write_run_manifest(struct(), files, struct(), struct(), struct());
            testCase.verifyEqual(manifest.files(1).status, "MISSING");
            testCase.verifyEqual(manifest.files(2).status, "EXCLUDED_EXTERNAL");
            testCase.verifyEqual(manifest.files(1).sha256, "");
            testCase.verifyEqual(manifest.files(2).sha256, "");
        end

        function nestedComplexValuesAreReversiblyEncoded(testCase)
            cfg = struct('rx_response', [1+2i 3-4i; -5i 6], ...
                'nested', struct('items', {{7+8i, struct('polar', [9-10i; 11+12i])}}));
            files = struct('paths', {{}}, 'out_dir', fullfile(testCase.Root, 'out'), ...
                'project_root', testCase.Root);
            manifest = rtsim.verification.write_run_manifest(cfg, files, struct(), struct(), struct());
            testCase.verifyEqual(manifest.configuration.rx_response.encoding, "complex");
            testCase.verifyEqual(manifest.configuration.rx_response.real, real(cfg.rx_response));
            testCase.verifyEqual(manifest.configuration.rx_response.imag, imag(cfg.rx_response));
            testCase.verifyEqual(manifest.configuration.rx_response.size, size(cfg.rx_response));
            decoded = jsondecode(fileread(fullfile(testCase.Root, 'out', 'run_manifest.json')));
            encoded = decoded.configuration.nested.items{2}.polar;
            restored = reshape(encoded.real + 1i*encoded.imag, encoded.size.');
            testCase.verifyEqual(restored, cfg.nested.items{2}.polar);
        end
    end
end

function localWrite(path, text)
fid = fopen(path, 'wb');
assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, unicode2native(char(text), 'UTF-8'), 'uint8');
end
