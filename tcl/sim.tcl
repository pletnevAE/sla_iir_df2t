set user_args $argv
set build_dir [file normalize [lindex $user_args 0]]
cd $build_dir

#=====================================================================================
# Initializing libraries
#=====================================================================================
if {![file exists "work"]} {
	vlib work
}
vmap work work

#=====================================================================================
# Script parameters
#=====================================================================================
set tcl_dir [file dirname [file normalize [info script]]] ;# tcl-scripts directory
set project_root [file dirname $tcl_dir] ;# directory above script directory
set rtl_dir [file join $project_root "rtl"] ;# directory with HDL files
set tb_dir [file join $project_root "tb"] ;# directory with constraints files

puts "\[INFO\] Modelsim: RTL Compilation..."

#=====================================================================================
# Compiling, setting parameters and running the simulation without visualization
#=====================================================================================
if {[catch {
;#------------------------------------------------------------------------------------
# Compiling RTL and testbench
	#vlog -work work [file join $rtl_dir "*.v"]
	#vlog -work work [file join $build_dir "*.vh"]
	vlog -work work [file join $rtl_dir "*.sv"]
	vlog -work work [file join $tb_dir "*.sv"]

;#------------------------------------------------------------------------------------
# Setting testbench parameters
	set g_flags ""
	set param_args [lrange $user_args 1 end]

	if {[llength $param_args] > 0} {
		foreach {flag p_val} $param_args {
			if {[string match "-*" $flag]} {
				set p_name [string range $flag 1 end]
				append g_flags " -g${p_name}=${p_val}"
			}
		}
	}
;#------------------------------------------------------------------------------------
# Simulation
	set tb_entity "testbench"
	puts "\[INFO\] Start simulation..."
	eval vsim -c $g_flags work.$tb_entity
	run -all
	quit -f
} sim_err]} {
	puts "\[MODELSIM ERROR\]"
	quit -code 1 -f
}

quit -f