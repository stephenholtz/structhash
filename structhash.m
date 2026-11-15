function hash = structhash(data)
% structhash  MD5 of a MATLAB value's class, size and contents, as 32 lowercase hex characters.
%
%   hash = structhash(data) gives the hash that Jan Simon's DataHash 1.7.1 (File Exchange 31272, hash
%   version 4) gives for DataHash(data) with its defaults (MD5, hex, array input). It needs no Java.
%
%   data may be a struct, cell, char, string, logical or real full numeric array, nested to any depth.
%   Anything else is an error. The order of a struct's fields does not matter; class, shape and every bit
%   of every value do: 1 and int8(1), [1 2] and [1;2], 'a' and "a" all hash differently.
%   A NaN is hashed with one warning (structhash:nan): its sign bit can differ between sessions.
%
%       structhash(struct(func='stims.makeEmpty', args=struct(rate=100000, duration_s=20)))
%       % '4c43c5d57be080c0631bb1e9788a3fb0'
%
%   Derived from DataHash by Jan Simon (c) 2018-2019, BSD licence: see license.txt.

arguments
    data  % no class or size here: a conversion would change the hash
end
[bytes, hasNaN] = serialize(data);
if hasNaN
    warning('structhash:nan', ['The input holds a NaN. A NaN can be stored with either sign bit, so the ' ...
        'same value may hash differently in another MATLAB session.']);
end
hash = sprintf('%.2x', md5(bytes));
end

function [bytes, hasNaN] = serialize(x)
% the byte stream of DataHash 1.7.1's CoreHash: class name, ndims and size as uint64, then the contents
hasNaN = false;
bytes = [uint8(class(x)), typecast(uint64([ndims(x), size(x)]), 'uint8')];
if issparse(x)
    error('structhash:unsupportedType', 'structhash does not hash sparse arrays.');
elseif isstruct(x)
    names = sort(fieldnames(x));  % field order does not count
    parts = cell(numel(names), 1 + numel(x));
    for f = 1:numel(names)
        parts{f, 1} = uint8(names{f});
        for k = 1:numel(x)
            [parts{f, 1 + k}, partNaN] = serialize(x(k).(names{f}));
            hasNaN = hasNaN || partNaN;
        end
    end
    parts = parts.';
    bytes = [bytes, parts{:}];
elseif iscell(x)
    parts = cell(1, numel(x));
    for k = 1:numel(x)
        [parts{k}, partNaN] = serialize(x{k});
        hasNaN = hasNaN || partNaN;
    end
    bytes = [bytes, parts{:}];
elseif isstring(x)
    for k = 1:numel(x)
        if ismissing(x(k))
            error('structhash:unsupportedType', 'structhash does not hash a missing string.');
        end
        c = uint16(x{k});
        bytes = [bytes, uint8('uint16'), typecast(uint64([ndims(c), size(c)]), 'uint8'), ...
            typecast(c(:).', 'uint8')]; %#ok<AGROW>
    end
elseif ischar(x)
    bytes = [bytes, typecast(uint16(x(:).'), 'uint8')];
elseif isequal(class(x), 'logical')  % by name: islogical is also true for logical-based objects
    bytes = [bytes, uint8(x(:).')];
elseif ismember(class(x), {'double', 'single', 'int8', 'uint8', 'int16', 'uint16', 'int32', 'uint32', ...
        'int64', 'uint64'}) && isreal(x)
    hasNaN = isfloat(x) && any(isnan(x), 'all');
    bytes = [bytes, typecast(x(:).', 'uint8')];
else
    error('structhash:unsupportedType', ['structhash hashes struct, cell, char, string, logical and real ' ...
        'numeric arrays, not %s%s.'], repmat('complex ', 1, isnumeric(x) && ~isreal(x)), class(x));
end
end

function hash = md5(bytes)
% MD5 (RFC 1321) of a uint8 row vector, as 16 doubles. Sums run in double (exact below 2^53) and wrap with
% mod 2^32, since uint32 arithmetic saturates.
S = [7 12 17 22 7 12 17 22 7 12 17 22 7 12 17 22, 5 9 14 20 5 9 14 20 5 9 14 20 5 9 14 20, ...
     4 11 16 23 4 11 16 23 4 11 16 23 4 11 16 23, 6 10 15 21 6 10 15 21 6 10 15 21 6 10 15 21];
K = uint32([ ...  % floor(abs(sin(i)) * 2^32), i = 1:64
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501, ...
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821, ...
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8, ...
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a, ...
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70, ...
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665, ...
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1, ...
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391]);

% pad to 56 bytes mod 64, then the length in bits as 64-bit little-endian; words are little-endian
n = numel(bytes);
padded = [double(bytes), 128, zeros(1, mod(55 - n, 64)), mod(floor(8 * n ./ 256 .^ (0:7)), 256)];
words = [1, 256, 65536, 16777216] * reshape(padded, 4, []);

state = uint32([0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476]);
for block = 1:numel(words) / 16
    M = words(16 * (block - 1) + (1:16));
    a = state(1); b = state(2); c = state(3); d = state(4);
    for i = 0:63
        if i < 16
            f = bitor(bitand(b, c), bitand(bitcmp(b), d));  g = i;
        elseif i < 32
            f = bitor(bitand(d, b), bitand(bitcmp(d), c));  g = mod(5 * i + 1, 16);
        elseif i < 48
            f = bitxor(bitxor(b, c), d);                    g = mod(3 * i + 5, 16);
        else
            f = bitxor(c, bitor(b, bitcmp(d)));             g = mod(7 * i, 16);
        end
        f = uint32(mod(double(f) + double(a) + double(K(i + 1)) + M(g + 1), 2^32));
        a = d; d = c; c = b;
        rotated = bitor(bitshift(f, S(i + 1)), bitshift(f, S(i + 1) - 32));
        b = uint32(mod(double(b) + double(rotated), 2^32));
    end
    state = uint32(mod(double(state) + double([a, b, c, d]), 2^32));
end
hash = reshape(mod(floor(double(state) ./ 256 .^ (0:3).'), 256), 1, []);
end
