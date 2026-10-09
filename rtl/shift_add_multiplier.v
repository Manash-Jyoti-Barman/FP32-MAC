module shift_add_multiplier (
    input clk,
    input rst,
    input start,
    input [23:0] a,
    input [23:0] b,
    output reg [47:0] product,
    output reg done
);
    reg [47:0] A;
    reg [23:0] B;
    reg [4:0] count;
    reg running;
    always @(posedge clk or posedge rst)
    begin
        if(rst) begin
            A <= 0;
            B <= 0;
            product <= 0;
            count <= 0;
            done <= 0;
            running <= 0;
        end
        
        else if(start && !running) begin
            A <= {24'd0, a};
            B <= b;
            product <= 0;
            count <= 0;
            done <= 0;
            running <= 1;
        end

        else if(running) begin
            if(B[0])
                product <= product + A;
            A <= A << 1;
            B <= B >> 1;
            count <= count + 1;
            if(count == 23) begin
                done <= 1;
                running <= 0;
            end
        end

        else begin
            done <= 0;
        end
    end
endmodule