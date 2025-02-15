`timescale 1ns/10ps
module  CONV(
	input		clk,
	input		reset,
	output	reg	busy,	
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
reg n_busy;

reg  busy_buf;
wire n_busy_buf;

//submodule
wire valid;
wire [18:0] data;
wire busy_layer0, busy_layer12;

assign crd = 1'd0;
assign caddr_rd = 12'd0;
assign n_busy_buf = busy_layer0 | busy_layer12 | _ready;

always @(*) begin
	if(busy) n_busy = busy_layer0 | busy_layer12 | busy_buf ? 1'b1 : 1'b0;
	else n_busy = _ready;
end


always @(posedge clk or posedge reset) begin
	if(reset) begin 
		i_data <= 20'd0;
		_ready <= 1'd0;
		busy <= 1'b0;
		busy_buf <= 1'b0;
	end else begin
		i_data <= idata;
		_ready <= ready;
		busy <= n_busy;
		busy_buf <= n_busy_buf;
	end
end

layer0 layer0(.clk(clk), .reset(reset), .o_busy(busy_layer0), .i_ready(_ready), .o_addr(iaddr), 
	.i_data(i_data), .o_valid  (valid), .o_data (data));

layer12 layer12(.clk(clk), .reset(reset), .o_busy(busy_layer12), .o_wr(cwr), .o_addr(caddr_wr), 
	.o_data(cdata_wr), .o_sel(csel), .i_valid(valid), .i_data(data));

endmodule

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
	end
	assign n_mul = i_sel ? mul_raw_1 : mul_raw_0;
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

always @(posedge clk or posedge reset) begin
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

module layer0(
	input clk,
	input reset,
	output reg o_busy,
	input i_ready,

	output reg [11:0] o_addr,
	input [19:0] i_data,

	output o_valid,
	output [18:0] o_data
);

integer i;

//IO
reg n_o_busy;
reg [11:0] n_o_addr;

//control
localparam IDLE       = 3'd0;
localparam INIT       = 3'd1;
localparam INIT_RUN   = 3'd2;
localparam      WAIT  = 3'd3;
localparam     SHIFT  = 3'd4;
localparam      RUN   = 3'd5;
localparam LAST_SHIFT = 3'd6;
localparam LAST_RUN   = 3'd7;
reg [2:0] state, n_state;
reg [3:0] step_counter, n_step_counter;
reg [4:0] conv_counter, n_conv_counter;

//men
reg [19:0]   mem [0:127];
reg [19:0] n_mem [0:127];
reg [19:0]   box [0:  7];
reg [19:0] n_box [0:  7];

//kernal
reg [179:0] k_element, n_k_element;
reg k_valid, n_k_valid;
reg k_sel, n_k_sel;

task kernal_nop;
	begin
		n_k_element = k_element;
		n_k_valid = 1'd0;
		n_k_sel = k_sel;
	end
endtask

task kernal_normal;
	input [6:0] pos;
	begin
		n_k_element[160 +: 20] =   pos[5:0]  ? mem[pos - 8'd1 ] : 20'd0; //0
		n_k_element[140 +: 20] =               mem[pos        ];         //1
		n_k_element[120 +: 20] = (~pos[5:0]) ? mem[pos + 8'd1 ] : 20'd0; //2

		if(pos[6]) begin
			n_k_element[100 +: 20] =   box[0];
			n_k_element[ 80 +: 20] =   box[1];
			n_k_element[ 60 +: 20] =   box[2];
			n_k_element[ 40 +: 20] =   box[4];
			n_k_element[ 20 +: 20] =   box[5];
			n_k_element[  0 +: 20] =   box[6];
		end else begin
			n_k_element[100 +: 20] =   pos[5:0]  ? mem[{1'b1, pos[5:0]} - 8'd1] : 20'd0; //3
			n_k_element[ 80 +: 20] =               mem[{1'b1, pos[5:0]}       ];         //4
			n_k_element[ 60 +: 20] = (~pos[5:0]) ? mem[{1'b1, pos[5:0]} + 8'd1] : 20'd0; //5
			n_k_element[ 40 +: 20] =   box[0];
			n_k_element[ 20 +: 20] =   box[1];
			n_k_element[  0 +: 20] =   box[2];
		end

		n_k_valid = 1'd1;
		n_k_sel = ~k_sel;
	end
endtask

task box_shift;
	begin
		n_box[0] = box[1];
		n_box[1] = box[2];
		n_box[2] = box[3];
		n_box[4] = box[5];
		n_box[5] = box[6];
		n_box[6] = box[7];
		n_box[3] = 20'd0;
		n_box[7] = 20'd0;

		if(!(conv_counter == 5'd0 && step_counter[2] == 1'b0) ) begin
			n_mem[{1'b0, conv_counter - {4'd0, (~step_counter[2])}, ~step_counter[2]}] = box[0];
			n_mem[{1'b1, conv_counter - {4'd0, (~step_counter[2])}, ~step_counter[2]}] = box[4];
		end
	end
endtask

task box_change;
	input [19:0] data;
	begin
		n_box[0] = 20'd0;
		n_box[1] = data;
		n_box[2] = 20'd0;
		n_box[3] = 20'd0;
		n_box[4] = 20'd0;
		n_box[5] = 20'd0;
		n_box[6] = 20'd0;
		n_box[7] = 20'd0;

		n_mem[ 62] = box[0];
		n_mem[ 63] = box[1];
		n_mem[126] = box[4];
		n_mem[127] = box[5];
	end
endtask 

//control && read
always @(*) begin
	n_o_addr = o_addr;
	for(i = 0; i < 128; i = i+1)n_mem[i] = mem[i];
	for(i = 0; i <   8; i = i+1)n_box[i] = box[i];

	n_o_busy = 1'd1;

	case (state)
		IDLE : begin
			n_state = i_ready ? INIT : IDLE;
			n_o_busy = i_ready;

			n_o_addr = 12'd0;
			for(i = 0; i < 128; i = i+1)n_mem[i] = 20'd0;
			for(i = 0; i <   8; i = i+1)n_box[i] = 20'd0;
		end

		INIT : begin
			n_state = (o_addr == 12'd2) ? INIT_RUN : INIT;
			case (o_addr)
				12'd0 : n_o_addr = 12'd64;

				12'd64 : begin
					n_o_addr = 12'd128;
					n_mem[64] = i_data;
				end

				12'd128 : begin
					n_o_addr = 12'd1;
					n_box[1] = i_data;
				end

				12'd1 : begin
					n_o_addr = 12'd65;
					n_box[5] = i_data;
				end

				12'd65 : begin
					n_o_addr = 12'd129;
					n_mem[65] = i_data;
				end

				12'd129 : begin
					n_o_addr = 12'd2;
					n_box[2] = i_data;
				end

				12'd2 : begin
					n_o_addr = 12'd66;
					n_box[6] = i_data;
				end
				default : n_o_addr = 12'dx;
			endcase
		end

		INIT_RUN : begin
			n_state = (o_addr == 12'd192) ? WAIT : INIT_RUN;

			case (step_counter)
				4'd0 : begin
					n_o_addr = {6'b000010, o_addr[5:0]};
					n_mem[{1'b1, conv_counter + 5'd1, 1'b0}] = i_data;
				end

				4'd1 : begin
					n_o_addr = {6'd0, o_addr[5:0] + 6'd1};
					n_box[3] = i_data;
				end

				4'd2 : begin
					n_o_addr = o_addr;
					n_box[7] = i_data;
				end

				4'd3 : begin
					n_o_addr = {6'b000001, o_addr[5:0]};
					box_shift;
				end

				4'd4 : begin
					n_o_addr = {6'b000010, o_addr[5:0]};
					n_mem[{1'b1, conv_counter + 5'd1, 1'b1}] = i_data;
				end

				4'd5 : begin
					n_o_addr = o_addr == 12'd191 ? 12'd192 : {6'd0, o_addr[5:0] + 6'd1};
					n_box[3] = i_data; 
				end

				4'd6 : begin
					n_o_addr = o_addr;
					n_box[7] = i_data; 
				end

				4'd7 : begin
					n_o_addr = o_addr;
					box_shift; 
				end

				4'd11 : n_o_addr = {6'b000001, o_addr[5:0]};
			endcase
		end

		WAIT : begin
			n_state = WAIT;
			if(step_counter == 4'd3 || step_counter == 4'd7)box_shift;

			if(o_addr) begin
				if(conv_counter == 5'd31 && step_counter == 4'd5) 
					n_state  = (o_addr[11:6] == 6'b111111) ? LAST_SHIFT : SHIFT; 
			end else begin
				if(conv_counter == 5'd31 && step_counter == 4'd7) 
					n_state  = IDLE; 
			end 
		end

		SHIFT : begin
			n_state = SHIFT;

			case (step_counter)
				4'd6 : n_o_addr = {o_addr[11:6], 6'd1};

				4'd7 : begin
					box_change(i_data);
					n_o_addr = {o_addr[11:7] + 5'd1, 1'b0, 6'd0};
				end

				4'd8 : begin
					n_box[2] = i_data;
					n_o_addr = {o_addr[11:6], 6'd1};
				end

				4'd9 : begin
					n_box[5] = i_data;
					n_o_addr = {o_addr[11:7] - 5'd1, 1'b1, 6'd2};
				end

				4'd10 : begin
					n_box[6] = i_data;
					n_state = RUN;
				end
			endcase
		end

		RUN : begin
			n_state = o_addr[5:0] ? RUN : WAIT;

			case (step_counter)
				4'd11 : n_o_addr = {o_addr[11:7] + 5'd1, 1'b0, o_addr[5:0]};

				4'd0 : begin
					n_o_addr = {o_addr[11:7] - 5'd1, 1'b1, o_addr[5:0] + 6'd1};
					n_box[3] = i_data;
				end

				4'd1 : n_box[7] = i_data;
				
				4'd3 : begin
					box_shift;
					n_o_addr = {o_addr[11:7] + 5'd1, 1'b0, o_addr[5:0]};
				end 

				4'd4 : begin
					n_box[3] = i_data;
					n_o_addr = o_addr[5:0] == 6'd63 ? {o_addr[11:7], 1'b1, 6'b0} : 
								{o_addr[11:7] - 5'd1, 1'b1, o_addr[5:0] + 6'd1};
				end 

				4'd5 : n_box[7] = i_data;
				4'd7 : box_shift;

			endcase
		end

		LAST_SHIFT : begin
			n_state = LAST_SHIFT;

			case (step_counter)
				4'd6 : n_o_addr = 12'd4033;
				
				4'd7 : begin
					box_change(i_data);
					n_o_addr = 12'd4034;
				end

				4'd8 : begin
					n_box[2] = i_data;
					n_state = LAST_RUN;
				end
			endcase
		end

		LAST_RUN : begin
			n_state = (o_addr[5:0]) ? LAST_RUN : WAIT;

			case (step_counter)
				4'd0 : begin
					n_box[3] = i_data;
					n_o_addr = {6'b111111, o_addr[5:0] + 6'd1};
				end 

				4'd3 : box_shift;
				4'd4 : begin
					n_box[3] = i_data;
					n_o_addr = (o_addr[5:0] == 6'b111111) ? 12'd0 : {6'b111111, o_addr[5:0] + 6'd1};
				end 
				4'd7 : box_shift;

			endcase
		end	
	endcase
end

//write to kernal
always @(*) begin
	case (state)
		IDLE, INIT : begin
			kernal_nop;
			n_conv_counter = 5'd0;
			n_step_counter = 4'd0;
		end

		default : begin
			n_conv_counter = (step_counter == 4'd11) ? conv_counter + 5'd1 : conv_counter;
			n_step_counter = (step_counter == 4'd11) ? 4'd0 : step_counter + 4'd1;

			if(step_counter[3])kernal_nop;
			else kernal_normal({step_counter[1], conv_counter, step_counter[2]});
		end
	endcase
end

always @(posedge clk or posedge reset) begin
	if(reset) begin
		//control
		state <= IDLE;
		conv_counter <= 5'd0;
		step_counter <= 4'd0; 
		//IO
		o_busy <= 1'd0;
		o_addr <= 12'd0;
		//mem
		for(i = 0; i < 128; i = i+1)mem[i] <= 20'd0;
		for(i = 0; i <   8; i = i+1)box[i] <= 20'd0;
		//kernal
		k_element <= 180'd0;
		k_valid <= 1'd0;
		k_sel <= 1'd1;
	end else begin
		//control
		state <= n_state;
		conv_counter <= n_conv_counter;
		step_counter <= n_step_counter;
		//IO
		o_busy <= n_o_busy;
		o_addr <= n_o_addr;
		//mem
		for(i = 0; i < 128; i = i+1)mem[i] <= n_mem[i];
		for(i = 0; i <   8; i = i+1)box[i] <= n_box[i];
		//kernal
		k_element <= n_k_element;
		k_valid <= n_k_valid;
		k_sel <= n_k_sel;
	end
end

kernal kernal (.clk(clk), .reset(reset), .i_valid(k_valid), .i_data(k_element), 
	.o_valid(o_valid), .o_data(o_data), .i_sel(k_sel));

endmodule

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
		n_o_busy = (step_counter == 4'd0 && addr_counter == 10'd0) ? 1'b0 : 1'b1;
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
			//4'b1000 : layer1 max0
			//4'b1001 : layer1 max1
			//4'b1010 : layer2 max0
			//4'b1011 : layer2 max1
			n_o_addr = step_counter[1] ? {1'b0, addr_counter, step_counter[0]} : {2'b0, addr_counter};
			n_o_data = step_counter[0] ? {1'b0,max_1} : {1'b0, max_0};
			n_o_sel  = step_counter[1] ? 3'b101 : {step_counter[0], ~step_counter[0], ~step_counter[0]};
		end else begin
			n_o_addr = {addr_counter[9:5], step_counter[1], addr_counter[4:0], step_counter[2]};
			n_o_data = {1'b0, i_data};
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
		o_addr <= 12'd0;
		o_data <= 20'd0;
		o_sel <= 3'd0;
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
		o_addr <= n_o_addr;
		o_data <= n_o_data;
		o_sel <= n_o_sel;
		//mem
		for(i = 0; i < 6; i = i+1)mem[i] <= n_mem[i];
		max_0 <= n_max_0;
		max_1 <= n_max_1;
	end
end
endmodule