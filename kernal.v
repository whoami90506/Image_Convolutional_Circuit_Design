module kernal (
	input clk,    // Clock
	input reset,

	input i_valid,
	input [179:0] i_data,
	input i_sel,

	output o_valid,
	output reg [18:0] o_data
);

parameter [179:0] weight_0 = 180'h0A89E_092D5_06D43_01004_F8F71_F6E54_FA6D7_FC834_FAC19;
parameter [179:0] weight_1 = 180'hFDB55_02992_FC994_050FD_02F20_0202D_03BD7_FD369_05E68;
parameter [39:0]    bias_0 = 40'h0_01310_0000;
parameter [39:0]    bias_1 = 40'hF_F7295_0000;

//control
reg [2:0] valid;
wire [2:0] n_valid;
assign o_valid = valid[2];
assign n_valid = {valid[1:0], i_valid};

genvar idx;
integer i;
//step1
reg  [39:0] bias;
wire [39:0] n_bias;
reg  [359:0] mul;
wire [359:0] n_mul;
wire [359:0] mul_raw_0, mul_raw_1;

assign n_bias = i_sel ? bias_1 : bias_0;
generate
	for(idx = 0; idx < 9; idx = idx +1) begin
		assign mul_raw_0[idx*40 +: 40] = $signed(i_data[idx*20 +: 20]) * $signed(weight_0[idx*20 +: 20]);
		assign mul_raw_1[idx*40 +: 40] = $signed(i_data[idx*20 +: 20]) * $signed(weight_1[idx*20 +: 20]);
		assign n_mul = i_sel ? mul_raw_1 : mul_raw_0;
	end
endgenerate

//step2
reg  [79:0] middle;
wire [79:0] n_middle;
assign n_middle[40+:40] = (mul[120+:40] + mul[  0+:40]) + (mul[ 40+:40] + mul[ 80+:40]) +         bias;
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
		valid <= 3'd0;
		bias <= bias_0;
	end else begin
		mul <= n_mul;
		middle <= n_middle;
		o_data <= relu;
		valid <= n_valid;
		bias <= n_bias;
	end
end
endmodule