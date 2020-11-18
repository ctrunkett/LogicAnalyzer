module UART_wrapper(input clk, input rst_n,
					input clr_cmd_rdy,
					input send_resp,
					input [7:0]resp,
					input RX,
					output logic cmd_rdy,
					output logic [15:0]cmd,
					output logic resp_sent,
					output logic TX);
	
	logic rx_rdy;
	logic clr_rdy;
	logic sel;
	logic [7:0]rx_data;
	logic [7:0] byte_h;
	logic pckg_cmplt;
	logic high_sent;
	logic rx1, rx_rdy_rise;
	
	//instantiate the UART//
	UART uart(.clk(clk), .rst_n(rst_n), .RX(RX), .TX(TX), .rx_rdy(rx_rdy), .clr_rx_rdy(clr_rdy), .rx_data(rx_data), .trmt(send_resp), .tx_data(resp), .tx_done(resp_sent));
	
	typedef enum reg [1:0] {BYTE_H, BYTE_L} state_t;
	state_t state, nxt_state;
	//select high byte
	always @(posedge clk)
		byte_h <= ( sel ? rx_data : cmd[15:8] );
	//package command
	assign cmd = {byte_h, rx_data};
	//flop for SM
	always @(posedge clk, negedge rst_n) begin
		if (!rst_n) 
			state <= BYTE_H;
		else 
			state <= nxt_state;
	end
	//assert or clear cmd_rdy & clr_rdy
	always @(posedge clk, negedge rst_n) begin
		if (!rst_n) begin
			cmd_rdy <= 1'b0;
			clr_rdy <= 1'b0;
		end
		else if (high_sent | clr_cmd_rdy) begin
			cmd_rdy <= 1'b0;
			clr_rdy <= 1'b1;
		end
		else if (pckg_cmplt) begin
			clr_rdy <= 1'b0;
			cmd_rdy <= 1'b1;
		end
		else 
			clr_rdy <= 1'b0;
	end
	//edge detector for rx_rdy
	always @(posedge clk) begin
		rx1 <= rx_rdy;
	end
	assign rx_rdy_rise = rx_rdy & ~rx1;
	
	//SM for packaging command
	always_comb begin
		sel = 1'b0;
		high_sent = 1'b0;
		nxt_state = state;
		pckg_cmplt = 1'b0;
		case (state)
			BYTE_H : begin
				if (rx_rdy_rise) begin
					sel = 1'b1;
					high_sent = 1'b1;
					//clr_rdy = 1'b1;
					nxt_state = BYTE_L;
				end
			end
			BYTE_L : begin
				if (rx_rdy_rise) begin
					//sel = 1'b0;
					pckg_cmplt = 1'b1;
					//clr_rdy = 1'b1;
					nxt_state = BYTE_H;
				end
			end
		endcase
	end
	
endmodule