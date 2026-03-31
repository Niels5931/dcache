module dcache_ahb_ctrl (
	clk,
	rst_n,
	req_valid,
	req_addr,
	req_wdata,
	req_write,
	req_size,
	req_ready,
	resp_valid,
	resp_rdata,
	haddr,
	hwdata,
	htrans,
	hwrite,
	hsize,
	hburst,
	hprot,
	hrdata,
	hready,
	hresp
);
	reg _sv2v_0;
	parameter signed [31:0] WORD_SIZE = 32;
	parameter signed [31:0] CACHE_SIZE = 4096;
	parameter signed [31:0] ADDR_LENGTH = 32;
	input wire clk;
	input wire rst_n;
	input wire req_valid;
	input wire [ADDR_LENGTH - 1:0] req_addr;
	input wire [WORD_SIZE - 1:0] req_wdata;
	input wire req_write;
	input wire [2:0] req_size;
	output reg req_ready;
	output reg resp_valid;
	output reg [WORD_SIZE - 1:0] resp_rdata;
	output reg [ADDR_LENGTH - 1:0] haddr;
	output reg [WORD_SIZE - 1:0] hwdata;
	output reg [1:0] htrans;
	output reg hwrite;
	output reg [2:0] hsize;
	output wire [2:0] hburst;
	output wire [3:0] hprot;
	input wire [WORD_SIZE - 1:0] hrdata;
	input wire hready;
	input wire hresp;
	reg [2:0] state_r;
	reg [2:0] next_state;
	localparam signed [31:0] BYTES_PER_WORD = WORD_SIZE / 8;
	localparam signed [31:0] NUM_LINES = CACHE_SIZE / BYTES_PER_WORD;
	localparam signed [31:0] OFFSET_WIDTH = $clog2(BYTES_PER_WORD);
	localparam signed [31:0] INDEX_WIDTH = $clog2(NUM_LINES);
	localparam signed [31:0] TAG_WIDTH = (ADDR_LENGTH - INDEX_WIDTH) - OFFSET_WIDTH;
	localparam signed [31:0] HSIZE_WORD = $clog2(BYTES_PER_WORD);
	reg [WORD_SIZE - 1:0] data_mem [0:NUM_LINES - 1];
	reg [(1 + TAG_WIDTH) - 1:0] tag_mem [0:NUM_LINES - 1];
	wire [TAG_WIDTH - 1:0] req_tag;
	wire [INDEX_WIDTH - 1:0] req_index;
	wire [WORD_SIZE - 1:0] rdata_mem;
	wire [(1 + TAG_WIDTH) - 1:0] tag_out;
	wire tag_hit;
	reg req_write_r;
	reg [ADDR_LENGTH - 1:0] req_addr_r;
	reg [WORD_SIZE - 1:0] req_wdata_r;
	reg [2:0] req_size_r;
	reg hready_r;
	reg [$clog2(NUM_LINES) - 1:0] flush_cnt;
	assign req_tag = req_addr_r[ADDR_LENGTH - 1-:TAG_WIDTH];
	assign req_index = req_addr_r[(INDEX_WIDTH + OFFSET_WIDTH) - 1-:INDEX_WIDTH];
	assign rdata_mem = data_mem[req_index];
	assign tag_out = tag_mem[req_index];
	assign tag_hit = tag_out[TAG_WIDTH + 0] && (tag_out[TAG_WIDTH - 1-:TAG_WIDTH] == req_tag);
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			state_r <= 3'd1;
		else
			state_r <= next_state;
	function automatic signed [INDEX_WIDTH - 1:0] sv2v_cast_5F989_signed;
		input reg signed [INDEX_WIDTH - 1:0] inp;
		sv2v_cast_5F989_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = state_r;
		case (state_r)
			3'd1:
				if (flush_cnt == sv2v_cast_5F989_signed(NUM_LINES - 1))
					next_state = 3'd0;
			3'd0:
				if (req_valid)
					next_state = 3'd2;
			3'd2:
				if (tag_hit) begin
					if (req_write_r)
						next_state = 3'd5;
					else if (req_valid)
						next_state = 3'd2;
					else
						next_state = 3'd0;
				end
				else if (req_write_r)
					next_state = 3'd4;
				else
					next_state = 3'd3;
			3'd3:
				if (hready && !hresp)
					next_state = 3'd2;
			3'd4:
				if ((hready && !hresp) && hready_r) begin
					if (req_valid)
						next_state = 3'd2;
					else
						next_state = 3'd0;
				end
			3'd5:
				if ((hready && !hresp) && hready_r) begin
					if (req_valid)
						next_state = 3'd2;
					else
						next_state = 3'd0;
				end
			default: next_state = 3'd0;
		endcase
	end
	function automatic signed [2:0] sv2v_cast_3_signed;
		input reg signed [2:0] inp;
		sv2v_cast_3_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		req_ready = 1'b0;
		resp_valid = 1'b0;
		resp_rdata = 1'sb0;
		haddr = 1'sb0;
		htrans = 2'b00;
		hwrite = 1'b0;
		hsize = req_size_r;
		hwdata = 1'sb0;
		case (state_r)
			3'd0: req_ready = 1'b1;
			3'd1:
				;
			3'd2:
				if (tag_hit) begin
					if (req_write_r) begin
						haddr = req_addr_r;
						htrans = 2'b10;
						hwrite = 1'b1;
						hsize = sv2v_cast_3_signed(HSIZE_WORD);
					end
					else begin
						resp_valid = 1'b1;
						resp_rdata = rdata_mem;
						req_ready = 1'b1;
					end
				end
				else begin
					haddr = req_addr_r;
					htrans = 2'b10;
					hwrite = req_write_r;
					hsize = sv2v_cast_3_signed(HSIZE_WORD);
				end
			3'd3:
				if (hready_r == 1'b0) begin
					haddr = req_addr_r;
					htrans = 2'b10;
					hwrite = req_write_r;
					hsize = sv2v_cast_3_signed(HSIZE_WORD);
				end
			3'd4:
				if (hready_r) begin
					hwdata = req_wdata_r;
					if (hready && !hresp) begin
						resp_valid = 1'b1;
						req_ready = 1'b1;
					end
				end
				else begin
					haddr = req_addr_r;
					htrans = 2'b10;
					hwrite = 1'b1;
					hsize = sv2v_cast_3_signed(HSIZE_WORD);
				end
			3'd5:
				if (hready_r) begin
					hwdata = req_wdata_r;
					if (hready && !hresp) begin
						resp_valid = 1'b1;
						req_ready = 1'b1;
					end
				end
				else begin
					haddr = req_addr_r;
					htrans = 2'b10;
					hwrite = 1'b1;
					hsize = sv2v_cast_3_signed(HSIZE_WORD);
				end
			default:
				;
		endcase
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			req_write_r <= 1'b0;
			req_addr_r <= 1'sb0;
			req_wdata_r <= 1'sb0;
			req_size_r <= 1'sb0;
		end
		else if (req_valid && req_ready) begin
			req_write_r <= req_write;
			req_addr_r <= req_addr;
			req_wdata_r <= req_wdata;
			req_size_r <= req_size;
		end
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			flush_cnt <= 1'sb0;
		else if (state_r == 3'd1)
			flush_cnt <= flush_cnt + 1;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			hready_r <= 1'b0;
		else
			hready_r <= hready;
	function automatic [TAG_WIDTH - 1:0] sv2v_cast_78CC7;
		input reg [TAG_WIDTH - 1:0] inp;
		sv2v_cast_78CC7 = inp;
	endfunction
	always @(posedge clk)
		if (state_r == 3'd1)
			tag_mem[flush_cnt][TAG_WIDTH + 0] <= 1'b0;
		else if (((state_r == 3'd3) && hready) && !hresp) begin
			data_mem[req_index] <= hrdata;
			tag_mem[req_index] <= {1'b1, sv2v_cast_78CC7(req_tag)};
		end
		else if ((((state_r == 3'd5) && hready) && !hresp) && hready_r)
			data_mem[req_index] <= req_wdata_r;
	assign hburst = 3'b000;
	assign hprot = 4'b0011;
	initial _sv2v_0 = 0;
endmodule