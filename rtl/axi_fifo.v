module axi_fifo #(
    parameter XLEN      = 32,
    parameter DEPTH_EXP = 2
) (
    input                     s_aclk,
    input                     s_aresetn,

    input                     s_axis_tvalid,
    output                    s_axis_tready,

    input  [XLEN     - 1 : 0] s_axis_tdata,
    input  [XLEN / 8 - 1 : 0] s_axis_tstrb,

`ifdef FORMAL
    input  [DEPTH_EXP -1 : 0] dbg_axis_addr,
    output [DEPTH_EXP    : 0] dbg_axis_wptr,
    output [DEPTH_EXP    : 0] dbg_axis_rptr,
    output [XLEN     - 1 : 0] dbg_axis_tdata,
    output [XLEN / 8 - 1 : 0] dbg_axis_tstrb,
`endif

    output                    m_axis_tvalid,
    input                     m_axis_tready,

    output [XLEN     - 1 : 0] m_axis_tdata,
    output [XLEN / 8 - 1 : 0] m_axis_tstrb
);

    reg [XLEN     - 1 : 0] m_axis_tdata;
    reg [XLEN / 8 - 1 : 0] m_axis_tstrb;
    reg [DEPTH_EXP    : 0] w_fifo_wptr;
    reg [DEPTH_EXP    : 0] w_fifo_rptr, w_fifo_rptr_next;
    reg [XLEN     - 1 : 0] w_tdata_fifo [0 : 2 ** DEPTH_EXP - 1];
    reg [XLEN / 8 - 1 : 0] w_tstrb_fifo [0 : 2 ** DEPTH_EXP - 1];

    wire w_lower_eq = (w_fifo_wptr[DEPTH_EXP-1:0] == w_fifo_rptr[DEPTH_EXP-1:0]);
    wire w_upper_eq = (w_fifo_wptr[DEPTH_EXP]     == w_fifo_rptr[DEPTH_EXP]);
    wire w_empty    =  w_upper_eq && w_lower_eq;
    wire w_full     = !w_upper_eq && w_lower_eq;

    wire w_writing  = s_axis_tvalid && s_axis_tready;
    wire w_reading  = m_axis_tvalid && m_axis_tready;

    assign s_axis_tready = !w_full;
    assign m_axis_tvalid = !w_empty;

    //====================//
    // Write Port Manager
    //====================//

    always @(posedge s_aclk) begin
        if (!s_aresetn) begin
            w_fifo_wptr                              <= 0;
        end else if (w_writing) begin
            w_tdata_fifo[w_fifo_wptr[DEPTH_EXP-1:0]] <= s_axis_tdata;
            w_tstrb_fifo[w_fifo_wptr[DEPTH_EXP-1:0]] <= s_axis_tstrb;
            w_fifo_wptr                              <= w_fifo_wptr + 1;
        end
    end

    //===================//
    // Read Port Manager
    //===================//

    wire [DEPTH_EXP:0] w_rptr_plus_1 = w_fifo_rptr + 1;

    always @(posedge s_aclk) begin
        if (!s_aresetn) begin
            w_fifo_rptr  <= 0;
            m_axis_tdata <= 0;
            m_axis_tstrb <= 0;
        end else begin
            if (w_reading) begin
                w_fifo_rptr <= w_rptr_plus_1;
                if (w_writing && (w_fifo_wptr == w_rptr_plus_1)) begin
                    m_axis_tdata <= s_axis_tdata;
                    m_axis_tstrb <= s_axis_tstrb;
                end else begin
                    m_axis_tdata <= w_tdata_fifo[w_rptr_plus_1[DEPTH_EXP-1:0]];
                    m_axis_tstrb <= w_tstrb_fifo[w_rptr_plus_1[DEPTH_EXP-1:0]];
                end
            end else if (w_empty && w_writing) begin
                m_axis_tdata <= s_axis_tdata;
                m_axis_tstrb <= s_axis_tstrb;
            end
        end
    end

`ifdef FORMAL

    //============//
    // Debug Port
    //============//

    assign dbg_axis_wptr  = w_fifo_wptr;
    assign dbg_axis_rptr  = w_fifo_rptr;
    assign dbg_axis_tdata = w_tdata_fifo[dbg_axis_addr[DEPTH_EXP-1:0]];
    assign dbg_axis_tstrb = w_tstrb_fifo[dbg_axis_addr[DEPTH_EXP-1:0]];

`endif
endmodule
