module channel_sample ( input clk,
						input smpl_clk,
						input CH_L, CH_H,
						output reg [7:0]smpl,
						output reg CH_Lff5, CH_Hff5 );
						
	reg CHxLff1, CHxLff2, CHxLff3, CHxLff4;
	reg CHxHff1, CHxHff2, CHxHff3, CHxHff4;
	
	always_ff @(negedge smpl_clk) begin
		CHxLff1 <= CH_L;
		CHxHff1 <= CH_H;
	end
	
	always_ff @(negedge smpl_clk) begin
		CHxLff2 <= CHxLff1;
		CHxHff2 <= CHxHff1;
	end
	
	always_ff @(negedge smpl_clk) begin
		CHxLff3 <= CHxLff2;
		CHxHff3 <= CHxHff2;
	end
	
	always_ff @(negedge smpl_clk) begin
		CHxLff4 <= CHxLff3;
		CHxHff4 <= CHxHff3;
	end
	
	always_ff @(negedge smpl_clk) begin
		CH_Lff5 <= CHxLff4;
		CH_Hff5 <= CHxHff4;
	end
	
	always_ff @(posedge clk) begin
		smpl <= {CHxHff2, CHxLff2, CHxHff3, CHxLff3, CHxHff4, CHxLff4, CH_Hff5, CH_Lff5};
	end
	
endmodule;
