module dual_PWM(
				input clk, rst_n, 
				input[7:0]VIL, 
				input[7:0]VIH,
				output VIL_PWM, VIH_PWM
				);
		pwm8 pwm_l(.clk(clk), .rst_n(rst_n), .duty(VIL), .PWM_sig(VIL_PWM));
		pwm8 pwm_h(.clk(clk), .rst_n(rst_n), .duty(VIH), .PWM_sig(VIH_PWM));
		

endmodule