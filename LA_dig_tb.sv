`timescale 1ns / 100ps
module LA_dig_tb();
			
//// Interconnects to DUT/support defined as type wire /////
wire clk400MHz,locked;			// PLL output signals to DUT
wire clk;						// 100MHz clock generated at this level from clk400MHz
wire VIH_PWM,VIL_PWM;			// connect to PWM outputs to monitor
wire CH1L,CH1H,CH2L,CH2H,CH3L;	// channel data inputs from AFE model
wire CH3H,CH4L,CH4H,CH5L,CH5H;	// channel data inputs from AFE model
wire RX,TX;						// interface to host
wire cmd_sent,resp_rdy;			// from master UART, monitored in test bench
wire [7:0] resp;				// from master UART, reponse received from DUT
wire tx_prot;					// UART signal for protocol triggering
wire SS_n,SCLK,MOSI;			// SPI signals for SPI protocol triggering
wire CH1L_mux,CH1H_mux;         // output of muxing logic for CH1 to enable testing of protocol triggering
wire CH2L_mux,CH2H_mux;			// output of muxing logic for CH2 to enable testing of protocol triggering
wire CH3L_mux,CH3H_mux;			// output of muxing logic for CH3 to enable testing of protocol triggering

////// Stimulus is declared as type reg ///////
reg REF_CLK, RST_n;
reg [15:0] host_cmd;			// command host is sending to DUT
reg send_cmd;					// asserted to initiate sending of command
reg clr_resp_rdy;				// asserted to knock down resp_rdy
reg [1:0] clk_div;				// counter used to derive 100MHz clk from clk400MHz
reg strt_tx;					// kick off unit used for protocol triggering
reg en_AFE;
reg capture_done_bit;			// flag used in polling for capture_done
reg [7:0] res,exp;				// used to store result and expected read from files
logic [15:0] spi_data;				//used for spi_protocol triggering

wire AFE_clk;

///////////////////////////////////////////
// Channel Dumps can be written to file //
/////////////////////////////////////////
integer fptr1;		// file pointer for CH1 dumps
integer fptr2;		// file pointer for CH2 dumps
integer fptr3;		// file pointer for CH3 dumps
integer fptr4;		// file pointer for CH4 dumps
integer fptr5;		// file pointer for CH5 dumps


integer fexp;		// file pointer to file with expected results
integer found_res,found_expected,loop_cnt;
integer mismatches;	// number of mismatches when comparing results to expected
integer sample;		// sample counter in dump & compare

///////////////////////////
// Define command bytes //
/////////////////////////
localparam DUMP_CH1  = 8'h81;		// Dump channel 1
localparam DUMP_CH2  = 8'h82;		// Dump channel 2
localparam DUMP_CH3  = 8'h83;		// Dump channel 3
localparam DUMP_CH4  = 8'h84;		// Dump channel 4
localparam DUMP_CH5  = 8'h85;		// Dump channel 5
localparam TRIG_CFG_RD = 8'h00;		// Used to read TRIG_CFG register
localparam SET_DEC     = 8'h46;		// Write to decimator register
localparam SET_VIH_PWM = 8'h47;		// Set VIH trigger level [255:0] are valid values
localparam SET_VIL_PWM = 8'h48;		// Set VIL trigger level [255:0] are valid values
localparam SET_CH1_TRG = 8'h41;		// Write to CH1 trigger config register
localparam SET_CH2_TRG = 8'h42;		// Write to CH2 trigger config register
localparam SET_CH3_TRG = 8'h43;		// Write to CH3 trigger config register
localparam SET_CH4_TRG = 8'h44;		// Write to CH4 trigger config register
localparam SET_CH5_TRG = 8'h45;		// Write to CH5 trigger config register
localparam SET_TRG_CFG = 8'h40;		// Write to TrigCfg register
localparam WRT_TRGPOSH = 8'h4F;		// Write to trig_posH register
localparam WRT_TRGPOSL = 8'h50;		// Write to trig_posL register
localparam SET_MATCHH  = 8'h49;		// Write to matchH register
localparam SET_MATCHL  = 8'h4A;		// Write to matchL register
localparam SET_MASKH   = 8'h4B;		// Write to maskH register
localparam SET_MASKL   = 8'h4C;		// Write to maskL register
localparam SET_BAUDH   = 8'h4D;		// Write to baudD register
localparam SET_BAUDL   = 8'h4E;		// Write to baudL register

//// define responses /////
  localparam POS_ACK = 8'hA5;
  localparam NEG_ACK = 8'hEE;
  
/////////////////////////////////
localparam UART_triggering = 1'b0;	// set to true if testing UART based triggering
logic SPI_triggering = 1'b0;	// set to true if testing SPI based triggering

assign AFE_clk = en_AFE & clk400MHz;
///// Instantiate Analog Front End model (provides stimulus to channels) ///////
AFE iAFE(.smpl_clk(AFE_clk),.VIH_PWM(VIH_PWM),.VIL_PWM(VIL_PWM),
         .CH1L(CH1L),.CH1H(CH1H),.CH2L(CH2L),.CH2H(CH2H),.CH3L(CH3L),
         .CH3H(CH3H),.CH4L(CH4L),.CH4H(CH4H),.CH5L(CH5L),.CH5H(CH5H));
		 
//// Mux for muxing in protocol triggering for CH1 /////
assign {CH1H_mux,CH1L_mux} = (UART_triggering) ? {2{tx_prot}} :		// assign to output of UART_tx used to test UART triggering
                             (SPI_triggering) ? {2{SS_n}}: 			// assign to output of SPI SS_n if SPI triggering
				             {CH1H,CH1L};

//// Mux for muxing in protocol triggering for CH2 /////
assign {CH2H_mux,CH2L_mux} = (SPI_triggering) ? {2{SCLK}}: 			// assign to output of SPI SCLK if SPI triggering
				             {CH2H,CH2L};	

//// Mux for muxing in protocol triggering for CH3 /////
assign {CH3H_mux,CH3L_mux} = (SPI_triggering) ? {2{MOSI}}: 			// assign to output of SPI MOSI if SPI triggering
				             {CH3H,CH3L};					  
	 
////// Instantiate DUT ////////		  
LA_dig iDUT(.clk400MHz(clk400MHz),.RST_n(RST_n),.locked(locked),
            .VIH_PWM(VIH_PWM),.VIL_PWM(VIL_PWM),.CH1L(CH1L_mux),.CH1H(CH1H_mux),
			.CH2L(CH2L_mux),.CH2H(CH2H_mux),.CH3L(CH3L_mux),.CH3H(CH3H_mux),.CH4L(CH4L),
			.CH4H(CH4H),.CH5L(CH5L),.CH5H(CH5H),.RX(RX),.TX(TX));

///// Instantiate PLL to provide 400MHz clk from 50MHz ///////
pll8x iPLL(.ref_clk(REF_CLK),.RST_n(RST_n),.out_clk(clk400MHz),.locked(locked));

///// It is useful to have a 100MHz clock at this level similar //////
///// to main system clock (clk).  So we will create one        //////
always @(posedge clk400MHz, negedge locked)
  if (~locked)
    clk_div <= 2'b00;
  else
    clk_div <= clk_div+1;
assign clk = clk_div[1];

//// Instantiate Master UART (mimics host commands) //////
CommMaster iMSTR(.clk(clk), .rst_n(RST_n), .RX(TX), .TX(RX),
                     .cmd(host_cmd), .snd_cmd(send_cmd),
					 .cmd_cmplt(cmd_sent), .rdy(resp_rdy),
					 .resp(resp), .clr_resp_rdy(clr_resp_rdy));
					 
////////////////////////////////////////////////////////////////
// Instantiate transmitter as source for protocol triggering //
//////////////////////////////////////////////////////////////
UART_tx iTX(.clk(clk), .rst_n(RST_n), .TX(tx_prot), .trmt(strt_tx),
            .tx_data(8'h96), .tx_done());
					 
////////////////////////////////////////////////////////////////////
// Instantiate SPI transmitter as source for protocol triggering //
//////////////////////////////////////////////////////////////////
SPI_TX iSPI(.clk(clk),.rst_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),.wrt(strt_tx),.done(done),
            .tx_data(spi_data),.MOSI(MOSI),.pos_edge(1'b0),.width8(1'b0));

initial begin
  fptr1 = $fopen("CH1dmp.txt","w");			// open file to write CH1 dumps to
  fptr2 = $fopen("CH2dmp.txt","w");			// open file to write CH2 dumps to
  fptr3 = $fopen("CH3dmp.txt","w");			// open file to write CH3 dumps to
  fptr4 = $fopen("CH4dmp.txt","w");			// open file to write CH4 dumps to
  fptr5 = $fopen("CH5dmp.txt","w");			// open file to write CH5 dumps to

  en_AFE = 0;
  strt_tx = 0;								// do not initiate protocol trigger for now
  
  //// Initialize ////
    init_LAdig();
    
  //////////////////////////////////////////////
  //// test 1: standard CH1 dump
  //////////////////////////////////////////////
    test_01();

	$display("YAHOO! comparison completed, test1 passed!");
  
	///////////////////////////////////////////////////////
	// test2: widen the dead zone 	//////////////////////////////
	/////////////////////////////////////////////////////
	test_02();
	
	$display("YAHOO! test2 passed!");
	
	//clear set capture done bit to reset VIH and VIL//
	send_command({SET_VIH_PWM,8'hAA});
	wait_cmd_sent(POS_ACK);
	send_command({SET_VIL_PWM,8'h55});
	wait_cmd_sent(POS_ACK);

	/////////////////////////////////////////////////
	/// test3: test channel 2 dump
	////////////////////////////////////////////////
	test_03();
	
	$display("YAHOO! test3 passed!");
	
	/////////////////////////////////////////////
	//// test4: test channel 3 dump
	/////////////////////////////////////////////
	test_04();

	$display("YAHOO! test4 passed!");
	
	/////////////////////////////////////////////
	//// test5: test channel 4 dump
	/////////////////////////////////////////////
	test_05();

	$display("YAHOO! test5 passed!");

	/////////////////////////////////////////////
	//// test6: test channel 5 dump
	/////////////////////////////////////////////
	test_06();

	$display("YAHOO! test6 passed!");

	
	//////////////////////////////////////////////////
	/// test7: change decimator 4'h6 - CH1
	//////////////////////////////////////////////////
	test_07();

	$display("YAHOO! test7 passed!");
	send_command({SET_CH1_TRG,8'h01});	//ch1 not part of trigger
	wait_cmd_sent(POS_ACK);
	
	//////////////////////////////////////////////////
	/// test8: change decimator 4'h6 - CH2 - negedge triggering
	//////////////////////////////////////////////////
	test_08();

	$display("YAHOO! test8 passed!");
	
	// reset decimator sample rate to 0 //
	send_command({SET_DEC,8'h00});
	wait_cmd_sent(POS_ACK);
	send_command({SET_CH2_TRG,8'h01});	//ch2 not part of trigger
	wait_cmd_sent(POS_ACK);
	
	///////////////////////////////////////////////
	/// test9: CH3 negedge trigerring
	///////////////////////////////////////////////
	test_09();

	$display("YAHOO! test9 passed!");
	send_command({SET_CH3_TRG,8'h01});	//ch3 not part of trigger
	wait_cmd_sent(POS_ACK);
	
	///////////////////////////////////////////////
	/// test10: CH4 - high level trigerring
	///////////////////////////////////////////////
	test_10();

	$display("YAHOO! test10 passed!");
	send_command({SET_CH4_TRG,8'h01});	//ch4 not part of trigger
	wait_cmd_sent(POS_ACK);
	
	///////////////////////////////////////////////
	/// test11: CH5 - low level trigerring
	///////////////////////////////////////////////
	test_11();

	$display("YAHOO! test11 passed!");
	send_command({SET_CH5_TRG,8'h01});	//ch5 not part of trigger
	wait_cmd_sent(POS_ACK);
	
	///////////////////////////////////////////////
	/// test12: CH1 -  increase trigPos
	///////////////////////////////////////////////
	test_12();

	$display("YAHOO! test12 passed!");
	send_command({SET_CH1_TRG,8'h01});	//ch1 not part of trigger
	wait_cmd_sent(POS_ACK);
	send_command({WRT_TRGPOSH, 8'h00});	//reset trigpos
	wait_cmd_sent(POS_ACK);
	send_command({WRT_TRGPOSL, 8'h01});
	wait_cmd_sent(POS_ACK);

	///////////////////////////////////////////////
	/// test13: SPI protocol triggering - simple
	///////////////////////////////////////////////
	test_13();
	
	$display("YAHOO! test13 passed!");

	//////////////////////////////////////////////////////
	/// test14: SPI protocol triggering - ~*~complex~*~
	/////////////////////////////////////////////////////
	test_14();
	
	$display("YAHOO! test14 passed!");
	
	/////////////////////////
	// TEST FINISHED ////////
	/////////////////////////
	$display("TEST FINISHED");

	
  $stop();
end

always
  #10.4 REF_CLK = ~REF_CLK;

`include "tb_tasks.txt"

endmodule	
