# Alignment
The thumb instruction set has a bunch of different ways that it might align the value when PC is involved.
- `LDR Rd,[PC,#nn]`where `PC = (($+4) AND NOT 2)`
- `ADD Rd,PC,#nn`; where `PC = (($+4) AND NOT 2)`

`$` is the current instruction address 
