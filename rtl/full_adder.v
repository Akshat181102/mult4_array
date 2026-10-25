`timescale 1ns / 1ps
// -----------------------------------------------------------------------------
// full_adder: 1-bit full adder
//   sum  = a XOR b XOR cin        (1 when an odd number of inputs are 1)
//   cout = majority(a, b, cin)    (1 when at least two inputs are 1)
// -----------------------------------------------------------------------------
module full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout
);

    assign sum  = a ^ b ^ cin;
    assign cout = (a & b) | (a & cin) | (b & cin);

endmodule
