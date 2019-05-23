module subKernal #( parameter [179 :0] weight = 180'h0, parameter [39:0] bias = 20'h0) (
	input clk,
	input reset,

	input [179:0] i_data,
	output reg [18:0] o_data
);
genvar idx;
integer i;
//step1
reg  [359:0] mul;
wire [359:0] n_mul;

generate
	for(idx = 0; idx < 9; idx = idx +1) begin
		assign n_mul[idx*40 +: 40] = $signed(i_data[idx*20 +: 20]) * $signed(weight[idx*20 +: 20]);
	end
endgenerate

//step2
reg  [79:0] middle;
wire [79:0] n_middle;
assign n_middle[40+:40] = (bias         + mul[  0+:40]) + (mul[ 40+:40] + mul[ 80+:40]) + mul[120+:40];
assign n_middle[ 0+:40] = (mul[160+:40] + mul[200+:40]) + (mul[240+:40] + mul[280+:40]) + mul[320+:40];

//step3
wire [39:0] total;
wire [19:0] reduce;
wire [18:0] relu;
assign total = middle[39:0] + middle[79:40];
assign reduce = total[16+:20] + total[15];
assign relu = reduce[19] ? 19'd0 : reduce[18:0];

always @(posedge clk, posedge reset) begin
	if(reset) begin
		mul <= 360'd0;
		middle <= 80'd0;
		o_data <= 20'd0;
	end else begin
		mul <= n_mul;
		middle <= n_middle;
		o_data <= relu;
	end
end
endmodule // subKernal

module kernal (
	input clk,    // Clock
	input reset,

	input i_valid,
	input [179:0] i_data,

	output o_valid,
	output [18:0] o_data_0,
	output [18:0] o_data_1
);

reg [2:0] valid;
assign o_valid = valid[2];

always @(posedge clk or posedge reset) begin
	if(reset)valid <= 3'd0;
	else valid <= {valid[1:0], i_valid};
end

subKernal #(.weight(180'h0A89E_092D5_06D43_01004_F8F71_F6E54_FA6D7_FC834_FAC19), .bias(40'h0_01310_0000)) 
	kernal0 (.clk(clk), .reset(reset), .i_data(i_data), .o_data(o_data_0));
subKernal #(.weight(180'hFDB55_02992_FC994_050FD_02F20_0202D_03BD7_FD369_05E68), .bias(40'hF_F7295_0000)) 
	kernal1 (.clk(clk), .reset(reset), .i_data(i_data), .o_data(o_data_1));

endmodule