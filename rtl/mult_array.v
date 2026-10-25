`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// mult_array: registered 4-bit x 4-bit unsigned array multiplier
//
//   a, b  : registered into a_r, b_r on every rising clock edge
//   array : 16 AND gates (partial products) and 12 full adders arranged as
//           three 4-bit ripple-carry rows, built from a_r and b_r
//   p     : 8-bit product, registered on the next rising clock edge
//
//   16 flip-flops in total (4 + 4 + 8), latency = 2 clock cycles.
//   rst_n : asynchronous, active-low reset that clears every register to 0.
//   The * operator is deliberately not used in this file.
// -----------------------------------------------------------------------------
module mult_array (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] a,
    input  wire [3:0] b,
    output reg  [7:0] p
);

    // ------------------------------------------------------------------
    // Input registers (8 flip-flops)
    // ------------------------------------------------------------------
    reg [3:0] a_r, b_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_r <= 4'd0;
            b_r <= 4'd0;
        end else begin
            a_r <= a;
            b_r <= b;
        end
    end

    // ------------------------------------------------------------------
    // Partial products: pp_i[j] = a[j] AND b[i]   (4 x 4 = 16 AND gates)
    // ------------------------------------------------------------------
    wire [3:0] pp0 = a_r & {4{b_r[0]}};
    wire [3:0] pp1 = a_r & {4{b_r[1]}};
    wire [3:0] pp2 = a_r & {4{b_r[2]}};
    wire [3:0] pp3 = a_r & {4{b_r[3]}};

    // ------------------------------------------------------------------
    // Row 0: AND gates only.
    // pp0[0] is already product bit p[0]; the other three bits are passed
    // down to row 1, with a 0 in the top position.
    // ------------------------------------------------------------------
    wire [3:0] r0 = {1'b0, pp0[3], pp0[2], pp0[1]};

    // ------------------------------------------------------------------
    // Rows 1-3: one 4-bit ripple-carry adder per row (4 full adders each).
    // Full adder j of row i adds pp_i[j] + r_(i-1)[j] + c_i[j].
    // c_i[0] = 0 and c_i[j+1] is the carry out of full adder j.
    // ------------------------------------------------------------------
    wire [3:0] s1, s2, s3;      // sum outputs of rows 1, 2, 3
    wire [4:0] c1, c2, c3;      // carry chains of rows 1, 2, 3

    assign c1[0] = 1'b0;
    assign c2[0] = 1'b0;
    assign c3[0] = 1'b0;

    // Bits passed down to the next row: final carry and upper three sums
    wire [3:0] r1 = {c1[4], s1[3], s1[2], s1[1]};
    wire [3:0] r2 = {c2[4], s2[3], s2[2], s2[1]};

    genvar j;
    generate
        for (j = 0; j < 4; j = j + 1) begin : row1
            full_adder fa (.a(pp1[j]), .b(r0[j]), .cin(c1[j]), .sum(s1[j]), .cout(c1[j+1]));
        end
        for (j = 0; j < 4; j = j + 1) begin : row2
            full_adder fa (.a(pp2[j]), .b(r1[j]), .cin(c2[j]), .sum(s2[j]), .cout(c2[j+1]));
        end
        for (j = 0; j < 4; j = j + 1) begin : row3
            full_adder fa (.a(pp3[j]), .b(r2[j]), .cin(c3[j]), .sum(s3[j]), .cout(c3[j+1]));
        end
    endgenerate

    // ------------------------------------------------------------------
    // Product bits:
    //   p[0] = pp0[0], p[1] = s1[0], p[2] = s2[0], p[3] = s3[0],
    //   p[7:4] = {c3[4], s3[3], s3[2], s3[1]}
    // ------------------------------------------------------------------
    wire [7:0] p_next = {c3[4], s3[3], s3[2], s3[1], s3[0], s2[0], s1[0], pp0[0]};

    // ------------------------------------------------------------------
    // Output register (8 flip-flops)
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            p <= 8'd0;
        else
            p <= p_next;
    end

endmodule
