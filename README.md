# WGPU Zig Playground

This repo exists to purely to play around with the Zig bindings of WGPU.

## Building

> [!WARNING]
> The build.zig file currently only supports MacOS and will fail on other systems

```console
$ git clone https://github.com/fwd-guidance/wgpu-zig-playground
$ cd wgpu-zig-playground
$ zig build run
```


## Demos

### Collatz:

This function/shader is responsible for calculating the Collatz stopping number of an array of positive integers.
For more info on the Collatz conjecture, see: [collatz-conjecture](https://en.wikipedia.org/wiki/Collatz_conjecture)


