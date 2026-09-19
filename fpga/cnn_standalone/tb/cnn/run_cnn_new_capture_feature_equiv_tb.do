onbreak {quit -f}
onerror {quit -code 1}
set prj_root [file normalize [pwd]]
set out_dir "$prj_root/sim/out/cnn_new_capture_feature_equiv"
set lib_name work_cnn_new_capture_feature_equiv
set lib_dir "$out_dir/$lib_name"
file mkdir $out_dir
if {[file exists $lib_dir]} {
    catch {vdel -lib $lib_name -all}
    catch {file delete -force $lib_dir}
}
vlib $lib_dir
vmap $lib_name $lib_dir
vlog -work $lib_name "$prj_root/rtl/cnn/cnn_feature_32x32.v"
vlog -sv -work $lib_name "$prj_root/tb/cnn/cnn_new_capture_feature_equiv_tb.sv"
if {[info exists ::env(CNN_MANIFEST)] && $::env(CNN_MANIFEST) ne ""} {
    set manifest [file normalize $::env(CNN_MANIFEST)]
} else {
    set manifest "$prj_root/sim/input/cnn/new_capture_smoke_manifest.txt"
}
if {![file exists $manifest]} {
    puts stderr "missing CNN manifest: $manifest"
    quit -code 3
}
vsim -c -l "$out_dir/cnn_new_capture_feature_equiv.log" \
    $lib_name.cnn_new_capture_feature_equiv_tb +MANIFEST=$manifest
run -all
quit -f
