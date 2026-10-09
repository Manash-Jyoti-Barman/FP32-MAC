module fp_norm_pack(
    input clk,
    input rst,
    input start,
    input sign_in,
    input signed [9:0] exp_in,
    input [51:0] mant_in,
    output [31:0] out,
    output done
);
    localparam IDLE = 2'd0, CHECK = 2'd1, ROUND = 2'd2;
    reg [1:0] PS;
    reg sign_r;
    reg signed [9:0] norm_exp;
    reg [51:0] n;
    reg sticky;
    reg [31:0] out_reg;
    reg done_reg;

    assign out = out_reg;
    assign done = done_reg;

    wire [23:0] m = n[51:28];
    wire g  = n[27];
    wire st = sticky | (|n[26:0]);
    wire inc = g & (st | m[0]);
    wire [24:0] mr = {1'b0, m} + {24'd0, inc};

    reg signed [9:0] ef;
    reg [22:0] frac;
    always @(*) begin
        if(mr[24]) begin 
            ef = norm_exp + 10'sd1; 
            frac = 23'd0;    
        end
        else if(mr[23]) begin 
            ef = norm_exp;          
            frac = mr[22:0]; 
        end
        else begin 
            ef = 10'sd0;      
            frac = mr[22:0]; 
        end
    end
    wire overflow = (ef >= 10'sd255);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            PS <= IDLE; 
            sign_r <= 1'b0; 
            norm_exp <= 10'sd0; 
            n <= 52'd0;
            sticky <= 1'b0; 
            out_reg <= 32'd0; 
            done_reg <= 1'b0;
        end else begin
            done_reg <= 1'b0;
            case (PS)
                IDLE: if (start) begin
                    n <= mant_in;  
                    norm_exp <= exp_in + 10'sd1;
                    sign_r <= sign_in;  
                    sticky <= 1'b0;
                    PS <= CHECK;
                end

                CHECK: begin
                    if(n == 52'd0 && !sticky) begin
                        out_reg <= {sign_r, 31'd0};
                        done_reg <= 1'b1;
                        PS <= IDLE;
                    end 
                    else if (norm_exp < 10'sd1) begin
                        if(norm_exp < -10'sd27) begin
                            n <= 52'd0;  
                            sticky <= 1'b1;  
                            norm_exp <= 10'sd1;
                        end else begin
                            n <= n >> 1;
                            sticky <= sticky | n[0];
                            norm_exp <= norm_exp + 10'sd1;
                        end
                    end else if(!n[51] && norm_exp > 10'sd1) begin
                        n <= n << 1;
                        norm_exp <= norm_exp - 10'sd1;
                    end else
                        PS <= ROUND;
                end

                ROUND: begin
                    out_reg  <= overflow ? {sign_r, 8'hFF, 23'd0} : {sign_r, ef[7:0], frac};
                    done_reg <= 1'b1;
                    PS <= IDLE;
                end

                default: PS <= IDLE;
            endcase
        end
    end
endmodule