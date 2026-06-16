// Author: Evan Wu
// Date: 6/16/2026s

`default_nettype none


module axis_fifo #(
    parameter int DATA_W = 8,
    parameter int FIFO_DEPTH = 64
) (
    input logic i_clk,
    input logic i_reset_n,

    // AXI4-Stream slave input
    input logic s_axis_tlast,
    input logic s_axis_tvalid,
    input logic [DATA_W-1:0] s_axis_tdata,
    output logic s_axis_tready,

    // AXI4-STream master output
    output logic m_axis_tlast,
    output logic m_axis_tvalid,
    output logic m_axis_tdata,
    input logic m_axis_tready
);


endmodule