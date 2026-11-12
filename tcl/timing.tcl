package require ::quartus::project
package require ::quartus::sta

set build_dir [file normalize [lindex $argv 0]] ;# build directory
cd $build_dir
set project_name $::env(PROJECT_NAME) ;# project name

#=====================================================================================
# Opening a project
#=====================================================================================
if {[project_exists $project_name]} {
	project_open $project_name -current_revision
} else {
	puts "\[ERROR\] Project for STA not found in $build_dir"
	exit 1
}

#=====================================================================================
# Reading and outputting a report
#=====================================================================================
if {[catch {
	create_timing_netlist
	read_sdc
	update_timing_netlist
	puts "\n====================================================================================="
	puts "                                         STA                                         "
	puts "====================================================================================="
;#------------------------------------------------------------------------------------
# Maximum operating frequencies
	puts "\n>>> 1. Maximum operating frequencies (Fmax):"
	set fmax_list [get_clock_fmax_info]
	if {[llength $fmax_list] == 0} {
		puts "\[WARNING\] No clocks detected."
	} else {
		foreach clk_info $fmax_list {
			set clk_name [lindex $clk_info 0]
			set fmax_val [lindex $clk_info 1]
			puts [format "	Clock: %-20s | Fmax: %s" $clk_name $fmax_val]
		}
	}
;#------------------------------------------------------------------------------------
# Worst-Case Slack
	puts "\n>>> 2. Worst-Case Slack:"
	set setup_paths [get_timing_paths -setup -npaths 1]
	set w_setup "N/A"
	foreach_in_collection path $setup_paths {
		set w_setup [get_path_info $path -slack]
	}
	puts [format "	Worst Setup Slack : %s ns" $w_setup]
	
	set hold_paths [get_timing_paths -hold -npaths 1]
	set w_hold "N/A"
	foreach_in_collection path $hold_paths {
		set w_hold [get_path_info $path -slack]
	}
	puts [format "	Worst Hold Slack : %s ns" $w_hold]
;#------------------------------------------------------------------------------------
# Top 10 Critical Paths (Setup)
	puts "\n>>> 3. Top 10 Critical Paths (Setup):"
	set top_paths_setup [get_timing_paths -setup -npaths 10]
	if {[get_collection_size $top_paths_setup] == 0} {
		puts "No paths found for analysis"
	} else {
		set idx 1
		foreach_in_collection path $top_paths_setup {
			set slack [get_path_info $path -slack]
			set from_node [get_node_info [get_path_info $path -from] -name]
			set to_node [get_node_info [get_path_info $path -to] -name]
			
			if {[string length $from_node] > 35} { set from_node "...[string range $from_node end-32 end]" }
			if {[string length $to_node] > 35} { set to_node "...[string range $to_node end-32 end]" }
			
			puts [format "	%2d. Slack: %8s ns | From %-35s -> To %-35s" $idx $slack $from_node $to_node]
			incr idx
		}
	}
;#------------------------------------------------------------------------------------
# Top 10 Critical Paths (Hold)
	puts "\n>>> 4. Top 10 Critical Paths (Hold):"
	set top_paths_hold [get_timing_paths -hold -npaths 10]
	if {[get_collection_size $top_paths_hold] == 0} {
		puts "No paths found for analysis"
	} else {
		set idx 1
		foreach_in_collection path $top_paths_hold {
			set slack [get_path_info $path -slack]
			set from_node [get_node_info [get_path_info $path -from] -name]
			set to_node [get_node_info [get_path_info $path -to] -name]
			
			if {[string length $from_node] > 35} { set from_node "...[string range $from_node end-32 end]" }
			if {[string length $to_node] > 35} { set to_node "...[string range $to_node end-32 end]" }
			
			puts [format "	%2d. Slack: %8s ns | From %-35s -> To %-35s" $idx $slack $from_node $to_node]
			incr idx
		}
	}
	
	delete_timing_netlist
} sta_err]} {
	puts "\[WARNING\] Error calculating time parameters: $sta_err"
}
puts "====================================================================================="

project_close