

module packet_gen_formal #(
        parameter int DATA_W = 8,
        parameter int FRAME_LEN_BYTES = 60,
        parameter int NUM_FRAMES = 10

)(
        input logic ACLK,
        input logic ARESETN,

        input  logic  M_AXIS_TREADY,
        output logic [DATA_W-1:0] M_AXIS_TDATA,
        output logic  M_AXIS_TVALID,
        output logic M_AXIS_TLAST
        
        // Rest of AXI stream signals are not used for current demo
);

packet_gen #(
    .DATA_W(DATA_W),
    .FRAME_LEN_BYTES(FRAME_LEN_BYTES),
    .NUM_FRAMES(NUM_FRAMES)
)
dut
(
    .ACLK(ACLK),
    .ARESETN(ARESETN),
    .M_AXIS_TREADY(M_AXIS_TREADY),
    .M_AXIS_TDATA(M_AXIS_TDATA),
    .M_AXIS_TVALID(M_AXIS_TVALID),
    .M_AXIS_TLAST(M_AXIS_TLAST)
);


// Formal properties

    reg f_past_valid;

    initial f_past_valid = 0;
    always @(posedge ACLK) begin
        f_past_valid <= 1;
    end


    // Reset constraint: On very first cycle assume that reset must be active
    always @(*) begin
        if (!f_past_valid) begin
            assume(!ARESETN);
        end
    end

    


    // f_past_valid can also be used to handle initial value checks
    // Assertion is only checked for M_AXIS_TVALID only on clock cycles following first one
    // Verifies Rule 1 and Rule 4 according to https://zipcpu.com/blog/2021/08/28/axi-rules.html
    always @(posedge ACLK) begin
        if (!f_past_valid || $past(!ARESETN)) begin
            if (f_past_valid)
                assert(!M_AXIS_TVALID);
        end else if ($past(M_AXIS_TVALID && !M_AXIS_TREADY)) begin
            assert(M_AXIS_TVALID);
            assert($stable(M_AXIS_TDATA));
            assert($stable(M_AXIS_TLAST));
        end
    end

endmodule