`include "kernal.v"

module layer0(
	input clk,
	input reset,
	output reg o_busy,
	input i_ready,

	output reg [11:0] o_addr,
	input [19:0] i_data,

	output o_valid,
	output [18:0] o_data
);

integer i;

//IO
reg n_o_busy;
reg [11:0] n_o_addr;

//control
localparam IDLE       = 3'd0;
localparam INIT       = 3'd1;
localparam INIT_RUN   = 3'd2;
localparam      WAIT  = 3'd3;
localparam     SHIFT  = 3'd4;
localparam      RUN   = 3'd5;
localparam LAST_SHIFT = 3'd6;
localparam LAST_RUN   = 3'd7;
reg [2:0] state, n_state;
reg [3:0] step_counter, n_step_counter;
reg [4:0] conv_counter, n_conv_counter;

//men
reg [19:0]   mem [0:255];
reg [19:0] n_mem [0:255];
reg [ 7:0] data_addr;

//kernal
reg [179:0] k_element, n_k_element;
reg k_valid, n_k_valid;
reg k_sel, n_k_sel;

task kernal_nop;
	begin
		n_k_element = k_element;
		n_k_valid = 1'd0;
		n_k_sel = k_sel;
	end
endtask

task kernal_normal;
	input [6:0] pos;
	begin
		n_k_element[160 +: 20] =   pos[5:0]  ? mem[{1'b0, pos} - 8'd1 ] : 20'd0; //0
		n_k_element[140 +: 20] =               mem[       pos         ];         //1
		n_k_element[120 +: 20] = (~pos[5:0]) ? mem[{1'b0, pos} + 8'd1 ] : 20'd0; //2
		n_k_element[100 +: 20] =   pos[5:0]  ? mem[{1'b0, pos} + 8'd63] : 20'd0;//3
		n_k_element[ 80 +: 20] =               mem[{1'b0, pos} + 8'd64];//4
		n_k_element[ 60 +: 20] = (~pos[5:0]) ? mem[{1'b0, pos} + 8'd65] : 20'd0;
		n_k_element[ 40 +: 20] =   pos[5:0]  ? mem[{1'b1, pos} - 8'd1 ] : 20'd0;
		n_k_element[ 20 +: 20] =               mem[{1'b1, pos}        ];
		n_k_element[  0 +: 20] = (~pos[5:0]) ? mem[{1'b1, pos} + 8'd1 ] : 20'd0;

		n_k_valid = 1'd1;
		n_k_sel = ~k_sel;
	end
endtask

function [11:0] nxt_init_addr;
	input [11:0] addr;
	begin
		if(addr[5:0] < 6'd2) begin //first left
			if(addr == 12'd129)nxt_init_addr = 12'd2;
			else nxt_init_addr = addr[0] ? {addr[11:1], 1'b0} + 12'd64 : addr + 12'd1;
		end else begin
			if(addr >= 12'd191)nxt_init_addr = 12'd192;
			else nxt_init_addr = addr[7] ? {addr[11:8], 2'd0, addr[5:0] + 6'd1} : addr + 12'd64;
		end
	end
endfunction

function [11:0] nxt_addr;
	input [11:0] addr;
	begin
		if(addr[6:0] == 7'd63)nxt_addr = addr + 12'd1;
		else nxt_addr = addr[6] ? addr + 12'd64 : addr - 12'd63;
	end
endfunction

//control && read
always @(*) begin
	n_o_addr = o_addr;
	for(i = 0; i < 256; i = i+1)n_mem[i] = mem[i];

	n_o_busy = 1'd1;

	case (state)
		IDLE : begin
			n_state = i_ready ? INIT : IDLE;
			n_o_busy = i_ready;

			n_o_addr = 12'd0;
			for(i = 0; i < 256; i = i+1)n_mem[i] = 20'd0;
		end

		INIT : begin
			n_state = (data_addr == 8'd65) ? INIT_RUN : INIT;

			n_o_addr = nxt_init_addr(o_addr);
			n_mem[data_addr + 12'd64] = i_data;
			
		end

		INIT_RUN : begin
			n_state = (o_addr == 12'd191) ? WAIT : INIT_RUN;

			n_o_addr = nxt_init_addr(o_addr);
			n_mem[data_addr + 12'd64] = i_data;
		end

		WAIT : begin
			n_state = WAIT;
			n_mem[255] = (data_addr[5:0] == 6'd63) ? i_data : mem[255];

			if(conv_counter == 5'd31 && step_counter == 4'd6) begin
				n_state  = (o_addr == 12'd4032) ? LAST_SHIFT : 
							o_addr ? SHIFT : IDLE;
				n_o_addr = (o_addr == 12'd4032) ? 12'd4033   :
							o_addr ? nxt_addr(o_addr) : 12'd0;
			end
		end

		SHIFT : begin
			n_state = RUN;

			n_o_addr = nxt_addr(o_addr);
			for(i =   0; i < 128; i = i+1)n_mem[i] = mem[i+128];
			n_mem[128] = i_data;
			for(i = 129; i < 256; i = i+1)n_mem[i] = 20'd0;
		end

		RUN : begin
			n_state = (o_addr[6:0] == 7'd63) ? WAIT : RUN;

			n_o_addr = nxt_addr(o_addr);
			n_mem[{1'b1, ~data_addr[6], data_addr[5:0]}] = i_data;
		end

		LAST_SHIFT : begin
			n_state = LAST_RUN;

			n_o_addr = 12'd4034;
			for(i =   0; i < 128; i = i+1)n_mem[i] = mem[i+128];
			n_mem[128] = i_data;
			for(i = 129; i < 256; i = i+1)n_mem[i] = 20'd0;
		end

		LAST_RUN : begin
			n_state = (o_addr[5:0] == 6'd63) ? WAIT : LAST_RUN;

			n_o_addr = o_addr + 12'd1;
			n_mem[{2'b10, data_addr[5:0]}] = i_data;
		end
		
	endcase
end

//write to kernal
always @(*) begin
	case (state)
		IDLE, INIT : begin
			kernal_nop;
			n_conv_counter = 5'd0;
			n_step_counter = 4'd0;
		end

		default : begin
			n_conv_counter = (step_counter == 4'd11) ? conv_counter + 5'd1 : conv_counter;
			n_step_counter = (step_counter == 4'd11) ? 4'd0 : step_counter + 4'd1;

			if(step_counter[3])kernal_nop;
			else kernal_normal({step_counter[1], conv_counter, step_counter[2]});
		end
	endcase
end

always @(posedge clk or posedge reset) begin
	if(reset) begin
		//control
		state <= IDLE;
		data_addr <= 8'd0;
		conv_counter <= 5'd0;
		step_counter <= 4'd0; 
		//IO
		o_busy <= 1'd0;
		o_addr <= 12'd0;
		//mem
		for(i = 0; i < 256; i = i+1)mem[i] <= 20'd0;
		//kernal
		k_element <= 180'd0;
		k_valid <= 1'd0;
		k_sel <= 1'd1;
	end else begin
		//control
		state <= n_state;
		data_addr <= o_addr[7:0];
		conv_counter <= n_conv_counter;
		step_counter <= n_step_counter;
		//IO
		o_busy <= n_o_busy;
		o_addr <= n_o_addr;
		//mem
		for(i = 0; i < 256; i = i+1)mem[i] <= n_mem[i];
		//kernal
		k_element <= n_k_element;
		k_valid <= n_k_valid;
		k_sel <= n_k_sel;
	end
end

kernal kernal (.clk(clk), .reset(reset), .i_valid(k_valid), .i_data(k_element), 
	.o_valid(o_valid), .o_data(o_data), .i_sel(k_sel));

endmodule