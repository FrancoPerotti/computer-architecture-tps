`timescale 1ns / 1ps

// Comprueba la frontera de plataforma con fuentes y un consumidor controlados.
module basys3_top_tb #(
    parameter system_pkg::memory_profile_t MEMORY_PROFILE = system_pkg::REFERENCE
);
  bit  clk_100mhz;
  bit  reset_btn;
  bit  uart_rx = 1;
  wire uart_tx;
  wire clk = dut.gen_supported_profile.clk;
  wire locked = dut.gen_supported_profile.locked;
  wire reset = dut.gen_supported_profile.system.reset;
  wire active = dut.gen_supported_profile.system.functional_operation;
  wire wizard_reset = dut.gen_supported_profile.clock_wizard.reset;
  wire uart_reset_request = dut.gen_supported_profile.uart_reset_request;

  always #5 clk_100mhz = !clk_100mhz;

  basys3_top #(
      .MEMORY_PROFILE(MEMORY_PROFILE)
  ) dut (
      .clk_100mhz_i(clk_100mhz),
      .reset_btn_i (reset_btn),
      .uart_rx_i   (uart_rx),
      .uart_tx_o   (uart_tx)
  );

  tp3_case_data data ();

  task automatic require(input bit condition, input string reason);
    if (!condition) begin
      $display("FAIL %s %s", data.case_id, reason);
      $fatal(1, "%s", reason);
    end
  endtask

  task automatic check_release;
    require(reset === 1'b1, "reset released between edges");
    @(posedge clk);
    #1;
    require(reset === 1'b1 && active === 1'b0, "reset released on first edge");
    @(posedge clk);
    #1;
    require(reset === 1'b0 && active === 1'b0, "reset did not release on second edge");
    @(posedge clk);
    #1;
    require(active === 1'b1, "consumer did not start after release");
  endtask

  task automatic check_clock(input time expected_period);
    time first_edge;
    @(posedge clk);
    first_edge = $time;
    @(negedge clk);
    require($time - first_edge == expected_period / 2, "functional clock duty cycle");
    @(posedge clk);
    require($time - first_edge == expected_period, "functional clock period");
  endtask

  task automatic set_source(input string source, input bit asserted);
    if (source == "button") reset_btn = asserted;
    else if (source == "UART") dut.gen_supported_profile.system.injected_request = asserted;
    else if (source == "not_locked")
      dut.gen_supported_profile.clock_wizard.lock_available = !asserted;
    else require(0, "unknown reset source");
  endtask

  initial begin
    string event_name;
    string hold_source;
    string release_source;
    data.load();

    if (!data.has_path("/inputs/profile")) begin
      $dumpfile("platform.vcd");
      $dumpvars(1, basys3_top_tb);
    end

    #1;
    require(reset === 1'b1 && active === 1'b0, "startup without reset");
    if (data.has_path("/inputs/profile")) begin
      require(dut.gen_supported_profile.system.IMEM_CAPACITY_BYTES === $unsigned(
              data.get_integer("/inputs/IMEM_C")), "IMEM capacity at system_top");
      require(dut.gen_supported_profile.system.DMEM_CAPACITY_BYTES === $unsigned(
              data.get_integer("/inputs/DMEM_C")), "DMEM capacity at system_top");
    end else if (data.has_path("/inputs/event")) begin
      event_name = data.get_string("/inputs/event");
      check_clock(64'd1000000000 / data.get_integer("/inputs/functional_clock_Hz"));
      #2;
      require(locked === 1'b0 && reset === 1'b1 && active === 1'b0 && wizard_reset === 1'b0,
              "startup did not wait for locked or reset was fed back to the Wizard");
      set_source("not_locked", 0);
      #1;
      check_release();
      if (event_name == "startup-lock") begin
        uart_rx = 0;
        #1;
        require(dut.gen_supported_profile.system.serial_rx === 1'b0 && uart_tx === 1'b0,
                "UART ports are not connected through the wrapper");
      end else if (event_name == "button-release") begin
        set_source("button", 1);
        #1;
        require(reset === 1'b1 && wizard_reset === 1'b1 && active === 1'b1,
                "button did not assert both resets asynchronously");
        set_source("not_locked", 1);
        #(1000 * data.get_integer("/inputs/button_min_hold_us"));
        require(clk === 1'b0 && reset === 1'b1, "button did not hold reset without clock edges");
        set_source("button", 0);
        repeat (3) @(negedge clk);
        require(reset === 1'b1 && wizard_reset === 1'b0, "released button bypassed locked");
        set_source("not_locked", 0);
        #1;
        check_release();
      end else if (event_name == "loss-of-lock") begin
        set_source("not_locked", 1);
        #1;
        require(reset === 1'b1 && wizard_reset === 1'b0 && active === 1'b1,
                "loss of lock did not assert only the common reset asynchronously");
        repeat (3) @(negedge clk);
        require(reset === 1'b1 && active === 1'b0, "consumer operated without locked");
        set_source("not_locked", 0);
        #1;
        check_release();
      end else if (event_name == "UART-reset") begin
        dut.gen_supported_profile.system.response_done_tick = 1;
        #1;
        require(reset === 1'b0, "reset asserted before registered UART request");
        @(posedge clk);
        #1;
        dut.gen_supported_profile.system.response_done_tick = 0;
        require(reset === 1'b1 && wizard_reset === 1'b0 && active === 1'b1,
                "UART request did not assert only common reset");
        @(posedge clk);
        #1;
        require(uart_reset_request === 1'b0 && active === 1'b0,
                "consumer did not clear UART request on the next edge");
        check_release();
      end else require(0, "unknown platform event");
    end else begin
      release_source = data.get_string("/inputs/release_source");
      hold_source = data.get_string("/inputs/hold_source");
      dut.gen_supported_profile.clock_wizard.independent_sources = 1;
      set_source("not_locked", 0);
      #1;
      check_release();
      set_source(release_source, 1);
      set_source(hold_source, 1);
      @(negedge clk);
      set_source(release_source, 0);
      repeat (3) @(negedge clk);
      require(reset === data.get_boolean("/expected/functional_reset_still_asserted"
              ) && active === 1'b0, "a remaining source failed to hold reset");
      require(wizard_reset === (hold_source == "button"), "unexpected Wizard reset source");
      set_source(hold_source, 0);
      #1;
      check_release();
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule

// Se elabora sin modelos de Clocking Wizard ni de system_top.
module basys3_top_invalid_tb;
  string case_id;

  basys3_top #(
      .MEMORY_PROFILE(32'hffffffff)
  ) dut (
      .clk_100mhz_i(1'b0),
      .reset_btn_i (1'b0),
      .uart_rx_i   (1'b1),
      .uart_tx_o   ()
  );

  initial begin
    #1;
    $finish;
  end

  final begin
    if ($value$plusargs("CASE=%s", case_id)) $display("REJECT %s CONFIG_UNSUPPORTED", case_id);
  end
endmodule
