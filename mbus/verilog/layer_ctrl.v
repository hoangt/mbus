
`include "include/mbus_def.v"

module layer_ctrl(

	input		CLK,
	input		RESETn,

	// Interface with MBus
	output reg	[`ADDR_WIDTH-1:0] TX_ADDR, 
	output reg	[`DATA_WIDTH-1:0] TX_DATA, 
	output reg	TX_PEND, 
	output reg	TX_REQ, 
	input		TX_ACK, 
	output reg	PRIORITY,

	input		[`ADDR_WIDTH-1:0] RX_ADDR, 
	input		[`DATA_WIDTH-1:0] RX_DATA, 
	input		RX_PEND, 
	input		RX_REQ, 
	output reg	RX_ACK, 
	input		RX_BROADCAST,

	input		RX_FAIL,
	input		TX_FAIL, 
	input		TX_SUCC, 
	output reg	TX_RESP_ACK,

	input 		RELEASE_RST_FROM_MBUS,
	// End of interface
	
	// Interface with Registers
	input		[(`LC_RF_DATA_WIDTH*`LC_RF_NUM)-1:0] RF_IN,
	output reg	RF_OUT,
	output reg	[`LC_RF_NUM-1:0] RF_MSB_LOAD,
	output reg	[`LC_RF_NUM-1:0] RF_LSB_LOAD,
	// End of interface
	
	// Interface with MEM
	output 		MEM_REQ_OUT,
	output 		MEM_WRITE,
	input		MEM_ACK_IN,
	output reg	[`LC_MEM_DATA_WIDTH-1:0] MEM_DATA_OUT,
	output reg	[`LC_MEM_ADDR_WIDTH-1:0] MEM_ADDR_OUT,
	input		[`LC_MEM_DATA_WIDTH-1:0] MEM_DATA_IN,
	// End of interface
	
	// Interface with Sensors
	input		[(`LC_SENSOR_DATA_WIDTH*`LC_SENSOR_NUM)-1:0] SENSOR_DIN,
	// End of interface
	
	// Interrupt
	input		INTERRUPT,
	output reg	CLR_INT
);

wire	resetn_local = (RESETn & (~RELEASE_RST_FROM_MBUS));

parameter BUF_SIZE = 4;
parameter LC_STATE_IDLE = 0;

// General registers
reg		[2:0]	lc_state, next_lc_state;
reg		rx_pend_reg, next_rx_pend_reg;
reg		[`FUNC_WIDTH-1:0] 	rx_func_id, next_rx_func_id;
reg		[`DATA_WIDTH-1:0] 	rx_dat_buffer [0:BUF_SIZE-1];
reg		[`DATA_WIDTH-1:0] 	next_rx_dat_buffer [0:BUF_SIZE-1];

// Interrupt register
reg		next_clr_int;

// Mbus interface
reg		[`ADDR_WIDTH-1:0] 	next_tx_addr;
reg		[`DATA_WIDTH-1:0]	next_tx_data;
reg		next_tx_pend;
reg		next_tx_req;
reg		next_priority;
reg		next_rx_ack;
reg		next_tx_resp_ack;

// RF interface
wire	[`LC_RF_DATA_WIDTH-1:0] rf_in_array [0:`LC_RF_NUM-1];
genvar unpk_idx; 
generate 
	for (unpk_idx=0; unpk_idx<(`LC_RF_NUM); unpk_idx=unpk_idx+1)
	begin: UNPACK
		assign rf_in_array[unpk_idx][((`LC_RF_DATA_WIDTH)-1):0] = RF_IN[((`LC_RF_DATA_WIDTH)*(unpk_idx+1)-1):((`LC_RF_DATA_WIDTH)*unpk_idx)]; 
	end
endgenerate
reg		[`LC_RF_NUM-1:0] next_rf_msb_load, next_rf_lsb_load;

// Mem interface
reg		mem_write, next_mem_write, mem_read, next_mem_read;
assign	MEM_REQ_OUT = (mem_write | mem_read);
assign	MEM_WRITE = mem_write;

// Sensor interface
wire	[`LC_SENSOR_DATA_WIDTH-1:0] sensor_din_array [0:`LC_SENSOR_NUM-1];
generate 
	for (unpk_idx=0; unpk_idx<(`LC_SENSOR_NUM); unpk_idx=unpk_idx+1)
	begin: S_UNPACK
		assign sensor_din_array[unpk_idx][((`LC_SENSOR_DATA_WIDTH)-1):0] = SENSOR_DIN[((`LC_SENSOR_DATA_WIDTH)*(unpk_idx+1)-1):((`LC_SENSOR_DATA_WIDTH)*unpk_idx)]; 
	end
endgenerate

always @ (posedge CLK or negedge resetn_local)
begin
	if (~resetn_local)
	begin
		// General registers
		lc_state <= LC_STATE_IDLE;
		rx_pend_reg <= 0;
		rx_func_id <= 0;
		// rx buffers
		rx_dat_buffer[0] <= 0;
		rx_dat_buffer[1] <= 0;
		rx_dat_buffer[2] <= 0;
		rx_dat_buffer[3] <= 0;
		// MBus interface
		TX_ADDR <= 0;
		TX_DATA <= 0;
		TX_PEND <= 0;
		TX_REQ	<= 0;
		PRIORITY<= 0;
		RX_ACK	<= 0;
		TX_RESP_ACK <= 0;
		// Register file interface
		RF_MSB_LOAD <= 0;
		RF_LSB_LOAD <= 0;
		// Interrupt interface
		CLR_INT <= 0;
	end
	else
	begin
		// General registers
		lc_state <= next_lc_state;
		rx_pend_reg <= next_rx_pend_reg;
		rx_func_id <= next_rx_func_id;
		// rx buffers
		rx_dat_buffer[0] <= next_rx_dat_buffer[0];
		rx_dat_buffer[1] <= next_rx_dat_buffer[1];
		rx_dat_buffer[2] <= next_rx_dat_buffer[2];
		rx_dat_buffer[3] <= next_rx_dat_buffer[3];
		// MBus interface
		TX_ADDR <= next_tx_addr;
		TX_DATA <= next_tx_data;
		TX_PEND <= next_tx_pend;
		TX_REQ	<= next_tx_req;
		PRIORITY<= next_priority;
		RX_ACK	<= next_rx_ack;
		TX_RESP_ACK <= next_tx_resp_ack;
		// Register file interface
		RF_MSB_LOAD <= next_rf_msb_load;
		RF_LSB_LOAD <= next_rf_lsb_load;
		// Interrupt interface
		CLR_INT <= next_clr_int;
	end
end

always @ *
begin
	// General registers
	next_lc_state 	= lc_state;
	next_rx_pend_reg= rx_pend_reg;
	next_rx_func_id = rx_func_id;
	// rx buffers
	next_rx_dat_buffer[0] = rx_dat_buffer[0];
	next_rx_dat_buffer[1] = rx_dat_buffer[1];
	next_rx_dat_buffer[2] = rx_dat_buffer[2];
	next_rx_dat_buffer[3] = rx_dat_buffer[3];
	// MBus registers
	next_tx_addr 	= TX_ADDR;
	next_tx_data 	= TX_DATA;
	next_tx_pend 	= TX_PEND;
	next_tx_req 	= TX_REQ;
	next_priority 	= PRIORITY;
	next_rx_ack		= RX_ACK;
	next_tx_resp_ack= TX_RESP_ACK;
	// RF registers
	next_rf_msb_load = 0;
	next_rf_lsb_load = 0;
	// Interrupt registers
	next_clk_int = CLR_INT;

	// Asynchronized interface
	if ((~(RX_REQ | RX_FAIL)) & RX_ACK)
		next_rx_ack = 0;
	
	if (TX_REQ & TX_ACK)
		next_tx_req = 0;

	if (CLR_INT & (~INTERRUPT))
		next_clr_int = 0;
	// End of asynchronized interface

	case (lc_state)
		LC_STATE_IDLE:
		begin
			if (INTERRUPT)
			begin
				next_lc_state = LC_STATE_INT;
				next_clr_int = 1;
			end
			else
				if (RX_REQ | RX_FAIL)
				begin
					next_rx_ack = 1;
				end

				if (RX_REQ)
				begin
					next_rx_dat_buffer[0] = RX_DATA;
					next_rx_pend_reg = RX_PEND;
					next_rx_func_id = RX_ADDR[`FUNC_WIDTH-1:0];
					next_lc_state = LC_STATE_PROC;
				end
			end
		end

		LC_STATE_PROC:
		begin
			case (rx_func_id)
				`LC_CMD_LOAD_SHORT:
				begin
				end

				`LC_CMD_LOAD_IMMED:
				begin
				end

				`LC_CMD_LOAD_STRIDE:
				begin
				end
			endcase
		end

		LC_STATE_INT:
		begin
		end
	endcase
end


endmodule