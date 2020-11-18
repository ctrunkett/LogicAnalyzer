module dual_drv(
				input clk, rst_n,
				output [7:0]duty1,
				output [7:0]duty2);

	reg [25:0]cnt; //26 bit counter
	
	always_ff @(posedge clk, negedge rst_n) begin
		if(!rst_n) 
			cnt <= 26'h0000000;
		else
			cnt <= cnt + 1;
	end
	
	assign duty1 = cnt[25:18];
	assign duty2 = ~cnt[25:18];

endmodule