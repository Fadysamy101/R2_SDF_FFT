vlib work
vlog -f src_files.list +cover -covercells
vsim -voptargs=+acc work.top -classdebug -uvmcontrol=all -cover
add wave -position insertpoint sim:/top/fft_wrapper_test_vif/*
coverage save fft_wrapper_tb.ucdb -onexit
run -all
#vcover report fft_wrapper_tb.ucdb -details -all 