module fp_mac(
    input clk,
    input rst,
    input start,
    input acc_clear,
    input [31:0] a,
    input [31:0] b,
    output reg [31:0] acc,
    output reg done
);
    localparam IDLE = 3'd0, CHECK = 3'd1, MUL = 3'd2, ADD = 3'd3, NORM = 3'd4, DONE = 3'd5;
    reg [2:0] PS;

    reg [31:0] a_reg, b_reg;
    reg mul_start, add_start, norm_start;
    reg p_sign;
    reg signed [9:0] p_exp;
    reg [47:0] p_mant;

    wire a_sign, b_sign, acc_sign;
    wire signed [9:0] a_exp, b_exp, acc_exp;
    wire [23:0] a_mant, b_mant, acc_mant;
    wire a_zero, a_inf, a_nan, b_zero, b_inf, b_nan, c_zero, c_inf, c_nan;

    fp_decoder DECA (a_reg, a_sign, a_exp, a_mant, a_zero, a_inf, a_nan);
    fp_decoder DECB (b_reg, b_sign, b_exp, b_mant, b_zero, b_inf, b_nan);
    fp_decoder DECC (acc, acc_sign, acc_exp, acc_mant, c_zero, c_inf, c_nan);

    wire prod_sign = a_sign ^ b_sign;
    wire prod_zero = a_zero | b_zero;
    wire prod_inf = (a_inf | b_inf) & ~(a_nan | b_nan) & ~((a_inf & b_zero) | (b_inf & a_zero));
    wire invalid = a_nan | b_nan | c_nan | (a_inf & b_zero) | (b_inf & a_zero) | (prod_inf & c_inf & (prod_sign != acc_sign));
    reg bypass;
    reg [31:0] bypass_val;
    always @(*) begin
        bypass= 1'b1;
        bypass_val = 32'd0;
        if(invalid) bypass_val = 32'h7FC00000;
        else if(prod_inf) bypass_val = {prod_sign, 8'hFF, 23'd0};
        else if(c_inf) bypass_val = acc;
        else if(prod_zero) begin
            if(c_zero) bypass_val = {prod_sign & acc_sign, 31'd0};
            else bypass_val = acc;
        end 
        else bypass = 1'b0;
    end

    wire mul_done, add_done, norm_done;
    wire m_sign;
    wire signed [9:0] m_exp;
    wire [47:0] m_mant;
    wire s_sign;
    wire signed [9:0] s_exp;
    wire [51:0] s_mant;
    wire [31:0] norm_out;

    fp_multiplier MUL0 (clk, rst, mul_start, a_sign, b_sign, a_exp, b_exp, a_mant, b_mant, m_sign, m_exp, m_mant, mul_done);
    fp_adder ADD0 (clk, rst, add_start, acc_sign, acc_exp, acc_mant, c_zero, p_sign, p_exp, p_mant, s_sign, s_exp, s_mant, add_done);
    fp_norm_pack NORM0 (clk, rst, norm_start, s_sign, s_exp, s_mant, norm_out, norm_done);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            PS <= IDLE; 
            acc <= 32'd0; 
            done <= 1'b0;
            a_reg <= 32'd0; 
            b_reg <= 32'd0;
            mul_start <= 1'b0; 
            add_start <= 1'b0; 
            norm_start <= 1'b0;
            p_sign <= 1'b0; 
            p_exp <= 10'sd0; 
            p_mant <= 48'd0;
        end else begin
            done <= 1'b0;  
            mul_start <= 1'b0;  
            add_start <= 1'b0;  
            norm_start <= 1'b0;
            case (PS)
                IDLE, DONE: begin
                    PS <= IDLE;
                    if(acc_clear)
                        acc <= 32'd0;
                    else if(start) begin
                        a_reg <= a;  
                        b_reg <= b;
                        PS <= CHECK;
                    end
                end

                CHECK: begin
                    if(bypass) begin
                        acc <= bypass_val;
                        done <= 1'b1;
                        PS <= DONE;
                    end else begin
                        mul_start <= 1'b1;
                        PS <= MUL;
                    end
                end

                MUL: if(mul_done) begin
                    p_sign<= m_sign;
                    p_exp <= m_exp;
                    p_mant <= m_mant;
                    add_start <= 1'b1;
                    PS <= ADD;
                end

                ADD: if(add_done) begin
                    norm_start <= 1'b1;
                    PS <= NORM;
                end

                NORM: if(norm_done) begin
                    acc <= norm_out;
                    done <= 1'b1;
                    PS <= DONE;
                end
                default: PS <= IDLE;
            endcase
        end
    end
endmodule