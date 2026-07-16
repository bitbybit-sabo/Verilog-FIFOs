# Verilog FIFO Designs

This repository contains Verilog implementations of two commonly used FIFO (First-In First-Out) architectures:

- Synchronous FIFO
- Asynchronous FIFO

Both designs are parameterizable and have been verified using self-checking testbenches.

---

## Repository Structure

```
Verilog-FIFOs/
│
├── sync_fifo/
│   ├── rtl/
│   └── tb/
│
├── async_fifo/
│   ├── rtl/
│   └── tb/
│
└── README.md
```

---

# Synchronous FIFO

A single-clock FIFO where both read and write operations are driven by the same clock.

### Features

- Parameterizable data width
- Parameterizable FIFO depth
- Circular buffer implementation
- Binary read/write pointers
- Full and Empty flag generation using counters
- Asynchronous reset
- Self-checking testbench

---

# Asynchronous FIFO

A dual-clock FIFO intended for safe Clock Domain Crossing (CDC), allowing independent write and read clocks.

### Features

- Independent write and read clocks
- Binary pointers for memory addressing
- Gray-code pointers for clock domain crossing
- Two flip-flop synchronizers
- Parameterizable data width
- Parameterizable FIFO depth
- Full and Empty flag generation using pointers converted to synchronised gray code
- Asynchronous reset
- Self-checking verification testbench

---

# Verification

Both verifications employed self-checking scoreboards, directed test cases, and AI-assisted randomized stress-test generation to improve coverage across synchronous and asynchronous clock-domain scenarios.

The verification includes:

- Reset verification
- FIFO fill and drain
- Overflow handling
- Underflow handling
- Pointer wrap-around
- Randomized read/write operations
- Data integrity checking using a reference queue (scoreboard)

---

# Tools Used

- Verilog-2001
- SystemVerilog (Testbench)
- Icarus Verilog
- EDA Playground

---

# License

This project is released under the MIT License.
