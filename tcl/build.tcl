package require ::quartus::project
package require ::quartus::flow
package require ::quartus::report

if {$argc < 1} {
	puts "\[ERROR\] The tcl-script did not receive a build path."
	exit 1
}

#=====================================================================================
# Script parameters
#=====================================================================================
set project_name $::env(PROJECT_NAME) ;# project name
set top_entity $::env(TOP_ENTITY) ;# top module
set device_part "10M50DAF484C6GES"; ;# FPGA name
set build_dir [file normalize [lindex $argv 0]];# build directory
set script_dir [file dirname [file normalize [info script]]] ;# script location deirectory
set project_root [file dirname $script_dir] ;# directory above script directory
set rtl_dir [file join $project_root "rtl"] ;# directory with HDL files
set sdc_dir [file join $project_root "sdc"] ;# directory with constraints files

#=====================================================================================
# Creating a directory for the build and moving into it
#=====================================================================================
file mkdir $build_dir
cd $build_dir

#=====================================================================================
# Creating or opening a project
#=====================================================================================
if {[project_exists $project_name]} {
	project_open $project_name -current_revision
} else {
	project_new $project_name -revision $project_name -overwrite
}

#=====================================================================================
# Setting build parameters
#=====================================================================================
set_global_assignment -name FAMILY "MAX 10" ;# FPGA family
set_global_assignment -name DEVICE $device_part ;# FPGA name
set_global_assignment -name TOP_LEVEL_ENTITY $top_entity ;# top module
set_global_assignment -name NUM_PARALLEL_PROCESSORS ALL ;# parallel compilation
set_global_assignment -name INTERNAL_FLASH_UPDATE_MODE "SINGLE IMAGE WITH ERAM"
set_global_assignment -name DSP_BLOCK_BALANCING "DSP BLOCKS"

foreach f [glob [file join $rtl_dir "*.sv"]] { set_global_assignment -name SYSTEMVERILOG_FILE $f } ;# HDL files
foreach f [glob [file join $build_dir "*.vh"]] { set_global_assignment -name VERILOG_INCLUDE_FILE $f } ;# Header files
foreach f [glob [file join $sdc_dir "*.sdc"]] { set_global_assignment -name SDC_FILE $f } ;# constraints files

#=====================================================================================
# Running a full compilation
#=====================================================================================
puts "\[INFO\] Start project $project_name compilation."
if {[catch {execute_flow -compile} result]} {
	puts "\[ERROR\] $result"
	project_close
	exit 1
} else {
	puts "\[SUCCESS\] Compilation completed successfully!"
}

#=====================================================================================
# Reading and outputting a report
#=====================================================================================
puts "\n====================================================================================="
puts "                                 Compilation Report                                  "
puts "====================================================================================="
if {[catch {
;#------------------------------------------------------------------------------------
# Loading a report database for an open project
	load_report
	set panel_name "Flow Summary" ;# the Flow Summary panel is boring
	set num_rows [get_number_of_rows -name $panel_name] ;# number of rows int the table
;#------------------------------------------------------------------------------------
# Iterating over lines and outputting to the console	
	for {set i 0} {$i < $num_rows} {incr i} {
		set row_data [get_report_panel_row -name $panel_name -row $i] ;# row data
		set metric [lindex $row_data 0]
		set value [lindex $row_data 1]
		puts [format "%-45s : %s" $metric $value] ;# output format
	}
	unload_report
} report_err]} {
	puts "\[WARNING\] Failed to read the Compilation Report: $report_err"
}
puts "====================================================================================="

project_close