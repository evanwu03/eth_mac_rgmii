
module axis_fifo_formal #(
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

    // AXI4-Stream master output
    output logic m_axis_tlast,
    output logic m_axis_tvalid,
    output logic [DATA_W-1:0] m_axis_tdata,
    input logic m_axis_tready,

    output logic o_overflow,  // Overflow status
    output logic o_underflow  // Underflow status
);


axis_fifo #(
    .DATA_W(DATA_W),
    .FIFO_DEPTH(FIFO_DEPTH)
)
dut
(
    .i_clk(i_clk),
    .i_reset_n(i_reset_n),

    // AXI4-Stream slave input
    .s_axis_tlast(s_axis_tlast),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tready(s_axis_tready),

    // AXI4-Stream master output
    .m_axis_tlast(m_axis_tlast),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tready(m_axis_tready),

    .o_overflow(o_overflow),
    .o_underflow(o_underflow)
);


reg f_past_valid;

initial f_past_valid = 0;
always @(posedge i_clk) begin
    f_past_valid <= 1;
end


// Reset constraint: On very first cycle assume that reset must be active
// 
always @(*) begin
    if (!f_past_valid) begin
        assume(!i_reset_n);
    end
end


// Assertion is only checked for m_axis_tvalid only on clock cycles following first one
// Verifies Rule 1 and Rule 4 according to https://zipcpu.com/blog/2021/08/28/axi-rules.html
// 
always @(posedge i_clk) begin
    if (!f_past_valid || $past(!i_reset_n)) begin
        if (f_past_valid)
            assert(!m_axis_tvalid);
    end else if ($past(m_axis_tvalid && !m_axis_tready)) begin
        assert(m_axis_tvalid);
        assert($stable(m_axis_tdata));
        assert($stable(m_axis_tlast));
    end
end


endmodule
