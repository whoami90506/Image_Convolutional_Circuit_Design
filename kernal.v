module subKernal #( parameter [179 :0] weight = 180'h0, parameter [19:0] bias = 20'h0) (
	input clk,
	input reset,

	input [179:0] i_data,
	output reg [19:0] o_data
);
genvar idx;
integer i;
//step1
reg  [179:0] mul;
wire [179:0] n_mul;
wire [359:0] mul_raw;

generate
	for(idx = 0; idx < 9; idx = idx +1) begin
		assign mul_raw[idx*40 +: 40] = $signed(i_data[idx*20 +: 20]) * $signed(weight[idx*20 +: 20]);
		assign n_mul[idx*20 +: 20] = mul_raw[idx*40+16 +: 20] + mul_raw[idx*40 +15];
	end
endgenerate

//step2
reg  [39:0] s2;
wire [39:0] n_s2;
assign n_s2[39:20] = (bias        + mul[  0+:20]) + (mul[ 20+:20] + mul[ 40+:20]);
assign n_s2[19: 0] = (mul[60+:20] + mul[ 80+:20]) + (mul[100+:20] + mul[120+:20]);

//step3
wire [19:0] sum, relu;
assign sum = (s2[39:20] + s2[19: 0]) + (mul[140+:20] + mul[160+:20]);
assign relu = sum[19] ? 20'd0 : sum;

always @(posedge clk, posedge reset) begin
	if(reset) begin
		mul <= 180'd0;
		s2 <= 40'd0;
		o_data <= 20'd0;
	end else begin
		mul <= n_mul;
		s2 <= n_s2;
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
	output [19:0] o_data_0,
	output [19:0] o_data_1
);

reg [2:0] valid;
assign o_valid = valid[2];

always @(posedge clk or posedge reset) begin
	if(reset)valid <= 3'd0;
	else valid <= {valid[1:0], i_valid};
end

subKernal #(.weight(180'h0A89E_092D5_06D43_01004_F8F71_F6E54_FA6D7_FC834_FAC19), .bias(20'h01310)) 
	kernal0 (.clk(clk), .reset(reset), .i_data(i_data), .o_data(o_data_0));
subKernal #(.weight(180'hFDB55_02992_FC994_050FD_02F20_0202D_03BD7_FD369_05E68), .bias(20'hF7295)) 
	kernal1 (.clk(clk), .reset(reset), .i_data(i_data), .o_data(o_data_1));

endmodule