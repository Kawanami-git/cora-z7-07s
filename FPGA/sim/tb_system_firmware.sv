`timescale 1ns / 1ps

module tb_system_firmware;

`ifndef ARCHI
  `define ARCHI 32
`endif
  localparam int unsigned XLEN_BYTES = `ARCHI / 8;
  typedef logic [`ARCHI-1:0] uword_t;

  import axi_vip_pkg::*;
  import simulation_axi_vip_0_0_pkg::*;

  // ---------------------------------------------------------------------------
  // Testbench signals
  // ---------------------------------------------------------------------------
  logic                        sys_clock;
  logic                        reset_rtl;

  simulation_axi_vip_0_0_mst_t mst_agent;

  // ---------------------------------------------------------------------------
  // Address map
  // ---------------------------------------------------------------------------
  localparam xil_axi_ulong SOC_BASE_ADDR = 32'h6000_0000;

  localparam xil_axi_ulong SYS_RESET_BASE = 32'h6000_0000;
  localparam xil_axi_ulong IMEM_BASE = 32'h6010_0000;
  localparam xil_axi_ulong DMEM_BASE = 32'h6014_0000;

  // Platform-to-core FIFO window.
  localparam xil_axi_ulong PTC_FIFO_BASE = 32'h6015_0000;
  localparam xil_axi_ulong PTC_FIFO_STATUS_ADDR = PTC_FIFO_BASE;
  localparam xil_axi_ulong PTC_FIFO_DATA_ADDR = PTC_FIFO_BASE + XLEN_BYTES;

  // Core-to-platform FIFO window.
  localparam xil_axi_ulong CTP_FIFO_BASE = 32'h6016_0000;
  localparam xil_axi_ulong CTP_FIFO_STATUS_ADDR = CTP_FIFO_BASE;
  localparam xil_axi_ulong CTP_FIFO_DATA_ADDR = CTP_FIFO_BASE + XLEN_BYTES;

  // ---------------------------------------------------------------------------
  // FIFO status register layout
  // ---------------------------------------------------------------------------
  localparam logic [31:0] FIFO_EMPTY_MASK = 32'h0000_0001;
  localparam logic [31:0] FIFO_FULL_MASK = 32'h0000_0002;
  localparam int unsigned FIFO_RCOUNT_SHIFT = 8;
  localparam int unsigned FIFO_WCOUNT_SHIFT = 20;
  localparam logic [31:0] FIFO_COUNT_MASK = 32'h0000_0fff;

  // ---------------------------------------------------------------------------
  // Firmware file
  // Format expected:
  //   00100000:00000293
  //   00100004:00000513
  //   00140000:12345678
  //
  // Effective AXI address = SOC_BASE_ADDR + file_addr
  // ---------------------------------------------------------------------------
  string FW_FILE = "../../../../../../firmware/build/echo.hex";

  // ---------------------------------------------------------------------------
  // Echo test frame
  // ---------------------------------------------------------------------------
  // The echo firmware protocol is message-oriented:
  //   word 0      : message size in bytes
  //   word 1..N   : message payload, packed little-endian in FIFO words
  //
  // This test sends the same payload as the known-good software simulation:
  //   "hi\n\0" -> 68 69 0a 00 -> 32'h000a_6968
  //
  // The response is expected to use the exact same frame format: first the
  // returned message size, then the returned message payload words.
  localparam int unsigned TEST_MESSAGE_BYTE_COUNT = 4;
  localparam int unsigned TEST_MESSAGE_WORD_COUNT = (TEST_MESSAGE_BYTE_COUNT + XLEN_BYTES - 1) /
      XLEN_BYTES;
  localparam int unsigned TEST_FRAME_WORD_COUNT = 1 + TEST_MESSAGE_WORD_COUNT;

  localparam uword_t TEST_MESSAGE_SIZE_WORD = uword_t'(TEST_MESSAGE_BYTE_COUNT);
  localparam uword_t TEST_MESSAGE_WORD0 = uword_t'(32'h000a_6968);

  // ---------------------------------------------------------------------------
  // Timing / polling parameters
  // ---------------------------------------------------------------------------
  localparam int STARTUP_WAIT_CYCLES = 20;
  localparam int EXEC_WAIT_CYCLES = 500;
  localparam int POLL_WAIT_CYCLES = 50;
  localparam int POLL_MAX_ITERS = 400;

  // ---------------------------------------------------------------------------
  // DUT
  // ---------------------------------------------------------------------------
  simulation_wrapper DUT (
      .reset_rtl(reset_rtl),
      .sys_clock(sys_clock)
  );

  // ---------------------------------------------------------------------------
  // Clock generation
  // ---------------------------------------------------------------------------
  initial sys_clock = 1'b0;
  always #4 sys_clock = ~sys_clock;  // 125 MHz

  // ---------------------------------------------------------------------------
  // Global timeout
  // ---------------------------------------------------------------------------
  initial begin
    #10_000_000ns;
    $error("Timeout: system firmware test did not complete");
    $finish;
  end

  // ---------------------------------------------------------------------------
  // Static configuration checks
  // ---------------------------------------------------------------------------
  initial begin
    if ((`ARCHI != 32) && (`ARCHI != 64)) begin
      $error("Unsupported ARCHI=%0d. Expected 32 or 64.", `ARCHI);
      $finish;
    end
  end

  // ---------------------------------------------------------------------------
  // Utility: wait on internal AXI clock
  // ---------------------------------------------------------------------------
  task automatic wait_axi_clk(input int cycles);
    repeat (cycles) @(posedge DUT.simulation_i.clk_wiz_0_clk_out1);
  endtask

  // ---------------------------------------------------------------------------
  // FIFO status helpers
  // ---------------------------------------------------------------------------
  function automatic logic fifo_status_empty(input logic [31:0] status);
    fifo_status_empty = ((status & FIFO_EMPTY_MASK) != 32'h0);
  endfunction

  function automatic logic fifo_status_full(input logic [31:0] status);
    fifo_status_full = ((status & FIFO_FULL_MASK) != 32'h0);
  endfunction

  function automatic int unsigned fifo_status_rcount(input logic [31:0] status);
    fifo_status_rcount = (status >> FIFO_RCOUNT_SHIFT) & FIFO_COUNT_MASK;
  endfunction

  function automatic int unsigned fifo_status_wcount(input logic [31:0] status);
    fifo_status_wcount = (status >> FIFO_WCOUNT_SHIFT) & FIFO_COUNT_MASK;
  endfunction

  // ---------------------------------------------------------------------------
  // AXI helpers
  // ---------------------------------------------------------------------------
  task automatic axi_write32(input xil_axi_ulong addr, input logic [31:0] data);
    axi_transaction   wr_tr;
    xil_axi_data_beat dbeat;
    xil_axi_uint      id;
    xil_axi_len_t     len;
    xil_axi_size_t    size;
    xil_axi_burst_t   burst;

    id    = 0;
    len   = 0;  // single beat
    size  = xil_axi_size_t'(2);  // 2^2 = 4 bytes
    burst = xil_axi_burst_t'(1);  // INCR, equivalent to FIXED for one beat

    wr_tr = mst_agent.wr_driver.create_transaction("wr32");
    wr_tr.set_write_cmd(addr, burst, id, len, size);

    dbeat       = '0;
    dbeat[31:0] = data;
    wr_tr.set_data_beat(0, dbeat);

    wr_tr.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);

    mst_agent.wr_driver.send(wr_tr);
    mst_agent.wr_driver.wait_rsp(wr_tr);

    $display("[%0t] AXI WRITE addr=0x%08h data=0x%08h", $time, addr[31:0], data);
  endtask

  task automatic axi_read32(input xil_axi_ulong addr, output logic [31:0] data);
    axi_transaction   rd_tr;
    xil_axi_data_beat rbeat;
    xil_axi_uint      id;
    xil_axi_len_t     len;
    xil_axi_size_t    size;
    xil_axi_burst_t   burst;

    id    = 0;
    len   = 0;  // single beat
    size  = xil_axi_size_t'(2);  // 4 bytes
    burst = xil_axi_burst_t'(1);  // INCR, equivalent to FIXED for one beat

    rd_tr = mst_agent.rd_driver.create_transaction("rd32");
    rd_tr.set_read_cmd(addr, burst, id, len, size);
    rd_tr.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);

    mst_agent.rd_driver.send(rd_tr);
    mst_agent.rd_driver.wait_rsp(rd_tr);

    rbeat = rd_tr.get_data_beat(0);
    data  = rbeat[31:0];

    $display("[%0t] AXI READ  addr=0x%08h data=0x%08h", $time, addr[31:0], data);
  endtask

  task automatic axi_write_uword(input xil_axi_ulong addr, input uword_t data);
    axi_transaction          wr_tr;
    xil_axi_data_beat        dbeat;
    xil_axi_uint             id;
    xil_axi_len_t            len;
    xil_axi_size_t           size;
    xil_axi_burst_t          burst;
    logic             [63:0] data64;

    id     = 0;
    burst  = xil_axi_burst_t'(1);  // INCR
    data64 = data;

    // The Cora/Zynq AXI VIP master interface is 32-bit wide. Therefore a
    // 64-bit firmware word must be emitted as a two-beat 32-bit INCR burst.
    // SmartConnect then performs the width conversion toward the 64-bit slave.
    case (XLEN_BYTES)
      4: begin
        len  = xil_axi_len_t'(0);  // one 32-bit beat
        size = xil_axi_size_t'(2);  // 2^2 = 4 bytes
      end

      8: begin
        len  = xil_axi_len_t'(1);  // two 32-bit beats
        size = xil_axi_size_t'(2);  // each beat is 4 bytes
      end

      default: begin
        $error("Unsupported FIFO uword access width: %0d bytes", XLEN_BYTES);
        $finish;
      end
    endcase

    wr_tr = mst_agent.wr_driver.create_transaction("wr_uword");
    wr_tr.set_write_cmd(addr, burst, id, len, size);

    dbeat       = '0;
    dbeat[31:0] = data64[31:0];
    wr_tr.set_data_beat(0, dbeat);

    if (XLEN_BYTES == 8) begin
      dbeat       = '0;
      dbeat[31:0] = data64[63:32];
      wr_tr.set_data_beat(1, dbeat);
    end

    wr_tr.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);

    mst_agent.wr_driver.send(wr_tr);
    mst_agent.wr_driver.wait_rsp(wr_tr);

    $display("[%0t] AXI WRITE_UWORD addr=0x%08h data=0x%0h xlen_bytes=%0d axi_beats=%0d", $time,
             addr[31:0], data, XLEN_BYTES, len + 1);
  endtask

  task automatic axi_read_uword(input xil_axi_ulong addr, output uword_t data);
    axi_transaction          rd_tr;
    xil_axi_data_beat        rbeat;
    xil_axi_uint             id;
    xil_axi_len_t            len;
    xil_axi_size_t           size;
    xil_axi_burst_t          burst;
    logic             [63:0] data64;

    id    = 0;
    burst = xil_axi_burst_t'(1);  // INCR

    // The Cora/Zynq AXI VIP master interface is 32-bit wide. Therefore a
    // 64-bit firmware word is read as a two-beat 32-bit INCR burst.
    case (XLEN_BYTES)
      4: begin
        len  = xil_axi_len_t'(0);  // one 32-bit beat
        size = xil_axi_size_t'(2);  // 2^2 = 4 bytes
      end

      8: begin
        len  = xil_axi_len_t'(1);  // two 32-bit beats
        size = xil_axi_size_t'(2);  // each beat is 4 bytes
      end

      default: begin
        $error("Unsupported FIFO uword access width: %0d bytes", XLEN_BYTES);
        $finish;
      end
    endcase

    rd_tr = mst_agent.rd_driver.create_transaction("rd_uword");
    rd_tr.set_read_cmd(addr, burst, id, len, size);
    rd_tr.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);

    mst_agent.rd_driver.send(rd_tr);
    mst_agent.rd_driver.wait_rsp(rd_tr);

    rbeat        = rd_tr.get_data_beat(0);
    data64       = '0;
    data64[31:0] = rbeat[31:0];

    if (XLEN_BYTES == 8) begin
      rbeat         = rd_tr.get_data_beat(1);
      data64[63:32] = rbeat[31:0];
    end

    data = uword_t'(data64[`ARCHI-1:0]);

    $display("[%0t] AXI READ_UWORD  addr=0x%08h data=0x%0h xlen_bytes=%0d axi_beats=%0d", $time,
             addr[31:0], data, XLEN_BYTES, len + 1);
  endtask

  task automatic axi_check32(input xil_axi_ulong addr, input logic [31:0] expected);
    logic [31:0] got;

    axi_read32(addr, got);

    if (got !== expected) begin
      $error("[%0t] MISMATCH addr=0x%08h got=0x%08h expected=0x%08h", $time, addr[31:0], got,
             expected);
      $finish;
    end
    else begin
      $display("[%0t] CHECK OK addr=0x%08h value=0x%08h", $time, addr[31:0], got);
    end
  endtask

  // ---------------------------------------------------------------------------
  // Firmware loader
  // Each valid line must match:
  //   <hex_addr>:<hex_data>
  //
  // Example:
  //   00100000:00000293
  //
  // Real AXI address = 0x6000_0000 + 0x00100000 = 0x6010_0000
  // ---------------------------------------------------------------------------
  task automatic load_firmware_file(input string file_name);
    integer              fd;
    integer              rc;
    string               line;
    int unsigned         file_addr;
    logic         [31:0] data;
    xil_axi_ulong        axi_addr;

    fd = $fopen(file_name, "r");
    if (fd == 0) begin
      $error("Cannot open firmware file '%0s'", file_name);
      $finish;
    end

    while (!$feof(
        fd
    )) begin
      line = "";
      void'($fgets(line, fd));

      rc = $sscanf(line, "%h:%h", file_addr, data);
      if (rc == 2) begin
        axi_addr = SOC_BASE_ADDR + file_addr;
        axi_write32(axi_addr, data);
      end
    end

    $fclose(fd);
    $display("[%0t] Firmware file loaded: %0s", $time, file_name);
  endtask

  // ---------------------------------------------------------------------------
  // FIFO access helpers
  // ---------------------------------------------------------------------------
  task automatic wait_for_ptc_fifo_writable(input int unsigned nb_words, input int max_iters);
    logic [31:0] status;
    int          i;

    for (i = 0; i < max_iters; i++) begin
      axi_read32(PTC_FIFO_STATUS_ADDR, status);

      if (!fifo_status_full(status) && (fifo_status_wcount(status) >= nb_words)) begin
        $display("[%0t] PTC FIFO writable: status=0x%08h wcount=%0d", $time, status,
                 fifo_status_wcount(status));
        return;
      end

      wait_axi_clk(POLL_WAIT_CYCLES);
    end

    $error("[%0t] Timeout waiting for PTC FIFO writable space.", $time);
    $finish;
  endtask

  task automatic wait_for_ctp_fifo_readable(input int unsigned nb_words, input int max_iters);
    logic [31:0] status;
    int          i;

    for (i = 0; i < max_iters; i++) begin
      axi_read32(CTP_FIFO_STATUS_ADDR, status);

      if (!fifo_status_empty(status) && (fifo_status_rcount(status) >= nb_words)) begin
        $display("[%0t] CTP FIFO readable: status=0x%08h rcount=%0d", $time, status,
                 fifo_status_rcount(status));
        return;
      end

      wait_axi_clk(POLL_WAIT_CYCLES);
    end

    $error("[%0t] Timeout waiting for CTP FIFO readable data.", $time);
    $finish;
  endtask

  task automatic ptc_fifo_write_uword(input uword_t data);
    wait_for_ptc_fifo_writable(1, POLL_MAX_ITERS);
    axi_write_uword(PTC_FIFO_DATA_ADDR, data);
  endtask

  task automatic ctp_fifo_read_uword(output uword_t data);
    wait_for_ctp_fifo_readable(1, POLL_MAX_ITERS);
    axi_read_uword(CTP_FIFO_DATA_ADDR, data);
  endtask

  task automatic send_test_payload_to_core_fifo;
    wait_for_ptc_fifo_writable(TEST_FRAME_WORD_COUNT, POLL_MAX_ITERS);

    // Echo protocol: send message byte size first, then payload words.
    axi_write_uword(PTC_FIFO_DATA_ADDR, TEST_MESSAGE_SIZE_WORD);
    axi_write_uword(PTC_FIFO_DATA_ADDR, TEST_MESSAGE_WORD0);

    $display("[%0t] PTC FIFO echo frame written: size=%0d bytes payload0=0x%0h", $time,
             TEST_MESSAGE_BYTE_COUNT, TEST_MESSAGE_WORD0);
  endtask

  task automatic check_echo_payload_from_core_fifo;
    uword_t      got_size;
    uword_t      got_word0;
    int unsigned got_message_byte_count;
    int unsigned got_message_word_count;

    // Echo protocol: read message byte size first.
    ctp_fifo_read_uword(got_size);
    got_message_byte_count = int'(got_size);
    got_message_word_count = (got_message_byte_count + XLEN_BYTES - 1) / XLEN_BYTES;

    if (got_size !== TEST_MESSAGE_SIZE_WORD) begin
      $error("[%0t] ECHO SIZE MISMATCH got=%0d/0x%0h expected=%0d/0x%0h", $time,
             got_message_byte_count, got_size, TEST_MESSAGE_BYTE_COUNT, TEST_MESSAGE_SIZE_WORD);
      $finish;
    end

    if (got_message_word_count != TEST_MESSAGE_WORD_COUNT) begin
      $error("[%0t] ECHO PAYLOAD WORD COUNT MISMATCH got=%0d expected=%0d", $time,
             got_message_word_count, TEST_MESSAGE_WORD_COUNT);
      $finish;
    end

    $display("[%0t] ECHO SIZE OK: %0d bytes", $time, got_message_byte_count);

    // Then read the message payload words.
    wait_for_ctp_fifo_readable(got_message_word_count, POLL_MAX_ITERS);
    axi_read_uword(CTP_FIFO_DATA_ADDR, got_word0);

    if (got_word0 !== TEST_MESSAGE_WORD0) begin
      $error("[%0t] ECHO PAYLOAD WORD0 MISMATCH got=0x%0h expected=0x%0h", $time, got_word0,
             TEST_MESSAGE_WORD0);
      $finish;
    end

    $display("[%0t] ECHO FRAME OK: size=%0d bytes payload0=0x%0h", $time, got_message_byte_count,
             got_word0);
  endtask

  // ---------------------------------------------------------------------------
  // Reset sequence
  // ---------------------------------------------------------------------------
  initial begin
    reset_rtl = 1'b1;

    repeat (20) @(posedge sys_clock);
    reset_rtl = 1'b0;
  end

  // ---------------------------------------------------------------------------
  // Debug dump
  // ---------------------------------------------------------------------------
  initial begin : debug_dump
    $dumpfile("fifo_debug.vcd");

    // First pass: dump the full TB hierarchy.
    // This can be large, but it is the easiest way to debug hierarchy issues.
    $dumpvars(0, tb_system_firmware);

    // Stop dumping after the useful debug window.
    #450_000ns;
    $dumpoff;
  end

  // ---------------------------------------------------------------------------
  // Main test sequence
  // ---------------------------------------------------------------------------
  initial begin : test_main
    $display("[%0t] Test started", $time);

    wait (reset_rtl == 1'b0);
    $display("[%0t] External reset released", $time);

    wait (DUT.simulation_i.proc_sys_reset_0_peripheral_aresetn == 1'b1);
    $display("[%0t] AXI reset released", $time);

    wait_axi_clk(STARTUP_WAIT_CYCLES);

    mst_agent = new("axi master vip", DUT.simulation_i.axi_vip_0.inst.IF);
    mst_agent.set_agent_tag("Master VIP");
    mst_agent.set_verbosity(XIL_AXI_VERBOSITY_NONE);
    mst_agent.start_master();

    $display("[%0t] AXI VIP master started", $time);

    // -------------------------------------------------------------------------
    // 1) Load complete firmware image while the core is in reset.
    //
    // The firmware memories are RAM-like and can be initialized while the core is
    // held in reset. The PTC/CTP FIFOs, however, are reset together with the core
    // reset path on the target wrapper. Therefore, do not push FIFO payload data
    // before SYS_RESET_BASE is released.
    // -------------------------------------------------------------------------
    axi_write32(SYS_RESET_BASE, 0);
    load_firmware_file(FW_FILE);

    // -------------------------------------------------------------------------
    // 2) Release core/FIFO reset, then let reset synchronizers and XPM FIFO
    // reset-busy signals settle before touching the FIFO register interface.
    // -------------------------------------------------------------------------
    axi_write32(SYS_RESET_BASE, 1);
    $display("[%0t] Core and FIFOs released from reset", $time);
    wait_axi_clk(100);

    // -------------------------------------------------------------------------
    // 3) Write platform-to-core FIFO echo frame: size first, then payload.
    // -------------------------------------------------------------------------
    send_test_payload_to_core_fifo();

    // -------------------------------------------------------------------------
    // 4) Give the core some time before reading the response.
    // -------------------------------------------------------------------------
    wait_axi_clk(EXEC_WAIT_CYCLES);

    // -------------------------------------------------------------------------
    // 5) Read and check the core-to-platform FIFO echo frame: size first, then
    // payload.
    // -------------------------------------------------------------------------
    check_echo_payload_from_core_fifo();

    $display("[%0t] SYSTEM TEST PASS", $time);
    $finish;
  end

endmodule
