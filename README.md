# 32-bit 5-Stage Pipelined RISC-Style Processor

A Verilog RTL implementation of a small 32-bit RISC-style processor with a classic five-stage pipeline, data forwarding, hazard detection infrastructure, register file, instruction memory, and data memory.

> **Project status:** Functionally verified in simulation and organized as synthesizable-oriented RTL. The current instruction set is intentionally small and custom; it is RISC-style rather than a complete standard RISC-V ISA implementation.

## Architecture

The processor uses the classic five pipeline stages:

```text
IF → ID → EX → MEM → WB
```

- **IF (Instruction Fetch):** Program counter and instruction memory
- **ID (Instruction Decode):** Instruction decoding, register-file reads, immediate generation
- **EX (Execute):** Forwarding, ALU input selection, ALU operation, address calculation
- **MEM (Memory):** Data-memory stores
- **WB (Writeback):** Write ALU results back to the register file

Pipeline registers separate the stages:

```text
IF → IF/ID → ID → ID/EX → EX → EX/MEM → MEM → MEM/WB → WB
```

## Key Features

- 32-bit datapath
- Five-stage in-order pipeline
- 16 × 32-bit register file
- Custom 32-bit instruction format
- Combinational instruction ROM
- Synchronous data-memory writes
- RAW data-hazard handling through forwarding
- Load-use hazard detection infrastructure
- Synchronous active-high reset
- Directed simulation testbench with waveform and final-state checks

## Instruction Format

Each instruction is 32 bits:

```text
31      28 27    24 23    20 19    16 15                    0
┌─────────┬────────┬────────┬────────┬────────────────────────┐
│ opcode  │   rd   │  rs1   │  rs2   │      immediate         │
│  4 bits │ 4 bits │ 4 bits │ 4 bits │       16 bits          │
└─────────┴────────┴────────┴────────┴────────────────────────┘
```

The current test program uses these opcode encodings:

| Opcode | Operation | ALU source | RegWrite | MemWrite |
|---|---|---|---|---|
| `0000` | AND | Register | Yes | No |
| `0001` | ORI | Immediate | Yes | No |
| `0010` | SW | Immediate | No | Yes |
| `0100` | SW | Immediate | No | Yes |
| `1111` | NOR | Register | Yes | No |

This is a small custom ISA subset and should not be interpreted as a full implementation of the standard RISC-V ISA.

## Pipeline Dataflow

### IF
The PC addresses instruction memory and the next PC is generated using:

```text
PC_next = PC + 4
```

### ID
The instruction is split into opcode/register/immediate fields. The register file supplies two read operands and the immediate is sign-extended to 32 bits.

### EX
The forwarding unit selects the newest available register value for each ALU operand. A 2:1 ALUSrc mux selects either the forwarded register operand or the immediate.

### MEM
Store instructions use the ALU result as the memory address and carry store data separately through the EX/MEM pipeline register.

### WB
For register-producing instructions, the MEM/WB result is written to the destination register.

## Hazard Handling

### Data Forwarding

The forwarding unit checks the EX/MEM and MEM/WB stages before falling back to the register-file value.

Current forwarding encoding:

- `2'b00` → register-file value
- `2'b10` → EX/MEM result
- `2'b01` → MEM/WB result

EX/MEM has priority because it contains the newer value when both later stages match the same source register.

### Hazard Detection

The design also contains load-use hazard detection logic that can:

- freeze the PC
- freeze the IF/ID register
- flush ID/EX to create a bubble

The current instruction set does not implement a load instruction, so `id_ex_memread` is tied low and the stall path is not exercised by the supplied program.

## Test Program

The instruction ROM contains:

```text
AND R1, R2, R3
SW  R1, 0(R5)
SW  R1, 12(R5)
ORI R7, R1, 0x162D
NOR R8, R7, R9
```

Reset initializes selected registers to known values:

```text
R2 = 0x0001234A
R3 = 0x000A1234
R5 = 0x00000016
R9 = 0x000B1234
```

Expected calculations:

```text
R1 = R2 & R3
   = 0x00000200

MEM[5] = 0x00000200

MEM[8] = 0x00000200

R7 = R1 | 0x162D
   = 0x0000162D

R8 = ~(R7 | R9)
   = 0xFFF4E9C2
```

## Verification

The supplied testbench:

1. Generates a 100 MHz simulation clock.
2. Applies reset for 20 ns.
3. Runs the processor for 50 rising clock edges.
4. Prints the final register and data-memory contents.
5. Can be inspected with a waveform viewer.

Verified simulation results:

```text
R1     = 00000200
R7     = 0000162D
R8     = FFF4E9C2
MEM[5] = 00000200
MEM[8] = 00000200
```

The program also exercises RAW dependencies such as:

```text
AND → SW
AND → SW
AND → ORI
ORI → NOR
```

which makes the forwarding logic observable in simulation.

## Repository Structure

```text
.
├── README.md
├── rtl/
│   └── risc_processor.v
├── tb/
│   └── tb_top.v
└── docs/
    └── architecture.md
```

## How to Simulate

The RTL can be simulated with a Verilog/SystemVerilog simulator such as Vivado Simulator, Icarus Verilog, or another compatible simulator.

Compile:

```text
rtl/risc_processor.v
tb/tb_top.v
```

Run the testbench and check the final-state output against the expected values above.

## Scope and Limitations

This project is intentionally small and educational.

- The ISA is a custom RISC-style subset, not a complete RISC-V implementation.
- No load instruction is implemented.
- No branch/jump unit is implemented.
- The supplied program is a directed verification workload rather than an exhaustive verification environment.
- The current focus is datapath, pipelining, forwarding, hazard infrastructure, RTL structure, and simulation.

## Interview Topics Covered

This project provides a concrete example for discussing:

- Five-stage pipelining
- Pipeline registers
- RAW hazards
- Data forwarding
- Load-use hazard detection
- Combinational vs sequential RTL
- Blocking vs non-blocking assignments
- Register files and memories
- Immediate generation
- ALU input multiplexing
- Synchronous reset
- Directed verification and waveform debugging

## Author

**Aadith Reddy**

Electrical & Electronics Engineering, BITS Pilani Hyderabad Campus
