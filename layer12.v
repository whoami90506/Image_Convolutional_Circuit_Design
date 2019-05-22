module layer12(
	input clk,
	input reset,
	output o_busy,
	output reg o_go_down,

	output reg o_wr,
	output reg [11:0] o_addr,
	output reg [19:0] o_data,
	output reg [ 2:0] o_sel,

	input i_valid,
	input [19:0] i_data_0,
	input [19:0] i_data_1
);
assign o_busy = 1'b0;
endmodule