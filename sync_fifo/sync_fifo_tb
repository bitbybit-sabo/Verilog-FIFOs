`timescale 1ns/1ps
//==============================================================================
// Self-checking testbench for sync_fifo
//
// Strategy:
//   - A "golden model" tracks expected FIFO contents using a SystemVerilog
//     queue (not a re-implementation of the DUT's pointer/counter RTL), so
//     bugs in the DUT's pointer/counter logic can't accidentally be
//     replicated in the checker.
//   - Directed tests hit every corner case explicitly: reset, fill-to-full,
//     drain-to-empty, illegal write-when-full, illegal read-when-empty,
//     simultaneous read+write at FULL, simultaneous read+write at EMPTY,
//     and pointer wraparound.
//   - A randomized soak test then hammers the DUT with constrained-random
//     write_en/read_en/data_in every cycle and checks full, empty and
//     data_out against the golden model on every single clock edge.
//==============================================================================

module tb_sync_fifo;

  //---------------------------------------------------------------
  // Parameters (must match DUT)
  //---------------------------------------------------------------
  localparam DATA_WIDTH   = 8;
  localparam DEPTH        = 8;
  localparam COUNTER_SIZE = 4;
  localparam POINTER_SIZE = 3;

  //---------------------------------------------------------------
  // DUT I/O
  //---------------------------------------------------------------
  reg                     clk;
  reg                     a_reset;
  reg                     write_en;
  reg                     read_en;
  reg  [DATA_WIDTH-1:0]   data_in;
  wire                    full;
  wire                    empty;
  wire [DATA_WIDTH-1:0]   data_out;

  int error_count = 0;
  int check_count = 0;

  sync_fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(DEPTH),
    .COUNTER_SIZE(COUNTER_SIZE),
    .POINTER_SIZE(POINTER_SIZE)
  ) dut (
    .clk(clk), .a_reset(a_reset),
    .write_en(write_en), .read_en(read_en),
    .data_in(data_in), .full(full), .empty(empty),
    .data_out(data_out)
  );

  //---------------------------------------------------------------
  // Clock
  //---------------------------------------------------------------
  initial clk = 0;
  always #5 clk = ~clk;

  //---------------------------------------------------------------
  // Golden reference model (implementation-independent FIFO semantics)
  //   - model_q: behavioral queue of "stored" items
  //   - model_data_out: registered output, mirrors DUT's registered style
  //   - cut-through rule when empty+write+read: bypass without storing
  //   - normal rule when non-empty (whether full or not) +write+read:
  //       pop oldest to output, push new item to back (order preserved)
  //---------------------------------------------------------------
  reg [DATA_WIDTH-1:0] model_mem [0:DEPTH-1];
  integer model_head; // next item to pop
  integer model_tail; // next free slot to push
  integer model_count;
  reg [DATA_WIDTH-1:0] model_data_out;
  wire model_full  = (model_count == DEPTH);
  wire model_empty = (model_count == 0);

  always @(posedge clk or posedge a_reset) begin
    if (a_reset) begin
      model_head     <= 0;
      model_tail     <= 0;
      model_count    <= 0;
      // NOTE: DUT's data_out is a reg that is only ever written on a real
      // read/cut-through event and is NOT cleared by a_reset. The model
      // intentionally mirrors that (no assignment here) so the scoreboard
      // checks actual FIFO correctness rather than masking this behavior.
    end else begin
      case ({write_en, read_en})
        2'b00: ; // idle
        2'b01: begin // read only
          if (!model_empty) begin
            model_data_out <= model_mem[model_head];
            model_head     <= (model_head + 1) % DEPTH;
            model_count    <= model_count - 1;
          end
        end
        2'b10: begin // write only
          if (!model_full) begin
            model_mem[model_tail] <= data_in;
            model_tail  <= (model_tail + 1) % DEPTH;
            model_count <= model_count + 1;
          end
        end
        2'b11: begin // simultaneous read+write
          if (model_empty) begin
            model_data_out <= data_in;   // cut-through, nothing stored
            // count/head/tail unchanged (net zero occupancy change)
          end else begin
            model_data_out <= model_mem[model_head]; // oldest out
            model_mem[model_tail] <= data_in;         // new item in
            model_head <= (model_head + 1) % DEPTH;
            model_tail <= (model_tail + 1) % DEPTH;
            // count unchanged: one out, one in
          end
        end
      endcase
    end
  end

  //---------------------------------------------------------------
  // Scoreboard: compare DUT against golden model every cycle
  // Sampled shortly after the clock edge so both DUT and model have
  // settled their non-blocking updates.
  //---------------------------------------------------------------
  task automatic check_outputs(string tag);
    check_count++;
    if (full !== model_full) begin
      error_count++;
      $display("[%0t] ERROR (%s): full mismatch. DUT=%0b MODEL=%0b",
                $time, tag, full, model_full);
    end
    if (empty !== model_empty) begin
      error_count++;
      $display("[%0t] ERROR (%s): empty mismatch. DUT=%0b MODEL=%0b",
                $time, tag, empty, model_empty);
    end
    if (data_out !== model_data_out) begin
      error_count++;
      $display("[%0t] ERROR (%s): data_out mismatch. DUT=0x%0h MODEL=0x%0h",
                $time, tag, data_out, model_data_out);
    end
  endtask

  // Continuous monitor: check after every posedge once things settle
  always @(posedge clk) begin
    #1; // let both DUT and model non-blocking assigns resolve
    check_outputs("monitor");
  end

  //---------------------------------------------------------------
  // Stimulus helper tasks
  //---------------------------------------------------------------
  task automatic do_reset();
    a_reset  = 1;
    write_en = 0;
    read_en  = 0;
    data_in  = '0;
    @(posedge clk); @(posedge clk);
    a_reset = 0;
    @(posedge clk);
  endtask

  task automatic write_item(input [DATA_WIDTH-1:0] d);
    @(negedge clk);
    write_en = 1; read_en = 0; data_in = d;
    @(negedge clk);
    write_en = 0;
  endtask

  task automatic read_item();
    @(negedge clk);
    read_en = 1; write_en = 0;
    @(negedge clk);
    read_en = 0;
  endtask

  task automatic write_read_item(input [DATA_WIDTH-1:0] d);
    @(negedge clk);
    write_en = 1; read_en = 1; data_in = d;
    @(negedge clk);
    write_en = 0; read_en = 0;
  endtask

  task automatic idle_cycle();
    @(negedge clk);
    write_en = 0; read_en = 0;
    @(negedge clk);
  endtask

  //---------------------------------------------------------------
  // Main test sequence
  //---------------------------------------------------------------
  int i;
  reg [DATA_WIDTH-1:0] rnd_data;

  initial begin
    $display("=========================================================");
    $display(" sync_fifo self-checking testbench starting");
    $display("=========================================================");

    write_en = 0; read_en = 0; data_in = 0; a_reset = 0;

    //--------------------------------------------------
    // Test 1: Reset behavior
    //--------------------------------------------------
    $display("\n--- Test 1: Reset ---");
    do_reset();
    if (full !== 0 || empty !== 1)
      $display("[%0t] ERROR: post-reset full/empty incorrect (full=%0b empty=%0b)",
                $time, full, empty);

    //--------------------------------------------------
    // Test 2: Fill to full, verify full flag, verify
    //         over-write while full is dropped
    //--------------------------------------------------
    $display("\n--- Test 2: Fill to full ---");
    for (i = 0; i < DEPTH; i++)
      write_item(i + 8'hA0);
    if (full !== 1)
      $display("[%0t] ERROR: FIFO should be full after %0d writes", $time, DEPTH);

    $display("--- Test 2b: illegal write while full (should be dropped) ---");
    write_item(8'hFF); // this must NOT overwrite / corrupt anything
    if (full !== 1)
      $display("[%0t] ERROR: full flag changed after illegal write", $time);

    //--------------------------------------------------
    // Test 3: Drain to empty, verify order (FIFO, not LIFO),
    //         verify empty flag, verify over-read when
    //         empty is dropped (data_out holds last value)
    //--------------------------------------------------
    $display("\n--- Test 3: Drain to empty, check ordering ---");
    for (i = 0; i < DEPTH; i++) begin
      read_item();
      #1;
      if (data_out !== (i + 8'hA0))
        $display("[%0t] ERROR: FIFO order violation. Expected 0x%0h got 0x%0h",
                  $time, i + 8'hA0, data_out);
    end
    if (empty !== 1)
      $display("[%0t] ERROR: FIFO should be empty after draining", $time);

    $display("--- Test 3b: illegal read while empty (should be dropped) ---");
    begin
      reg [DATA_WIDTH-1:0] held;
      held = data_out;
      read_item();
      #1;
      if (data_out !== held)
        $display("[%0t] ERROR: data_out changed on illegal read-while-empty", $time);
    end

    //--------------------------------------------------
    // Test 4: Simultaneous read+write while EMPTY
    //         (cut-through case)
    //--------------------------------------------------
    $display("\n--- Test 4: simultaneous read+write while EMPTY (cut-through) ---");
    write_read_item(8'h55);
    #1;
    if (data_out !== 8'h55)
      $display("[%0t] ERROR: empty cut-through failed. Expected 0x55 got 0x%0h",
                $time, data_out);
    if (empty !== 1 || full !== 0)
      $display("[%0t] ERROR: empty/full flags disturbed by cut-through (empty=%0b full=%0b)",
                $time, empty, full);

    //--------------------------------------------------
    // Test 5: Simultaneous read+write while FULL
    //--------------------------------------------------
    $display("\n--- Test 5: simultaneous read+write while FULL ---");
    for (i = 0; i < DEPTH; i++)
      write_item(i + 8'h10);
    if (full !== 1)
      $display("[%0t] ERROR: setup for test 5 failed, FIFO not full", $time);

    write_read_item(8'hE0); // push E0 in, expect 0x10 (oldest) out
    #1;
    if (data_out !== 8'h10)
      $display("[%0t] ERROR: full simultaneous r/w failed. Expected 0x10 got 0x%0h",
                $time, data_out);
    if (full !== 1)
      $display("[%0t] ERROR: FIFO should remain full after simultaneous r/w", $time);

    // drain and check the pushed value came out in order at the tail
    for (i = 0; i < DEPTH - 1; i++) begin
      read_item(); #1;
    end
    read_item(); #1;
    if (data_out !== 8'hE0)
      $display("[%0t] ERROR: pushed value during full-r/w not found at tail. Got 0x%0h",
                $time, data_out);

    //--------------------------------------------------
    // Test 6: Pointer wraparound stress
    //  (repeatedly push/pop single items past pointer rollover)
    //--------------------------------------------------
    $display("\n--- Test 6: pointer wraparound stress ---");
    for (i = 0; i < 20; i++) begin
      write_item(i[7:0] + 8'h30);
      read_item();
      #1;
      if (data_out !== (i[7:0] + 8'h30))
        $display("[%0t] ERROR: wraparound mismatch at i=%0d. Expected 0x%0h got 0x%0h",
                  $time, i, i[7:0] + 8'h30, data_out);
    end
    if (empty !== 1)
      $display("[%0t] ERROR: FIFO should be empty after wraparound stress", $time);

    //--------------------------------------------------
    // Test 7: Randomized soak test
    //  every cycle randomly assert write_en/read_en/data_in,
    //  scoreboard (already running in background) checks
    //  full/empty/data_out against the golden model each cycle.
    //--------------------------------------------------
    $display("\n--- Test 7: randomized soak test (2000 cycles) ---");
    for (i = 0; i < 2000; i++) begin
      @(negedge clk);
      write_en = $urandom_range(0, 99) < 55; // bias slightly towards writes
      read_en  = $urandom_range(0, 99) < 55;
      data_in  = $urandom_range(0, 255);
    end
    @(negedge clk);
    write_en = 0; read_en = 0;
    @(posedge clk); #1;

    //--------------------------------------------------
    // Test 8: async reset mid-operation
    //--------------------------------------------------
    $display("\n--- Test 8: async reset mid-operation ---");
    write_item(8'hAB);
    write_item(8'hCD);
    @(negedge clk);
    a_reset = 1;
    #2; // assert reset asynchronously, off the clock edge
    if (full !== 0 || empty !== 1)
      $display("[%0t] ERROR: async reset did not clear full/empty immediately", $time);
    @(posedge clk);
    a_reset = 0;
    @(posedge clk); #1;
    check_outputs("post_async_reset");

    //--------------------------------------------------
    // Final report
    //--------------------------------------------------
    $display("\n=========================================================");
    if (error_count == 0)
      $display(" ALL TESTS PASSED  (%0d checks performed, 0 errors)", check_count);
    else
      $display(" TESTS FAILED  (%0d checks performed, %0d errors)", check_count, error_count);
    $display("=========================================================");
    $finish;
  end

  //---------------------------------------------------------------
  // Safety timeout
  //---------------------------------------------------------------
  initial begin
    #200000;
    $display("[%0t] ERROR: TIMEOUT - simulation did not finish in time", $time);
    $finish;
  end

endmodule
