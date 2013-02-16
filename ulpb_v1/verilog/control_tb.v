

//`define SYNTH

`ifdef SYNTH
	`timescale 1ns/1ps
	`include "/afs/eecs.umich.edu/kits/ARM/TSMC_cl018g/mosis_2009q1/sc-x_2004q3v1/aci/sc/verilog/tsmc18_neg.v"
`endif

`include "include/ulpb_def.v"

module testbench();

reg 	RESET, CLK_IN;

wire	OUT, CLK_OUT;
wire	[5:0]	state_out;
reg		IN;

parameter MODE_IDLE = 0;
parameter MODE_ARBI = 1;
parameter MODE_DRIVE1 = 2;
parameter MODE_LATCH1 = 3;
parameter MODE_DRIVE2 = 4;
parameter MODE_LATCH2 = 5;
parameter MODE_ALIGN = 6;
parameter MODE_RESET = 7;

reg wait_reset;
reg	[4:0] data_counter;
reg [2:0] state;
reg	IN_REG;
reg	[3:0] tx_state;
reg [2:0] input_buffer;

reg tx_start;	// tb control

wire done = (state==MODE_RESET)? 1: 0;

control c0(.DIN(IN), .DOUT(OUT), .RESET(RESET), .CLK_OUT(CLK_OUT), .CLK(CLK_IN), .test_pt(state_out));

`define SD #1

wire [1:0] MES_SEQ_WIRE = `MES_SEQ;
wire [1:0] ACK_SEQ_WIRE = `ACK_SEQ;

reg ACK_SEQ_EXTRACT;

always @ *
begin
	ACK_SEQ_EXTRACT = 0;
	case (tx_state)
		// ACK
		2: begin ACK_SEQ_EXTRACT = ACK_SEQ_WIRE[1]; end
		3: begin ACK_SEQ_EXTRACT = ACK_SEQ_WIRE[0]; end
	endcase
end


initial
begin
	`ifdef SYNTH
		$sdf_annotate("control.dc.sdf", c0);
	`endif

	CLK_IN = 0;
	RESET = 0;
	tx_start = 0;
	
	@ (negedge CLK_IN)
	@ (posedge CLK_IN)
	@ (posedge CLK_IN)
	@ (posedge CLK_IN)
	@ (posedge CLK_IN)
		`SD RESET = 1;

	// TASK0, normal transaction
	@ (posedge CLK_IN)
	@ (posedge CLK_IN)
		`SD
		tx_start = 1;
	@ (posedge done)
		tx_start = 0;


	#3000
		$stop;
end

always @ (posedge CLK_OUT or negedge RESET)
begin
	if (~RESET)
	begin
		state <= MODE_IDLE;
		IN_REG <= 0;
		tx_state <= 0;
		data_counter <= 0;
		wait_reset <= 0;
	end
	else
	begin
		case (state)
			MODE_IDLE:
			begin
				state <= MODE_ARBI;
			end

			MODE_ARBI:
			begin
				state <= MODE_DRIVE1;
				IN_REG <= $random;
			end

			MODE_DRIVE1:
			begin
				if (input_buffer==3'b010)
					state <= MODE_ALIGN;
				else
					state <= MODE_LATCH1;
			end

			MODE_LATCH1:
			begin
				state <= MODE_DRIVE2;
				case (tx_state)
					0: begin end
					1: begin IN_REG <= MES_SEQ_WIRE[0]; tx_state <= tx_state + 1; end
					4: begin end
					default: begin IN_REG <= ACK_SEQ_EXTRACT; tx_state <= tx_state + 1; end
				endcase
			end

			MODE_DRIVE2:
			begin
				if (input_buffer==3'b010)
					state <= MODE_ALIGN;
				else
					state <= MODE_LATCH2;
			end

			MODE_LATCH2:
			begin
				state <= MODE_DRIVE1;
				case (tx_state)
					0:
					begin
						if (data_counter < 31)
						begin
							IN_REG <= $random;
							data_counter <= data_counter + 1;
						end
						else
						begin
							IN_REG <= MES_SEQ_WIRE[1];
							tx_state <= 1;
						end
					end
					4: begin wait_reset <= 1; end
					default: begin IN_REG <= ACK_SEQ_EXTRACT; tx_state <= tx_state + 1; end
				endcase
			end

			MODE_ALIGN:
			begin
				state <= MODE_RESET;
			end

			MODE_RESET:
			begin
				tx_state <= 0;
				data_counter <= 0;
				wait_reset <= 0;
				IN_REG <= 1;
				if (input_buffer[2:0]==3'b111)
					state <= MODE_IDLE;
			end
		endcase
	end
end

always @ (posedge CLK_OUT or negedge RESET)
begin
	if (~RESET)
	begin
		input_buffer <= 0;
	end
	else
	begin
		if ((state==MODE_DRIVE1)||(state==MODE_DRIVE2)||(state==MODE_ALIGN)||(state==MODE_RESET))
			input_buffer <= {input_buffer[1:0], OUT};
	end
end

always @ *
begin
	IN = OUT;
	case (state)
		MODE_IDLE:
		begin
			if (tx_start)
				IN = 0;
			else
				IN = 1;
		end

		MODE_ARBI:
		begin
			if (tx_start)
				IN = 0;
			else
				IN = 1;
		end

		MODE_DRIVE1:
		begin
			if (~wait_reset)
				IN = IN_REG;
			else
				IN = OUT;
		end

		MODE_DRIVE2:
		begin
			if (~wait_reset)
			begin
				if (tx_state)
					IN = IN_REG;
				else
					IN = OUT;
			end
			else
				IN = OUT;
		end
	endcase
end

always #50 CLK_IN = ~CLK_IN;


endmodule