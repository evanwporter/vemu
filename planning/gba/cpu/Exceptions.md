While in an exception `CPSR` is restored from `SPSR` if and only if the following conditions are met:
1. CPU is in ARM mode (not THUMB mode)
2. Data processing instruction OR a LDM instruction
3. `Destination Register (Rd) == R15` (data proc) OR `reg_list[15] == 1` (LDM)
4. Current mode has an SPSR (FIQ, IRQ, SVC, ABT, UND)
5. `S bit == 1`