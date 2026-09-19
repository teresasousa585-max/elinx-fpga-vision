onbreak {quit -f}
onerror {quit -code 1}
set prj_root [file normalize [pwd]]
set out_dir "$prj_root/sim/out/cnn_feature_collision"
set lib_name work_cnn_feature_collision
set lib_dir "$out_dir/$lib_name"
file mkdir $out_dir
if {[file exists $lib_dir]} {
    catch {vdel -lib $lib_name -all}
    catch {file delete -force $lib_dir}
}
vlib $lib_dir
vmap $lib_name $lib_dir
vlog -work $lib_name "$prj_root/rtl/cnn/cnn_feature_32x32.v"
vlog -work $lib_name -sv "$prj_root/tb/cnn/cnn_feature_collision_tb.sv"
vsim -c -l "$out_dir/cnn_feature_collision.log" $lib_name.cnn_feature_collision_tb
run -all
quit -f
