# Architecture Notes

## Pipeline

The datapath is divided into five stages:

1. **IF:** PC and instruction fetch
2. **ID:** Decode, register read, immediate generation
3. **EX:** Forwarding, ALU operand selection, ALU operation
4. **MEM:** Store to data memory
5. **WB:** Register-file writeback

## Packed Pipeline Registers

### ID/EX (112 bits)

```text
[111:108] rs
[107:104] rt
[103:100] rd
[99:96]   opcode
[95:64]   data1
[63:32]   data2
[31:0]    immediate
```

### EX/MEM (73 bits)

```text
[72:69] rd
[68:65] opcode
[64:33] ALU result
[32:1]  store data
[0]     zero
```

### MEM/WB (40 bits)

```text
[39:36] rd
[35:32] opcode
[31:0]  ALU result
```

## Forwarding

```text
2'b00 → register-file value
2'b10 → EX/MEM result
2'b01 → MEM/WB result
```

EX/MEM takes priority over MEM/WB because it represents the more recent producer.

## Store Path

For `SW R1,12(R5)`:

- ALU input A = R5
- ALU input B = sign-extended immediate 12
- ALU result = memory address
- store data = R1
- MemWrite = 1
- RegWrite = 0

This is why store data must be carried through the EX/MEM register independently of the ALU result.

## Verification Result

The supplied testbench produces:

```text
R1     = 00000200
R7     = 0000162D
R8     = FFF4E9C2
MEM[5] = 00000200
MEM[8] = 00000200
```

These values match the expected calculations for the supplied test program.
