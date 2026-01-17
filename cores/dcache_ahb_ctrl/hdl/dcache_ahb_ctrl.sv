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
  typedef enum logic [2:0] {
    IDLE,
    FLUSH,
    CMP_TAG,
    R_MISS,
    W_MISS
  } state_e;

  state_e state_r, next_state;

  // -------------------------------------------------------------------------
  // Derived Parameters
  // -------------------------------------------------------------------------
  localparam int BYTES_PER_WORD = WORD_SIZE / 8;
  localparam int NUM_LINES      = CACHE_SIZE / BYTES_PER_WORD;
  localparam int OFFSET_WIDTH   = $clog2(BYTES_PER_WORD);
  localparam int INDEX_WIDTH    = $clog2(NUM_LINES);
  localparam int TAG_WIDTH      = ADDR_LENGTH - INDEX_WIDTH - OFFSET_WIDTH;
  localparam int HSIZE_WORD     = $clog2(BYTES_PER_WORD);

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

  // Registers
  logic                   req_write_r;
  logic [ADDR_LENGTH-1:0] req_addr_r;
  logic [WORD_SIZE-1:0]   req_wdata_r;
  logic [2:0]             req_size_r;
  logic                   hready_r;

  // Flush Counter
  logic [$clog2(NUM_LINES)-1:0] flush_cnt;

  // -------------------------------------------------------------------------
  // Address Decoding & Read Path
  // -------------------------------------------------------------------------
  assign req_tag   = req_addr_r[ADDR_LENGTH-1 -: TAG_WIDTH];
  assign req_index = req_addr_r[INDEX_WIDTH+OFFSET_WIDTH-1 -: INDEX_WIDTH];

  assign rdata_mem = data_mem[req_index];
  assign tag_out   = tag_mem[req_index];

  assign tag_hit   = tag_out.valid && (tag_out.tag == req_tag);

  // -------------------------------------------------------------------------
  // State Machine Register
  // -------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_r <= FLUSH;
    end else begin
      state_r <= next_state;
    end
  end

  // -------------------------------------------------------------------------
  // Next State Logic
  // -------------------------------------------------------------------------
  always_comb begin
    next_state = state_r;
    case (state_r)
      FLUSH: begin
        if (flush_cnt == INDEX_WIDTH'(NUM_LINES-1)) begin
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
          if (req_valid) begin
            next_state = CMP_TAG;
          end else begin
            next_state = IDLE;
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
        next_state = IDLE;
      end
      default: begin
        next_state = IDLE;
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
    hsize      = req_size_r;
    hwdata     = '0;

    case (state_r)
      IDLE: begin
        req_ready = 1'b1;
      end

      FLUSH: begin
        // Busy flushing
      end

      CMP_TAG: begin
        if (tag_hit) begin
          resp_valid = 1'b1;
          resp_rdata = rdata_mem;
          req_ready  = 1'b1; // Ready for next request on hit
        end else begin
          // request data from memory
          haddr  = req_addr_r;
          htrans = 2'b10; // NONSEQ
          hwrite = req_write_r;
          hsize  = 3'(HSIZE_WORD); // Always fetch full word // Always fetch full word
        end
      end
      R_MISS: begin
        // if AHB was not ready, hold request high again
        if (hready_r == 1'b0) begin
          haddr  = req_addr_r;
          htrans = 2'b10; // NONSEQ
          hwrite = req_write_r;
          hsize  = 3'(HSIZE_WORD);
        end
      end
      W_MISS: begin
        // fix later
      end
    endcase
  end

  // -------------------------------------------------------------------------
  // Input Registration
  // -------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      req_write_r <= 1'b0;
      req_addr_r  <= '0;
      req_wdata_r <= '0;
      req_size_r  <= '0;
    end else if (req_valid && req_ready) begin
      req_write_r <= req_write;
      req_addr_r  <= req_addr;
      req_wdata_r <= req_wdata;
      req_size_r  <= req_size;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      flush_cnt <= '0;
    end else if (state_r == FLUSH) begin
      flush_cnt <= flush_cnt + 1;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hready_r <= 1'b0;
    end else begin
      hready_r <= hready;
    end
  end

  // -------------------------------------------------------------------------
  // Memory Update Logic
  // -------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (state_r == FLUSH) begin
      tag_mem[flush_cnt].valid <= 1'b0;
    end
    // Refill on Read Miss (when AHB response is ready)
    else if (state_r == R_MISS && hready && !req_write_r) begin
      data_mem[req_index] <= hrdata;
      tag_mem[req_index]  <= '{valid: 1'b1, tag: req_tag};
    end
    // Write Hit
    else if (state_r == CMP_TAG && tag_hit && req_write_r) begin
      data_mem[req_index] <= req_wdata_r;
    end
  end

  // -------------------------------------------------------------------------
  // Default Output Assignments
  // -------------------------------------------------------------------------
  assign hburst = 3'b000; // SINGLE
  assign hprot  = 4'b0011; // Non-cacheable, non-bufferable, privileged, data access

endmodule
