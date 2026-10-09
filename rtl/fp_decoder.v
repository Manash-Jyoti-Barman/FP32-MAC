module fp_decoder(
    input [31:0] number,
    output sign,
    output signed [9:0] exponent,
    output [23:0] mantissa,
    output is_zero,
    output is_inf,
    output is_nan
);
    wire [7:0] exp_field = number[30:23];
    wire [22:0] fraction = number[22:0];
    wire [23:0] fraction24 = {1'b0, fraction};
    wire exp_zero = (exp_field == 8'd0);
    wire exp_ones = (exp_field == 8'hFF);
    wire frac_zero = (fraction == 23'd0);

    assign sign = number[31];
    assign is_zero = exp_zero & frac_zero;
    assign is_inf = exp_ones & frac_zero;
    assign is_nan = exp_ones & ~frac_zero;

    reg [4:0] lead_zero;
    reg found;
    integer i;
    always @(*) begin
        lead_zero = 5'd0;
        found = 1'b0;
        for(i = 23; i >= 0; i = i - 1)
            if(!found) begin
                if (fraction24[i]) found = 1'b1;
                else lead_zero = lead_zero + 5'd1;
            end
    end
    assign exponent = exp_zero ? (10'sd1 - $signed({5'b0, lead_zero})) : $signed({2'b00, exp_field});
    assign mantissa = exp_zero? (fraction24 << lead_zero) : {1'b1, fraction};
endmodule