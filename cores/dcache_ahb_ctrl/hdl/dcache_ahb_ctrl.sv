import pkg_dcache::*;

module dcache_ahb_ctrl #(
  parameter int WORD_SIZE   = 32,
  parameter int CACHE_SIZE  = 4096,
  parameter int ADDR_LENGTH = 32
)(
  input  logic                   clk,
  input  logic                   rst_n,

  // Cache Request Interface
  input  logic                   req_valid,
  input  logic [ADDR_LENGTH-1:0] req_addr,
  input  logic [WORD_SIZE-1:0]   req_wdata,
  input  logic                   req_write,
  input  logic [2:0]             req_size,
  output logic                   req_ready,

  output logic                   resp_valid,
  output logic [WORD_SIZE-1:0]   resp_rdata,

  // AHB Master Interface
  output logic [ADDR_LENGTH-1:0] haddr,
  output logic [WORD_SIZE-1:0]   hwdata,
  output logic [1:0]             htrans,
  output logic                   hwrite,
  output logic [2:0]             hsize,
  output logic [2:0]             hburst,
  output logic [3:0]             hprot,
  input  logic [WORD_SIZE-1:0]   hrdata,
  input  logic                   hready,
  input  logic                   hresp
);

  // -------------------------------------------------------------------------
  // Types and States
  // -------------------------------------------------------------------------
  typedef enum logic [1:0] {
    IDLE,
    CMP_TAG,
    R_MISS,
    W_MISS
  } state_e;

  state_e state_t, next_state_t;

  // -------------------------------------------------------------------------
  // Derived Parameters
  // -------------------------------------------------------------------------
  localparam int BYTES_PER_WORD = WORD_SIZE / 8;
  localparam int NUM_LINES      = CACHE_SIZE / BYTES_PER_WORD;
  localparam int OFFSET_WIDTH   = $clog2(BYTES_PER_WORD);
  localparam int INDEX_WIDTH    = $clog2(NUM_LINES);
  localparam int TAG_WIDTH      = ADDR_LENGTH - INDEX_WIDTH - OFFSET_WIDTH;

  // Define tag structure using package macro
  parameter type t_dcache_tag = `DCACHE_TAG_T(TAG_WIDTH);

  // -------------------------------------------------------------------------
  // Internal Signals & Memories
  // -------------------------------------------------------------------------
  // Memories
  logic [WORD_SIZE-1:0] data_mem [NUM_LINES];
  t_dcache_tag          tag_mem  [NUM_LINES];

  // Address Decoding
  logic [TAG_WIDTH-1:0]   req_tag;
  logic [INDEX_WIDTH-1:0] req_index;

  // Read Logic Signals
  logic [WORD_SIZE-1:0] rdata_mem;
  t_dcache_tag          tag_out;
  logic                 tag_hit;

  // Request write register
  logic req_write_r;

  // -------------------------------------------------------------------------
  // Address Decoding & Read Path
  // -------------------------------------------------------------------------
  assign req_tag   = req_addr[ADDR_LENGTH-1 -: TAG_WIDTH];
  assign req_index = req_addr[INDEX_WIDTH+OFFSET_WIDTH-1 -: INDEX_WIDTH];

  assign rdata_mem = data_mem[req_index];
  assign tag_out   = tag_mem[req_index];

  assign tag_hit   = tag_out.valid && (tag_out.tag == req_tag);

  // -------------------------------------------------------------------------
  // State Machine Register
  // -------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_t <= IDLE;
    end else begin
      state_t <= next_state_t;
    end
  end

  // -------------------------------------------------------------------------
  // Next State Logic
  // -------------------------------------------------------------------------
  always_comb begin
    next_state_t = state_t;
    case (state_t)
      IDLE: begin
        if (req_valid) begin
          next_state_t = CMP_TAG;
        end
      end
      CMP_TAG: begin
        if (tag_hit) begin
          next_state_t = IDLE;
        end else begin
          if (req_write_r) begin
            next_state_t = W_MISS;
          end else begin
            next_state_t = R_MISS;
          end
        end
      end
      R_MISS: begin
        if (hready && !hresp) begin
          next_state_t = CMP_TAG;
        end
      end
      W_MISS: begin
        next_state_t = IDLE;
      end
      default: begin
        next_state_t = IDLE;
      end
    endcase
  end

  // -------------------------------------------------------------------------
  // Output & Control Logic
  // -------------------------------------------------------------------------
  always_comb begin
    // Default values
    req_ready  = 1'b0;
    resp_valid = 1'b0;
    resp_rdata = '0;
    haddr      = '0;
    htrans     = 2'b00; // IDLE
    hwrite     = 1'b0;
    hsize      = req_size;
    hwdata     = '0;

    case (state_t)
      IDLE: begin
        req_ready = 1'b1;
      end

      CMP_TAG: begin
        if (tag_hit) begin
          resp_valid = 1'b1;
          resp_rdata = rdata_mem;
        end else begin
          // request data from memory
          haddr  = req_addr;
          htrans = 2'b10; // NONSEQ
          hwrite = req_write_r;
      end

      W_MISS: begin
        // Placeholder
      end
    endcase
  end

  // -------------------------------------------------------------------------
  // Input Registration
  // -------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      req_write_r <= 1'b0;
    end else if (req_valid) begin
      req_write_r <= req_write;
    end
  end

  // -------------------------------------------------------------------------
  // Memory Update Logic
  // -------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    // Refill on Read Miss (when AHB response is ready)
    if (state_t == R_MISS && hready && !req_write) begin
      data_mem[req_index] <= hrdata;
      tag_mem[req_index]  <= '{valid: 1'b1, tag: req_tag};
    end
    // Write Hit
    else if (state_t == CMP_TAG && tag_hit && req_write) begin
      data_mem[req_index] <= req_wdata;
    end
  end

  // -------------------------------------------------------------------------
  // Default Output Assignments
  // -------------------------------------------------------------------------
  assign hburst = 3'b000; // SINGLE
  assign hprot  = 4'b0011; // Non-cacheable, non-bufferable, privileged, data access

endmodule
