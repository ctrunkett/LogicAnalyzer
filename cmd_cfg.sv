module cmd_cfg(clk,rst_n,resp,send_resp,resp_sent,cmd,cmd_rdy,clr_cmd_rdy,
               set_capture_done,raddr,rdataCH1,rdataCH2,rdataCH3,rdataCH4,
			   rdataCH5,waddr,trig_pos,decimator,maskL,maskH,matchL,matchH,
			   baud_cntL,baud_cntH,TrigCfg,CH1TrigCfg,CH2TrigCfg,CH3TrigCfg,
			   CH4TrigCfg,CH5TrigCfg,VIH,VIL);
			   
  parameter ENTRIES = 384,	// defaults to 384 for simulation, use 12288 for DE-0
            LOG2 = 9;		// Log base 2 of number of entries
			
  input clk,rst_n;
  input [15:0] cmd;			// 16-bit command from UART (host) to be executed
  input cmd_rdy;			// indicates command is valid
  input resp_sent;			// indicates transmission of resp[7:0] to host is complete
  input set_capture_done;	// from the capture module (sets capture done bit in TrigCfg)
  input [LOG2-1:0] waddr;		// on a dump raddr is initialized to waddr
  input [7:0] rdataCH1;		// read data from RAMqueues
  input [7:0] rdataCH2,rdataCH3;
  input [7:0] rdataCH4,rdataCH5;
  output logic [7:0] resp;		// data to send to host as response (formed in SM)
  output logic send_resp;				// used to initiate transmission to host (via UART)
  output logic clr_cmd_rdy;			// when finished processing command use this to knock down cmd_rdy
  output logic [LOG2-1:0] raddr;		// read address to RAMqueues (same address to all queues)
  output logic [LOG2-1:0] trig_pos;	// how many sample after trigger to capture
  output reg [3:0] decimator;	// goes to clk_rst_smpl block
  output reg [7:0] maskL,maskH;				// to trigger logic for protocol triggering
  output reg [7:0] matchL,matchH;			// to trigger logic for protocol triggering
  output reg [7:0] baud_cntL,baud_cntH;		// to trigger logic for UART triggering
  output reg [5:0] TrigCfg;					// some bits to trigger logic, others to capture unit
  output reg [4:0] CH1TrigCfg,CH2TrigCfg;	// to channel trigger logic
  output reg [4:0] CH3TrigCfg,CH4TrigCfg;	// to channel trigger logic
  output reg [4:0] CH5TrigCfg;				// to channel trigger logic
  output reg [7:0] VIH,VIL;					// to dual_PWM to set thresholds
  
  reg wrt, rd, dmp; 
  reg ld, inc;
  reg dump_done;
 // logic [7:0] resp_in;
  
  typedef enum reg[4:0] {IDLE, DUMP, WAIT_RESP, WRT_REG, RD_REG, WAIT_LD} state_t;
  
  state_t state,nxt_state;
  //hey kids, wanna buy some uart commands?
  always_ff @(posedge clk) begin
	if (!rst_n)
		TrigCfg <= 6'h03;
	else if (set_capture_done)
		TrigCfg[5] <= 1'b1;
	else if (cmd[13:8] == 6'h00) begin
		if (wrt)
			TrigCfg <= cmd[5:0];
	end
  end
  
  always_ff @(posedge clk) begin
	if (!rst_n)
		CH1TrigCfg <= 5'h01;
	else if (cmd[13:8] == 6'h01)  begin
		if (wrt)
			CH1TrigCfg  <= cmd[4:0];
	end
  end
  
  always_ff @(posedge clk) begin
	if (!rst_n)
		CH2TrigCfg <= 5'h01;
	else if (cmd[13:8] == 6'h02) begin
		if (wrt)
			CH2TrigCfg <= cmd[4:0];
	end	
  end
  
  always_ff @(posedge clk) begin
	if (!rst_n)
		CH3TrigCfg <= 5'h01;
	else if (cmd[13:8] == 6'h03)  begin
		if (wrt)
			CH3TrigCfg  <= cmd[4:0];
	end
  end
  
  always_ff @(posedge clk) begin
	if (!rst_n)
		CH4TrigCfg <= 5'h01;
	else if (cmd[13:8] == 6'h04)  begin
		if (wrt)
			CH4TrigCfg  <= cmd[4:0];
	end
  end
  
  always_ff @(posedge clk) begin
	if (!rst_n)
		CH5TrigCfg <= 5'h01;
	else if (cmd[13:8] == 6'h05)  begin
		if (wrt)
			CH5TrigCfg  <= cmd[4:0];
	end
  end
  
  always_ff @(posedge clk) begin
	if (!rst_n)
		decimator <= 4'h0;
	else if (cmd[13:8] == 6'h06) begin
		if (wrt)
			decimator <= cmd[3:0];
	end
  end
  
  always_ff @(posedge clk) begin
	if (!rst_n)
		VIH <= 8'hAA;
	else if (cmd[13:8] == 6'h07) begin
		if (wrt)
			VIH <= cmd[7:0];
	end
  end
  
  always_ff @(posedge clk) begin
	if (!rst_n)
		VIL <= 8'h55;
	else if (cmd[13:8] == 6'h08) begin
		if (wrt)
			VIL <= cmd[7:0];
	end
  end
  
  always_ff @(posedge clk) begin
	if (!rst_n)
		matchH <= 8'h00;
	else if (cmd[13:8] == 6'h09) begin
		if (wrt)
			matchH <= cmd[7:0];
	end
  end
  
  always_ff @(posedge clk) begin
	if (!rst_n)
		matchL <= 8'h00;
	else if (cmd[13:8] == 6'h0A) begin
		if (wrt)
			matchL <= cmd[7:0];
	end
  end
  
  always_ff @(posedge clk) begin
	if (!rst_n)
		maskH <= 8'h00;
	else if (cmd[13:8] == 6'h0B) begin
		if (wrt)
			maskH <= cmd[7:0];
	end
  end
  
  always_ff @(posedge clk) begin
	if (!rst_n)
		maskL <= 8'h00;
	else if (cmd[13:8] == 6'h0C) begin
		if (wrt)
			maskL <= cmd[7:0];	
	end
  end
  
  always_ff @(posedge clk) begin
	if (!rst_n)
		baud_cntH <= 8'h06;
	else if (cmd[13:8] == 6'h0D) begin
		if (wrt)
			baud_cntH <= cmd[7:0];	
	end
  end
  
  always_ff @(posedge clk) begin
	if (!rst_n)
		baud_cntL <= 8'hC8;
	else if (cmd[13:8] == 6'h0E) begin
		if (wrt)
			baud_cntL <= cmd[7:0];
	end
  end
  
  always_ff @(posedge clk) begin
	if (!rst_n)
		trig_pos[LOG2-1:8] <= 8'h00;
	else if (cmd[13:8] == 6'h0F) begin
		if (wrt)
			trig_pos[LOG2-1:8] <= cmd[LOG2 - 8:0];
	end
  end
  
  always_ff @(posedge clk) begin
	if (!rst_n)
		trig_pos[7:0] <= 8'h01;
	else if (cmd[13:8] == 6'h10) begin
		if (wrt)
			trig_pos[7:0] <= cmd[7:0];	
	end
  end
  always @(posedge clk, negedge rst_n) begin
	if (!rst_n) begin
	end
	else if (ld) begin
		raddr <= waddr;
	end
	else if (inc) begin
		raddr <= (raddr + 1) % ENTRIES;
	end
  end
  always @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		dump_done <= 1'b0;
	else if (ld)
		dump_done <= 1'b0;
	else if (raddr + 1 == waddr)
		dump_done <= 1'b1;
  end
  
  always_ff @(posedge clk, negedge rst_n) begin
	if (!rst_n) 
		state <= IDLE;
	else
		state <= nxt_state;
  end
  
 // assign resp = send_resp ? resp_in : resp;
  
  always_comb begin
	nxt_state = state;
	send_resp = 1'b0;
	clr_cmd_rdy = 1'b0;
	wrt = 1'b0;
	rd = 1'b0;
	ld = 1'b0;
	inc = 1'b0;
	resp = 8'h00;
	case (state)
		IDLE : begin
			if (cmd_rdy) begin
				if (cmd[15:14] == 2'b00)	// read
					nxt_state = RD_REG;
				else if (cmd[15:14] == 2'b01) begin	//write
					wrt = 1'b1;
					nxt_state = WRT_REG;					
				end
				else if (cmd[15:14] == 2'b10) begin	//dump
					ld = 1'b1;
					nxt_state = WAIT_LD;
				end
				else begin	//neg ack
					resp = 8'hEE;
					send_resp = 1'b1;
					clr_cmd_rdy = 1'b1;
				end
			end
		end
		DUMP : begin
			if (dump_done) begin
				clr_cmd_rdy = 1'b1;
				nxt_state = IDLE;
			end
			else begin
				case (cmd[10:8])
					3'h1 : begin
						resp = rdataCH1;
					end
					3'h2 : begin
						resp = rdataCH2;
					end
					3'h3 : begin
						resp = rdataCH3;
					end
					3'h4 : begin
						resp = rdataCH4;
					end
					3'h5 : begin
						resp = rdataCH5;
					end
					default : begin
						resp = 8'hEE;
						send_resp = 1'b1;
						clr_cmd_rdy = 1'b1;
						nxt_state = IDLE;
					end
				endcase
				send_resp = 1'b1;
				nxt_state = WAIT_RESP;
			end
		end
		WAIT_RESP : begin
			if (resp_sent) begin
				inc = 1'b1;
				nxt_state = DUMP;
			end
			if (dump_done) begin
				clr_cmd_rdy = 1'b1;
				nxt_state = IDLE;
			end
		end
		WRT_REG : begin
			resp = 8'hA5;
			send_resp = 1'b1;
			clr_cmd_rdy = 1'b1;
			nxt_state = IDLE;
		end
		RD_REG : begin
			case (cmd[13:8])	//hold onto your hats this is gonna be looooooong
					8'h00 : begin
						resp = TrigCfg;
					end
					8'h01 : begin
						resp = CH1TrigCfg;
					end
					8'h02 : begin
						resp = CH2TrigCfg;
					end
					8'h03 : begin
						resp = CH3TrigCfg;
					end
					8'h04 : begin
						resp = CH4TrigCfg;
					end
					8'h05 : begin
						resp = CH5TrigCfg;
					end
					8'h06 : begin
						resp = decimator;
					end
					8'h07 : begin
						resp = VIH;
					end
					8'h08 : begin
						resp = VIL;
					end
					8'h09 : begin
						resp = matchH;
					end
					8'h0A : begin
						resp = matchL;
					end
					8'h0B : begin
						resp = maskH;
					end
					8'h0C : begin
						resp = maskL;
					end
					8'h0D : begin
						resp = baud_cntH;
					end
					8'h0E : begin
						resp = baud_cntL;
					end
					8'h0F : begin
						resp = trig_pos[LOG2-1:8];
					end
					8'h10 : begin
						resp = trig_pos[7:0];
					end
			endcase
			send_resp = 1'b1;
			clr_cmd_rdy = 1'b1;
			nxt_state = IDLE;
		end
		WAIT_LD : begin
			if (raddr == waddr) begin
				nxt_state = DUMP;
			end
		end
	endcase
  end
  
endmodule
  