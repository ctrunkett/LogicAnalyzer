module capture(clk,rst_n,wrt_smpl,run,capture_done,triggered,trig_pos,
               we,waddr,set_capture_done,armed);

  parameter ENTRIES = 384,		// defaults to 384 for simulation, use 12288 for DE-0
            LOG2 = 9;			// Log base 2 of number of entries
  
  input clk;					// system clock.
  input rst_n;					// active low asynch reset
  input wrt_smpl;				// from clk_rst_smpl.  Lets us know valid sample ready
  input run;					// signal from cmd_cfg that indicates we are in run mode
  input capture_done;			// signal from cmd_cfg register.
  input triggered;				// from trigger unit...we are triggered
  input [LOG2-1:0] trig_pos;	// How many samples after trigger do we capture
  
  output logic we;					// write enable to RAMs
  output logic [LOG2-1:0] waddr;	// write addr to RAMs
  output logic set_capture_done;		// asserted to set bit in cmd_cfg
  output logic armed;				// we have enough samples to accept a trigger

  typedef enum reg[1:0] {IDLE,CAPTURE,WAIT_RD} state_t;
  state_t state,nxt_state;
  
  reg [LOG2-1:0] trig_cnt;						// how many samples post trigger?
 
 /////////////////////////////////////////////////////////////////////////
 //
 /////////////////////////////////////////////////////////////////////////
 logic inc;
 logic init_cnt; 
// reg clr_armed;
 logic set;
 
  assign we = run & wrt_smpl & ~capture_done;
  assign inc = triggered & we;
  assign set = (trig_pos + waddr) == (ENTRIES - 1);
  assign set_capture_done = triggered & (trig_pos == trig_cnt);
  
  //incrementer for waddr
  always @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		waddr <= 0;
	else if (init_cnt)
		waddr <= 0;
	else if (we)
		waddr <= (waddr + 1)%ENTRIES;
  end
  
  //incrementer for trig_cnt
  always @(posedge clk, negedge rst_n) begin
	if (!rst_n) 
		trig_cnt <= 0;
	else if (init_cnt)
		trig_cnt <= 0;
	else if (inc)
		trig_cnt <= trig_cnt + 1;
  end
  
  //flop for armed
  always @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		armed <= 0;
	else if (set_capture_done)
		armed <= 0;
	else if (set)
		armed <= 1;
  end
  
  always @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;
  end
  
  always_comb begin
	init_cnt = 0;
	nxt_state = state;
	case (state)
		IDLE: begin
			if (run) begin
				init_cnt = 1;
				nxt_state = CAPTURE;
			end
		end
		CAPTURE: begin
			if (capture_done)
					nxt_state = WAIT_RD;
		end
		WAIT_RD: begin
			if (!capture_done) begin
				nxt_state = IDLE;
			end
		end
		default : 
			nxt_state = IDLE;
	endcase
  end
  
endmodule
