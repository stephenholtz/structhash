classdef StructHashTest < matlab.unittest.TestCase
    % structhash must give what Jan Simon's DataHash 1.7.1 (hash version 4) gave: recorded trial folders are
    % named by these hashes, so none may ever change. Run with and without a Java runtime (matlab -nojvm):
    %
    %   results = runtests('tests');
    %
    % recorded_hashes.json: every distinct stimulus the rigs hashed in MATLAB up to 2026-11-15, with the hash
    %   its trial folder carries (column: the three 2023 cases whose vector was hashed as a column).
    % frozen_hashes.txt: DataHash 1.7.1's hash of each of inputs(), in order, written under Java on R2025a.

    methods (Static)
        function in = inputs()
            late = struct('rate', 100000, 'duration_s', 20); late.led_on_V = 10;  % a field added afterwards
            in = { ...
                ... % the eleven inputs frozen from the unmodified original; the zeros straddle MD5's block edges
                struct('func', 'stims.piezo.step', 'args', struct('amp_um', 1, 'dur_s', 0.5, 'pre_s', 1, 'post_s', 1)), ...
                struct('func', 'stims.ephys.currentStep', 'args', struct('amp_pA', [-20 -10 0 10 20], 'dur_s', 0.2, 'label', "iv")), ...
                struct('func', 'x', 'args', struct()), ...
                struct('func', 'x', 'args', struct('a', [], 'b', '', 'c', {{1, 'two', [3 4 5]}}, 'd', true, 'e', single(2.5), 'f', int16(-7))), ...
                struct('func', 'chirp', 'args', struct('wave', (1:5000) / 7, 'fs', 40000, 'nested', struct('k', uint8(1:200), 's', 'long string here'))), ...
                struct('func', 'x', 'args', struct('v', zeros(1, 7))), ...
                struct('func', 'x', 'args', struct('v', zeros(1, 8))), ...
                struct('func', 'x', 'args', struct('v', zeros(1, 55))), ...
                struct('func', 'x', 'args', struct('v', zeros(1, 56))), ...
                'a char vector', ...
                1:10, ...
                ... % rig shapes and their edges
                struct('func', 'stims.positionSteps', 'args', struct('gen_rate', 80000, 'step_val_um', -10, ...
                    'dur_pre_ms', 1500, 'dur_ramp_ms', 1500, 'dur_post_ms', 1500, 'lfp_hz', 2500)), ...
                struct('func', 'stims.makeEmpty', 'args', late), ...
                struct('func', '', 'args', struct()), ...
                struct('func', 'x', 'args', struct('v', zeros(1, 0))), struct('func', 'x', 'args', struct('v', [])), ...
                struct('func', 'r', 'args', struct('ramp', [-5 25])), struct('func', 'r', 'args', struct('ramp', [-5; 25])), ...
                struct('func', "r", 'args', struct('a_1', 1, 'a1', 2, 'A', 3, 'x_', -0, 'i', -Inf, 'f', 0.1 + 0.2)), ...
                ... % every other type it takes
                struct('a', {1, 2, 'x'}), struct('a', {1; 2}), struct([]), struct('a', {}), struct(), ...
                '', char(zeros(1, 0)), ['ab'; 'cd'], char([228 8364 960]), ...
                "hi", "", string.empty, ["a", "bc"; "", "d"], string(char([228 8364])), ...
                (1:10).', [], zeros(0, 3), reshape(1:24, 3, 4, 2), magic(4), pi, -0, ...
                true, [true false; false true], logical([]), ...
                int8(-1), uint8(200:255), int16([1 -2]), uint16(7), int32(-5), uint32(5), int64(-2^40), uint64(2^60), single(pi), ...
                {}, {1, 2}, {{1, 2}}, {[1 2]}, cell(1, 2), {struct('a', {{}}), "s", 'c', {true}}, ...
                ... % a known collision, kept from DataHash: a field name runs straight into its value's class name
                struct('xu', int8(5)), struct('x', uint8(5))};
        end
    end

    methods (TestClassSetup)
        function addStructhash(t)
            t.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(mfilename('fullpath')))));
        end
    end

    methods (Test)
        function recordedTrialHashes(t)
            here = fileparts(mfilename('fullpath'));
            cases = jsondecode(fileread(fullfile(here, 'recorded_hashes.json')));
            if ~iscell(cases), cases = num2cell(cases); end
            t.assertGreaterThan(numel(cases), 360);
            for i = 1:numel(cases)
                c = cases{i};
                args = c.args;
                names = fieldnames(args);
                for k = 1:numel(names)  % jsondecode gives columns; the rigs hash rows
                    if ~c.column, args.(names{k}) = reshape(args.(names{k}), 1, []); end
                end
                t.verifyEqual(structhash(struct('func', c.func, 'args', args)), c.hash, sprintf('case %d', i));
            end
        end

        function frozenHashes(t)
            here = fileparts(mfilename('fullpath'));
            expected = splitlines(strtrim(fileread(fullfile(here, 'frozen_hashes.txt'))));
            in = StructHashTest.inputs();
            t.assertNumElements(expected, numel(in));
            for i = 1:numel(in)
                t.verifyEqual(structhash(in{i}), expected{i}, sprintf('input %d', i));
            end
        end

        function fieldOrderDoesNotCount(t)
            t.verifyEqual(structhash(struct('a', 1, 'b', 2)), structhash(struct('b', 2, 'a', 1)));
        end

        function outputIs32LowercaseHex(t)
            t.verifyMatches(structhash(1), '^[0-9a-f]{32}$');
            t.verifyClass(structhash(1), 'char');
        end

        function nanIsHashedWithAWarning(t)
            d = struct('func', 'x', 'args', struct('v', [1 NaN]));
            h = t.verifyWarning(@() structhash(d), 'structhash:nan');
            t.verifyMatches(h, '^[0-9a-f]{32}$');
            t.verifyWarning(@() structhash(single(NaN)), 'structhash:nan');
            t.verifyWarningFree(@() structhash(struct('v', [1 Inf])));
            lastwarn('');
            w = warning('off', 'structhash:nan'); restore = onCleanup(@() warning(w));
            t.verifyEqual(structhash({NaN, struct('a', NaN, 'b', {{single(NaN)}})}), ...
                structhash({NaN, struct('b', {{single(NaN)}}, 'a', NaN)}));  % hashed all the same
        end

        function unsupportedTypesError(t)
            bad = {sparse(1), complex(1, 2), @sin, datetime(2026, 1, 1), table(1), containers.Map(), ...
                string(missing), categorical("a"), struct('a', {{@sin}}), matlab.lang.OnOffSwitchState.on};
            for i = 1:numel(bad)
                t.verifyError(@() structhash(bad{i}), 'structhash:unsupportedType', sprintf('bad %d', i));
            end
        end

        function takesExactlyOneInput(t)
            t.verifyError(@() structhash(), 'MATLAB:minrhs');
            t.verifyError(@() structhash(1, 'SHA-256'), 'MATLAB:TooManyInputs');
        end
    end
end
