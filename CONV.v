`timescale 1ns/10ps

`include "layer0.v"
`include "layer12.v"

module  CONV(
	input		clk,
	input		reset,
	output		busy,	
	input		ready,	
			
	output	[11:0]	iaddr,
	input	[19:0]	idata,	
	
	output	 	cwr,
	output	 [11:0]	caddr_wr,
	output	 [19:0]	cdata_wr,
	
	output	 	crd,
	output	 [11:0]	caddr_rd,
	input	 [19:0]	cdata_rd,
	
	output	 [2:0]	csel
);

//top
reg [19:0] i_data;
reg _ready;

//submodule
wire valid;
wire [18:0] data_0, data_1;
wire busy_layer0, busy_layer12;
wire go_down;

assign busy = busy_layer0 | busy_layer12;
assign crd = 1'd0;
assign caddr_rd = 12'd0;


always @(posedge clk or posedge reset) begin
	if(reset) begin 
		i_data <= 20'd0;
		_ready <= 1'd0;
	end else begin
		i_data <= idata;
		_ready <= ready;
	end
end

layer0 layer0(.clk(clk), .reset(reset), .o_busy(busy_layer0), .i_ready(_ready), .i_go_down(go_down), 
	.o_addr(iaddr), .i_data(i_data), .o_valid  (valid), .o_data_0 (data_0), .o_data_1 (data_1));

layer12 layer12(.clk(clk), .reset(reset), .o_busy(busy_layer12), .o_go_down(go_down), 
	.o_wr(cwr), .o_addr(caddr_wr), .o_data(cdata_wr), .o_sel(csel), .i_valid(valid), .i_data_0(data_0), .i_data_1(data_1));

endmodule




