    // Author: Evan Wu
    // Date of Revision: 6/15/2026

    `timescale 1ns / 1ps
    `default_nettype none

    /* verilator lint_off WIDTHEXPAND */

    // Notes to self:
    // AXI Stream master
    // Generates a fixed 60 byte ethernet frame (minus the FCS which is appended by the ethernet MAC)

    module packet_gen #(
        parameter int DATA_W = 8,
        parameter int FRAME_LEN_BYTES = 60,
        parameter int NUM_FRAMES = 10

    ) (
        input logic ACLK,
        input logic ARESETN,

        input  logic  M_AXIS_TREADY,
        output logic [DATA_W-1:0] M_AXIS_TDATA,
        output logic  M_AXIS_TVALID,
        output logic M_AXIS_TLAST
        
        // Rest of AXI stream signals are not used for current demo
    );

    localparam int COUNT_W = $clog2(FRAME_LEN_BYTES);
    localparam int FRAME_COUNT_W = $clog2(NUM_FRAMES + 1);


    logic [DATA_W-1:0] frame [0:FRAME_LEN_BYTES-1];
    logic [COUNT_W-1:0] byte_count;
    logic [COUNT_W-1:0] load_byte_count;
    logic [FRAME_COUNT_W-1:0] frame_count;


    logic [DATA_W-1:0] next_data;
    logic next_valid;


    assign next_valid = (frame_count < NUM_FRAMES);




// Prepare the next byte
always_comb begin
    load_byte_count = byte_count;

    if (!M_AXIS_TVALID) begin
        // Output register is empty. Load first byte.
        load_byte_count = '0;
    end
    else if (M_AXIS_TVALID && M_AXIS_TREADY && M_AXIS_TLAST) begin
        // Last byte was accepted. Next frame starts at byte 0.
        load_byte_count = '0;
    end
    else if (M_AXIS_TVALID && M_AXIS_TREADY) begin
        // Current byte was accepted. Load next byte.
        load_byte_count = byte_count + 1'b1;
    end
end

    // Generate packet
    always_comb begin
        unique case (load_byte_count)
            // Destination MAC: ff:ff:ff:ff:ff:ff
            0:  next_data = 8'hff;
            1:  next_data = 8'hff;
            2:  next_data = 8'hff;
            3:  next_data = 8'hff;
            4:  next_data = 8'hff;
            5:  next_data = 8'hff;

            // Source MAC: 02:00:00:00:00:01
            6:  next_data = 8'h02;
            7:  next_data = 8'h00;
            8:  next_data = 8'h00;
            9:  next_data = 8'h00;
            10: next_data = 8'h00;
            11: next_data = 8'h01;

            // EtherType: 0x88B5
            12: next_data = 8'h88;
            13: next_data = 8'hb5;

            // Payload starts at frame_count
            default: next_data = DATA_W'(frame_count);
        endcase
    end


    // Update TVALID & TLAST
    always_ff @(posedge ACLK) begin
        
        if (!ARESETN) begin
            
            M_AXIS_TVALID <= 0;
        end
        else if (!M_AXIS_TVALID || M_AXIS_TREADY) begin
            M_AXIS_TVALID <= next_valid;
        end
    end

    // Upadte data
    always_ff @(posedge ACLK) begin
        if(!ARESETN) begin
            M_AXIS_TLAST  <= 0;
            M_AXIS_TDATA <= '0;
        end
        else if (!M_AXIS_TVALID || M_AXIS_TREADY) begin

            M_AXIS_TDATA <= next_data;
            // Frame is finished sending after 60 bytes are sent
            M_AXIS_TLAST <= (load_byte_count == FRAME_LEN_BYTES -1);
        
            if (!next_valid) begin
                M_AXIS_TDATA <= '0;
            end
        end
    end

    // Frame and Byte counter logic
    always_ff @(posedge ACLK) begin
        if (!ARESETN) begin
            byte_count <= '0;
            frame_count <= '0;
        end
        else if (M_AXIS_TVALID && M_AXIS_TREADY)

            if (M_AXIS_TLAST) begin
                byte_count <= '0;

                // Count up to NUM_FRAMES and stop
                if (frame_count < NUM_FRAMES) begin
                    frame_count <= frame_count + 1'b1;
                end

            end else begin
                byte_count <= byte_count + 1;
            end
    end


    // IRule 2:  Frame counter and byte counter should update
    // when M_AXIS_TVALID && M_AXIS_READY
    `ifdef FORMAL
        logic f_past_valid;
        initial f_past_valid = 1'b0;

        always @(posedge ACLK) begin
            f_past_valid <= 1'b1;
        end

        always @(posedge ACLK) begin
            if (f_past_valid && $past(ARESETN) && ARESETN) begin
                if (!$past(M_AXIS_TVALID && M_AXIS_TREADY))
                    assert(byte_count == $past(byte_count));

                if (!$past(M_AXIS_TVALID && M_AXIS_TREADY && M_AXIS_TLAST))
                    assert(frame_count == $past(frame_count));
            end
        end
    `endif

endmodule : packet_gen