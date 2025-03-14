/////////////////////////////////////////////
// NOTE: This UART has inverted TX line!! //
// it is 3M baud with 100MHz clock       //
//////////////////////////////////////////
module UART_tx(clk,rst_n,TX,trmt,tx_data,tx_done);

input clk,rst_n;		// clock and active low reset
input trmt;				// trmt tells TX section to transmit tx_data
input [7:0] tx_data;	// byte to transmit
output TX, tx_done;		// tx_done asserted when transmission complete

reg [8:0] shift_reg;	// 1-bit wider to store start bit
reg [3:0] bit_cnt;		// bit counter
reg [5:0] baud_cnt;		// baud rate counter (100MHz/3MBaud) = div of 34
reg tx_done;			// tx_done will be a set/reset flop

reg load, trnsmttng;		// assigned in state machine

wire shift;

typedef enum reg {IDLE, TXD} state_t;

////////////////////////////////
// declare state & nxt_state //
//////////////////////////////
state_t state, nxt_state;

////////////////////////////
// Infer state flop next //
//////////////////////////
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    state <= IDLE;
  else
    state <= nxt_state;
end


/////////////////////////
// Infer bit_cnt next //
///////////////////////
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    bit_cnt <= 4'b0000;
  else if (load)
    bit_cnt <= 4'b0000;
  else if (shift)
    bit_cnt <= bit_cnt+1;
end

//////////////////////////
// Infer baud_cnt next //
////////////////////////
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    baud_cnt <= 6'd34;			// divider for 3M baud at 100MHz
  else if (load || shift)
    baud_cnt <= 6'd34;			// reset when baud count indicates
  else if (trnsmttng)
    baud_cnt <= baud_cnt-1;		// only burn power incrementing if tranmitting
end

////////////////////////////////
// Infer shift register next //
//////////////////////////////
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    shift_reg <= 9'h1FF;		// reset to idle state being transmitted
  else if (load)
    shift_reg <= {tx_data,1'b0};	// start bit is loaded as well as data to TX
  else if (shift)
    shift_reg <= {1'b1,shift_reg[8:1]};	// LSB shifted out and idle state shifted in 
end

///////////////////////////////////////////////
// Easiest to make tx_done a set/reset flop //
/////////////////////////////////////////////
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    tx_done <= 1'b0;
  else if (trmt)
    tx_done <= 1'b0;
  else if (bit_cnt==4'b1010)
    tx_done <= 1'b1;
end

//////////////////////////////////////////////
// Now for hard part...State machine logic //
////////////////////////////////////////////
always_comb
  begin
    //////////////////////////////////////
    // Default assign all output of SM //
    ////////////////////////////////////
    load         = 0;
    trnsmttng    = 0;
    nxt_state    = IDLE;	// always a good idea to default to IDLE state
    
    case (state)
      IDLE : begin
        if (trmt)
          begin
            nxt_state = TXD;
            load = 1;
          end
        else nxt_state = IDLE;
      end
      default : begin		// this is TXD state
        if (bit_cnt==4'b1010)
          nxt_state = IDLE;
        else
          nxt_state = TXD;
        trnsmttng = 1;
      end
    endcase
  end

////////////////////////////////////
// Continuous assignement follow //
//////////////////////////////////
assign shift = ~|baud_cnt;		// shift when baud_cnt hits zero
assign TX = ~shift_reg[0];		// TX is inverted LSB of shft_reg

endmodule

