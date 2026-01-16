# AXI-Stream FIFO Formal Verification Assignment

## Overview:

This project involves the formal verification of a synchronous FIFO buffer with an AXI-Stream interface.
Your goal is to write SymbiYosys assertions to verify the correctness of the design and detect bugs in broken implementations.

The project includes a reference design (axi_fifo.v) and three buggy variants (axi_fifo_bug_*.v).
You will implement verification logic in a wrapper module to prove the golden design correct and catch the errors in the buggy designs.

## Dependencies:

To run the provided checks, you will require the following tools:

- Yosys: Open-source verilog synthesis tool
- SymbiYosys: Formal Verification driver program
- Boolector: SMT solver called by SymbiYosys to run checks

All of these are conveniently packaged with the Yosys OSS Design suite:
[Instructions Here](https://yosyshq.readthedocs.io/projects/yosys/en/0.40/getting_started/installation.html)

## 
