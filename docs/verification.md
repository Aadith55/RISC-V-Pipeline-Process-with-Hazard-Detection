# Verification Notes

## Directed testbench

The current verification environment is intentionally small and directed. It drives the clock and reset, runs the fixed instruction sequence from instruction memory, and checks final architectural state.

### Clock

The testbench uses:

```verilog
forever #5 clk = ~clk;
```

This creates a 10 ns period, corresponding to 100 MHz in simulation.

### Reset

Reset is asserted for 20 ns and released before normal execution begins.

### Expected state

After the program completes:

```text
R1     = 0x00000200
R7     = 0x0000162D
R8     = 0xFFF4E9C2
MEM[5] = 0x00000200
MEM[8] = 0x00000200
```

## Hazard/forwarding coverage

The program deliberately includes dependent instructions:

```text
AND R1,R2,R3
SW  R1,0(R5)
SW  R1,12(R5)
ORI R7,R1,0x162D
NOR R8,R7,R9
```

These exercise RAW dependencies that require forwarding.

For example:

```text
AND R1,...   → produces R1
SW  R1,...   → consumes R1
```

The forwarding unit can select the EX/MEM ALU result instead of waiting for register-file writeback.

## Current verification scope

Verified:

- PC progression
- reset behavior
- register-file initialization
- AND operation
- ORI operation
- NOR operation
- store address calculation
- store data forwarding
- register writeback
- final data-memory contents

Not exhaustively verified:

- every possible instruction encoding
- invalid instructions
- load-use stalls
- all forwarding combinations
- memory boundary conditions
- arbitrary programs

The load-use hazard detector is present, but the current ISA has no load instruction, so its active stall path is not exercised by this test program.
