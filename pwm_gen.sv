// Description : Design of PWM Generator
// Owner : Soham Sen
// Date : 25/04/2026

module pwm_gen #(
    parameter PWM_BITS  = 8,        // Resolution: 2^PWM_BITS levels (0-255 for 8-bit)
    parameter PRESCALER = 1         // Clock divider: PWM freq = clk / (PRESCALER * 2^PWM_BITS)
)(
    input  wire                 clk,        // System clock
    input  wire                 rst_n,      // Active-low asynchronous reset
    input  wire                 en,         // PWM enable (output LOW when disabled)
    input  wire [PWM_BITS-1:0]  duty_in,    // Desired duty cycle (0 = 0%, all-1s = ~100%)
    output reg                  pwm_out     // PWM output
);

    // ---------- Internal registers ----------
    reg [PWM_BITS-1:0] counter;         // Free-running PWM counter
    reg [PWM_BITS-1:0] duty_buf;        // Double-buffered duty value
    reg [15:0]         pre_cnt;         // Prescaler counter

    wire tick = (pre_cnt == PRESCALER - 1);   // One-clock pulse every PRESCALER cycles

    // ---------- Prescaler ----------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pre_cnt <= 16'd0;
        else if (tick)
            pre_cnt <= 16'd0;
        else
            pre_cnt <= pre_cnt + 1'b1;
    end

    // ---------- PWM counter ----------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter  <= {PWM_BITS{1'b0}};
            duty_buf <= {PWM_BITS{1'b0}};
        end else if (tick) begin
            if (counter == {PWM_BITS{1'b1}}) begin
                counter  <= {PWM_BITS{1'b0}};
                duty_buf <= duty_in;            // Latch new duty at period boundary
            end else begin
                counter <= counter + 1'b1;
            end
        end
    end

    // ---------- Comparator — generate PWM output ----------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_out <= 1'b0;
        else if (!en)
            pwm_out <= 1'b0;
        else
            pwm_out <= (counter < duty_buf);
    end

endmodule
