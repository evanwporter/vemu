interface GBA_Interrupt_if;

  logic vblank_req;
  logic hblank_req;

  logic vcounter_req;

  logic timer0_req;
  logic timer1_req;
  logic timer2_req;
  logic timer3_req;

  logic serial_req;

  logic dma0_req;
  logic dma1_req;
  logic dma2_req;
  logic dma3_req;

  logic keypad_req;

  logic gamepak_req;

  modport Handler_side(
      input vblank_req,
      input hblank_req,
      input vcounter_req,
      input timer0_req,
      input timer1_req,
      input timer2_req,
      input timer3_req,
      input serial_req,
      input dma0_req,
      input dma1_req,
      input dma2_req,
      input dma3_req,
      input keypad_req,
      input gamepak_req
  );


endinterface : GBA_Interrupt_if
