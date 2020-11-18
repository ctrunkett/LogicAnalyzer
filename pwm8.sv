module pwm8(
			input clk, rst_n, 
			input [7:0]duty,
			output logic PWM_sig
			);
		// internal signals
		logic [7:0]cnt;
		logic PWM_in;
		
		//counter
		always_ff@(posedge clk, negedge rst_n) begin
			if (!rst_n)
			cnt <= 8'h00;
			else
			cnt <= cnt + 1;
		end
		
		assign PWM_in = (cnt <= duty);
		
		always_ff@(posedge clk, negedge rst_n) begin
			if (!rst_n)
			PWM_sig <= 1'b0;
			else
			PWM_sig <= PWM_in;
		end
		
endmodule