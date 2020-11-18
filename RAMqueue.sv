module RAMqueue(clk, we, wdata, waddr, raddr, rdata);

	parameter ENTRIES = 384; //default to 384
	parameter LOG2 = 9; //default to 9
	
	input clk, we;
	input [LOG2-1:0] waddr, raddr;
	input [7:0] wdata;
	output reg [7:0]rdata;
	// synopsys translate_off
	reg [7:0]memory[ENTRIES-1:0];
	
	always @(posedge clk) begin
		rdata <= memory[raddr]; // flopped val
		if (we) begin
			memory[waddr]<=wdata;
		end
	end
	//synopsys translate_on
endmodule

	