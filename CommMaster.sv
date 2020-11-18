module CommMaster(	input clk, input rst_n,
					input [15:0] cmd,
					input snd_cmd,
					input RX,
					input clr_resp_rdy,
					output logic rdy,
					output logic [7:0] resp,
					output logic TX,
					output logic cmd_cmplt);
					
	logic tx_done;
	logic [7:0] tx_data;	//either upper or ower bit of cmd
	logic trmt;	//asserted to begin transmission to uart
	logic [7:0] m0;	// 0 input for mux- lower inputs of cmd
	logic sel;	//output from SM to select which byte of cmd to transmit

	//instantiate the UART//
	UART uartComm(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .rx_rdy(rdy), .clr_rx_rdy(clr_resp_rdy), .rx_data(resp), .trmt(trmt), .tx_data(tx_data), .tx_done(tx_done));
	
	typedef enum reg [3:0] {IDLE, BYTE_L, BYTE_H, CMPLT} state_t;
	state_t state, nxt_state;
	
	//flop lower byte
	always_ff @(posedge clk) begin
		if (snd_cmd)
			m0 <= cmd[7:0];
	end
	//slect byte
	assign tx_data = sel ? cmd[15:8] : m0;
	
	//flop for SM
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;
	end
	//SM for sending command
	always_comb begin
		sel = 1'b0;
		trmt = 1'b0;
		cmd_cmplt = 1'b0;
		nxt_state = state;		
		case (state)
			IDLE: begin
				if (snd_cmd) begin
					sel = 1'b1;
					trmt = 1'b1;
					nxt_state = BYTE_H;
				end
			end
			BYTE_H : begin
				if (tx_done) begin
					trmt = 1'b1;
					nxt_state = BYTE_L;
				end
			end
			BYTE_L : begin
				if (tx_done) begin
					cmd_cmplt = 1'b1;
					nxt_state = CMPLT;
				end
			end
			CMPLT : begin
				if (snd_cmd) begin
					trmt = 1'b1;
					sel = 1'b1;
					cmd_cmplt = 1'b0;
					nxt_state = BYTE_H;
				end
				else 
					cmd_cmplt = 1'b1;
			end
		endcase
	end
endmodule