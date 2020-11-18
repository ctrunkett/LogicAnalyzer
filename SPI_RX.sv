module SPI_RX(input clk, rst_n,	// 100MHz system clock and reset
			input SS_n, SCLK, MOSI,	//  SPI protocol signals. Coming from VIL comparators
			input edg,	// When high the receive shift register should shift on SCLK rise
			input len8_16,	// When high we are doing an 8-bit comparison to match[7:0]
			input [15:0]mask,	// Used to mask off bits of match to a don’t care for comparison
			input [15:0]match,	// Data unit is looking to match for a trigger
			output logic SPItrig);	// Asserted for 1 clock cycle at end of a reception if received data matches match[7:0]

	logic [15:0] shft_reg;
	logic SS_ff1, SS_ff2, SS_ff3;
	logic MOSI_ff1, MOSI_ff2, MOSI_ff3;
	logic SCLK_rise, SCLK_fall;
	logic SCLK_ff1, SCLK_ff2, SCLK_ff3;
	logic shift;
	logic done;
	logic [15:0] match_msq;
	logic [15:0] shft_msq;
	
	typedef enum reg [1:0] {IDLE, RX} state_t;
	state_t state, nxt_state;
	
	//flop for state machine
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;
	end
	
	//triple flop the SS_n signal
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)	begin
			SS_ff3 <= 1'b1;
			SS_ff2 <= 1'b1;
			SS_ff1 <= 1'b1;
		end
		else begin
			SS_ff3 <= SS_ff2;
			SS_ff2 <= SS_ff1;
			SS_ff1 <= SS_n;
		end
	end
	
	//create SCLK edge detectors
	always @(posedge clk) begin
		SCLK_ff3 <= SCLK_ff2;
		SCLK_ff2 <= SCLK_ff1;
		SCLK_ff1 <= SCLK;
	end
	 
	assign SCLK_rise = SCLK_ff2 & ~SCLK_ff3;
	assign SCLK_fall = ~SCLK_ff2 & SCLK_ff3;
	
	//mask off signals
	assign match_msq = match | mask;
	assign shft_msq = shft_reg | mask;
	
	//mux for determining SPItrig
	//assign SPItrig = done ? ( len8_16 ? (match_msq[7:0] == shft_msq[7:0]) : (match_msq == shft_msq) ) : 1'b0;
	assign SPItrig = done ? ( len8_16 ? (match_msq[7:0] == shft_msq[7:0]) : (match_msq == shft_msq) ) : 1'b0;
	
	//triple flop MOSI line
	always_ff @(posedge clk) begin
		MOSI_ff3 <= MOSI_ff2;
		MOSI_ff2 <= MOSI_ff1;
		MOSI_ff1 <= MOSI;
	end
	
	//update shift reg
	always_ff @(posedge clk) begin
		if (shift)
			shft_reg <= {shft_reg[14:0], MOSI_ff3};
	end
	
	//SM for SPI Receiver
	always_comb begin
		shift = 1'b0;
		done = 1'b0;
		nxt_state = state;
		case (state)
			IDLE : begin
				if (~SS_ff3) begin
					nxt_state = RX;
				end
			end
			RX : begin
				if (SS_ff3) begin
					done = 1'b1;
					nxt_state = IDLE;
				end
				else if (edg)
					shift = SCLK_rise;
				else 
					shift = SCLK_fall;
			end
		endcase
	end

endmodule