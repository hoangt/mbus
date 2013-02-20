
`include "include/ulpb_def.v"

module ulpb_node32(
	input CLKIN, 
	input RESETn, 
	input DIN, 
	output reg CLKOUT,
	output reg DOUT, 
	input [`ADDR_WIDTH-1:0] TX_ADDR, 
	input [`DATA_WIDTH-1:0] TX_DATA, 
	input TX_PEND, 
	input TX_REQ, 
	input PRIORITY,
	output reg TX_ACK, 
	output reg [`ADDR_WIDTH-1:0] RX_ADDR, 
	output reg [`DATA_WIDTH-1:0] RX_DATA, 
	output reg RX_REQ, 
	input RX_ACK, 
	output reg RX_PEND, 
	output reg TX_FAIL, 
	output reg TX_SUCC, 
	input TX_RESP_ACK
);

`include "include/ulpb_func.v"

parameter ADDRESS = 8'hef;
parameter ADDRESS_MASK=8'hff;

// Node mode
parameter MODE_TX_NON_PRIO = 0;
parameter MODE_TX = 1;
parameter MODE_RX = 2;
parameter MODE_FWD = 3;

// BUS state
parameter BUS_IDLE = 0;
parameter BUS_ARBITRATE = 1;
parameter BUS_PRIO = 2;
parameter BUS_ADDR = 3;
parameter BUS_DATA_RX_ADDI = 4;
parameter BUS_DATA = 5;
parameter BUS_INTERRUPT = 6;
parameter BUS_CONTROL0 = 7;
parameter BUS_CONTROL1 = 8;
parameter BUS_CONTROL2 = 9;
parameter NUM_OF_BUS_STATE = 10;

// general registers
reg		[1:0] mode, next_mode;
reg		[log2(NUM_OF_BUS_STATE-1)-1:0] bus_state, next_bus_state, bus_state_neg;
reg		[log2(`DATA_WIDTH-1)-1:0] bit_position, next_bit_position; 
reg		req_interrupt, next_req_interrupt;
reg		out_reg_pos, next_out_reg_pos, out_reg_neg;

// tx registers
reg		[`ADDR_WIDTH-1:0] ADDR, next_addr;
reg		[`DATA_WIDTH-1:0] DATA, next_data;
reg		tx_pend, next_tx_pend;
reg		tx_underflow, next_tx_underflow;

// rx registers
reg		[`ADDR_WIDTH-1:0] next_rx_addr;
reg		[`DATA_WIDTH-1:0] next_rx_data; 
reg		[`DATA_WIDTH+1:0] rx_data_buf, next_rx_data_buf;

// interrupt register
reg		BUS_INT_RSTn, next_bus_int_rstn;
wire	BUS_INT_STATE, BUS_INT;

// interface registers
reg		next_tx_ack;
reg		next_tx_fail;
reg		next_tx_success;
reg		next_rx_req;
reg		next_rx_pend;

wire	addr_bit_extract = ((ADDR  & (1'b1<<bit_position))==0)? 1'b0 : 1'b1;
wire	data_bit_extract = ((DATA & (1'b1<<bit_position))==0)? 1'b0 : 1'b1;
wire	address_match = (((RX_ADDR^ADDRESS)&ADDRESS_MASK)==0)? 1'b1 : 1'b0;

always @ (posedge CLKIN or negedge RESETn or posedge BUS_INT)
begin
	if (~RESETn)
	begin
		// general registers
		mode <= MODE_RX;
		bus_state <= BUS_IDLE;
		bit_position <= `ADDR_WIDTH - 1'b1;
		req_interrupt <= 0;
		out_reg_pos <= 0;
		// Transmitter registers
		ADDR <= 0;
		DATA <= 0;
		tx_pend <= 0;
		tx_underflow <= 0;
		// Receiver register
		RX_ADDR <= 0;
		RX_DATA <= 0;
		rx_data_buf <= 0;
		// interrupt register
		BUS_INT_RSTn <= 1;
		// Interface registers
		TX_ACK <= 0;
		RX_REQ <= 0;
		RX_PEND <= 0;
		TX_FAIL <= 0;
		TX_SUCC <= 0;
	end
	else
	begin
		// general registers
		mode <= next_mode;
		if (BUS_INT)
			bus_state <= BUS_INTERRUPT;
		else
			bus_state <= next_bus_state;
		bit_position <= next_bit_position;
		req_interrupt <= next_req_interrupt;
		out_reg_pos <= next_out_reg_pos;
		// Transmitter registers
		ADDR <= next_addr;
		DATA <= next_data;
		tx_pend <= next_tx_pend;
		tx_underflow <= next_tx_underflow;
		// Receiver register
		RX_ADDR <= next_rx_addr;
		RX_DATA <= next_rx_data;
		rx_data_buf <= next_rx_data_buf;
		// interrupt register
		BUS_INT_RSTn <= next_bus_int_rstn;
		// Interface registers
		TX_ACK <= next_tx_ack;
		RX_REQ <= next_rx_req;
		RX_PEND <= next_rx_pend;
		TX_FAIL <= next_tx_fail;
		TX_SUCC <= next_tx_success;
	end
end

always @ *
begin
	// general registers
	next_mode = mode;
	next_bus_state = bus_state;
	next_bit_position = bit_position;
	next_req_interrupt = req_interrupt;
	next_out_reg_pos = out_reg_pos;

	// Transmitter registers
	next_addr = ADDR;
	next_data = DATA;
	next_tx_pend = tx_pend;
	next_tx_underflow = tx_underflow;

	// Receiver register
	next_rx_addr = RX_ADDR;
	next_rx_data = RX_DATA;
	next_rx_data_buf = rx_data_buf;

	// interrupt register
	next_bus_int_rstn = 1;
	
	// Interface registers
	next_rx_req = RX_REQ;
	next_rx_pend = RX_PEND;
	next_tx_fail = TX_FAIL;
	next_tx_success = TX_SUCC;
	next_tx_ack = TX_ACK;

	// Asynchronous interface
	if (TX_ACK & (~TX_REQ))
		next_tx_ack = 0;
	
	if (RX_REQ & RX_ACK)
	begin
		next_rx_req = 0;
		next_rx_pend = 0;
	end

	if (TX_RESP_ACK)
	begin
		next_tx_fail = 0;
		next_tx_success = 0;
	end


	case (bus_state)
		BUS_IDLE:
		begin
			if (DIN^DOUT)
				next_mode = MODE_TX_NON_PRIO;
			else
				next_mode = MODE_RX;
			// general registers
			next_bus_state = BUS_ARBITRATE;
			next_bit_position = `ADDR_WIDTH - 1'b1;
		end

		BUS_ARBITRATE:
		begin
			next_bus_state = BUS_PRIO;
		end

		BUS_PRIO:
		begin
			if (mode==MODE_TX_NON_PRIO)
			begin
				// Lose Priority
				if (DIN^DOUT)
				begin
					next_mode = MODE_RX;
				end
				// Remain Arbitration
				else
				begin
					next_addr = TX_ADDR;
					next_data = TX_DATA;
					next_mode = MODE_TX;
					next_tx_ack = 1;
					next_tx_pend = TX_PEND;
				end
			end
			else
			begin
				// Win Priority
				if (DIN^DOUT)
				begin
					next_addr = TX_ADDR;
					next_data = TX_DATA;
					next_mode = MODE_TX;
					next_tx_ack = 1;
					next_tx_pend = TX_PEND;
				end
				else
				begin
					next_mode = MODE_RX;
				end
			end
			next_bus_state = BUS_ADDR;
		end

		BUS_ADDR:
		begin
			if (bit_position)
				next_bit_position = bit_position - 1'b1;
			else
			begin
				next_bit_position = `DATA_WIDTH - 1'b1;
				if (mode==MODE_RX)
					next_bus_state = BUS_DATA_RX_ADDI;
				else
					next_bus_state = BUS_DATA;
			end
			if (mode==MODE_RX)
				next_rx_addr = {RX_ADDR[`ADDR_WIDTH-2:0], DIN};
		end

		BUS_DATA_RX_ADDI:
		begin
			next_rx_data_buf = {rx_data_buf[`DATA_WIDTH:0], DIN};
			next_bit_position = bit_position - 1'b1;
			if (bit_position==(`DATA_WIDTH-2'b11))
			begin
				next_bus_state = BUS_DATA;
				next_bit_position = `DATA_WIDTH - 1'b1;
			end
			if (address_match==0)
				next_mode = MODE_FWD;
		end

		BUS_DATA:
		begin
			case (mode)
				MODE_TX:
				begin
					if (bit_position)
						next_bit_position = bit_position - 1'b1;
					else
					begin
						next_bit_position = `DATA_WIDTH - 1'b1;
						case ({tx_pend, TX_REQ})
							// continue next word
							2'b11:
							begin
								next_tx_pend = TX_PEND;
								next_data = TX_DATA;
								next_tx_ack = 1;
							end
							
							// underflow
							2'b10:
							begin
								next_bus_state = BUS_INTERRUPT;
								next_tx_underflow = 1;
								next_req_interrupt = 1;
							end

							default:
							begin
								next_bus_state = BUS_INTERRUPT;
								next_req_interrupt = 1;
							end
						endcase
					end
				end

				MODE_RX:
				begin
					next_rx_data_buf = {rx_data_buf[`DATA_WIDTH:0], DIN};
					if (bit_position)
						next_bit_position = bit_position - 1'b1;
					else
					begin
						// RX overflow
						if (RX_REQ)
						begin
							next_bus_state = BUS_INTERRUPT;
							next_req_interrupt = 1;
						end
						else
						begin
							next_bit_position = `DATA_WIDTH - 1'b1;
							next_rx_req = 1;
							next_rx_pend = 1;
							next_rx_data = rx_data_buf[`DATA_WIDTH+1:2];
						end
					end
				end

			endcase
		end

		BUS_INTERRUPT:
		begin
			if (BUS_INT)
			begin
				next_bus_state = BUS_CONTROL0;
				next_bus_int_rstn = 0;
			end
		end

		BUS_CONTROL0:
		begin
			next_bus_state = BUS_CONTROL1;
			if ((mode==MODE_RX)&&(~req_interrupt))
			begin
				// End of Message
				if (DIN)
				begin
					// RX overflow
					if (RX_REQ)
						next_out_reg_pos = 0;
					else
					begin
						next_out_reg_pos = 1;
						next_rx_req = 1;
						next_rx_pend = 0;
						// node above tx, two additional bits
						// NEED TO CHECK COUNTER STATE!!!
						if (BUS_INT_STATE)
							next_rx_data = rx_data_buf[`DATA_WIDTH+1:2];
						else
							next_rx_data = rx_data_buf[`DATA_WIDTH-1:0];
					end
				end
				else
					next_out_reg_pos = 0;
			end
		end

		BUS_CONTROL1:
		begin
			next_bus_state = BUS_CONTROL2;
			if (req_interrupt)
			begin
				if ((mode==MODE_TX)&&(~tx_underflow))
				begin
					// ACK received
					if (DIN)
						next_tx_success = 1;
					else
						next_tx_fail = 1;
				end
			end
		end

		BUS_CONTROL2:
		begin
			next_bus_state = BUS_IDLE;
			next_req_interrupt = 0;
		end
	endcase
end

always @ (negedge CLKIN or negedge RESETn)
begin
	if (~RESETn)
	begin
		bus_state_neg <= BUS_IDLE;
		out_reg_neg <= 1;
	end
	else
	begin
		bus_state_neg <= bus_state;
		case (bus_state)
			BUS_ADDR:
			begin
				if (mode==MODE_TX)
					out_reg_neg <= addr_bit_extract;
			end

			BUS_DATA:
			begin
				if (mode==MODE_TX)
					out_reg_neg <= data_bit_extract;
			end

			BUS_CONTROL0:
			begin
				if ((req_interrupt)&&(mode==MODE_TX))
				begin
					if (tx_underflow)
						out_reg_neg <= 0;
					else
						out_reg_neg <= 1;
				end
				else
					out_reg_neg <= 0;
			end

			BUS_CONTROL1:
			begin
				out_reg_neg <= out_reg_pos;
			end

			BUS_CONTROL2:
			begin
				// for now... might be changed
				if (req_interrupt)
					out_reg_neg <= 0;
			end

		endcase
	end
end

always @ *
begin
	DOUT = DIN;
	case (bus_state_neg)
		BUS_IDLE:
		begin
			DOUT = ((~TX_REQ) & DIN);
		end

		BUS_ARBITRATE:
		begin
			if (mode==MODE_TX_NON_PRIO)
				DOUT = 0;
		end

		BUS_PRIO:
		begin
			if (mode==MODE_TX_NON_PRIO)
			begin
				if (~PRIORITY)
					DOUT = 0;
				else
					DOUT = DIN;
			end
			else if ((mode==MODE_RX)&&(PRIORITY & TX_REQ))
				DOUT = 1;
		end

		BUS_ADDR:
		begin
			if (mode==MODE_TX)
				DOUT = out_reg_neg;
		end

		BUS_DATA:
		begin
			if (mode==MODE_TX)
				DOUT = out_reg_neg;
		end

		BUS_CONTROL0:
		begin
			if (req_interrupt)
				DOUT = out_reg_neg;
		end

		BUS_CONTROL1:
		begin
			if ((mode==MODE_RX)&&(~req_interrupt))
				DOUT = out_reg_neg;
		end

		BUS_CONTROL2:
		begin
			if (req_interrupt)
				DOUT = out_reg_neg;
		end

	endcase
end

always @ *
begin
	CLKOUT = CLKIN;
	case (bus_state_neg)
		BUS_INTERRUPT: begin if (req_interrupt) CLKOUT = 0; end
	endcase
end

ulpb_swapper swapper0(
	// inputs
	.CLK(CLKIN),
    .RESETn(RESETn),
    .DATA(DIN),
    .INT_FLAG_RESETn(BUS_INT_RSTn),
   	//Outputs
    .INT(),
    .LAST_CLK(BUS_INT_STATE),
    .INT_FLAG(BUS_INT));

endmodule
