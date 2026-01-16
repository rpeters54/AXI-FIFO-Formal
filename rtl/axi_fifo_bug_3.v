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

    // This one is potentially the trickiest
    // How can we show a FIFO that never accepts data is broken?

    assign s_axis_tready = 0;
    assign m_axis_tvalid = 0;
    assign m_axis_tdata  = 0;
    assign m_axis_tstrb  = 0;

`ifdef FORMAL

    //============//
    // Debug Port
    //============//

    assign dbg_axis_wptr  = 0;
    assign dbg_axis_rptr  = 0;
    assign dbg_axis_tdata = 0;
    assign dbg_axis_tstrb = 0;

`endif
endmodule
