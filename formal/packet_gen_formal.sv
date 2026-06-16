

module packet_gen_formal #(
        parameter int DATA_W = 8,
        parameter int FRAME_LEN_BYTES = 60,
        parameter int NUM_FRAMES = 10

)(
        input logic i_clk,
        input logic i_reset_n,

        input  logic  m_axis_tready,
        output logic [DATA_W-1:0] m_axis_tdata,
        output logic  m_axis_tvalid,
        output logic m_axis_tlast
        
        // Rest of AXI stream signals are not used for current demo
);

packet_gen #(
    .DATA_W(DATA_W),
    .FRAME_LEN_BYTES(FRAME_LEN_BYTES),
    .NUM_FRAMES(NUM_FRAMES)
)
dut
(
    .i_clk(i_clk),
    .i_reset_n(i_reset_n),
    .m_axis_tready(m_axis_tready),
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tlast(m_axis_tlast)
);


// Formal properties

    reg f_past_valid;

    initial f_past_valid = 0;
    always @(posedge i_clk) begin
        f_past_valid <= 1;
    end


    // Reset constraint: On very first cycle assume that reset must be active
    always @(*) begin
        if (!f_past_valid) begin
            assume(!i_reset_n);
        end
    end

    


    // f_past_valid can also be used to handle initial value checks
    // Assertion is only checked for m_axis_tvalid only on clock cycles following first one
    // Verifies Rule 1 and Rule 4 according to https://zipcpu.com/blog/2021/08/28/axi-rules.html
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