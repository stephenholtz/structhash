# structhash

`structhash(data)` gives a 32-character hex hash of a MATLAB value: its class, shape and contents. It is one file of plain MATLAB and needs no Java runtime, which MATLAB R2026b no longer ships.

It is derived from Jan Simon's `DataHash` (File Exchange 31272, version 1.7.1 of 2019, hash version 4) and gives exactly the hash `DataHash(data)` gave with its defaults (MD5, hex). Everything else `DataHash` did is gone: other digests, output formats, file and raw-byte input, the options.

The rig repos (`antenna-ephys-experiments`, `antenna-ldv-experiments`, `antenna-twop-experiments`) take this repo as the submodule `ext/DataHash` and name each stimulus's trial folder by its hash.

## Use

Put the folder on the MATLAB path.

```matlab
structhash(struct(func='stims.makeEmpty', args=struct(rate=100000, duration_s=20)))
% '4c43c5d57be080c0631bb1e9788a3fb0'
```

- **Input:** a struct, cell, char, string, logical or real full numeric array, nested to any depth. Complex and sparse arrays, function handles and objects are an error (`structhash:unsupportedType`).
- **Field order does not count; class, shape and every bit of every value do.** `1` and `int8(1)`, `[1 2]` and `[1;2]`, `'a'` and `"a"` hash differently.
- **One known collision, kept from `DataHash`:** a field name runs straight into its value's class name, so `struct('xu', int8(5))` and `struct('x', uint8(5))` hash the same.
- **A NaN is hashed with one warning** (`structhash:nan`): MATLAB can store a NaN with either sign bit, so the same value may hash differently in another session.

## What is hashed

The MD5 (RFC 1321) of a byte stream built from the value, depth first:

- **Every array:** its class name as bytes, then `[ndims, size]` as uint64, then its contents. Multi-byte values are little-endian.
- **Numeric, logical:** the elements' bytes in column order; a logical is one byte per element.
- **Char:** each character as a uint16.
- **String:** each element as if it were a uint16 array of its characters: a 1-by-n row, or 0-by-0 for `""`.
- **Cell:** each element in column order.
- **Struct:** the field names sorted by character code (`A` < `_` < `a`); for each, the name as bytes, then that field of every element.

## The rule

**A hash never changes.** Recorded data are filed by these hashes, so an edit that changes one is a bug. After any edit, run the tests with and without Java:

```
matlab -batch "results = runtests('tests'); disp(table(results)); assert(all([results.Passed]))"
matlab -nojvm -batch "results = runtests('tests'); disp(table(results)); assert(all([results.Passed]))"
```

- **`tests/recorded_hashes.json`:** every distinct stimulus the rigs hashed up to 2026-11-15, with the hash its trial folder carries.
- **`tests/frozen_hashes.txt`:** `DataHash` 1.7.1's hash of each input in `StructHashTest.inputs()`, written under Java. Add an input only with a hash from that `DataHash`: the tag `datahash-1.7.1-nojava` holds it.

This repo does not follow the File Exchange entry, whose later versions (1.9.0 on) are a rewrite by another maintainer and report hash version 5.

## License

BSD, as `DataHash` (`license.txt`, Jan Simon's notice kept).
