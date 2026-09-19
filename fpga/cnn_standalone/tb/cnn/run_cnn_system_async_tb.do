onbreak {quit -f}
onerror {quit -code 1}
set prj_root [file normalize [pwd]]
if {![info exists ::env(ELINX_LIB)] || $::env(ELINX_LIB) eq ""} {puts stderr "ELINX_LIB required";quit -code 2}
set elinx_lib [file normalize $::env(ELINX_LIB)];set out_dir "$prj_root/sim/out/cnn_system_async";set lib_name work_cnn_system_async;set lib_dir "$out_dir/$lib_name";file mkdir $out_dir
if {[file exists $lib_dir]} {catch {vdel -lib $lib_name -all};catch {file delete -force $lib_dir}}
vlib $lib_dir;vmap $lib_name $lib_dir
foreach f [list "$elinx_lib/altera_primitives.v" "$elinx_lib/220model.v" "$elinx_lib/stratix_atoms.v" "$elinx_lib/altera_mf.v" "$prj_root/hdmi_1280x720.srcs/sources_1/ip/fifo_data/fifo_data.v"] {vlog -work $lib_name $f}
foreach f [lsort [glob -nocomplain "$prj_root/rtl/cnn/*.v"]] {vlog -work $lib_name $f}
vlog -work $lib_name -sv "$prj_root/tb/cnn/cnn_system_async_tb.sv"
set cnn_sample "$prj_root/new_capture/1/raw8_digit_1_20260622_153700_344_0000.raw"
vsim -c -l "$out_dir/cnn_system_async.log" -suppress 2685 -suppress 2718 +CNN_SAMPLE=$cnn_sample $lib_name.cnn_system_async_tb
run -all
quit -f
