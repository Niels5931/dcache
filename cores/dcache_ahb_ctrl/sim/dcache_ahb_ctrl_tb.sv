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
  logic [31:0] memory [logic [31:0]]; // Sparse memory

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hready <= 1'b1;
      hresp  <= 1'b0;
      hrdata <= '0;
    end else begin
      // Simple random wait state insertion
      // hready <= ($random % 5) != 0;
      hready <= 1'b1; // Always ready for now to simplify

      if (hready && htrans[1]) begin // NONSEQ or SEQ
        if (hwrite) begin
           // Write not tested in read test
        end else begin
           // Read
           if (memory.exists(haddr)) begin
             hrdata <= memory[haddr];
           end else begin
             hrdata <= 32'hDEADBEEF; // Default value
           end
        end
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
        disable fork; // Break other thread? No, this is tricky in SV.
      end
    join_any

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
    memory[32'h0000_1000] = 32'hAAAA_BBBB;
    memory[32'h0000_1004] = 32'hCCCC_DDDD;
    memory[32'h0000_2000] = 32'h1234_5678;

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
    // Test 1: Read Miss (Address 0x1000)
    perform_read(32'h0000_1000, 32'hAAAA_BBBB, "Read Miss @ 0x1000");

    // Test 2: Read Hit (Address 0x1000)
    // AHB slave should NOT see a transaction here (checked by observation/waves, or we could add counters)
    perform_read(32'h0000_1000, 32'hAAAA_BBBB, "Read Hit @ 0x1000");

    // Test 3: Read Miss Different Index (Address 0x1004)
    perform_read(32'h0000_1004, 32'hCCCC_DDDD, "Read Miss @ 0x1004");

    // Test 4: Read Miss Conflict (Address 0x2000) -> Maps to same index as 0x1000?
    // Index bits:
    // Offset: 2 bits (Byte 0-3)
    // Cache: 1024 bytes.
    // Index Width: $clog2(1024/4) = 8 bits.
    // Address bits used for index: [9:2]
    // 0x1000 -> Bin: ...0001 0000 0000 0000. Index = 00.
    // 0x2000 -> Bin: ...0010 0000 0000 0000. Index = 00.
    // Same index, different tag. Should be a conflict miss.
    perform_read(32'h0000_2000, 32'h1234_5678, "Conflict Miss @ 0x2000");

    // Test 5: Read Hit (Address 0x2000)
    perform_read(32'h0000_2000, 32'h1234_5678, "Read Hit @ 0x2000");

    // Test 6: Read Miss (Address 0x1000) - Should have been evicted
    perform_read(32'h0000_1000, 32'hAAAA_BBBB, "Read Miss (Evicted) @ 0x1000");


    if (error_cnt == 0) begin
      $display("ALL TESTS PASSED");
    end else begin
      $display("TESTS FAILED with %0d errors", error_cnt);
    end

    $finish;
  end

endmodule
