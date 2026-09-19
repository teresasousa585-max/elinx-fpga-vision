onerror {quit -code 1}
set r [file normalize [pwd]]
set o "$r/sim/out/cnn_feature_backpressure"
set l work_cnn_feature_backpressure
file mkdir $o
if {[file exists "$o/$l"]} { catch {vdel -lib $l -all}; catch {file delete -force "$o/$l"} }
vlib "$o/$l"
vmap $l "$o/$l"
vlog -work $l "$r/rtl/cnn/cnn_feature_32x32.v"
vlog -work $l -sv "$r/tb/cnn/cnn_feature_backpressure_tb.sv"
vsim -c -l "$o/cnn_feature_backpressure.log" $l.cnn_feature_backpressure_tb
run -all
quit -f
