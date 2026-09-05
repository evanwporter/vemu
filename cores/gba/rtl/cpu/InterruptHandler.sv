import gba_types_pkg::*;
import gba_mmu_types_pkg::*;

module GBA_InterruptHandler (
    input logic clk,
    input logic reset,
    GBA_Interrupt_if.Handler_side interrupt_bus,
    output logic irq,
    GBA_Bus_if.Slave_side bus
);
  /**
  4000208h - IME - Interrupt Master Enable Register (R/W)

    Bit   Expl.
    0     Disable all interrupts         (0=Disable All, 1=See IE register)
    1-31  Not used


  4000200h - IE - Interrupt Enable Register (R/W)

    Bit   Expl.
    0     LCD V-Blank                    (0=Disable)
    1     LCD H-Blank                    (etc.)
    2     LCD V-Counter Match            (etc.)
    3     Timer 0 Overflow               (etc.)
    4     Timer 1 Overflow               (etc.)
    5     Timer 2 Overflow               (etc.)
    6     Timer 3 Overflow               (etc.)
    7     Serial Communication           (etc.)
    8     DMA 0                          (etc.)
    9     DMA 1                          (etc.)
    10    DMA 2                          (etc.)
    11    DMA 3                          (etc.)
    12    Keypad                         (etc.)
    13    Game Pak (external IRQ source) (etc.)
    14-15 Not used

  Note that there is another 'master enable flag' directly in the CPUs Status Register (CPSR) accessible in privileged modes, see CPU reference for details.

  4000202h - IF - Interrupt Request Flags / IRQ Acknowledge (R/W, see below)

    Bit   Expl.
    0     LCD V-Blank                    (1=Request Interrupt)
    1     LCD H-Blank                    (etc.)
    2     LCD V-Counter Match            (etc.)
    3     Timer 0 Overflow               (etc.)
    4     Timer 1 Overflow               (etc.)
    5     Timer 2 Overflow               (etc.)
    6     Timer 3 Overflow               (etc.)
    7     Serial Communication           (etc.)
    8     DMA 0                          (etc.)
    9     DMA 1                          (etc.)
    10    DMA 2                          (etc.)
    11    DMA 3                          (etc.)
    12    Keypad                         (etc.)
    13    Game Pak (external IRQ source) (etc.)
    14-15 Not used
**/

  localparam word_t IE_ADDR = 32'h0400_0200;
  localparam word_t IF_ADDR = 32'h0400_0202;
  localparam word_t IME_ADDR = 32'h0400_0208;

  // Interrupt Enable
  logic [13:0] IE;

  /// Interrupt Request Flags
  /// Interrupts must be acknoledged by writing a 1 to the corresponding bit in this register.
  logic [13:0] IF;
  logic IME;

  assign irq = IME && |(IE & IF);

  wire [13:0] interrupt_requests = {
    interrupt_bus.gamepak_req,
    interrupt_bus.keypad_req,
    interrupt_bus.dma3_req,
    interrupt_bus.dma2_req,
    interrupt_bus.dma1_req,
    interrupt_bus.dma0_req,
    interrupt_bus.serial_req,
    interrupt_bus.timer3_req,
    interrupt_bus.timer2_req,
    interrupt_bus.timer1_req,
    interrupt_bus.timer0_req,
    interrupt_bus.vcounter_req,
    interrupt_bus.hblank_req,
    interrupt_bus.vblank_req
  };

  //-------------------------------
  // Read Logic
  //-------------------------------

  function automatic logic [7:0] read_byte(input word_t addr);
    case (addr)
      IE_ADDR:     read_byte = IE[7:0];
      IE_ADDR + 1: read_byte = {2'b0, IE[13:8]};
      IF_ADDR:     read_byte = IF[7:0];
      IF_ADDR + 1: read_byte = {2'b0, IF[13:8]};
      IME_ADDR:    read_byte = {7'b0, IME};
      default:     read_byte = 8'h00;
    endcase
  endfunction

  always_comb begin
    bus.rdata = 32'h0000_0000;
    if (bus.read_en) begin
      bus.rdata = {
        read_byte(bus.addr + 3),
        read_byte(bus.addr + 2),
        read_byte(bus.addr + 1),
        read_byte(bus.addr)
      };
    end
  end

  //-------------------------------
  // Write Logic
  //-------------------------------

  logic [13:0] enable_write_value;
  logic [13:0] enable_write_mask;
  logic [13:0] acknowledge_mask;
  logic master_write_value;
  logic master_write_enable;

  always_comb begin
    enable_write_value = '0;
    enable_write_mask = '0;
    acknowledge_mask = '0;
    master_write_value = 1'b0;
    master_write_enable = 1'b0;

    if (bus.write_en) begin
      case (bus.addr)
        IE_ADDR: begin
          enable_write_value[7:0] = bus.wdata[7:0];
          enable_write_mask[7:0]  = 8'hFF;
          if (bus.transfer_size != ARM_BUS_SIZE_BYTE) begin
            enable_write_value[13:8] = bus.wdata[13:8];
            enable_write_mask[13:8]  = 6'h3F;
          end
          if (bus.transfer_size == ARM_BUS_SIZE_WORD) acknowledge_mask = bus.wdata[29:16];
        end
        IE_ADDR + 1: begin
          enable_write_value[13:8] = bus.wdata[5:0];
          enable_write_mask[13:8]  = 6'h3F;
        end
        IF_ADDR: begin
          acknowledge_mask[7:0] = bus.wdata[7:0];
          if (bus.transfer_size != ARM_BUS_SIZE_BYTE) acknowledge_mask[13:8] = bus.wdata[13:8];
        end
        IF_ADDR + 1: acknowledge_mask[13:8] = bus.wdata[5:0];
        IME_ADDR: begin
          master_write_value  = bus.wdata[0];
          master_write_enable = 1'b1;
        end
        default: ;
      endcase
    end
  end

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      IE  <= 14'b0;
      IF  <= 14'b0;
      IME <= 1'b0;
    end else begin
      IE <= (IE & ~enable_write_mask) | (enable_write_value & enable_write_mask);
      // A source asserted during acknowledgement remains pending.
      IF <= (IF & ~acknowledge_mask) | interrupt_requests;
      if (master_write_enable) IME <= master_write_value;
    end
  end


endmodule : GBA_InterruptHandler
