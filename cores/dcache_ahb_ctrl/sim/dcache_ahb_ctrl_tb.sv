`timescale 1ns/1ns

module dcache_ahb_ctrl_tb;


  // -------------------------------------------------------------------------
  // Parameters
  // -------------------------------------------------------------------------
  parameter int WORD_SIZE   = 32;
  parameter int CACHE_SIZE  = 1024; // Small cache for sim
  parameter int ADDR_LENGTH = 32;

  // -------------------------------------------------------------------------
  // Signals
  // -------------------------------------------------------------------------
  logic                   clk;
  logic                   rst_n;

  // Cache Request Interface
  logic                   req_valid;
  logic [ADDR_LENGTH-1:0] req_addr;
  logic [WORD_SIZE-1:0]   req_wdata;
  logic                   req_write;
  logic [2:0]             req_size;
  logic                   req_ready;

  logic                   resp_valid;
  logic [WORD_SIZE-1:0]   resp_rdata;

  // AHB Master Interface
  logic [ADDR_LENGTH-1:0] haddr;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [WORD_SIZE-1:0]   hwdata;
  logic [1:0]             htrans;
  logic                   hwrite;
  logic [2:0]             hsize;
  logic [2:0]             hburst;
  logic [3:0]             hprot;
  /* verilator lint_on UNUSEDSIGNAL */
  logic [WORD_SIZE-1:0]   hrdata;
  logic                   hready;
  logic                   hresp;

  // Testbench Control
  int error_cnt = 0;

  // -------------------------------------------------------------------------
  // DUT Instantiation
  // -------------------------------------------------------------------------
  dcache_ahb_ctrl #(
    .WORD_SIZE   (WORD_SIZE),
    .CACHE_SIZE  (CACHE_SIZE),
    .ADDR_LENGTH (ADDR_LENGTH)
  ) dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .req_valid  (req_valid),
    .req_addr   (req_addr),
    .req_wdata  (req_wdata),
    .req_write  (req_write),
    .req_size   (req_size),
    .req_ready  (req_ready),
    .resp_valid (resp_valid),
    .resp_rdata (resp_rdata),
    .haddr      (haddr),
    .hwdata     (hwdata),
    .htrans     (htrans),
    .hwrite     (hwrite),
    .hsize      (hsize),
    .hburst     (hburst),
    .hprot      (hprot),
    .hrdata     (hrdata),
    .hready     (hready),
    .hresp      (hresp)
  );

  // -------------------------------------------------------------------------
  // Clock Generation
  // -------------------------------------------------------------------------
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

// -------------------------------------------------------------------------
  // AHB Slave Model (Memory)
  // -------------------------------------------------------------------------
  logic [31:0] memory [0:1023]; // 1024-entry memory (bits [11:2] of address)
  logic [31:0] haddr_r;          // Registered address for data phase
  logic        hwrite_r;         // Registered write enable for data phase

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hready <= 1'b1;
      hresp  <= 1'b0;
      hrdata <= '0;
      haddr_r <= '0;
      hwrite_r <= 1'b0;
    end else begin
      hready <= 1'b1;

      // Handle data phase (one cycle after address phase)
      if (hready && hwrite_r) begin
        memory[haddr_r[11:2]] <= hwdata;
        $display("AHB Write: addr=%h, idx=%0d, data=%h", haddr_r, haddr_r[11:2], hwdata);
      end else if (hready && htrans[1] && !hwrite) begin
        // Read: respond immediately on address phase
        hrdata <= memory[haddr[11:2]];
      end

      // Register address phase for next cycle's data phase
      if (hready && htrans[1]) begin
        haddr_r <= haddr;
        hwrite_r <= hwrite;
      end else begin
        hwrite_r <= 1'b0;
      end
    end
  end

  // -------------------------------------------------------------------------
  // Tasks
  // -------------------------------------------------------------------------
  task wait_cycles(int n);
    repeat(n) @(posedge clk);
  endtask

  task perform_read(input logic [31:0] addr, input logic [31:0] expected_data, input string msg);
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] timeout;
    /* verilator lint_on UNUSEDSIGNAL */
    timeout = 0;

    // Send Request
    wait(req_ready);
    req_valid = 1'b1;
    req_addr  = addr;
    req_write = 1'b0;
    req_size  = 3'b010; // Word

    @(posedge clk);
    // Request is sampled at this posedge if req_ready was high.
    // If for some reason req_ready dropped before this edge, we should have waited.
    // But since we did wait(req_ready) before, it should be fine.
    req_valid = 1'b0;

    // Wait for response
    fork
      begin
        wait(resp_valid);
      end
      begin
        repeat(100) @(posedge clk);
        $display("Error: Timeout waiting for response - %s", msg);
        error_cnt++;
      end
    join_any

    disable fork; // Kill the other thread

    if (resp_valid) begin
      if (resp_rdata !== expected_data) begin
        $display("Error: Data Mismatch - %s. Expected: %h, Got: %h", msg, expected_data, resp_rdata);
        error_cnt++;
      end else begin
        $display("Success: %s. Got: %h", msg, resp_rdata);
      end
    end

@(posedge clk);
  endtask

  task perform_write(input logic [31:0] addr, input logic [31:0] wdata, input string msg);
    /* verilator lint_off UNUSEDSIGNAL */
    logic [31:0] timeout;
    /* verilator lint_on UNUSEDSIGNAL */
    timeout = 0;

    wait(req_ready);
    req_valid = 1'b1;
    req_addr  = addr;
    req_wdata = wdata;
    req_write = 1'b1;
    req_size  = 3'b010;

    @(posedge clk);
    req_valid = 1'b0;

    fork
      begin
        wait(resp_valid);
      end
      begin
        repeat(100) @(posedge clk);
        $display("Error: Timeout waiting for write response - %s", msg);
        error_cnt++;
      end
    join_any

    disable fork; // Kill the other thread

    if (resp_valid) begin
      $display("Success: Write complete - %s. Addr: %h, Data: %h", msg, addr, wdata);
    end

    @(posedge clk);
  endtask

  // -------------------------------------------------------------------------
  // Main Test
  // -------------------------------------------------------------------------
  initial begin
    // Initialize Inputs
    rst_n = 0;
    req_valid = 0;
    req_addr = 0;
    req_wdata = 0;
    req_write = 0;
    req_size = 0;

// Initialize Memory
    // Memory index = bits [11:2] of address
    memory[0]   = 32'hAAAA_BBBB; // 0x0000_0000
    memory[1]   = 32'hCCCC_DDDD; // 0x0000_0004
    memory[64]  = 32'h1234_5678; // 0x0000_0100
    memory[256] = 32'hBEEF_CAFE; // 0x0000_0400

    // Reset Sequence
    #20;
    rst_n = 1;
        $display("Reset released. Waiting for flush...");
        
        // Wait for flush to complete (CACHE_SIZE/4 cycles approx)
        // 1024 bytes / 4 = 256 lines. 256 cycles.
        repeat(300) begin
          @(posedge clk);
          if (dut.state_r == 1) begin // FLUSH
             $display("Time: %t, State: FLUSH, Cnt: %d", $time, dut.flush_cnt);
          end
        end
        $display("Flush wait done. DUT State: %d, Flush Cnt: %d", dut.state_r, dut.flush_cnt);
    
        $display("Starting Read Tests...");
    // Test 1: Read Miss (Address 0x0000 - idx 0)
    perform_read(32'h0000_0000, 32'hAAAA_BBBB, "Read Miss @ 0x0000");

    // Test 2: Read Hit (Address 0x0000)
    perform_read(32'h0000_0000, 32'hAAAA_BBBB, "Read Hit @ 0x0000");

    // Test 3: Read Miss Different Index (Address 0x0004 - idx 1)
    perform_read(32'h0000_0004, 32'hCCCC_DDDD, "Read Miss @ 0x0004");

    // Test 4: Read Miss Conflict (Address 0x0400)
    // Index 0, Tag 1 - Same index as 0x0000, different tag
    perform_read(32'h0000_0400, 32'hBEEF_CAFE, "Conflict Miss @ 0x0400");

    // Test 5: Read Hit (Address 0x0400)
    perform_read(32'h0000_0400, 32'hBEEF_CAFE, "Read Hit @ 0x0400");

    // Test 6: Read Miss (Address 0x0000) - Should have been evicted
    perform_read(32'h0000_0000, 32'hAAAA_BBBB, "Read Miss (Evicted) @ 0x0000");

    // Write Tests
    $display("Starting Write Tests...");

    // Test 7: Write Hit (Address 0x0000 - recently cached)
    perform_write(32'h0000_0000, 32'h5555_AAAA, "Write Hit @ 0x0000");

    // Test 8: Read after Write Hit - should get updated value from cache
    perform_read(32'h0000_0000, 32'h5555_AAAA, "Read after Write Hit @ 0x0000");

    // Test 9: Write Miss (Address 0x0100 - not cached)
    perform_write(32'h0000_0100, 32'hFEED_FACE, "Write Miss @ 0x0100");

    // Test 10: Read after Write Miss - should fetch from memory (write-through)
    perform_read(32'h0000_0100, 32'hFEED_FACE, "Read after Write Miss @ 0x0100");

    // Test 11: Write to conflicting address (Address 0x0400 - evicts 0x0000)
    perform_write(32'h0000_0400, 32'hDEAD_BEEF, "Write Conflict @ 0x0400");


    if (error_cnt == 0) begin
      $display("ALL TESTS PASSED");
    end else begin
      $display("TESTS FAILED with %0d errors", error_cnt);
    end

    $finish;
  end

endmodule
