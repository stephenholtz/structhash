# DataHash

Jan Simon's `DataHash` for MATLAB (File Exchange 31272, version 1.7.1 of 2019, hash version 4) with one change: MD5 works without a Java runtime. MATLAB R2026b ships without Java, and the original stops there with "DataHash needs Java."

The rig repos (`antenna-ephys-experiments`, `antenna-ldv-experiments`, `antenna-twop-experiments`) take it as the submodule `ext/DataHash` and name each stimulus's trial folder by its hash.

## What differs from the original

- **`DataHash.m`:** with no Java runtime and the method `MD5` (the default), the digest comes from `MD5Engine` instead of `java.security.MessageDigest`. The `base64` and `short` output formats use MATLAB's own encoder instead of Java's Apache codec. With Java, nothing changes. The other methods (SHA-1, SHA-256, ...) still need Java.
- **`MD5Engine.m`:** MD5 (RFC 1321) in plain MATLAB, with the two methods `DataHash` calls on Java's digest. It keeps every byte until the digest: fine for small structs, slow for large files.
- **`tests/`:** `FrozenHashTest` (hashes recorded from the unmodified original under Java), `MD5EngineTest` (RFC 1321's values, and Java's digest at every length across two block boundaries), `DataHashOptionsTest` (the examples in `DataHash`'s help, input types, output formats).

`uTest_DataHash.m` and `license.txt` are Jan Simon's, unchanged. His test needs Java, and on MATLAB R2025a it stops at its non-ASCII file case ("Failed: File access") with his unmodified `DataHash` too, so `tests/` is the suite to run.

## The rule

**A hash never changes.** Recorded data are filed by these hashes, so an edit that changes one is a bug. After any edit, run the tests both ways; a few are skipped in each, the ones that need Java or need it absent:

```
matlab -batch "results = runtests('tests'); disp(table(results)); assert(~any([results.Failed]))"
matlab -nojvm -batch "results = runtests('tests'); disp(table(results)); assert(~any([results.Failed]))"
```

This repo does not follow the File Exchange entry, whose later versions (1.9.0 on) are a rewrite by another maintainer and report hash version 5.

## License

BSD, Jan Simon's (`license.txt`); `MD5Engine.m` and the tests are under the same terms.
