


module axis_gmii_tx #(
    parameter int DATA_W = 8,
    parameter int ENABLE_PADDING = 1,
    parameter int MIN_FRAME_LENGTH = 64,
    parameter int PADDING_EN = 1
) (
    input wire logic i_clk,
    input wire logic i_rst_n,

    // Note: tx_clk as specified in RGMII v1.3 spec will stay in top MAC module

    // Axis Interface
    input  wire logic [DATA_W-1:0] s_axis_tdata,
    input  wire logic              s_axis_tvalid,
    input  wire logic              s_axis_tlast,
    output logic                   s_axis_tready,

    // GMII outputs
    output wire logic [DATA_W-1:0] gmii_txd,
    output wire logic              gmii_tx_en,
    output wire logic              gmii_tx_er,

    // Control
    input wire logic clk_enable,
    input wire logic mii_select,

    // Configuration
    input wire logic [15:0] cfg_tx_max_pkt_len = 16'd1518 - 1,
    input wire logic [ 7:0] cfg_tx_ifg = 8'd12,
    input wire logic        cfg_tx_enable,

    // Status
    output wire start_packet,
    output wire error_underflow
);


  // check configuration
  if (DATA_W != 8) $fatal(0, "Error: Interface width must be 8 (instance %m)");



  typedef enum logic [7:0] {
    ETH_PRE = 8'h55,
    ETH_SFD = 8'hD5
  } eth_pre_t;


  typedef enum logic [2:0] {
    STATE_IDLE,
    STATE_PREAMBLE,
    STATE_PAYLOAD,
    STATE_LAST,
    STATE_PAD,
    STATE_FCS,
    STATE_IFG
  } state_t;


  // State register
  state_t state_reg = STATE_IDLE, state_next;



  // Datapath control signals

  always_comb begin
    state_next = STATE_IDLE;
    case (state_reg)

      STATE_IDLE: begin


      end

      STATE_PREAMBLE: begin


      end

      STATE_PAYLOAD: begin

      end

      STATE_LAST: begin


      end

      STATE_FCS: begin

      end

      STATE_IFG: begin

      end

      default: begin
        state_next = STATE_IDLE;
      end
    endcase


  end



  always_ff @(posedge i_clk) begin

    // load next state this cycle
    state_reg <= state_next;

  end



endmodule : axis_gmii_tx

`resetall

