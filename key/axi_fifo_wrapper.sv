
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

    wire f_reading = m_axis_tvalid && m_axis_tready;
    wire f_writing = s_axis_tvalid && s_axis_tready;


    //===============================//
    // FIFO Bound Checks
    //===============================//

    // track the number of read and write transactions
    reg [31:0] write_count;
    reg [31:0] read_count;

    // increment for each valid read/write transaction
    always @(posedge s_aclk) begin
        if (!s_aresetn) begin
            write_count <= 0;
            read_count  <= 0;
        end else begin
            if (f_writing) write_count <= write_count + 1;
            if (f_reading) read_count  <= read_count  + 1;
        end
    end

    // fifo bound safety checks
    always @(*) if (f_past_valid) begin
        if (write_count == read_count) 
            assert(!m_axis_tvalid);

        assert(write_count >= read_count);
        assert(write_count <= read_count + 2 ** DEPTH_EXP);
    end

    //===============================//
    // AXI Compliance Checks
    //===============================//

    // data must be stable between cycles if signal is valid, but not read
    always @(posedge s_aclk) if (f_past_valid) begin
        if ($past(s_aresetn) && $past(m_axis_tvalid) && !$past(m_axis_tready)) begin 
            assert($stable(m_axis_tvalid));
            assert($stable(m_axis_tdata));
            assert($stable(m_axis_tstrb));
        end
    end

    //===============================//
    // Data Integrity Checks
    //===============================//

    // tells the solver to select an arbitrary constant value
    (* anyconst *) reg [XLEN-1:0] f_watch_id;

    // track arbitrary data as it passes through the fifo
    reg              f_shadow_valid;
    reg [XLEN-1:0]   f_shadow_data;
    reg [XLEN/8-1:0] f_shadow_strb;

    always @(posedge s_aclk) begin
        if (!s_aresetn) begin
            f_shadow_valid <= 0;
            f_shadow_data  <= 0;
            f_shadow_strb  <= 0;
        end else begin
            if (f_writing && (write_count == f_watch_id)) begin
                f_shadow_valid <= 1;
                f_shadow_data  <= s_axis_tdata;
                f_shadow_strb  <= s_axis_tstrb;
            end
        end
    end

    // fifo data safety checks
    always @(posedge s_aclk) begin
        if (s_aresetn && f_reading) begin
            if (read_count == f_watch_id) begin
                assert(f_shadow_valid); 
                assert(m_axis_tdata == f_shadow_data); 
                assert(m_axis_tstrb == f_shadow_strb); 
            end
        end
    end

    //===============================//
    // Liveness Checks
    //===============================//

    // if the fifo was written to, the output must be valid next cycle
    always @(posedge s_aclk) if (f_past_valid) begin
        if ($past(s_aresetn) && $past(f_writing)) begin
            assert(m_axis_tvalid);
        end
    end

    // if the fifo is not full, the input should be ready
    always @(posedge s_aclk) if (f_past_valid) begin
        if (read_count + 2 ** DEPTH_EXP > write_count) begin
            assert(s_axis_tready);
        end
    end

    //==========================================//
    // Strengthening Assumptions and Assertions
    // (necessary for prove mode)
    //==========================================//

    // assume the read and write counter will not overflow
    always @(*) begin
        if (!f_past_valid) begin
            assume (write_count == 0);
            assume (read_count  == 0);
            assume (f_watch_id  == 0);
        end else begin
            assume (write_count < 32'hFFFF_FFFF - 2 ** DEPTH_EXP);
            assume (read_count  < 32'hFFFF_FFFF - 2 ** DEPTH_EXP);
            assume (f_watch_id  < 32'hFFFF_FFFF - 2 ** DEPTH_EXP);
        end
    end

    // ensure that data is properly placed inside the queue
    wire [DEPTH_EXP-1:0] internal_raddr = f_watch_id[DEPTH_EXP-1:0];
    always @(*) if (f_past_valid) begin
        assume(dbg_axis_addr == internal_raddr);

        if (write_count > f_watch_id && write_count <= f_watch_id + 2 ** DEPTH_EXP) begin
            assert(dbg_axis_tdata == f_shadow_data);
            assert(dbg_axis_tstrb == f_shadow_strb);
        end

        assert(dbg_axis_wptr == write_count[DEPTH_EXP:0]);
        assert(dbg_axis_wptr - dbg_axis_rptr == write_count[DEPTH_EXP:0] - read_count[DEPTH_EXP:0]);
    end

    // ensure that the shadow value is only valid after
    // the location was written to 
    always @(*) if (f_past_valid) begin
        if (write_count > f_watch_id) 
            assert(f_shadow_valid);
        if (write_count <= f_watch_id) 
            assert(!f_shadow_valid);
    end

    // dbg signal must mirror the output if read_count == watch_id
    always @(*) if (f_past_valid) begin
        if (m_axis_tvalid && (read_count == f_watch_id)) begin
             assert(m_axis_tdata == dbg_axis_tdata);
             assert(m_axis_tstrb == dbg_axis_tstrb);
        end
    end

    //===============================//
    // Coverage Properties
    //===============================//

    always @(*) if (f_past_valid) begin
        cover(f_reading);
        cover(f_writing);
        cover(f_reading && f_writing);
    end

endmodule

