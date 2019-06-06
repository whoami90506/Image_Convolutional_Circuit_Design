module layer12(
	input clk,
	input reset,
	output reg o_busy,

	output reg o_wr,
	output reg [11:0] o_addr,
	output reg [19:0] o_data,
	output reg [ 2:0] o_sel,

	input i_valid,
	input [18:0] i_data
);
genvar idx;
integer i;

//control
reg n_o_busy;
reg [3:0] step_counter, n_step_counter;
reg [9:0] addr_counter, n_addr_counter;

//output
reg n_o_wr;
reg [11:0] n_o_addr;
reg [19:0] n_o_data;
reg [ 2:0] n_o_sel;

//mem
reg  [18:0]   mem [0:5];
wire [18:0] n_mem [0:5];

//max
reg  [18:0]   max_0,   max_1;
wire [18:0] n_max_0, n_max_1;
wire [18:0] max_tree_0_w, max_tree_1_w, max_tree_w;

//assign
assign max_tree_0_w = ( i_data > mem[1] ) ? i_data : mem[1];
assign max_tree_1_w = ( mem[3] > mem[5] ) ? mem[3] : mem[5];
assign max_tree_w   = ( max_tree_0_w > max_tree_1_w ) ? max_tree_0_w : max_tree_1_w;
assign n_max_0 = (step_counter == 4'd6) ? max_tree_w : max_0;
assign n_max_1 = (step_counter == 4'd7) ? max_tree_w : max_1;
assign n_mem[0] = i_valid ? i_data : mem[0];
generate
	for(idx = 1; idx <6; idx = idx+1)
		assign n_mem[idx] = i_valid ? mem[idx-1] : mem[idx];
endgenerate

//control
always @(*) begin
	if(o_busy) begin
		n_o_busy = (step_counter == 4'd11 && addr_counter == 10'd1023) ? 1'b0 : 1'b1;
		n_step_counter = (step_counter == 4'd11) ? 4'd0 : step_counter + 4'd1;
		n_addr_counter = (step_counter == 4'd11) ? addr_counter + 10'd1 : addr_counter;
	end else begin
		n_o_busy = i_valid;
		n_step_counter = {3'd0, i_valid};
		n_addr_counter = 10'd0;
	end
end

//output
always @(*) begin
	if(o_busy) begin
		n_o_wr = 1'b1;

		if(step_counter[3]) begin
		end else begin
			n_o_data = i_data;
			n_o_sel  = {1'b0, step_counter[0], ~step_counter[0]}; 
		end
	end else begin
		n_o_wr = i_valid;
		n_o_addr = 12'd0;
		n_o_data = i_data;
		n_o_sel  = 3'd1;
	end
end

always @(posedge clk or posedge reset) begin
	if (reset) begin
		//control
		o_busy <= 1'b0;
		step_counter <=  4'd0;
		addr_counter <= 10'd0;
		//output
		o_wr <= 1'd0;
		n_o_addr <= 12'd0;
		n_o_data <= 20'd0;
		n_o_sel <= 3'd0;
		//mem
		for(i = 0; i < 6; i = i+1)mem[i] <= 19'd0;
		max_0 <= 19'd0;
		max_1 <= 19'd0;
	end else begin
		//control
		o_busy <= n_o_busy;
		step_counter <=  n_step_counter;
		addr_counter <= n_addr_counter;
		//output
		o_wr <= n_o_wr;
		n_o_addr <= n_o_addr;
		n_o_data <= n_o_data;
		n_o_sel <= n_o_sel;
		//mem
		for(i = 0; i < 6; i = i+1)mem[i] <= n_mem[i];
		max_0 <= n_max_0;
		max_1 <= n_max_1;
	end
end
endmodule