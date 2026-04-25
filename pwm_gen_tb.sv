// Description : Verification of PWM Generator
// Owner : Soham Sen
// Date : 25/04/2026

module pwm_gen_tb;

    // -------- Parameters --------
    parameter PWM_BITS  = 8;
    parameter PRESCALER = 1;
    localparam PERIOD   = (1 << PWM_BITS);   // 256 ticks per PWM cycle

    // Half-period for 100 MHz clock = 5 ns
    localparam HALF_CLK = 5;

    // -------- DUT signals --------
    reg                     clk;
    reg                     rst_n;
    reg                     en;
    reg  [PWM_BITS-1:0]     duty_in;
    wire                    pwm_out;

    // -------- Instantiate DUT --------
    pwm_gen #(
        .PWM_BITS  (PWM_BITS),
        .PRESCALER (PRESCALER)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .en      (en),
        .duty_in (duty_in),
        .pwm_out (pwm_out)
    );

    // -------- Clock generation --------
    initial clk = 0;
    always #(HALF_CLK) clk = ~clk;

    // -------- Test tracking --------
    integer pass_count = 0;
    integer fail_count = 0;

    // ======= Task: measure duty cycle over one full PWM period =======
    // Counts how many of PERIOD ticks pwm_out is HIGH.
    // Allows +/-2 tick tolerance for pipeline delay.
    task automatic measure_duty;
        input [PWM_BITS-1:0] expected_duty;
        integer high_cnt;
        integer i;
        integer diff;
        begin
            high_cnt = 0;

            // Wait for counter wrap (start of new period) —
            // detected by observing pwm_out transition after letting current
            // period complete. We simply wait one full period + margin.
            repeat (PERIOD + 4) @(posedge clk);

            // Now sample for exactly one period
            for (i = 0; i < PERIOD; i = i + 1) begin
                @(posedge clk);
                if (pwm_out) high_cnt = high_cnt + 1;
            end

            diff = high_cnt - expected_duty;
            if (diff < 0) diff = -diff;

            if (diff <= 2) begin
                $display("[PASS] duty_in=%0d  measured_high=%0d  (tolerance OK)  @ %0t",
                         expected_duty, high_cnt, $time);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] duty_in=%0d  measured_high=%0d  (diff=%0d > 2)  @ %0t",
                         expected_duty, high_cnt, diff, $time);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ======= Main stimulus ========
    initial begin
        $dumpfile("pwm_gen_tb.vcd");
        $dumpvars(0, pwm_gen_tb);

        rst_n   = 1'b0;
        en      = 1'b0;
        duty_in = 8'd0;

        // ---- Reset ----
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        // ---- Test 1: output LOW when disabled ----
        $display("\n=== Test 1: PWM disabled ===");
        en      = 1'b0;
        duty_in = 8'd128;
        repeat (PERIOD + 10) @(posedge clk);
        if (pwm_out === 1'b0) begin
            $display("[PASS] pwm_out LOW when en=0  @ %0t", $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] pwm_out should be LOW when en=0  @ %0t", $time);
            fail_count = fail_count + 1;
        end

        // ---- Enable PWM ----
        en = 1'b1;

        // ---- Test 2: 0% duty (duty_in = 0) ----
        $display("\n=== Test 2: 0%% duty ===");
        duty_in = 8'd0;
        measure_duty(8'd0);

        // ---- Test 3: 25% duty ----
        $display("\n=== Test 3: 25%% duty ===");
        duty_in = 8'd64;
        measure_duty(8'd64);

        // ---- Test 4: 50% duty ----
        $display("\n=== Test 4: 50%% duty ===");
        duty_in = 8'd128;
        measure_duty(8'd128);

        // ---- Test 5: 75% duty ----
        $display("\n=== Test 5: 75%% duty ===");
        duty_in = 8'd192;
        measure_duty(8'd192);

        // ---- Test 6: ~100% duty (duty_in = 255) ----
        $display("\n=== Test 6: ~100%% duty ===");
        duty_in = 8'd255;
        measure_duty(8'd255);

        // ---- Test 7: mid-period duty change (glitch-free) ----
        $display("\n=== Test 7: mid-period duty change ===");
        duty_in = 8'd64;
        repeat (PERIOD / 2) @(posedge clk);   // Wait half a period
        duty_in = 8'd192;                       // Change mid-period
        // The double-buffer should apply 192 only on the NEXT period
        measure_duty(8'd192);

        // ---- Test 8: disable mid-operation ----
        $display("\n=== Test 8: disable mid-operation ===");
        duty_in = 8'd128;
        repeat (PERIOD + 10) @(posedge clk);
        en = 1'b0;
        repeat (10) @(posedge clk);
        if (pwm_out === 1'b0) begin
            $display("[PASS] pwm_out goes LOW after disable  @ %0t", $time);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] pwm_out should be LOW after disable  @ %0t", $time);
            fail_count = fail_count + 1;
        end

        // ---- Test 9: re-enable ----
        $display("\n=== Test 9: re-enable with 50%% duty ===");
        en      = 1'b1;
        duty_in = 8'd128;
        measure_duty(8'd128);

        // ---- Summary ----
        $display("\n============================================");
        $display("  TEST SUMMARY : %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("============================================");
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***");
        else
            $display("  *** SOME TESTS FAILED ***");
        $display("============================================\n");

        #100;
        $finish;
    end

    // ---- Timeout watchdog ----
    initial begin
        #50_000_000;
        $display("[TIMEOUT] Simulation exceeded time limit!");
        $finish;
    end
  
    initial begin
      $dumpfile("dump.vcd");
      $dumpvars;
    end

endmodule
