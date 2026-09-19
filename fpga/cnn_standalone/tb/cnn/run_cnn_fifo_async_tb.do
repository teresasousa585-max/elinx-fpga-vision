onbreak {quit -f}
onerror {quit -code 1}

set prj_root [file normalize [pwd]]
if {![info exists ::env(ELINX_LIB)] || $::env(ELINX_LIB) eq ""} {
    puts stderr "ELINX_LIB must name the official eLinx simulation library"
    quit -code 2
}
set elinx_lib [file normalize $::env(ELINX_LIB)]
set out_dir "$prj_root/sim/out/cnn_fifo_async"
set lib_name work_cnn_fifo_async
set lib_dir "$out_dir/$lib_name"
set log_file "$out_dir/cnn_fifo_async.log"

foreach required [list \
    "$elinx_lib/altera_primitives.v" "$elinx_lib/220model.v" \
    "$elinx_lib/stratix_atoms.v" "$elinx_lib/altera_mf.v" \
    "$prj_root/hdmi_1280x720.srcs/sources_1/ip/fifo_data/fifo_data.v" \
    "$prj_root/rtl/cnn/cnn_fifo_pop.v" \
    "$prj_root/tb/cnn/cnn_fifo_async_tb.sv"] {
    if {![file exists $required]} {
        puts stderr "required simulation input is missing: $required"
        quit -code 2
    }
}

file mkdir $out_dir
if {[file exists $lib_dir]} {
    catch {vdel -lib $lib_name -all}
    catch {file delete -force $lib_dir}
}
vlib $lib_dir
vmap $lib_name $lib_dir
vlog -work $lib_name "$elinx_lib/altera_primitives.v"
vlog -work $lib_name "$elinx_lib/220model.v"
vlog -work $lib_name "$elinx_lib/stratix_atoms.v"
vlog -work $lib_name "$elinx_lib/altera_mf.v"
vlog -work $lib_name "$prj_root/hdmi_1280x720.srcs/sources_1/ip/fifo_data/fifo_data.v"
vlog -work $lib_name "$prj_root/rtl/cnn/cnn_fifo_pop.v"
vlog -work $lib_name -sv "$prj_root/tb/cnn/cnn_fifo_async_tb.sv"
vsim -c -l $log_file -suppress 2685 -suppress 2718 $lib_name.cnn_fifo_async_tb
run -all
quit -f
