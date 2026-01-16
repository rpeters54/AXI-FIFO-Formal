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

## Running SymbiYosys

This repo comes with an included makefile to build and run the formal checks in axi_fifo_wrapper.v against all the fifo implementations.
The following commands are supported:
```bash
# to run bmc of all implementations
make formal

# to run bmc on a specific implementation
make formal/\<impl-name\>

# to run a specific job type (bmc, prove, cover) on a specific implementation
make formal/\<impl-name\> SBY_JOB_TYPE=\<job-name\>
```

## Tasks 

Your primary task is to complete the `axi_fifo_wrapper.sv` file in the `rtl/` directory.
Fill in the logic and assertions where \[TODO\] comments are present.

1. FIFO Bound Checks

The first FIFO seems to pass data properly but behaves illegally when full or empty.
To prove it is incorrect, we must demonstrate:
- The FIFO does not overflow (write when full) or underflow (read when empty).
- The write_count must be always greater than or equal to read_count.
- The difference between the write_count and read_count can not exceed the FIFO's capacity.

2. Data Integrity and AXI Compliance

This FIFO behaves normally for a while, but eventually starts outputting corrupted data.
To catch this bug we assert that data always passes through unaltered.
- Use the provided f_watch_id (an (* anyconst *) value) to track a specific arbitrary transaction.
- Capture data into f_shadow_data when it enters the FIFO at the write_count matching f_watch_id.
- Assert that when read_count matches f_watch_id, the output data m_axis_tdata matches f_shadow_data.

To behave in accordance with the AXI specification, we must also show valid data remains stable until it is read:
- If tvalid is high but tready is low, the data (tdata) and control signals must remain stable until the transaction occurs.

3. Liveness Checks

This FIFO doesn't do anything, which suprisingly does not break our previous assertions.
To prove this is invalid behavior, we need to show the FIFO attempts to make progress.
- If data is written, it should eventually be valid at the output.
- If the FIFO is not full, it should eventually be ready to accept new data.

4. (Optional) Unbounded Proof

The original proofs are only sufficient to pass a BMC.
To show the FIFO will always work, we need to strengthen the assertions and assumptions so the solver can not start induction in an invalid state.
For simplicity, these are included at the bottom of the file.
Uncomment these statements and verify that the reference axi_fifo passes the unbounded proof.

