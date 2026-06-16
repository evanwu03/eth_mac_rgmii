// Author: Evan Wu
// Date: 6/16/2026s

/* verilator lint_off WIDTHEXPAND */
/* verilator lint_off WIDTHTRUNC */

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

    // AXI4-Stream master output
    output logic m_axis_tlast,
    output logic m_axis_tvalid,
    output logic [DATA_W-1:0] m_axis_tdata,
    input logic m_axis_tready,

    output logic o_overflow,  // Overflow status
    output logic o_underflow  // Underflow status
);


// Check configuration
generate
    if ( (FIFO_DEPTH < 2) || ((FIFO_DEPTH & (FIFO_DEPTH-1)) != 0)) begin
        $error("Error: FIFO_DEPTH must be a power of 2 and at least 2");
    end
endgenerate

localparam ADDR_W = $clog2(FIFO_DEPTH);

logic [DATA_W-1:0] mem_tdata [0:FIFO_DEPTH-1];
logic mem_tlast [0:FIFO_DEPTH-1];
logic [ADDR_W:0] wr_addr; 
logic [ADDR_W:0] rd_addr;

logic fifo_full;
logic fifo_empty;

logic [ADDR_W-1:0] wr_next_addr;


logic [DATA_W-1:0] next_tdata;
logic next_tlast;
logic next_tvalid;


logic rd_en;
logic wr_en;

// Naive calculation as full and empty sit in the decision path 
assign wr_next_addr = wr_addr + 1'b1;

assign fifo_full = (wr_next_addr == rd_addr);
assign fifo_empty = (wr_addr == rd_addr);

assign rd_en = m_axis_tvalid && m_axis_tready;
assign wr_en = s_axis_tvalid && s_axis_tready;
assign next_tdata = mem_tdata[rd_addr[ADDR_W-1:0]];
assign next_tlast = mem_tlast[rd_addr[ADDR_W-1:0]];
assign next_tvalid = !fifo_empty; 

// slave TREADY logic
always_ff @(posedge i_clk) begin
    if (!i_reset_n) begin
        s_axis_tready <= 1'b0;        
    end else begin
        s_axis_tready <= !fifo_full;
    end
end


// Write logic
always_ff @(posedge i_clk) begin
    if(!i_reset_n) begin
        wr_addr <= '0;
        o_overflow <= 1'b0;
    end else if (wr_en) begin
        
        if (!fifo_full || rd_en) begin
            mem_tdata[wr_addr[ADDR_W-1:0]] <= s_axis_tdata;
            mem_tlast[wr_addr[ADDR_W-1:0]] <= s_axis_tlast;
            wr_addr <= (wr_addr + 1'b1);
        end else begin
            // overrun
            o_overflow <= 1'b1;
        end
    end
end

// Master TVALID logic
always @(posedge i_clk) begin
    if (!i_reset_n) begin
        m_axis_tvalid <= 1'b0;
    end else if (!m_axis_tvalid || m_axis_tready) begin
        m_axis_tvalid <= next_tvalid;
    end
end

// Read logic
always_ff @(posedge i_clk) begin
    if (!i_reset_n) begin
        o_underflow <= 1'b0;
    end
    if (!m_axis_tvalid || m_axis_tready) begin
        
        o_underflow <= 1'b0;

        if (!fifo_empty) begin
            m_axis_tdata <= next_tdata;
            m_axis_tlast <= next_tlast;
            rd_addr <= rd_addr + 1'b1;
        end else begin
            o_underflow <= 1'b1;
        end
    end
end


`ifdef FORMAL
// Verifies internal invariants

reg f_past_valid;

initial f_past_valid = 0;
always @(posedge i_clk) begin
    f_past_valid <= 1;
end

// AXI backpressure is not overflow
always @(posedge i_clk) begin
    if (f_past_valid && i_reset_n) begin
        if (s_axis_tvalid && !s_axis_tready) begin
            assert(!wr_en);
        end
    end
end


always @(posedge i_clk) begin
    if (f_past_valid && i_reset_n && $past(i_reset_n)) begin
        if ($past(fifo_full && !rd_en)) begin
            assert(!wr_en);
        end
    end
end

always @(posedge i_clk) begin
    if(f_past_valid && i_reset_n && $past(i_reset_n)) begin
        if(!m_axis_tvalid) begin
            assert(!rd_en);
        end
    end
end

// Formal Contract
// 
// If we write two arbitrary values in succession, you should be able to read those 
// same two values in succession some time later
//  
// 

logic [ADDR_W:0] f_fill;

logic f_wr = s_axis_tvalid && s_axis_tready;
logic f_rd = m_axis_tvalid && m_axis_tready;

assign f_fill = wr_addr - rd_addr;


(* anyconst *) logic [ADDR_W:0] f_first_addr;
               logic [ADDR_W:0] f_second_addr;


(* anyconst *) logic [DATA_W-1:0] f_first_data, f_second_data;

logic	f_first_addr_in_fifo,  f_first_in_fifo;
logic 	f_second_addr_in_fifo, f_second_in_fifo;
logic	[ADDR_W:0]	f_distance_to_first, f_distance_to_second;


always_comb begin
    f_second_addr = f_first_addr + 1'b1;
end

always_comb begin
    // unwrap by subtracting the distance to the read address
    f_distance_to_first = (f_first_addr - rd_addr);
    f_first_addr_in_fifo = 0;
    if ((f_fill != 0) && (f_distance_to_first < f_fill))
        f_first_addr_in_fifo = 1;
    else
        f_first_addr_in_fifo = 0;
end


always_comb begin
	begin
		f_distance_to_second = (f_second_addr - rd_addr);
		if ((f_fill != 0) && (f_distance_to_second < f_fill))
			f_second_addr_in_fifo = 1;
		else
			f_second_addr_in_fifo = 0;
	end
end

logic [1:0] f_state;
initial f_state = 2'b0;

always @(posedge i_clk) begin
    case(f_state)
    2'h0: 
        // IDLE state
        // Process starts when we write our first value to FIFO,
        // at the first of our chosen two addresses
        if (wr_en && (wr_addr == f_first_addr) && (s_axis_tdata == f_first_data)) begin
            f_state <= 2'h1;
        end 
    2'h1:
        // If we read the first value out at this stage, then abort our check
        if (rd_en && (rd_addr == f_first_addr)) begin
            f_state <= 2'h0;
        end else if (wr_en) begin
            // Otherwise if we write to the second value then move to the next state.
            // If it is the wrong value then abort the check
            f_state <= (s_axis_tdata == f_second_data) ? 2'h2: 2'h0;
        end
    2'h2:
        // Wait until we read the first value
        // back out of the fifo
        if (rd_en && rd_addr == f_first_addr) begin
            // Then move forward by one state
            f_state <= 2'h3;
        end
    
    2'h3:
        if (rd_en) begin
            f_state <= 2'h0;
        end
    endcase
end


always @(*)
	if (f_state == 2'b01)
	begin
		assert(f_first_addr_in_fifo);
		assert(mem_tdata[f_first_addr]
			== f_first_data);
		assert(wr_addr == f_second_addr);
	end

	always @(*)
	if (f_state == 2'b10)
	begin
		assert(f_first_addr_in_fifo);
		assert(mem_tdata[f_first_addr]
			== f_first_data);
		//
		assert(f_second_addr_in_fifo);
		assert(mem_tdata[f_second_addr]
			== f_second_data);

		if (rd_en && rd_addr == f_first_addr)
			assert(m_axis_tdata == f_first_data);
	end


	always @(*)
	if (f_state == 2'b11)
	begin
		assert(f_second_addr_in_fifo);
		assert(mem_tdata[f_second_addr]
			== f_second_data);

		assert(m_axis_tdata == f_second_data);
	end


`endif 

endmodule
