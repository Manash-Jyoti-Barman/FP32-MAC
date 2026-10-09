module fp_adder(
    input clk,
    input rst,
    input start,
    input sign_a,
    input signed [9:0] exp_a,
    input [23:0] mant_a,
    input zero_a,
    input sign_p,
    input signed [9:0] exp_p,
    input [47:0] mant_p,

    output reg sum_sign,
    output reg signed [9:0] sum_exp,
    output reg [51:0] sum_mant,
    output reg done
);
    localparam IDLE = 2'd0, ALIGN = 2'd1, EXEC = 2'd2, DONE = 2'd3;
    reg [1:0] PS;
    reg [50:0] a_aligned, b_aligned;
    wire [50:0] a_extend = zero_a? 51'd0 : {mant_a, 27'd0};
    wire [50:0] b_extend = {mant_p, 3'd0};
    wire signed [10:0] diff = {exp_a[9], exp_a} - {exp_p[9], exp_p};
    wire [10:0] abs_diff  = (diff[10])? (~diff + 11'd1) : diff;

    function [50:0] shr_jam;
        input [50:0] v;
        input [10:0] d;
        reg [50:0] shifted, mask;
        begin
            if(d >= 11'd51) 
            	shr_jam = {50'd0, |v};
            else begin
                shifted = v >> d;
                mask = ~({51{1'b1}} << d);
                shr_jam = {shifted[50:1], shifted[0] | (|(v & mask))};
            end
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            PS <= IDLE; 
            done <= 1'b0;
            a_aligned <= 51'd0; 
            b_aligned <= 51'd0;
            sum_sign <= 1'b0; 
            sum_exp <= 10'sd0; 
            sum_mant <= 52'd0;
        end else begin
            done <= 1'b0;
            case (PS)
                IDLE: if(start) PS <= ALIGN;
                
                ALIGN: begin
                    if(zero_a) begin
                        a_aligned <= 51'd0;          
                        b_aligned <= b_extend;  
                        sum_exp <= exp_p;
                    end 
                    else if(!diff[10]) begin 
                        a_aligned <= a_extend;             
                        b_aligned <= shr_jam(b_extend, abs_diff); 
                        sum_exp <= exp_a;
                    end 
                    else begin 
                        a_aligned <= shr_jam(a_extend, abs_diff); 
                        b_aligned <= b_extend;  
                        sum_exp <= exp_p;
                    end
                    PS <= EXEC;
                end

                EXEC: begin
                    if(sign_a == sign_p) begin
                        sum_mant <= {1'b0, a_aligned} + {1'b0, b_aligned};
                        sum_sign <= sign_a;
                    end 
                    else if(a_aligned >= b_aligned) begin
                        sum_mant <= {1'b0, a_aligned} - {1'b0, b_aligned};
                        sum_sign <= (a_aligned == b_aligned) ? 1'b0 : sign_a;
                    end 
                    else begin
                        sum_mant <= {1'b0, b_aligned} - {1'b0, a_aligned};
                        sum_sign <= sign_p;
                    end
                    PS <= DONE;
                end

                DONE: begin
                    done <= 1'b1; 
                    PS <= IDLE;
                end
            endcase
        end
    end
endmodule
