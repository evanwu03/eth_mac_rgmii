

module axis_rgmii_tx #(
 parameter  int DATA_W = 8
)(
    input logic i_clk,
    input logic i_rst_n,

    // Axis Interface
    input  logic [DATA_W-1:0]   s_axis_tdata,
    input  logic                s_axis_tvalid,
    input  logic                s_axis_tlast,
    output logic                s_axis_tready,

    output logic [DATA_W-1:0]   m_axis_tdata,
    output logic                m_axis_tvalid,
    output logic                m_axis_tlast,
    input  logic                m_axis_tready

);


// To Temporarily pass tests, remove once logic is written
assign s_axis_tready = 1'b1;


endmodule : axis_rgmii_tx