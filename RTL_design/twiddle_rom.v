
`timescale 1ns / 1ps
`default_nettype none
module twiddle_rom #(
    parameter DEPTH = 8,
    parameter AW    = 3,
    parameter CW    = 16
)(
    input  wire [AW-1:0]       addr,
    output reg  signed [CW-1:0] w_re,
    output reg  signed [CW-1:0] w_im
);

    always @(*) begin
        w_re = 0;
        w_im = 0;

        if (DEPTH == 8) begin
            // Stage 1: W_16^k, k = 0..7
             case (addr)
            3'd0: begin
                w_re = 16'sb01_00000000000000;   // +1
                w_im = 16'sb00_00000000000000;
            end
            3'd1: begin
                w_re = 16'sb00_11101100100001;   // +0.9239
                w_im = 16'sb11_10011110000010;   // -0.3827
            end
            3'd2: begin
                w_re = 16'sb00_10110101000001;   // +0.7071
                w_im = 16'sb11_01001010111111;   // -0.7071
            end
            3'd3: begin
                w_re = 16'sb00_01100001111110;   // +0.3827
                w_im = 16'sb11_00010011011111;   // -0.9239
            end
            3'd4: begin
                w_re = 16'sb00_00000000000000;
                w_im = 16'sb11_00000000000000;   // -j
            end
            3'd5: begin
                w_re = 16'sb11_10011110000010;   // -0.3827
                w_im = 16'sb11_00010011011111;   // -0.9239
            end
            3'd6: begin
                w_re = 16'sb11_01001011011111;   // -0.7071
                w_im = 16'sb11_01001011011111;   // -0.7071
            end
            3'd7: begin
                w_re = 16'sb11_00010011011111;   // -0.9239
                w_im = 16'sb11_10011110000010;   // -0.3827
            end
            default: begin
                w_re = 16'sb01_00000000000000;
                w_im = 16'sb00_00000000000000;
            end
        endcase
        end
    else if (DEPTH == 4) begin
            // Stage 2: W8^k, k = 0..3
            case (addr)
                2'd0: begin
                    w_re = 16'sb01_00000000000000;   // +1.0000
                    w_im = 16'sb00_00000000000000;   // +0.0000
                end

                2'd1: begin
                    w_re = 16'sb00_10110101000001;   // +0.7071
                    w_im = 16'sb11_01001010111111;   // -0.7071
                end

                2'd2: begin
                    w_re = 16'sb00_00000000000000;   // +0.0000
                    w_im = 16'sb11_00000000000000;   // -1.0000 (-j)
                end

                2'd3: begin
                    w_re = 16'sb11_01001010111111;   // -0.7071
                    w_im = 16'sb11_01001010111111;   // -0.7071
                end

                default: begin
                    w_re = 16'sb01_00000000000000;
                    w_im = 16'sb00_00000000000000;
                end
            endcase
        end
        else begin
            // Stages 3 and 4 never read a coefficient
            w_re = 16'sb01_00000000000000;   // +1.0000
            w_im = 16'sb00_00000000000000;   // +0.0000
        end
    end

endmodule
