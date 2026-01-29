# AXI-Stream FIFO Formal Verification Assignment

## Overview:

This project involves the formal verification of a synchronous FIFO buffer with an AXI-Stream interface.
Your goal is to write SymbiYosys assertions to verify the correctness of the design and detect bugs in broken implementations.

The project includes a reference design (axi_fifo.v) and three buggy variants (axi_fifo_bug_*.v).
You will implement verification logic in a wrapper module to prove the golden design correct and catch the errors in the buggy designs.

## Goals:

This assignment provides a simple overview of using the SBY formal verification tool to prove correctness for verilog designs.
It was designed with the following goals in mind:

1. Provide hands on experience crafting assertions, assumptions, and cover properties for a design.
2. Teach safety and liveness properties, and show how both are necessary for a design to be "correct."
3. Introduce (\* anyconst \*) and (\* anyseq \*) shadow logic for verifying data transactions.
4. Gain experience with the \$past function to create assertions that rely on previous states.
5. Understand how properties for a bmc must be strengthened to inductively prove a design.

## Dependencies:

To run the provided checks, you will require the following tools:

- Yosys: Open-source verilog synthesis tool
- SymbiYosys: Formal Verification driver program
- Boolector: SMT solver called by SymbiYosys to run checks

You can run these using the provided Dockerfile, or install them natively.

### Running with Docker

The repository includes a Dockerfile that will download and build all the dependencies you need to run the assignment.
If you do not have Docker, you can install the Docker Desktop tool [HERE](https://docs.docker.com/desktop/).
*Note: the installation options are at the bottom of the page under the "Next Steps" heading.*

After you download and install Docker Desktop, run the app to start the Docker Daemon. This needs to be active for Docker containers to run.

You can then build and enter the Docker container using the following commands:
```bash
# This builds the docker container
docker build -t riscv-verification-env .

# This starts the docker container
docker run -it -v $(pwd):/assignment riscv-verification-env

# To exit the docker container run:
exit
```

Once inside the Docker container, you should have all the necessary dependencies to run the lab.

### Native Installation

If you want to install these tools natively, the Yosys OSS-CAD Suite includes tar files with all the necessary executables.
Note: this is less likely to work that the Docker container since the tools you use may have different versions that those collected by the container.

[Installation Instructions Here](https://yosyshq.readthedocs.io/projects/yosys/en/0.40/getting_started/installation.html)

## Running SymbiYosys

This repo comes with an included makefile to build and run the formal checks in axi_fifo_wrapper.v against all the fifo implementations.
The following commands are supported:
```bash
# to run bmc of all implementations
make formal

# to run bmc on a specific implementation
make formal/impl-name

# to run a specific job type (bmc, prove, cover) on a specific implementation
make formal/impl-name SBY_JOB_TYPE=job-name
```

## Getting Started 

Your task is to complete the `axi_fifo_wrapper.sv` file in the `rtl/` directory.
Fill in the logic and assertions where \[TODO\] comments are present.
To progress to the next step, running a bmc should fail on the bugged model, but pass on the reference.
If at any point you get stuck, the `key` directory contains a reference implementation.

## Tasks

### 0. Background

Before adding any code, it is important to understand what the existing skeleton code does.
The most important block is included below:

```verilog
reg f_past_valid;
initial                  f_past_valid  = 0;
always @(posedge s_aclk) f_past_valid <= 1;
always @(*)              if (!f_past_valid) assume (!s_aresetn);
```

This block includes an `assume` directive.
When encountered by the SBY solver, `assume` tells it that the contents of the parenthesis must evaluate to true.
The solver is restricted from selecting values that cause an `assume` to be false.
**Beware of unnecessary/invalid asssumptions! Adding an assumption that is not correct makes the resulting proof meaningless.**

For the time being you can ignore the `f_past_valid`, and focus only on the reset assumption.
Simply put, the final statement assumes that the first cycle of the check resets the device.
This is almost always necessary for any formal checks, as it allows the solver to start in a valid state.
If this were not included, the solver could initialize the FIFO to an illegal state that would never occur in actual use.
With that established, we can move on to the main tasks.

### 1. FIFO Bound Checks

The first FIFO (`rtl/axi_fifo_bug_1.v`) seems to pass data properly but behaves illegally when full or empty.
To prove this is incorrect, we can track reads and writes to the FIFO using a set of counters.
Based on these counters, we can add assertions to verify whether or not the FIFO behaves properly.

When running sby in bmc mode, the `assert` function establishes what outputs/state are illegal.
If the solver finds a way to make the input to an `assert` false, the bmc fails and returns a .VCD trace of the steps that lead to failure.
By adding assertions to track the movement of the counters, we can be certain that the FIFO never underflows or overflows.

```verilog
// If condition_1 or condition_2 are ever false, bmc will fail
always @(*) begin
    assert(condition_1 && condition_2);
end
```

**TODO**

Build the counters and add four sets of assertions to prove the following:
- The FIFO does not overflow (write when full) 
- The FIFO does not underflow (read when empty).
- The difference between the write_count and read_count can never be negative.
- The difference between the write_count and read_count can not exceed the FIFO's capacity.

### 2. Data Integrity and AXI Compliance

The second FIFO (`rtl/axi_fifo_bug_2.v`) behaves normally for a while, but eventually starts outputting corrupted data.
To catch this bug we must prove that data always passes through unaltered.

#### Task 1:

The standard method to verify data integrity is to choose an arbitrary data transaction and prove that the read and write data matches.
To handle the selection SBY provides the (\* anyconst \*) and (\* anyseq \*) modifiers.
When applied to a variable, (\* anyconst \*) tells the solver it can pick any value, but that value must remain constant from cycle 0 to N of the bmc.
(\* anyseq \*) provides a bit more flexibility, allowing the solver to change the variables value each cycle of the check.
In our case, since we want to track a single transaction from start to finish, (\* anyconst \*) is the proper keyword.

**TODO**

The testbench includes a few variables that are needed before setting up any assertions.
You are expected to use the provided f_watch_id (an (\* anyconst \*) value) to track a specific arbitrary transaction.
Using f_watch_id, store the relevant write into the shadow variables, and later compare those saved items to the data read from the FIFO:
- Capture data into f_shadow_data when it enters the FIFO at the write_count matching f_watch_id.
- Assert that when read_count matches f_watch_id, the output data m_axis_tdata matches f_shadow_data.

#### Task 2:

Additionally, the AXI specification expects that when data is output, it remains stable until read.
This requires tracking behavior across multiple cycles.
SBY provides the \$past function to retrieve the data for an expression from the previous cycle.
You can also specify a number of cycles 'N' into the past, but that is not necessary for this assignment.

Before using \$past, you must ensure the past is valid.
During the first cycle, if you have a check that uses the \$past operator, the value returned by \$past is undefined.
As a result, the solver is free to select whatever value it wants to, often breaking the assertions.
Thus, any statement that uses \$past should have a precondition that checks if that number of cycles has occured.

For example:
```verilog
reg f_past_valid;
initial                  f_past_valid  = 0;
always @(posedge s_aclk) f_past_valid <= 1;
always @(*)              if (!f_past_valid) assume (!s_aresetn);

always @(*) begin
    // INVALID
    // $past can not be used in unclocked blocks
end


always @(posedge s_aclk) begin
    // INVALID
    // $past will return an undefined value on the first cycle
end

always @(posedge s_aclk) if (f_past_valid) begin
    // VALID
    // $past is safe to use here

    // NOTE: This is only safe for one cycle into the past.
    // If you want to look more than one cycle into the past,
    // you must update f_past_valid to only be true after that many cycles.
end
```

**TODO**

Now that we can use \$past, add the following assertion:
- If last cycle was not a reset, tvalid was high, and tready was low, the data (tdata) and control signals must be the same this cycle as they were the previous.

### 3. Liveness Checks

The third FIFO (`rtl/axi_fifo_bug_3.v`) doesn't do anything, which suprisingly does not break our previous assertions.

In fact, our current assertions are safety properties; they prove that the system can never reach an invalid state.
A device that does absolutely nothing is technically safe. To show that the device *must* do something eventually, we need liveness properties.

#### Task 1:

We can use cover statements to quickly show that FIFO can never send or receive data to be sure that it is broken.
Cover statements task the solver with finding a sequence of inputs that lead to some value being true.

For example:

```verilog
always @(*) begin
    cover(condition_1 && condition_2);
end
```

When sby is run in cover mode, it will try to find a way to make condition\_1 and condition\_2 true.
If it can find a path, the cover run will return a .VCD trace that shows the way to reach this condition.
Otherwise, the solver will return that this state is unreachable.
For our case, we simply want to show that the FIFO can never write nor read.

**TODO**

Add some cover statements that check if the FIFO can send and receive data, and run a cover check on the reference and bugged FIFO.

> [!TIP]
```bash
# To run "cover" on the bugged FIFO:
make formal/fv_axi_fifo_bug_3 SBY_JOB_TYPE=cover

# To run "cover" on the reference:
make formal/fv_axi_fifo SBY_JOB_TYPE=cover
```

#### Task 2:

Covers are exceptionally useful for finding simple deadlocks, but they are not sufficient to prove liveness.
For instance, a broken FIFO could send and receive one packet of data before halting.
A 'live' system must run forever without halting.
To prove the liveness property always holds, we must add some additional assertions.
In this case, we need to show the FIFO attempts to make progress.

**TODO**

Add two sets of assertions to prove the following:
- If data is written, it should eventually be valid at the output.
- If the FIFO is not full, it should eventually be ready to accept new data.

### 4. Extending BMC to an Unbounded Proof

Even though we have proven that the FIFO should behave correctly, trying to run an unbounded inductive proof on the reference model will fail as-is.
This is not because the reference implementation is wrong. Instead, the error is caused by the solver selecting unreachable states during induction.
During a proof of induction, the solver selects a series of N states that behave according to our assertions, before checking if the assertions hold in the N + 1 state.
Unlike the bounded model check, where we force the first cycle to reset, induction does not necessarily start at cycle 0.

This leads to three main issues with our FIFO checks:
- The solver can select a state when the read/write counts are out of sync with the internal read/write pointers
- The solver can choose data points that overflow counters into the negatives, causing the checks to fail
- The solver can have the shadow logic become valid at the improper time.

To show the FIFO will always work, we must strengthen the assertions and assumptions so the solver can not start induction in an invalid state.
This requires adding some extra debugging signals that expose the values of the FIFO's read and write pointers, as well as the FIFO's internal memory.
With those values, we can include new assertions that bind our counters and shadow logic to the FIFO's internal state.

**TODO**

For simplicity, all the checks are included at the bottom of the file.
Uncomment these statements and verify that the reference axi_fifo passes the unbounded proof.

> [!TIP]
```bash
# To run "proof" on the reference:
make formal/fv_axi_fifo SBY_JOB_TYPE=prove
```

