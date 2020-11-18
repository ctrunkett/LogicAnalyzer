module trigger_logic(
	input CH1Trig, CH2Trig, CH3Trig, CH4Trig, CH5Trig, protTrig, armed, set_capture_done, clk, rst_n,
	output reg triggered
	);
	//internal signal
	logic trig_in;
	
	// update flop input
		assign trig_in = triggered ? ~set_capture_done : armed & protTrig & CH1Trig & CH2Trig & CH3Trig & CH4Trig & CH5Trig;
		
	// flopped output
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) 
			triggered <= 1'b0;
		else 
			triggered <= trig_in;
	end 
	
endmodule
