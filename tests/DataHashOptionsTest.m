classdef DataHashOptionsTest < matlab.unittest.TestCase
    % DataHash's inputs and output formats, against the examples in its own help and MD5's published values.
    % Every MD5 test runs with and without a Java runtime; the SHA tests need Java.

    methods (TestClassSetup)
        function addDataHash(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(mfilename('fullpath')))));
        end
    end

    methods (Test)
        function helpExamplesMD5(testCase)
            testCase.verifyEqual(DataHash([]), '5b302b7b2099a97ba2a276640a192485');
            testCase.verifyEqual(DataHash(int32(1:10), 'short', 'MD5'), '+tJN9yeF89h3jOFNN55XLg');
        end

        function helpExamplesSHA(testCase)
            testCase.assumeTrue(usejava('jvm'), 'SHA needs a Java runtime');
            S.a = uint8([]);
            S.b = {{1:10}, struct('q', uint64(415))};
            testCase.verifyEqual(DataHash(S, 'SHA-1', 'HEX'), '18672BE876463B25214CA9241B3C79CC926F3093');
            testCase.verifyEqual(DataHash(1:8, 'SHA-1', 'bin'), '826cf9d3a5d74bbe415e97d4cecf03f445f69225');
            testCase.verifyEqual(DataHash('abc', 'SHA-256', 'ascii'), ...
                'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
        end

        function shaWithoutJavaSaysSo(testCase)
            testCase.assumeFalse(usejava('jvm'), 'only without a Java runtime');
            testCase.verifyError(@() DataHash('abc', 'SHA-256'), 'JSimon:DataHash:needJava');
        end

        function asciiAndBinHashTheBytes(testCase)
            abc = '900150983cd24fb0d6963f7d28e17f72';   % MD5 of the three bytes 'abc'
            testCase.verifyEqual(DataHash('abc', 'ascii'), abc);
            testCase.verifyEqual(DataHash(uint8('abc'), 'bin'), abc);
            testCase.verifyEqual(DataHash('', 'bin'), 'd41d8cd98f00b204e9800998ecf8427e');
            testCase.verifyEqual(DataHash(true, 'bin'), DataHash(uint8(1), 'bin'));
            testCase.verifyEqual(DataHash(complex(1, 2), 'bin'), DataHash([1 2], 'bin'));
        end

        function fileHashesItsContents(testCase)
            folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture).Folder;
            file = fullfile(folder, 'abc.txt');
            fid = fopen(file, 'w');  fwrite(fid, 'abc');  fclose(fid);
            testCase.verifyEqual(DataHash(file, 'file'), '900150983cd24fb0d6963f7d28e17f72');

            empty = fullfile(folder, 'empty.txt');
            fclose(fopen(empty, 'w'));
            testCase.verifyEqual(DataHash(empty, 'file'), 'd41d8cd98f00b204e9800998ecf8427e');

            testCase.verifyError(@() DataHash(fullfile(folder, 'missing.txt'), 'file'), 'JSimon:DataHash:BadFile');
        end

        function outputFormatsAgree(testCase)
            data = struct('func', 'x', 'args', struct('a', 1));
            hex = DataHash(data);
            bytes = hex2dec(reshape(hex, 2, []).').';
            testCase.verifyEqual(DataHash(data, 'hex'), hex);
            testCase.verifyEqual(DataHash(data, 'HEX'), upper(hex));
            testCase.verifyEqual(DataHash(data, 'double'), bytes);
            testCase.verifyEqual(DataHash(data, 'uint8'), uint8(bytes));
            padded = matlab.net.base64encode(uint8(bytes));
            testCase.verifyEqual(DataHash(data, 'base64'), padded);
            testCase.verifyEqual(DataHash(data, 'short'), strrep(padded, '=', ''));
        end

        function optionsAsStruct(testCase)
            data = {1, 'two'};
            testCase.verifyEqual(DataHash(data, struct('Method', 'MD5', 'Format', 'HEX')), DataHash(data, 'HEX'));
        end

        function sameContentSameHash(testCase)
            a = struct('func', 'stims.piezo.step', 'args', struct('amp_um', 1, 'dur_s', 0.5));
            b = struct('func', 'stims.piezo.step', 'args', struct('amp_um', 1, 'dur_s', 0.5));
            testCase.verifyEqual(DataHash(a), DataHash(b));
        end

        function anyDifferenceChangesTheHash(testCase)
            % value, class, shape, field name, text, and nesting each count
            base = struct('func', 'f', 'args', struct('a', 1, 'b', [1 2 3]));
            variants = { ...
                struct('func', 'f', 'args', struct('a', 2, 'b', [1 2 3])), ...
                struct('func', 'f', 'args', struct('a', single(1), 'b', [1 2 3])), ...
                struct('func', 'f', 'args', struct('a', 1, 'b', [1; 2; 3])), ...
                struct('func', 'f', 'args', struct('a', 1, 'c', [1 2 3])), ...
                struct('func', 'g', 'args', struct('a', 1, 'b', [1 2 3])), ...
                struct('func', 'f', 'args', struct('a', 1, 'b', {{[1 2 3]}})), ...
                struct('func', 'f', 'args', struct('a', 1, 'b', [1 2 3], 'c', []))};
            hashes = [{DataHash(base)}, cellfun(@DataHash, variants, 'UniformOutput', false)];
            testCase.verifyNumElements(unique(hashes), numel(hashes));
        end

        function badInputsAreRefused(testCase)
            testCase.verifyError(@() DataHash(1, 'nonsense'), ?MException);
            testCase.verifyError(@() DataHash({1}, 'bin'), ?MException);
        end
    end
end
