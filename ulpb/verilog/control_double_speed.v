
module control(DIN, DOUT, RESET, CLK_OUT, CLK, test_pt);

`include "include/ulpb_func.v"

input 	CLK;
output	CLK_OUT;
input	RESET;
input	DIN;
output	DOUT;
output	[3:0]test_pt;

parameter START_CYCLES = 12;

parameter BUS_IDLE 			= 6'b000000;
parameter WAIT_FOR_START 	= 6'b000001;
parameter ENABLE_CLK_NEG 	= 6'b100010;
parameter ARBI_RES_POS 		= 6'b000011;
parameter ARBI_RES_NEG 		= 6'b100100;
parameter DRIVE1_POS 		= 6'b000101;
parameter DRIVE1_NEG 		= 6'b100110;
parameter LATCH1_POS 		= 6'b000111;
parameter LATCH1_NEG 		= 6'b101000;
parameter DRIVE2_POS 		= 6'b001001;
parameter DRIVE2_NEG 		= 6'b101010;
parameter LATCH2_POS 		= 6'b001011;
parameter LATCH2_NEG 		= 6'b101100;
parameter RESET_S0_D_NEG 	= 6'b001101;
parameter RESET_S0_D_POS 	= 6'b101110;
parameter RESET_S0_L_NEG 	= 6'b101111;
parameter RESET_S0_L_POS 	= 6'b110000;
parameter RESET_S1_D_NEG 	= 6'b110001;
parameter RESET_S1_D_POS 	= 6'b110010;
parameter RESET_S1_L_NEG 	= 6'b110011;
parameter RESET_S1_L_POS 	= 6'b110100;
parameter RESET_S0_D1_NEG 	= 6'b110101;
parameter RESET_S0_D1_POS 	= 6'b110110;
parameter RESET_S0_L1_NEG 	= 6'b110111;
parameter RESET_S0_L1_POS 	= 6'b111000;
parameter RESET_R_D_NEG 	= 6'b011001;
parameter RESET_R_D_POS 	= 6'b011010;
parameter RESET_R_L_NEG 	= 6'b011011;
parameter RESET_R_L_POS 	= 6'b011100;
parameter BACK_TO_IDLE_NEG	= 6'b011101;
parameter BACK_TO_IDLE_POS	= 6'b011110;

parameter NUM_OF_STATES = 31;

// CLK registers
reg		CLK_HALF, next_clk_half;
reg		CLK_OUT, next_clk_out;
reg		ctrl_hold, next_ctrl_hold; 
reg		ctrl_dout, next_ctrl_dout; 

// Reset registers
reg		[2:0] seq_state, next_seq_state;

// General registers
reg		[5:0] state, next_state;
reg		[log2(START_CYCLES-1)-1:0] start_cycle_cnt, next_start_cycle_cnt;
reg		[3:0]	input_buffer;

// Combinational logics
reg		out_of_phase;
assign DOUT = (ctrl_hold)? ctrl_dout : DIN;
assign test_pt = state;

always @ (posedge CLK or negedge RESET)
begin
	if (~RESET)
	begin
		// CLK registers
		CLK_HALF <= 0;
		CLK_OUT <= 1;
		ctrl_hold <= 1;
		ctrl_dout <= 1;
		// Reset registers
		seq_state <= 0;
		// General registers
		state <= BUS_IDLE;
		start_cycle_cnt <= START_CYCLES - 1'b1;
	end
	else
	begin
		// CLK registers
		CLK_HALF <= next_clk_half;
		CLK_OUT <= next_clk_out;
		ctrl_hold <= next_ctrl_hold;
		ctrl_dout <= next_ctrl_dout;
		// Reset registers
		seq_state <= next_seq_state;
		// General registers
		state <= next_state;
		start_cycle_cnt <= next_start_cycle_cnt;
	end
end

always @ *
begin
	if ((state==DRIVE1_NEG)||(state==DRIVE2_NEG))
		out_of_phase = (input_buffer[1]^input_buffer[0]);
	else
		out_of_phase = 0;
end

always @ *
begin
	// CLK registers
	next_clk_half = CLK_HALF;
	next_clk_out = CLK_OUT;
	next_ctrl_hold = ctrl_hold;
	next_ctrl_dout = ctrl_dout;;
	// Reset registers
	next_seq_state = seq_state;
	// General registers
	next_state = state;
	next_start_cycle_cnt = start_cycle_cnt;

	case (state)
		BUS_IDLE:
		begin
			if (~DIN)
			begin
				next_state = WAIT_FOR_START;
			end
			next_start_cycle_cnt = START_CYCLES - 1'b1;
			next_seq_state = 0;
			next_clk_half = 0;
		end

		WAIT_FOR_START:
		begin
			if (start_cycle_cnt)
				next_start_cycle_cnt = start_cycle_cnt - 1'b1;
			else
			begin
				next_state = ENABLE_CLK_NEG;
				next_clk_out = 0;
			end
		end

		ENABLE_CLK_NEG:
		begin
			next_state = ARBI_RES_POS;
			next_clk_out = 1;
		end

		ARBI_RES_POS:
		begin
			next_state = ARBI_RES_NEG;
			next_clk_out = 0;
		end

		ARBI_RES_NEG:
		begin
			next_state = DRIVE1_POS;
			next_clk_out = 1;
			next_ctrl_hold = 0;
		end

		DRIVE1_POS:
		begin
			next_state = DRIVE1_NEG;
			next_clk_out = 0;
		end

		DRIVE1_NEG:
		begin
			if (out_of_phase)
			begin
				next_state = RESET_S0_D_NEG;
				next_clk_out = 0;
				next_ctrl_hold = 1;
				next_ctrl_dout = 0;
			end
			else
			begin
				next_state = LATCH1_POS;
				next_clk_out = 1;
			end
		end

		LATCH1_POS:
		begin
			next_state = LATCH1_NEG;
			next_clk_out = 0;
		end

		LATCH1_NEG:
		begin
			case (seq_state)
				0:
				begin
					next_state = DRIVE2_POS;
					next_clk_out = 1;
				end

				// 3rd of end of meesage
				1:
				begin
					// 011
					if (input_buffer[0])
					begin
						next_seq_state = seq_state + 1;
						next_state = DRIVE2_POS;
						next_clk_out = 1;
					end
					// 010, reset
					else
					begin
						next_state = RESET_S0_D_NEG;
						next_clk_out = 0;
						next_ctrl_hold = 1;
						next_ctrl_dout = 0;
					end
				end

				// 1st of ACK
				3:
				begin
					if (input_buffer[0])
					begin
						next_state = RESET_S0_D_NEG;
						next_clk_out = 0;
						next_ctrl_hold = 1;
						next_ctrl_dout = 0;
					end
					else
					begin
						next_seq_state = seq_state + 1;
						next_state = DRIVE2_POS;
						next_clk_out = 1;
					end
				end

				// 3rd of ACK
				5:
				begin
					if (input_buffer[0])
					begin
						next_seq_state = seq_state + 1;
						next_state = DRIVE2_POS;
						next_clk_out = 1;
					end
					// 010, reset
					else
					begin
						next_state = RESET_S0_D_NEG;
						next_clk_out = 0;
						next_ctrl_hold = 1;
						next_ctrl_dout = 0;
					end
				end
			endcase
		end

		DRIVE2_POS:
		begin
			next_state = DRIVE2_NEG;
			next_clk_out = 0;
		end

		DRIVE2_NEG:
		begin
			if (out_of_phase)
			begin
				next_state = RESET_S0_D_NEG;
				next_clk_out = 0;
				next_ctrl_hold = 1;
				next_ctrl_dout = 0;
			end
			else
			begin
				next_state = LATCH2_POS;
				next_clk_out = 1;
			end
		end

		LATCH2_POS:
		begin
			next_state = LATCH2_NEG;
			next_clk_out = 0;
		end

		LATCH2_NEG:
		begin
			case (seq_state)
				0:
				begin
					case ({input_buffer[2], input_buffer[0]})
						// 2nd bit of message end
						2'b01:
						begin
							next_seq_state = seq_state + 1;
							next_state = DRIVE1_POS;
							next_clk_out = 1;
						end

						2'b10:
						begin
							next_state = RESET_S0_D_NEG;
							next_clk_out = 0;
							next_ctrl_hold = 1;
							next_ctrl_dout = 0;
						end

						default:
						begin
							next_state = DRIVE1_POS;
							next_clk_out = 1;
						end
					endcase
				end

				// 4th bit of end of message
				2:
				begin
					// 0111, reset
					if (input_buffer[0])
					begin
						next_state = RESET_S0_D_NEG;
						next_clk_out = 0;
						next_ctrl_hold = 1;
						next_ctrl_dout = 0;
					end
					// 0110, end of sequence
					else
					begin
						next_seq_state = seq_state + 1;
						next_state = DRIVE1_POS;
						next_clk_out = 1;
					end
				end

				// 2nd bit of ACK
				4:
				begin
					if (input_buffer[0])
					begin
						next_seq_state = seq_state + 1;
						next_state = DRIVE1_POS;
						next_clk_out = 1;
					end
					else
					begin
						next_state = RESET_S0_D_NEG;
						next_clk_out = 0;
						next_ctrl_hold = 1;
						next_ctrl_dout = 0;
					end
				end

				6:
				begin
					next_state = RESET_S0_D_NEG;
					next_clk_out = 0;
					next_ctrl_hold = 1;
					next_ctrl_dout = 0;
				end
			endcase
		end

		RESET_S0_D_NEG:
		begin
			next_clk_half = ~CLK_HALF;
			if (CLK_HALF)
			begin
				next_state = RESET_S0_D_POS;
				next_clk_out = 1;
			end
		end

		RESET_S0_D_POS:
		begin
			next_clk_half = ~CLK_HALF;
			if (CLK_HALF)
			begin
				next_state = RESET_S0_L_NEG;
				next_clk_out = 0;
			end
		end

		RESET_S0_L_NEG:
		begin
			next_clk_half = ~CLK_HALF;
			if (CLK_HALF)
			begin
				next_state = RESET_S0_L_POS;
				next_clk_out = 1;
			end
		end

		RESET_S0_L_POS:
		begin
			next_clk_half = ~CLK_HALF;
			if (CLK_HALF)
			begin
				// 1st reset bit successed
				if (input_buffer[2:0]==0)
				begin
					next_state = RESET_S1_D_NEG;
					next_ctrl_dout = 1;
				end
				// 1st reset bit failed
				else
					next_state = RESET_S0_D_NEG;
				next_clk_out = 0;
			end
		end

		RESET_S1_D_NEG:
		begin
			next_clk_half = ~CLK_HALF;
			if (CLK_HALF)
			begin
				next_state = RESET_S1_D_POS;
				next_clk_out = 1;
			end
		end

		RESET_S1_D_POS:
		begin
			next_clk_half = ~CLK_HALF;
			if (CLK_HALF)
			begin
				next_state = RESET_S1_L_NEG;
				next_clk_out = 0;
			end
		end

		RESET_S1_L_NEG:
		begin
			next_clk_half = ~CLK_HALF;
			if (CLK_HALF)
			begin
				next_state = RESET_S1_L_POS;
				next_clk_out = 1;
			end
		end

		RESET_S1_L_POS:
		begin
			next_clk_half = ~CLK_HALF;
			if (CLK_HALF)
			begin
				// 2nd reset bit successed
				if (input_buffer==4'b1111)
					next_state = RESET_S0_D1_NEG;
				// 2nd reset bit failed
				else
					next_state = RESET_S0_D_NEG;
				next_ctrl_dout = 0;
				next_clk_out = 0;
			end
		end

		RESET_S0_D1_NEG:
		begin
			next_clk_half = ~CLK_HALF;
			if (CLK_HALF)
			begin
				next_state = RESET_S0_D1_POS;
				next_clk_out = 1;
			end
		end

		RESET_S0_D1_POS:
		begin
			next_clk_half = ~CLK_HALF;
			if (CLK_HALF)
			begin
				next_state = RESET_S0_L1_NEG;
				next_clk_out = 0;
			end
		end

		RESET_S0_L1_NEG:
		begin
			next_clk_half = ~CLK_HALF;
			if (CLK_HALF)
			begin
				next_state = RESET_S0_L1_POS;
				next_clk_out = 1;
			end
		end

		RESET_S0_L1_POS:
		begin
			next_clk_half = ~CLK_HALF;
			if (CLK_HALF)
			begin
				// 3rd reset bit successed
				if (input_buffer==4'b0000)
				begin
					next_state = RESET_R_D_NEG;
					next_ctrl_dout = 1;
				end
				// 3rd reset bit failed
				else
				begin
					next_state = RESET_S0_D_NEG;
					next_ctrl_dout = 0;
				end
				next_clk_out = 0;
			end
		end

		RESET_R_D_NEG:
		begin
			next_clk_half = ~CLK_HALF;
			if (CLK_HALF)
			begin
				next_state = RESET_R_D_POS;
				next_clk_out = 1;
			end
		end

		RESET_R_D_POS:
		begin
			next_clk_half = ~CLK_HALF;
			if (CLK_HALF)
			begin
				next_state = RESET_R_L_NEG;
				next_clk_out = 0;
			end
		end

		RESET_R_L_NEG:
		begin
			next_clk_half = ~CLK_HALF;
			if (CLK_HALF)
			begin
				next_state = RESET_R_L_POS;
				next_clk_out = 1;
			end
		end

		RESET_R_L_POS:
		begin
			next_clk_half = ~CLK_HALF;
			if (CLK_HALF)
			begin
				next_state = BACK_TO_IDLE_NEG;
				next_clk_out = 0;
			end
		end

		// additional clock cycle for each node back to idle
		BACK_TO_IDLE_NEG:
		begin
			next_clk_half = ~CLK_HALF;
			if (CLK_HALF)
			begin
				next_state = BACK_TO_IDLE_POS;
				next_clk_out = 1;
			end
		end

		BACK_TO_IDLE_POS:
		begin
			next_clk_half = ~CLK_HALF;
			if (CLK_HALF)
				next_state = BUS_IDLE;
		end

	endcase
end


always @ (posedge CLK or negedge RESET)
begin
	if (~RESET)
		input_buffer <= 0;
	else
	begin
		// need to modify
		if (state[5]&(~CLK_HALF))
			input_buffer <= {input_buffer[2:0], DIN};
	end
end


endmodule
