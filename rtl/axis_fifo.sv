
`default_nettype none

module axis_fifo #(
    parameter int DATA_W     = 8,
    parameter int FIFO_DEPTH = 64,
    parameter int ADDR_W     = $clog2(FIFO_DEPTH)
) (
    input  logic                i_clk,
    input  logic                i_reset_n,

    input  logic [DATA_W-1:0]   s_axis_tdata,
    input  logic                s_axis_tvalid,
    input  logic                s_axis_tlast,
    output logic                s_axis_tready,

    output logic [DATA_W-1:0]   m_axis_tdata,
    output logic                m_axis_tvalid,
    output logic                m_axis_tlast,
    input  logic                m_axis_tready,

    output logic [ADDR_W:0]     o_fifo_count
);


    logic [DATA_W-1:0] mem_tdata [0:FIFO_DEPTH-1];
    logic              mem_tlast [0:FIFO_DEPTH-1];

    logic [ADDR_W:0] wr_addr;
    logic [ADDR_W:0] rd_addr;

    logic [ADDR_W:0] wr_next_addr;
    logic [ADDR_W:0] rd_next_addr;

    logic fifo_empty;
    logic fifo_full;

    logic fifo_empty_next;
    logic fifo_full_next;

    wire load_output;
    wire wr_en;

    assign load_output = (!m_axis_tvalid || m_axis_tready) && !fifo_empty;

    assign s_axis_tready = !fifo_full || load_output;

    assign wr_en = s_axis_tvalid && s_axis_tready;

    assign o_fifo_count = wr_addr - rd_addr;


    always_comb begin
        wr_next_addr = wr_addr;
        rd_next_addr = rd_addr;

        if (wr_en)
            wr_next_addr = wr_addr + 1'b1;

        if (load_output)
            rd_next_addr = rd_addr + 1'b1;
    end

    always_comb begin
        fifo_empty_next = (wr_next_addr == rd_next_addr);

        fifo_full_next =
            (wr_next_addr[ADDR_W]     != rd_next_addr[ADDR_W]) &&
            (wr_next_addr[ADDR_W-1:0] == rd_next_addr[ADDR_W-1:0]);
    end

    always_ff @(posedge i_clk) begin
        if (!i_reset_n) begin
            fifo_empty <= 1'b1;
            fifo_full  <= 1'b0;
        end else begin
            fifo_empty <= fifo_empty_next;
            fifo_full  <= fifo_full_next;
        end
    end

    // Slave logic
    always_ff @(posedge i_clk) begin
        if (!i_reset_n) begin
            wr_addr <= '0;
        end else if (wr_en) begin
            mem_tdata[wr_addr[ADDR_W-1:0]] <= s_axis_tdata;
            mem_tlast[wr_addr[ADDR_W-1:0]] <= s_axis_tlast;
            wr_addr <= wr_next_addr;
        end
    end

    // Master Logic
    always_ff @(posedge i_clk) begin
        if (!i_reset_n) begin
            rd_addr       <= '0;
            m_axis_tvalid <= 1'b0;
            m_axis_tdata  <= '0;
            m_axis_tlast  <= 1'b0;
        end else begin
            if (!m_axis_tvalid || m_axis_tready) begin
                if (!fifo_empty) begin
                    m_axis_tvalid <= 1'b1;
                    m_axis_tdata  <= mem_tdata[rd_addr[ADDR_W-1:0]];
                    m_axis_tlast  <= mem_tlast[rd_addr[ADDR_W-1:0]];
                    rd_addr       <= rd_next_addr;
                end else begin
                    m_axis_tvalid <= 1'b0;
                    m_axis_tlast  <= 1'b0;
                end
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


`endif 

endmodule
