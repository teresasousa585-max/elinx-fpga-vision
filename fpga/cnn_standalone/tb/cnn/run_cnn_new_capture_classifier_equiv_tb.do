onbreak {quit -f}
onerror {quit -code 1}

set prj_root [file normalize [pwd]]
if {![info exists ::env(ELINX_LIB)] || $::env(ELINX_LIB) eq ""} {
    puts stderr "ELINX_LIB required"
    quit -code 2
}
set elinx_lib [file normalize $::env(ELINX_LIB)]
set out_dir "$prj_root/sim/out/cnn_new_capture_classifier_equiv"
set lib_name work_cnn_new_capture_classifier_equiv
set lib_dir "$out_dir/$lib_name"
file mkdir $out_dir
if {[file exists $lib_dir]} {
    catch {vdel -lib $lib_name -all}
    catch {file delete -force $lib_dir}
}
vlib $lib_dir
vmap $lib_name $lib_dir

foreach source [list \
    "$elinx_lib/altera_primitives.v" \
    "$elinx_lib/220model.v" \
    "$elinx_lib/stratix_atoms.v" \
    "$elinx_lib/altera_mf.v" \
    "$prj_root/tb/cnn/source_reference/gesture_cnn_weight_rom.v" \
    "$prj_root/tb/cnn/source_reference/gesture_cnn_flat_classifier.v" \
    "$prj_root/rtl/cnn/cnn_weight_rom.v" \
    "$prj_root/rtl/cnn/cnn_flat_classifier.v" \
    "$prj_root/rtl/cnn/cnn_classifier_session_25m.v"] {
    vlog -work $lib_name $source
}
vlog -sv -work $lib_name "$prj_root/tb/cnn/cnn_new_capture_classifier_equiv_tb.sv"

if {[info exists ::env(CNN_MANIFEST)] && $::env(CNN_MANIFEST) ne ""} {
    set manifest [file normalize $::env(CNN_MANIFEST)]
} else {
    set manifest "$prj_root/sim/input/cnn/new_capture_manifest.txt"
}
if {![file exists $manifest]} {
    puts stderr "missing CNN manifest: $manifest"
    quit -code 3
}

vsim -c -l "$out_dir/cnn_new_capture_classifier_equiv.log" \
    -suppress 2685 -suppress 2718 \
    $lib_name.cnn_new_capture_classifier_equiv_tb \
    +MANIFEST=$manifest
run -all
quit -f
