
module axi_fifo_wrapper #(
    parameter XLEN      = 32,
    parameter DEPTH_EXP = 2
) (
    input                     s_aclk,
    input                     s_aresetn,

    input                     s_axis_tvalid,
    output                    s_axis_tready,

    input  [XLEN     - 1 : 0] s_axis_tdata,
    input  [XLEN / 8 - 1 : 0] s_axis_tstrb,

    input  [DEPTH_EXP -1 : 0] dbg_axis_addr,
    output [DEPTH_EXP    : 0] dbg_axis_wptr,
    output [DEPTH_EXP    : 0] dbg_axis_rptr,
    output [XLEN     - 1 : 0] dbg_axis_tdata,
    output [XLEN / 8 - 1 : 0] dbg_axis_tstrb,

    output                    m_axis_tvalid,
    input                     m_axis_tready,

    output [XLEN     - 1 : 0] m_axis_tdata,
    output [XLEN / 8 - 1 : 0] m_axis_tstrb
);

    axi_fifo #(
        .XLEN      (XLEN),
        .DEPTH_EXP (DEPTH_EXP)
    ) u_axi_fifo (
        // inputs
        .s_aclk         (s_aclk),
        .s_aresetn      (s_aresetn),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tstrb   (s_axis_tstrb),

        // necessary for prove mode assertions
        .dbg_axis_addr  (dbg_axis_addr),
        .dbg_axis_wptr  (dbg_axis_wptr),
        .dbg_axis_rptr  (dbg_axis_rptr),
        .dbg_axis_tdata (dbg_axis_tdata),
        .dbg_axis_tstrb (dbg_axis_tstrb),

        // outputs
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tready  (m_axis_tready),
        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tstrb   (m_axis_tstrb)
    );

    // valid signal (necessary for using $past operator)
    reg f_past_valid;
    initial                  f_past_valid  = 0;
    always @(posedge s_aclk) f_past_valid <= 1;
    always @(posedge s_aclk) if (!f_past_valid) assume (!s_aresetn);

    localparam MAX_ITEMS = 2 ** DEPTH_EXP;
    wire f_reading = m_axis_tvalid && m_axis_tready;
    wire f_writing = s_axis_tvalid && s_axis_tready;


    //===============================//
    // FIFO Bound Checks
    //===============================//

    // track the number of read and write transactions
    int write_count, read_count;

    // increment for each valid read/write transaction
    always @(posedge s_aclk) begin
        if (!s_aresetn) begin
            // [TODO] set the counters to zero
        end else begin
            // [TODO] if a read/write occurs increment the proper counter
            //        hint: use f_reading and f_writing
        end
    end

    int diff_count;
    always @(*) begin
        // [TODO] diff_count should track the difference between the number of
        // writes and reads
    end

    // fifo bound safety checks
    // HINT: you should use diff_count ONLY for these assertions
    always @(*) if (f_past_valid) begin
        // [TODO] if the queue is empty, the output should be invalid

        // [TODO] if the queue is full, the input should not be ready

        // [TODO] the queue should never allow reads when empty

        // [TODO] the queue should never accept writes when full
    end


    //===============================//
    // Data Integrity Checks
    //===============================//

    // tells the solver to select an arbitrary constant value
    (* anyconst *) int f_watch_id;

    // track arbitrary data as it passes through the fifo
    reg              f_shadow_valid;
    reg [XLEN-1:0]   f_shadow_data;
    reg [XLEN/8-1:0] f_shadow_strb;

    always @(posedge s_aclk) begin
        if (!s_aresetn) begin
            // [TODO] on reset, all shadows should be zero
        end else begin
            // [TODO] if the current write count matches the arbitrary index,
            //        save the inputs in the shadow registers
        end
    end

    // fifo data safety checks
    always @(posedge s_aclk) begin
        // [TODO] if we're reading, not resetting, and the read count matches
        //        the arbitrary index (f_watch_id), assert the output matches the shadow values
    end

    //===============================//
    // AXI Compliance Checks
    //===============================//

    // data must be stable between cycles if signal is valid, but not read
    always @(posedge s_aclk) if (f_past_valid) begin
        // [TODO] if the output was valid last cycle, no data was read, and no reset occured:
        //        data, strb, and valid should remain stable
    end

    //===============================//
    // Coverage Properties
    //===============================//

    always @(*) if (f_past_valid) begin
        // [TODO] add coverage properties for important cases
    end

    //===============================//
    // Liveness Checks
    //===============================//

    always @(posedge s_aclk) if (f_past_valid) begin
        // [TODO] if the fifo was written to, the output must be valid next cycle
    end

    always @(posedge s_aclk) if (f_past_valid) begin
        // [TODO] if the fifo is not full, the input should be ready
    end

    //==========================================//
    // Strengthening Assumptions and Assertions
    // (necessary for prove mode)
    //==========================================//

    /*
    // assume the read and write counter will not overflow
    always @(*) if (!f_past_valid) begin
        assume (write_count == 0);
        assume (read_count  == 0);
        assume (f_watch_id  == 0);
    end
    always @(*) begin
        assume (write_count >= 0);
        assume (read_count  >= 0);
        assume (f_watch_id  >= 0);
    end
    int f_watch_diff;
    always @(*) begin
        f_watch_diff = write_count - f_watch_id;
    end

    // ensure that data is properly placed inside the queue
    wire [DEPTH_EXP-1:0] internal_raddr = f_watch_id[DEPTH_EXP-1:0];
    always @(*) if (f_past_valid) begin
        assume(dbg_axis_addr == internal_raddr);

        if (f_watch_diff > 0 && f_watch_diff <= MAX_ITEMS) begin
            assert(dbg_axis_tdata == f_shadow_data);
            assert(dbg_axis_tstrb == f_shadow_strb);
        end

        assert(dbg_axis_wptr == write_count[DEPTH_EXP:0]);
        assert(dbg_axis_wptr - dbg_axis_rptr == diff_count[DEPTH_EXP:0]);
    end

    // ensure that the shadow value is only valid after
    // the location was written to 
    always @(*) if (f_past_valid) begin
        assert(f_watch_diff > 0 == f_shadow_valid); 
    end

    // dbg signal must mirror the output if read_count == watch_id
    always @(*) if (f_past_valid) begin
        if (m_axis_tvalid && (read_count == f_watch_id)) begin
             assert(m_axis_tdata == dbg_axis_tdata);
             assert(m_axis_tstrb == dbg_axis_tstrb);
        end
    end
    */

endmodule

