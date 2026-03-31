package gba_mmu_types_pkg;

  typedef enum logic {
    ARM_BUS_READ  = 1'b0,
    ARM_BUS_WRITE = 1'b1
  } bus_direction_t;

  typedef enum logic [1:0] {
    /// Byte (8-bit) transfer
    /// Uses addr[31:0]
    ARM_BUS_SIZE_BYTE = 2'b00,

    /// Halfword (16-bit) transfer
    /// Uses addr[31:1]
    ARM_BUS_SIZE_HALFWORD = 2'b01,

    /// Word (32-bit) transfer
    /// Uses addr[31:2]
    ARM_BUS_SIZE_WORD = 2'b10
  } bus_transfer_size_t;

  typedef enum logic {
    ARM_BUS_MODE_USER,
    ARM_BUS_MODE_PRIVILEGED
  } bus_transfer_access_t;

  typedef enum logic {
    ARM_BUS_OPCODE,
    ARM_BUS_DATA
  } bus_data_transfer_type_t;

endpackage : gba_mmu_types_pkg
