`include "kernal.v"

module layer0(
	input clk,
	input reset,
	output reg o_busy,
	input i_ready,
	input i_go_down,

	output reg [11:0] o_addr,
	input [19:0] i_data,

	output o_valid,
	output [18:0] o_data_0,
	output [18:0] o_data_1
);

integer i;

//IO
reg n_o_busy;
reg [11:0] n_o_addr;

//control
localparam IDLE = 3'd0;
localparam INIT = 3'd1;
localparam RUN1_BUF = 3'd2;
localparam RUN2 = 3'd3;
localparam RUN2_BUF = 3'd4;
localparam WAIT = 3'd5;
localparam RUN1 = 3'd6;
localparam LAST = 3'd7;
reg [2:0] state, n_state;

//men
reg [19:0] mem [0:191];
reg [19:0] n_mem [0:191];
reg [6:0]  data_addr;

//kernal
reg [179:0] k_element, n_k_element;
reg k_valid, n_k_valid;

task kernal_nop;
	begin
		n_k_element = k_element;
		n_k_valid = 1'd0;
	end
endtask

task kernal_normal;
	input [5:0] pos;
	begin
		n_k_element[160 +: 20] = pos    ? mem[{2'b00, pos} - 7'd1] : 20'd0; //0
		n_k_element[140 +: 20] = mem[pos];                                 //1
		n_k_element[120 +: 20] = (~pos) ? mem[{2'b00, pos} + 7'd1] : 20'd0; //2
		n_k_element[100 +: 20] = pos    ? mem[{2'b01, pos} - 7'd1] : 20'd0;//3
		n_k_element[ 80 +: 20] = mem[{2'b01, pos}];//4
		n_k_element[ 60 +: 20] = (~pos) ? mem[{2'b01, pos} + 7'd1] : 20'd0;
		n_k_element[ 40 +: 20] = pos    ? mem[{2'b10, pos} - 7'd1] : 20'd0;
		n_k_element[ 20 +: 20] = mem[{2'b10, pos}];
		n_k_element[  0 +: 20] = (~pos) ? i_data : 20'd0;

		n_k_valid = 1'd1;
	end
endtask

task kernal_last;
	input [5:0] pos;
	begin
		n_k_element[160 +: 20] = pos    ? mem[{2'b00, pos} - 7'd1] : 20'd0; //0
		n_k_element[140 +: 20] = mem[pos];                                 //1
		n_k_element[120 +: 20] = (~pos) ? mem[{2'b00, pos} + 7'd1] : 20'd0; //2
		n_k_element[100 +: 20] = pos    ? mem[{2'b01, pos} - 7'd1] : 20'd0;//3
		n_k_element[ 80 +: 20] = mem[{2'b01, pos}];//4
		n_k_element[ 60 +: 20] = (~pos) ? mem[{2'b01, pos} + 7'd1] : 20'd0;
		n_k_element[ 40 +: 20] = 20'd0;
		n_k_element[ 20 +: 20] = 20'd0;
		n_k_element[  0 +: 20] = 20'd0;

		n_k_valid = 1'd1;
	end
endtask

function [11:0] nxt_init_addr;
	input [11:0] addr;
	nxt_init_addr = (addr >= 12'd127) ? addr + 12'd1 :
				 	addr[6] ? {6'd0,addr[5:0]+ 6'd1} : {6'd1, addr[5:0]};
endfunction

always @(*) begin
	n_state = state;
	n_o_addr = o_addr;
	n_o_busy = 1'd1;
	for(i = 0; i < 192; i = i+1)n_mem[i] = mem[i];
	kernal_nop;

	case (state)
		IDLE : begin
			n_o_busy = i_ready;
			if(i_ready) n_state = INIT;
		end

		INIT : begin
			n_mem[{1'b0, data_addr} + 8'd64] = i_data;
			n_o_addr = nxt_init_addr(o_addr);
			if(data_addr[6] && data_addr != 7'd64) kernal_normal(data_addr[5:0] - 6'd1);

			if(data_addr == 12'd127) begin
				n_state = RUN1_BUF;
			end
		end

		RUN1_BUF : begin
			n_state = RUN2;
			for(i = 0; i < 64; i = i+1) begin
				n_mem[i] = mem[64 + i];
				n_mem[64 + i] = mem[128 + i];
				n_mem[128 + i] = i ? 20'd0 : i_data;
			end
			n_o_addr = o_addr + 12'd1;
			kernal_normal(63);

			//last
			if(data_addr == 12'hFFF) begin
				n_state = LAST;
				n_mem[128] = 20'd0;
			end
		end

		RUN2 : begin
			n_mem[128 + data_addr[5:0]] = i_data;
			kernal_normal(data_addr[5:0] - 12'd1);
			n_o_addr = o_addr + 12'd1;

			//last
			if(data_addr[5:0] == 6'd63) n_state = RUN2_BUF;
		end

		RUN2_BUF : begin
			n_state = WAIT;
			for(i = 0; i < 64; i = i+1) begin
				n_mem[i] = mem[64 + i];
				n_mem[64 + i] = mem[128 + i];
				n_mem[128 + i] = i ? 20'd0 : i_data;
			end
			n_o_addr = o_addr + 12'd1;
			kernal_normal(63);
		end

		WAIT : begin
			if(i_go_down) begin
				n_state = RUN1;
				n_o_addr = o_addr + 12'd1;
			end
			n_o_busy = 1'd0;
		end
	endcase
end

always @(posedge clk, posedge reset) begin
	if(reset) begin
		//control
		state <= IDLE;
		data_addr <= 7'd0; 
		//IO
		o_busy <= 1'd0;
		o_addr <= 12'd0;
		//mem
		for(i = 0; i < 192; i = i+1)mem[i] <= 20'd0;
		//kernal
		k_element <= 180'd0;
		k_valid <= 1'd0;
	end else begin
		//control
		state <= n_state;
		data_addr <= o_addr[6:0];
		//IO
		o_busy <= n_o_busy;
		o_addr <= n_o_addr;
		//mem
		for(i = 0; i < 192; i = i+1)mem[i] <= n_mem[i];
		//kernal
		k_element <= n_k_element;
		k_valid <= n_k_valid;
	end
end

kernal kernal (.clk(clk), .reset(reset), .i_valid(k_valid), .i_data(k_element), 
	.o_valid(o_valid), .o_data_0(o_data_0), .o_data_1(o_data_1));

endmodule