import gba_types_pkg::*;
import gba_mmu_types_pkg::*;

/// MMU bus interface
/// Connects CPU to MMU, and MMU to peripherals.
/// CPU <--> MMU <--> Peripherals
///     BUS       BUS
/// Most data between the CPU and peripherals flows through this bus.
interface GBA_Bus_if;
  word_t addr;
  word_t wdata;
  word_t rdata;
  logic read_en;
  logic write_en;

  bus_transfer_size_t transfer_size;

  /// Bus master/router master: this connects to the Peripherals, and passes
  /// the CPU signals along to them, as well as gathering rdata from the Peripherals
  modport Master_side(output addr, wdata, read_en, write_en, transfer_size, input rdata);

  /// Peripherals (PPU/APU/etc.) are slaves: they listen to addr, write_en/read_en,
  /// and drive rdata when selected.
  modport Slave_side(input addr, wdata, read_en, write_en, transfer_size, output rdata);

endinterface
