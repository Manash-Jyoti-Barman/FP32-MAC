module fp_multiplier(
    input clk,
    input rst,
    input start,
    input sign_a, sign_b,
    input signed [9:0] exp_a, exp_b,
    input [23:0] mant_a, mant_b,
    output sign_p,
    output signed [9:0] exp_p,
    output [47:0] mant_p,
    output done
);
    wire [47:0] mult_result;
    wire top = mult_result[47];
    
    shift_add_multiplier SAM (clk, rst, start, mant_a, mant_b, mult_result, done);

    assign sign_p = sign_a ^ sign_b;
    assign mant_p = top? mult_result : (mult_result << 1);
    assign exp_p = exp_a + exp_b - 10'sd127 + (top ? 10'sd1 : 10'sd0);
endmodule