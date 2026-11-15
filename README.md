# structhash

`structhash(data)` returns a 32-character hash of a MATLAB value. The same value always gives the same hash, on any machine. It is one file of plain MATLAB and needs no Java.

```matlab
structhash(struct(func='makeTone', args=struct(freq_hz=440, dur_s=2)))
% '83cfd2ae7305e393a44155e1d848a3e1'
```

I use it to name things by what made them: hash a struct holding a function's name and its arguments, and save the result in a folder with that hash. The same settings then always land in the same place.

- **Takes:** structs, cells, char, strings, logicals and real numbers, nested to any depth.
- **Field order does not matter.** Class and shape do: `1` and `int8(1)`, `[1 2]` and `[1;2]` hash differently.
- **Hashes must never change.** After any edit, run `runtests('tests')`.

Derived from [DataHash](https://www.mathworks.com/matlabcentral/fileexchange/31272-datahash) 1.7.1 by Jan Simon, and gives the same hashes as its defaults. BSD license (`license.txt`).
