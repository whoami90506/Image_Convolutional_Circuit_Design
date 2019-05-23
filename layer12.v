module layer12(
	input clk,
	input reset,
	output reg o_busy,
	output reg o_go_down,

	output reg o_wr,
	output reg [11:0] o_addr,
	output reg [19:0] o_data,
	output reg [ 2:0] o_sel,

	input i_valid,
	input [18:0] i_data_0,
	input [18:0] i_data_1
);
integer i;

//contorl
reg n_o_busy;
reg [4:0] addr, n_addr;
reg [8:0] counter, n_counter;
reg n_o_go_down;

//mem
reg [18:0]   mem_0 [0:127];
reg [18:0] n_mem_0 [0:127];
reg [18:0]   mem_1 [0:127];
reg [18:0] n_mem_1 [0:127];
reg [6:0] rd_addr, n_rd_addr;

//max_mem
reg [18:0]   max_mem_0 [0:31];
reg [18:0] n_max_mem_0 [0:31];
reg [18:0]   max_mem_1 [0:31];
reg [18:0] n_max_mem_1 [0:31];
reg max_lock, n_max_lock;

//output
reg n_o_wr;
reg [11:0] n_o_addr;
reg [19:0] n_o_data;
reg [ 2:0] n_o_sel;

//control
always @(*) begin
	if(o_busy) begin
		n_o_busy = ~((addr == 5'd31) && (counter == 9'd374));
		n_addr = (counter == 9'd374) ? addr + 5'd1 : addr;
		n_counter = (counter == 9'd374) ? 9'd0 : counter + 9'd1;
		n_o_go_down = (counter == 9'd255);
	end else begin
		n_o_busy = i_valid;
		n_addr = 5'd0;
		n_counter = 9'd0;
		n_o_go_down = 1'b0;
	end
end

always @(posedge clk, posedge reset) begin
	if (reset) begin 
		//contorl
		o_busy <= 1'd0;
		addr <= 5'd0;
		counter <= 8'd0;
		o_go_down <= 1'd0;

		//mem
		rd_addr <= 7'd0;
		for(i = 0; i < 128; i = i +1) begin
			mem_0[i] <= 19'd0;
			mem_1[i] <= 19'd0;
		end

		//output
		o_wr <=1'd0;
		o_addr <= 12'd0;
		o_data <= 20'd0;
		o_sel <= 3'd0;
	end else begin
		//contorl
		o_busy <= n_o_busy;
		addr <= n_addr;
		counter <= n_counter;
		o_go_down <= n_o_go_down;

		//mem
		rd_addr <= n_rd_addr;
		for(i = 0; i < 128; i = i +1) begin
			mem_0[i] <= n_mem_0[i];
			mem_1[i] <= n_mem_1[i];
		end

		//output
		o_wr <= n_o_wr;
		o_addr <= n_o_addr;
		o_data <= n_o_data;
		o_sel <= n_o_sel;
	end
end
endmodule