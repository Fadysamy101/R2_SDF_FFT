import fft_wrapper_test_pkg::*;
import uvm_pkg::*;
`include "uvm_macros.svh"
module top ();
    bit clk ;
    initial begin
        forever begin
            #10;
            clk=!clk;
        end
    end
    fft_wrapper_inter fft_wrapper_test_vif(clk);
    fft_wrapper dut (/*put your variables*/);
    bind fft_wrapper sva sva_inst(/*put your variables*/);
    initial begin
    uvm_config_db#(virtual fft_wrapper_inter)::set(null,"*","fft_wrapper_test_vif",fft_wrapper_test_vif);
    run_test("fft_wrapper_test");
    end

endmodule