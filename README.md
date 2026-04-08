# VEMU

(systemVerilog EMUlator)

There are currently two cores; a Gameboy emulator and a Gameboy Advance emulator

The Gameboy emulator is working. 

Here is the Gameboy Emulator simulated using Verilator.

![](./display.gif)

Note: the gif is sped up 8 times.

So progress.

The GBA emulator is WIP. The ARM7TMDI is mostly working (`thumb/swi` still needs to be implemented). The Peripherals still need to be implemented--notable the PPU.
