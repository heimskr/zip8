# ZIP-8

This is a [CHIP-8](https://en.wikipedia.org/wiki/CHIP-8) emulator written in Zig. It's designed to be portable through a minimal interface so that you can embed it on a variety of different platforms. Currently, there's a web wrapper which uses the code compiled to WebAssembly, and it also gets compiled to an Arduino library suitable for the RP2040 (or other Cortex-M0+ microcontrollers).

## Credits

The pony artwork in `pony.ch8` and `ponyhop.ch8` was done by Fayabella.

## Limitations

- Sound is not exposed via the C API.

## Demo

A WebAssembly demo is [hosted on GitHub Pages](https://190n.github.io/zip8/), running a Flappy Bird game that I wrote for CHIP-8. This supports display, timer, and input, but no sound yet. You can try some of the other ROMs too or upload your own

Both demo ROMs were developed using [Octo](https://github.com/JohnEarnest/Octo), an excellent CHIP-8 implementation with a built-in high-level assembler, and you can view the assembly source code in the `.8o` files inside `web-host/public`.

I've also gotten this running on the Raspberry Pi RP2040 microcontroller, using an [Adafruit Feather RP2040 DVI](https://www.adafruit.com/product/5710), [Earle F Philhower III's Arduino core](https://github.com/earlephilhower/arduino-pico), and [Adafruit's fork of PicoDVI](https://github.com/adafruit/PicoDVI). This version scales the CHIP-8's display up to 640x320, with black bars surrounding to fill 800x480, at 60Hz with an RP2040 overclocked to 295MHz. [Here is a video of that running!](https://cdn.discordapp.com/attachments/854614083345055745/1143692785032118282/PXL_20230822_234035511.TS.mp4)

## Usage

After cloning the repository, you can build everything (a WebAssembly library and an Arduino library ZIP for RP2040) with `zig build` and run the test suite (for your native architecture) with `zig build test`. Or you can use `zig build wasm` and `zig build arduino`, which also lets you tweak compilation options individually, i.e.:

```sh
$ zig build wasm -Doptimize=ReleaseSmall
$ zig build arduino -Doptimize=ReleaseFast
```

`zig build wasm` will output `zig-out/lib/zip8.wasm`, while `zig build arduino` gives you `zig-out/lib/libzip8.a` and `zig-out/lib/zip8.zip`. The ZIP file can be installed in an Arduino project (theoretically for any ARM chip, and optimized for Cortex-M0+, but I've only tested on RP2040) with `Sketch -> Include Library -> Add .ZIP Library...`.

For WASM, `ReleaseSmall` uses wasm-opt from the [binaryen](https://github.com/WebAssembly/binaryen) project, which you'll need to have installed. This produces (as of commit d8afd44) a binary of only 8,005 bytes! Other modes are much larger so I recommend using `ReleaseSmall` for WASM.

The WASM and Arduino libraries expose the interface in `src/zip8.h`. WASM also includes these two functions, helpful for when you need to pass pointers in the WASM address space:

```c
// Allocate enough memory for the ZIP-8 CPU structure
void *zip8CpuAlloc(void);
// Allocate an arbitrary amount of memory
void *wasmAlloc(size_t size);
```

You should also provide the function:

```c
void zip8Log(const char *text, size_t length);
```

to send log output to a suitable place. `text` points to a null-terminated string, but the length is provided as well.

## Structure

- `src`
	- `main.zig`: entrypoint; as the root file this is able to override Zig's `std.log` to go through the `zip8Log` callback.
	- `bindings.zig`: C ABI-compatible wrappers around most CPU functions.
	- `cpu.zig`: defines the structure representing a CPU, including registers, memory, and display.
	- `instruction.zig`: contains logic to decode an instruction and apply its effects to a CPU.
	- `zip8.h`: C API function declarations.
- `build.zig`: tells Zig how to compile everything and put together the Arduino library
- `library.properties`: configuration file telling the Arduino IDE how to use this library (this file gets bundled in the ZIP file)
- `web-host` contains a web application embedding the library:
	- `index.html` is the main page
	- `src/cpu.ts` is a JavaScript class wrapping a WebAssembly module running the ZIP-8 code
	- `src/main.ts` creates a CPU with a given ROM and handles input and drawing
	- `public` contains various ROMs (`.ch8` files) and in some cases their assembly source code (`.8o` files)
