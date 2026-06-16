`ifndef VERILATOR
module testbench;
  reg [4095:0] vcdfile;
  reg clock;
`else
module testbench(input clock, output reg genclock);
  initial genclock = 1;
`endif
  reg genclock = 1;
  reg [31:0] cycle = 0;
  reg [0:0] PI_m_axis_tready;
  reg [7:0] PI_s_axis_tdata;
  reg [0:0] PI_s_axis_tlast;
  reg [0:0] PI_s_axis_tvalid;
  reg [0:0] PI_i_clk;
  reg [0:0] PI_i_reset_n;
  axis_fifo_formal UUT (
    .m_axis_tready(PI_m_axis_tready),
    .s_axis_tdata(PI_s_axis_tdata),
    .s_axis_tlast(PI_s_axis_tlast),
    .s_axis_tvalid(PI_s_axis_tvalid),
    .i_clk(PI_i_clk),
    .i_reset_n(PI_i_reset_n)
  );
`ifndef VERILATOR
  initial begin
    if ($value$plusargs("vcd=%s", vcdfile)) begin
      $dumpfile(vcdfile);
      $dumpvars(0, testbench);
    end
    #5 clock = 0;
    while (genclock) begin
      #5 clock = 0;
      #5 clock = 1;
    end
  end
`endif
  initial begin
`ifndef VERILATOR
    #1;
`endif
    // UUT.$auto$async2sync.\cc:107:execute$590  = 1'b0;
    // UUT.$auto$async2sync.\cc:107:execute$602  = 1'b0;
    // UUT.$auto$async2sync.\cc:116:execute$594  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$600  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$606  = 1'b1;
    // UUT.$auto$async2sync.\cc:116:execute$612  = 1'b1;
    UUT._witness_.anyinit_procdff_546 = 1'b0;
    UUT._witness_.anyinit_procdff_547 = 1'b0;
    UUT._witness_.anyinit_procdff_548 = 8'b00000000;
    UUT._witness_.anyinit_procdff_549 = 1'b0;
    // UUT.dut.$auto$async2sync.\cc:107:execute$572  = 1'b0;
    // UUT.dut.$auto$async2sync.\cc:107:execute$578  = 1'b0;
    // UUT.dut.$auto$async2sync.\cc:107:execute$584  = 1'b0;
    // UUT.dut.$auto$async2sync.\cc:116:execute$582  = 1'b1;
    // UUT.dut.$auto$async2sync.\cc:116:execute$588  = 1'b1;
    UUT.dut._witness_.anyinit_procdff_552 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_553 = 1'b0;
    UUT.dut._witness_.anyinit_procdff_554 = 1'b0;
    UUT.dut.f_past_valid = 1'b0;
    UUT.dut.f_state = 2'b00;
    UUT.dut.m_axis_tdata = 8'b00000000;
    UUT.dut.m_axis_tlast = 1'b0;
    UUT.dut.m_axis_tvalid = 1'b0;
    UUT.dut.o_overflow = 1'b0;
    UUT.dut.o_underflow = 1'b0;
    UUT.dut.rd_addr = 7'b0100000;
    UUT.dut.s_axis_tready = 1'b1;
    UUT.dut.wr_addr = 7'b0111111;
    UUT.f_past_valid = 1'b0;
    UUT.dut.f_first_addr = 7'b0111111;
    UUT.dut.f_first_data = 8'b10000000;
    UUT.dut.f_second_data = 8'b00000000;
    UUT.dut.mem_tdata[6'b100000] = 8'b00000000;
    UUT.dut.mem_tdata[6'b111111] = 8'b10000000;
    UUT.dut.mem_tdata[6'b000000] = 8'b10000000;
    UUT.dut.mem_tdata[6'b100001] = 8'b00000000;
    UUT.dut.mem_tlast[6'b100000] = 1'b0;
    UUT.dut.mem_tlast[6'b100001] = 1'b0;

    // state 0
    PI_m_axis_tready = 1'b0;
    PI_s_axis_tdata = 8'b10000000;
    PI_s_axis_tlast = 1'b0;
    PI_s_axis_tvalid = 1'b1;
    PI_i_clk = 1'b0;
    PI_i_reset_n = 1'b0;
  end
  always @(posedge clock) begin
    // state 1
    if (cycle == 0) begin
      PI_m_axis_tready <= 1'b0;
      PI_s_axis_tdata <= 8'b00000000;
      PI_s_axis_tlast <= 1'b0;
      PI_s_axis_tvalid <= 1'b0;
      PI_i_clk <= 1'b0;
      PI_i_reset_n <= 1'b0;
    end

    genclock <= cycle < 1;
    cycle <= cycle + 1;
  end
endmodule
