module subKernal #( parameter [179 :0] weight = 180'h0, parameter [19:0] bias = 20'h0) (
	input clk,
	input reset,

	input [179:0] i_data,
	output reg [19:0] o_data
);
endmodule // subKernal

module kernal (
	input clk,    // Clock
	input reset,

	input i_valid,
	input [179:0] i_data,

	output o_valid,
	output [19:0] o_data_0,
	output [19:0] o_data_1
);

subKernal #(.weight(180'h0), .bias(20'h0)) k0 (.clk(clk), .reset(reset), .i_data(i_data), .o_data(o_data_0));
subKernal #(.weight(180'h0), .bias(20'h0)) k1 (.clk(clk), .reset(reset), .i_data(i_data), .o_data(o_data_1));

endmodule