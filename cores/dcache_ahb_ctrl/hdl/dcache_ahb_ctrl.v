module dcache_ahb_ctrl #(
  parameter WORD_SIZE   = 32,
  parameter CACHE_SIZE  = 4096,
  parameter ADDR_LENGTH = 32
)(
  input wire clk,
  input wire rst_n,

  input wire req_valid,
  input wire [ADDR_LENGTH-1:0] req_addr,
  input wire [WORD_SIZE-1:0]   req_wdata,
  input wire req_write,
  input wire [2:0]             req_size,
  output reg  req_ready,

  output reg  resp_valid,
  output reg  [WORD_SIZE-1:0]   resp_rdata,

  output reg  [ADDR_LENGTH-1:0] haddr,
  output reg  [WORD_SIZE-1:0]   hwdata,
  output reg  [1:0]             htrans,
  output reg  hwrite,
  output reg  [2:0]             hsize,
  output wire [2:0]            hburst,
  output wire [3:0]            hprot,
  input wire [WORD_SIZE-1:0]   hrdata,
  input wire hready,
  input wire hresp
);

  localparam BYTES_PER_WORD = WORD_SIZE / 8;
  localparam NUM_LINES = CACHE_SIZE / BYTES_PER_WORD;
  localparam OFFSET_WIDTH = $clog2(BYTES_PER_WORD);
  localparam INDEX_WIDTH = $clog2(NUM_LINES);
  localparam TAG_WIDTH = ADDR_LENGTH - INDEX_WIDTH - OFFSET_WIDTH;
  localparam HSIZE_WORD = $clog2(BYTES_PER_WORD);
  localparam [INDEX_WIDTH-1:0] FLUSH_LAST = NUM_LINES-1;

  localparam IDLE = 3'd0;
  localparam FLUSH = 3'd1;
  localparam CMP_TAG = 3'd2;
  localparam R_MISS = 3'd3;
  localparam W_MISS = 3'd4;
  localparam W_HIT = 3'd5;

  reg [2:0] state_r;
  reg [2:0] next_state;

  wire [TAG_WIDTH-1:0]   req_tag;
  wire [INDEX_WIDTH-1:0] req_index;

  reg [WORD_SIZE-1:0] data_mem [0:NUM_LINES-1];
  reg [TAG_WIDTH:0]   tag_mem [0:NUM_LINES-1];

  wire [WORD_SIZE-1:0] rdata_mem;
  wire [TAG_WIDTH:0]   tag_out;
  wire                 tag_hit;

  reg req_write_r;
  reg [ADDR_LENGTH-1:0] req_addr_r;
  reg [WORD_SIZE-1:0]   req_wdata_r;
  reg [2:0]             req_size_r;
  reg                   hready_r;

  reg [$clog2(NUM_LINES)-1:0] flush_cnt;

  assign req_tag = req_addr_r[ADDR_LENGTH-1 -: TAG_WIDTH];
  assign req_index = req_addr_r[INDEX_WIDTH+OFFSET_WIDTH-1 -: INDEX_WIDTH];

  assign rdata_mem = data_mem[req_index];
  assign tag_out   = tag_mem[req_index];

  assign tag_hit = tag_out[TAG_WIDTH] && (tag_out[TAG_WIDTH-1 -: TAG_WIDTH] == req_tag);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_r <= FLUSH;
    end else begin
      state_r <= next_state;
    end
  end

  always @(*) begin
    next_state = state_r;
    case (state_r)
      FLUSH: begin
        if (flush_cnt == FLUSH_LAST) begin
          next_state = IDLE;
        end
      end
      IDLE: begin
        if (req_valid) begin
          next_state = CMP_TAG;
        end
      end
      CMP_TAG: begin
        if (tag_hit) begin
          if (req_write_r) begin
            next_state = W_HIT;
          end else begin
            if (req_valid) begin
              next_state = CMP_TAG;
            end else begin
              next_state = IDLE;
            end
          end
        end else begin
          if (req_write_r) begin
            next_state = W_MISS;
          end else begin
            next_state = R_MISS;
          end
        end
      end
      R_MISS: begin
        if (hready && !hresp) begin
          next_state = CMP_TAG;
        end
      end
      W_MISS: begin
        if (hready && !hresp && hready_r) begin
          if (req_valid) begin
            next_state = CMP_TAG;
          end else begin
            next_state = IDLE;
          end
        end
      end
      W_HIT: begin
        if (hready && !hresp && hready_r) begin
          if (req_valid) begin
            next_state = CMP_TAG;
          end else begin
            next_state = IDLE;
          end
        end
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

  always @(*) begin
    req_ready = 1'b0;
    resp_valid = 1'b0;
    resp_rdata = {WORD_SIZE{1'b0}};
    haddr = {ADDR_LENGTH{1'b0}};
    htrans = 2'b00;
    hwrite = 1'b0;
    hsize = req_size_r;
    hwdata = {WORD_SIZE{1'b0}};

    case (state_r)
      IDLE: begin
        req_ready = 1'b1;
      end

      FLUSH: begin
      end

      CMP_TAG: begin
        if (tag_hit) begin
          if (req_write_r) begin
            haddr = req_addr_r;
            htrans = 2'b10;
            hwrite = 1'b1;
            hsize = HSIZE_WORD[2:0];
          end else begin
            resp_valid = 1'b1;
            resp_rdata = rdata_mem;
            req_ready = 1'b1;
          end
        end else begin
          haddr = req_addr_r;
          htrans = 2'b10;
          hwrite = req_write_r;
          hsize = HSIZE_WORD[2:0];
        end
      end

      R_MISS: begin
        if (hready_r == 1'b0) begin
          haddr = req_addr_r;
          htrans = 2'b10;
          hwrite = req_write_r;
          hsize = HSIZE_WORD[2:0];
        end
      end

      W_MISS: begin
        if (hready_r) begin
          hwdata = req_wdata_r;
          if (hready && !hresp) begin
            resp_valid = 1'b1;
            req_ready = 1'b1;
          end
        end else begin
          haddr = req_addr_r;
          htrans = 2'b10;
          hwrite = 1'b1;
          hsize = HSIZE_WORD[2:0];
        end
      end

      W_HIT: begin
        if (hready_r) begin
          hwdata = req_wdata_r;
          if (hready && !hresp) begin
            resp_valid = 1'b1;
            req_ready = 1'b1;
          end
        end else begin
          haddr = req_addr_r;
          htrans = 2'b10;
          hwrite = 1'b1;
          hsize = HSIZE_WORD[2:0];
        end
      end

      default: begin
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      req_write_r <= 1'b0;
      req_addr_r <= {ADDR_LENGTH{1'b0}};
      req_wdata_r <= {WORD_SIZE{1'b0}};
      req_size_r <= 3'b000;
    end else if (req_valid && req_ready) begin
      req_write_r <= req_write;
      req_addr_r <= req_addr;
      req_wdata_r <= req_wdata;
      req_size_r <= req_size;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      flush_cnt <= {$clog2(NUM_LINES){1'b0}};
    end else if (state_r == FLUSH) begin
      flush_cnt <= flush_cnt + 1'b1;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hready_r <= 1'b0;
    end else begin
      hready_r <= hready;
    end
  end

  always @(posedge clk) begin
    if (state_r == FLUSH) begin
      tag_mem[flush_cnt][TAG_WIDTH] <= 1'b0;
    end
    else if (state_r == R_MISS && hready && !hresp) begin
      data_mem[req_index] <= hrdata;
      tag_mem[req_index] <= {1'b1, req_tag};
    end
    else if (state_r == W_HIT && hready && !hresp && hready_r) begin
      data_mem[req_index] <= req_wdata_r;
    end
  end

  assign hburst = 3'b000;
  assign hprot = 4'b0011;

endmodule