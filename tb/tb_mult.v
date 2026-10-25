`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// tb_mult: exhaustive, self-checking testbench for mult_array
//   - 10 ns clock; rst_n is held low for the first 2 clock cycles
//   - applies all 256 (a, b) combinations, a new one every 2 clock cycles
//   - waits for the 2-cycle latency, then compares p with a * b
//   - prints one line per mismatch and exactly one summary line at the end
//   - writes the waveform file mult.vcd
// Only the ports of mult_array are used, so the same testbench also runs
// unchanged on the gate-level netlist from Yosys (Part B).
//
// Timing: vector k (k = 16*a + b) is applied at t = 20 + 20k ns (a falling
// edge), captured at t = 25 + 20k ns (edge 1), the product is registered at
// t = 35 + 20k ns (edge 2) and checked at t = 40 + 20k ns.
// -----------------------------------------------------------------------------
module tb_mult;

    reg        clk;
    reg        rst_n;
    reg  [3:0] a;
    reg  [3:0] b;
    wire [7:0] p;

    reg  [7:0] expected;
    integer    i, j;
    integer    vectors;
    integer    errors;

    // Device under test
    mult_array dut (
        .clk   (clk),
        .rst_n (rst_n),
        .a     (a),
        .b     (b),
        .p     (p)
    );

    // 10 ns clock: rising edges at 5, 15, 25, ... ns
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Waveform file
    initial begin
        $dumpfile("mult.vcd");
        $dumpvars(0, tb_mult);
    end

    // Stimulus and checking
    initial begin
        vectors = 0;
        errors  = 0;
        a       = 4'd0;
        b       = 4'd0;

        // Hold reset low for the first 2 clock cycles
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // Inputs change on falling edges, half a cycle away from the rising
        // edges where the registers sample them, so there are no races.
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                a = i[3:0];
                b = j[3:0];
                @(posedge clk);          // edge 1: a, b captured by the input registers
                @(posedge clk);          // edge 2: product captured by the output register
                @(negedge clk);          // check half a cycle later
                expected = {4'd0, a} * {4'd0, b};   // * is allowed in the testbench only
                vectors  = vectors + 1;
                if (p !== expected) begin
                    errors = errors + 1;
                    $display("MISMATCH at %0t ns: a = %0d, b = %0d, expected p = %0d, got p = %0d",
                             $time, a, b, expected, p);
                end
            end
        end

        if (errors == 0)
            $display("PASS: %0d vectors checked, 0 errors", vectors);
        else
            $display("FAIL: %0d vectors checked, %0d errors", vectors, errors);

        $finish;
    end

endmodule
