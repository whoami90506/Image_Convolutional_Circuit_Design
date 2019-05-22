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
	output [19:0] o_data_0,
	output [19:0] o_data_1
);

//kernal
reg [179:0] k_element, n_k_element;
reg k_valid, n_k_valid;

kernal k (.clk(clk), .reset(reset), .i_valid(k_valid), .i_data(k_element), 
	.o_valid(o_valid), .o_data_0(o_data_0), .o_data_1(o_data_1));

endmodule