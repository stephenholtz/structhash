classdef MD5EngineTest < matlab.unittest.TestCase
    % MD5Engine stands in for java.security.MessageDigest when MATLAB has no Java runtime: the same bytes in
    % must give the same 16 bytes out, in the form DataHash expects.

    methods (TestClassSetup)
        function addDataHash(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(fileparts(fileparts(mfilename('fullpath')))));
        end
    end

    methods (Static)
        function hex = hexOf(engine)
            hex = sprintf('%.2x', typecast(engine.digest(), 'uint8'));
        end
    end

    methods (Test)
        function rfc1321Suite(testCase)
            msgs = {'', 'a', 'abc', 'message digest', 'abcdefghijklmnopqrstuvwxyz', ...
                    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789', ...
                    repmat('1234567890', 1, 8)};
            sums = {'d41d8cd98f00b204e9800998ecf8427e', '0cc175b9c0f1b6a831c399e269772661', ...
                    '900150983cd24fb0d6963f7d28e17f72', 'f96b697d7cb7938d525a2f31aaf161d0', ...
                    'c3fcd3d76192e4007dfb496cca67e13b', 'd174ab98d277d9f5a5611c2c9f419d9f', ...
                    '57edf4a22be3c955ac49da2e2107b67a'};
            for i = 1:numel(msgs)
                testCase.verifyEqual(sprintf('%.2x', MD5Engine.md5(uint8(msgs{i}))), sums{i}, msgs{i});
            end
        end

        function digestIsInt8Column(testCase)
            % as Java's byte[] arrives in MATLAB
            engine = MD5Engine();
            engine.update(uint8('abc'));
            d = engine.digest();
            testCase.verifyClass(d, 'int8');
            testCase.verifySize(d, [16 1]);
        end

        function updatesAccumulate(testCase)
            bytes = uint8(mod(1:1000, 251));
            whole = MD5Engine();  whole.update(bytes);
            parts = MD5Engine();
            for edges = [1 2 64 65 500; 1 63 64 499 1000]
                parts.update(bytes(edges(1):edges(2)));
            end
            testCase.verifyEqual(MD5EngineTest.hexOf(parts), MD5EngineTest.hexOf(whole));
        end

        function updateTakesAnyNumericShape(testCase)
            % DataHash passes columns of several classes; the bytes are the memory layout
            x = [1.5 -2; 3 4e10];
            a = MD5Engine();  a.update(x);
            b = MD5Engine();  b.update(typecast(x(:), 'uint8'));
            testCase.verifyEqual(MD5EngineTest.hexOf(a), MD5EngineTest.hexOf(b));
        end

        function digestResets(testCase)
            engine = MD5Engine();
            engine.update(uint8('abc'));
            engine.digest();
            testCase.verifyEqual(MD5EngineTest.hexOf(engine), 'd41d8cd98f00b204e9800998ecf8427e');
        end

        function matchesJavaAtEveryLength(testCase)
            % every length across two block boundaries, then a few long ones
            testCase.assumeTrue(usejava('jvm'), 'needs a Java runtime to compare against');
            stream = RandStream('mt19937ar', 'Seed', 1);
            for n = [0:130, 1000, 4096, 100003]
                bytes = uint8(randi(stream, [0 255], 1, n));
                digest = java.security.MessageDigest.getInstance('MD5');
                if n > 0, digest.update(bytes); end
                testCase.verifyEqual(MD5Engine.md5(bytes), reshape(typecast(digest.digest(), 'uint8'), 1, []), ...
                    sprintf('%d bytes', n));
            end
        end
    end
end
