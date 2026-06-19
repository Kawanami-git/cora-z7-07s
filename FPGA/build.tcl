# SPDX-License-Identifier: MIT
#
# Reproducible CORA Z7-07S Vivado batch flow (Vivado 2025.2)
#
# This script is intended to be executed from a *work copy* of
# riscv-core-harness/cora-z7-07s/FPGA.
# --origin_dir MUST point to the original
# riscv-core-harness/cora-z7-07s/FPGA directory in the repository.
#
# Usage examples:
#   vivado -mode batch -source build.tcl -tclargs --xlen 32 --origin_dir /path/to/repo/riscv-core-harness/cora-z7-07s/FPGA --dut_dir /path/to/repo/risc-v
#   vivado -mode batch -source build.tcl -tclargs --xlen 32 --origin_dir /path/to/repo/riscv-core-harness/cora-z7-07s/FPGA --dut_dir /path/to/repo/risc-v --board_repo /opt/Xilinx/board_files/digilent/new/board_files
#
# Notes:
#   * Board files: set_param board.repoPaths must include the Digilent board repo
#     so that the board_part "digilentinc.com:cora-z7-07s:part0:1.1" can be resolved.
#     See UG895 (board.repoPaths) and UG835 (get_board_parts).
#   * IP/BD output products: generate_target + export_ip_user_files are used prior to simulation.

set script_dir [file normalize [file dirname [info script]]]

# ---------------------------------------------------------------------------
# Helper: find repository root when running from a repository or work-copy path
# ---------------------------------------------------------------------------
proc _sr_find_repo_root {start_dir} {
  set d [file normalize $start_dir]
  for {set i 0} {$i < 10} {incr i} {
    #   <repo>/riscv-core-harness/{hardware,cora-z7-07s}
    if {[file isdirectory [file join $d riscv-core-harness hardware]] &&         [file exists [file join $d riscv-core-harness cora-z7-07s FPGA build.tcl]]} {
      return [file normalize [file join $d riscv-core-harness]]
    }

    # Standalone riscv-core-harness repository layout:
    #   <repo>/{hardware,cora-z7-07s}
    if {[file isdirectory [file join $d hardware]] &&         [file exists [file join $d cora-z7-07s FPGA build.tcl]]} {
      return $d
    }

    set parent [file dirname $d]
    if {$parent eq $d} { break }
    set d $parent
  }
  return ""
}

# ---------------------------------------------------------------------------
# Default argument values
# ---------------------------------------------------------------------------
set origin_dir $script_dir
set _origin_dir_user_set 0

# Backward-compat with some Vivado-generated scripts:
# They sometimes pass ::origin_dir_loc instead of --origin_dir.
if { [info exists ::origin_dir_loc] } {
  set origin_dir [file normalize $::origin_dir_loc]
  set _origin_dir_user_set 1
}

set _xil_proj_name_ "riscv-core-harness"
if { [info exists ::user_project_name] } {
  set _xil_proj_name_ $::user_project_name
}

set ::ARCHI 32

# Vivado flow selector.
# Supported values:
#   simulation : build the simulation BD and run behavioral simulation only
#   design     : build the hardware BD, run implementation, export bit/bin/xsa
#   both       : run simulation first, then implementation/export
set ::CORA_Z7_07S_VIVADO_FLOW "both"

set dut_dir ""

# Digilent board repository (can be overridden with --board_repo or env var)
set ::DIGILENT_BOARD_REPO ""
if {[info exists ::env(DIGILENT_BOARD_REPO)]} {
  set ::DIGILENT_BOARD_REPO $::env(DIGILENT_BOARD_REPO)
} else {
  set ::DIGILENT_BOARD_REPO "/opt/Xilinx/board_files/digilent/new/board_files"
}

proc print_help {} {
  puts "Usage:"
  puts {  vivado -mode batch -source build.tcl -tclargs --xlen <32|64> --origin_dir <path/to/repo/riscv-core-harness/cora-z7-07s/FPGA> [--board_repo <path/to/digilent/board_files>]}
  puts ""
  puts "Options:"
  puts "  --xlen              32 or 64 (default: 32)"
  puts "  --origin_dir        Absolute path to the original riscv-core-harness/cora-z7-07s/FPGA directory"
  puts "  --dut_dir           Absolute path to the DUT RTL directory (default: <repo>/risc-v)"
  puts "  --core_clk_freq_mhz risc-v core required frequency (MHz)"
  puts "  --flow              Vivado flow to run: simulation, design, or both (default: both)"
  puts "  --board_repo        Path containing Digilent Vivado board files (default: $::DIGILENT_BOARD_REPO)"
  puts "  --project_name      Project name (default: riscv-core-harness)"
  puts "  --help              Print this help"
  exit 0
}

# ---------------------------------------------------------------------------
# Tclargs parsing
# ---------------------------------------------------------------------------
if { $::argc > 0 } {
  for {set i 0} {$i < $::argc} {incr i} {
    set option [string trim [lindex $::argv $i]]
    switch -regexp -- $option {
      "--xlen"              { incr i; set ::ARCHI [lindex $::argv $i] }
      "--origin_dir"        { incr i; set origin_dir [file normalize [lindex $::argv $i]] ; set _origin_dir_user_set 1 }
      "--dut_dir"           { incr i; set dut_dir [file normalize [lindex $::argv $i]] }
      "--core_clk_freq_mhz" { incr i; set ::CORE_CLK_FREQ_MHZ [lindex $::argv $i] }
      "--flow"              { incr i; set ::CORA_Z7_07S_VIVADO_FLOW [string tolower [lindex $::argv $i]] }
      "--board_repo"        { incr i; set ::DIGILENT_BOARD_REPO [file normalize [lindex $::argv $i]] }
      "--project_name"      { incr i; set _xil_proj_name_ [lindex $::argv $i] }
      "--help"              { print_help }
      default {
        if { [regexp {^-} $option] } {
          puts "ERROR: Unknown option '$option'"
          print_help
        }
      }
    }
  }
}

# Normalize flow aliases and fail early on invalid values.
switch -- $::CORA_Z7_07S_VIVADO_FLOW {
  "sim"        { set ::CORA_Z7_07S_VIVADO_FLOW "simulation" }
  "simulation" { set ::CORA_Z7_07S_VIVADO_FLOW "simulation" }
  "design"     { set ::CORA_Z7_07S_VIVADO_FLOW "design" }
  "bitstream"  { set ::CORA_Z7_07S_VIVADO_FLOW "design" }
  "hw"         { set ::CORA_Z7_07S_VIVADO_FLOW "design" }
  "both"       { set ::CORA_Z7_07S_VIVADO_FLOW "both" }
  "all"        { set ::CORA_Z7_07S_VIVADO_FLOW "both" }
  "full"       { set ::CORA_Z7_07S_VIVADO_FLOW "both" }
  default {
    puts "ERROR: Unsupported --flow '$::CORA_Z7_07S_VIVADO_FLOW'"
    puts "       Expected: simulation, design, or both."
    print_help
  }
}
puts "Vivado flow      : $::CORA_Z7_07S_VIVADO_FLOW"

# ---------------------------------------------------------------------------
# Auto-detect origin_dir if not provided explicitly.
#   Accepted forms:
#     1) <repo>/riscv-core-harness/cora-z7-07s/FPGA  (preferred)
#     2) <repo>/riscv-core-harness
#     3) <repo> containing riscv-core-harness/
# ---------------------------------------------------------------------------
if {!$_origin_dir_user_set} {
  set repo_root [_sr_find_repo_root $script_dir]
  if {$repo_root ne ""} {
    set origin_dir [file normalize [file join $repo_root cora-z7-07s FPGA]]
  }
}

# If the user passed the full repository root, adjust.
if {[file exists [file join $origin_dir riscv-core-harness cora-z7-07s FPGA build.tcl]]} {
  set origin_dir [file normalize [file join $origin_dir riscv-core-harness cora-z7-07s FPGA]]
}

# If the user passed the riscv-core-harness root, adjust.
if {[file exists [file join $origin_dir cora-z7-07s FPGA build.tcl]]} {
  set origin_dir [file normalize [file join $origin_dir cora-z7-07s FPGA]]
}

# Validate origin_dir content (fail fast).
set _req1 [file join $origin_dir sources hdl riscv_env_wrapper.v]
set _req2 [file join $origin_dir design.tcl]
set _req3 [file normalize [file join $origin_dir ../../hardware harness riscv_core_harness.sv]]
set _req4 [file normalize [file join $origin_dir ../../hardware common axi_if.sv]]
if {![file exists $_req1] || ![file exists $_req2] || ![file exists $_req3] || ![file exists $_req4]} {
  puts "ERROR: origin_dir does not look like riscv-core-harness/cora-z7-07s/FPGA."
  puts "  origin_dir = $origin_dir"
  puts "  expected   = $_req1 (exists=[file exists $_req1])"
  puts "  expected   = $_req2 (exists=[file exists $_req2])"
  puts "  expected   = $_req3 (exists=[file exists $_req3])"
  puts "  expected   = $_req4 (exists=[file exists $_req4])"
  puts ""
  puts "Fix:"
  puts "  Re-run with: -tclargs --origin_dir /ABS/PATH/TO/<repo>/riscv-core-harness/cora-z7-07s/FPGA"
  error "Invalid --origin_dir"
}

# Resolve and validate DUT_DIR.
set harness_root [file normalize [file join $origin_dir "../.."]]
set project_root [file normalize [file join $harness_root ".."]]

set dut_dir [string trim $dut_dir]
if {$dut_dir eq ""} {
  set dut_dir [file normalize [file join $project_root "risc-v"]]
} else {
  set dut_dir [file normalize $dut_dir]
}

if {![file isdirectory $dut_dir]} {
  puts "ERROR: DUT directory does not exist: $dut_dir"
  puts ""
  puts "Fix:"
  puts "  Re-run with: -tclargs --dut_dir /ABS/PATH/TO/<repo>/risc-v"
  error "Invalid --dut_dir"
}

puts "Using DUT dir   : $dut_dir"
puts "Using origin_dir: $origin_dir"

# ---------------------------------------------------------------------------
# Configure Digilent board repository paths so board_part resolves.
# ---------------------------------------------------------------------------
if {[file isdirectory $::DIGILENT_BOARD_REPO]} {
  # Prefer a narrower repo path (reduces warnings about boards for uninstalled devices)
  set cora_only [file join $::DIGILENT_BOARD_REPO cora-z7-07s]
  if {[file isdirectory $cora_only]} {
    set dig_repo $cora_only
  } else {
    set dig_repo $::DIGILENT_BOARD_REPO
  }

  # Preserve any existing board.repoPaths the user has (append Digilent path).
  set current_paths {}
  catch { set current_paths [get_param board.repoPaths] }
  if {$current_paths eq ""} { set current_paths {} }

  set new_paths [lsort -unique [concat $current_paths [list $dig_repo]]]
  set_param board.repoPaths $new_paths
  puts "board.repoPaths = $new_paths"
  puts "Available Cora board parts: [get_board_parts -quiet *cora*]"
} else {
  puts "WARNING: Digilent board repo not found: $::DIGILENT_BOARD_REPO"
  puts {         You may get [Board 49-71] unless you install Digilent board files.}
}

puts "Configure project for $ARCHI-bit architecture"

set proj_path "./"
create_project ${_xil_proj_name_} $proj_path -part xc7z007sclg400-1
set proj_dir [get_property directory [current_project]]

set obj [current_project]

set_property -name "board_part" -value "digilentinc.com:cora-z7-07s:part0:1.1" -objects $obj
set_property -name "compxlib.activehdl_compiled_library_dir" -value "$proj_dir/${_xil_proj_name_}.cache/compile_simlib/activehdl" -objects $obj
set_property -name "compxlib.funcsim" -value "1" -objects $obj
set_property -name "compxlib.modelsim_compiled_library_dir" -value "$proj_dir/${_xil_proj_name_}.cache/compile_simlib/modelsim" -objects $obj
set_property -name "compxlib.overwrite_libs" -value "0" -objects $obj
set_property -name "compxlib.questa_compiled_library_dir" -value "$proj_dir/${_xil_proj_name_}.cache/compile_simlib/questa" -objects $obj
set_property -name "compxlib.riviera_compiled_library_dir" -value "$proj_dir/${_xil_proj_name_}.cache/compile_simlib/riviera" -objects $obj
set_property -name "compxlib.timesim" -value "1" -objects $obj
set_property -name "compxlib.vcs_compiled_library_dir" -value "$proj_dir/${_xil_proj_name_}.cache/compile_simlib/vcs" -objects $obj
set_property -name "compxlib.xsim_compiled_library_dir" -value "" -objects $obj
set_property -name "corecontainer.enable" -value "0" -objects $obj
set_property -name "customized_default_ip_location" -value "" -objects $obj
set_property -name "default_lib" -value "xil_defaultlib" -objects $obj
set_property -name "enable_dpi_simulation" -value "0" -objects $obj
set_property -name "enable_optional_runs_sta" -value "0" -objects $obj
set_property -name "enable_resource_estimation" -value "0" -objects $obj
set_property -name "enable_vhdl_2008" -value "1" -objects $obj
set_property -name "generate_ip_upgrade_log" -value "1" -objects $obj
set_property -name "ip.user_files_dir" -value "$proj_dir/${_xil_proj_name_}.ip_user_files" -objects $obj
set_property -name "ip_cache_permissions" -value "read write" -objects $obj
set_property -name "ip_interface_inference_priority" -value "" -objects $obj
set_property -name "ip_output_repo" -value "$proj_dir/${_xil_proj_name_}.cache/ip" -objects $obj
set_property -name "legacy_ip_repo_paths" -value "" -objects $obj
set_property -name "local_ip_repo_leaf_dir_name" -value "ip_repo" -objects $obj
set_property -name "mem.enable_memory_map_generation" -value "1" -objects $obj
set_property -name "noc_phases" -value "" -objects $obj
set_property -name "platform.board_id" -value "cora-z7-07s" -objects $obj
set_property -name "platform.default_output_type" -value "undefined" -objects $obj
set_property -name "platform.design_intent.datacenter" -value "undefined" -objects $obj
set_property -name "platform.design_intent.embedded" -value "undefined" -objects $obj
set_property -name "platform.design_intent.external_host" -value "undefined" -objects $obj
set_property -name "platform.design_intent.server_managed" -value "undefined" -objects $obj
set_property -name "platform.rom.debug_type" -value "0" -objects $obj
set_property -name "platform.rom.prom_type" -value "0" -objects $obj
set_property -name "platform.slrconstraintmode" -value "0" -objects $obj
set_property -name "preferred_sim_model" -value "rtl" -objects $obj
set_property -name "project_type" -value "Default" -objects $obj
set_property -name "pr_flow" -value "0" -objects $obj
set_property -name "revised_directory_structure" -value "1" -objects $obj
set_property -name "segmented_configuration" -value "0" -objects $obj
set_property -name "sim.central_dir" -value "$proj_dir/${_xil_proj_name_}.ip_user_files" -objects $obj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $obj
set_property -name "sim.ipstatic.source_dir" -value "$proj_dir/${_xil_proj_name_}.ip_user_files/ipstatic" -objects $obj
set_property -name "sim.use_ip_compiled_libs" -value "1" -objects $obj
set_property -name "simulator_language" -value "Mixed" -objects $obj
set_property -name "source_mgmt_mode" -value "All" -objects $obj
set_property -name "target_language" -value "Verilog" -objects $obj
set_property -name "target_simulator" -value "XSim" -objects $obj
set_property -name "tool_flow" -value "Vivado" -objects $obj
set_property -name "use_inline_hdl_ip" -value "1" -objects $obj
set_property -name "xpm_libraries" -value "XPM_CDC XPM_FIFO XPM_MEMORY" -objects $obj
set_property -name "xsim.array_display_limit" -value "1024" -objects $obj
set_property -name "xsim.radix" -value "hex" -objects $obj
set_property -name "xsim.time_unit" -value "ns" -objects $obj
set_property -name "xsim.trace_limit" -value "65536" -objects $obj

# The hardware BD is always required.
source [file join $script_dir design.tcl]

# The simulation BD is only required when the selected flow runs XSim.
if {$::CORA_Z7_07S_VIVADO_FLOW eq "simulation" || $::CORA_Z7_07S_VIVADO_FLOW eq "both"} {
  source [file join $script_dir sim.tcl]
}

# Generate outputs for user-managed IP (XCI) and BDs.
# Important: do NOT reset nested XCI generated inside a BD. Vivado only allows
# those to be reset/regenerated through their parent block design.
set xci_files {}
foreach f [get_files -quiet -of_objects [get_filesets sources_1] *.xci] {
  # If this XCI is referenced from within a BD, PARENT_COMPOSITE_FILE is set.
  # We skip these and let generate_target run on the parent .bd instead.
  set parent_bd ""
  catch { set parent_bd [get_property PARENT_COMPOSITE_FILE $f] }

  if { $parent_bd ne "" } {
    continue
  }
  lappend xci_files $f
}

if { [llength $xci_files] > 0 } {
  puts "Generating output products for user XCI files: $xci_files"
  generate_target all $xci_files
  # Do NOT use -sync here (-sync deletes files). See UG835 export_ip_user_files.
  export_ip_user_files -of_objects $xci_files -no_script -force -quiet
}
set bd_files [get_files -quiet *.bd]
if { [llength $bd_files] > 0 } {
  generate_target all $bd_files
  export_ip_user_files -of_objects $bd_files -no_script -force -quiet
}

# Keep the implementation top on the hardware BD.
set_property top block_design_wrapper [get_filesets sources_1]

update_compile_order -fileset sources_1
catch { update_compile_order -fileset sim_1 }

set idrFlowPropertiesConstraints ""
catch {
  set idrFlowPropertiesConstraints [get_param runs.disableIDRFlowPropertyConstraints]
  set_param runs.disableIDRFlowPropertyConstraints 1
}

if {[string equal [get_runs -quiet synth_1] ""]} {
  create_run -name synth_1 -part xc7z007sclg400-1 -flow {Vivado Synthesis 2025} -strategy "Flow_PerfOptimized_high" -report_strategy {No Reports} -constrset constrs_1
} else {
  set_property strategy "Flow_PerfOptimized_high" [get_runs synth_1]
  set_property flow "Vivado Synthesis 2025" [get_runs synth_1]
}
set obj [get_runs synth_1]
set_property -name "constrset" -value "constrs_1" -objects $obj
set_property -name "description" -value "Higher performance designs, resource sharing is turned off, the global fanout guide is set to a lower number, FSM extraction forced to one-hot, LUT combining is disabled, equivalent registers are preserved, SRL are inferred  with a larger threshold" -objects $obj
set_property -name "flow" -value "Vivado Synthesis 2025" -objects $obj
set_property -name "srcset" -value "sources_1" -objects $obj
set_property -name "incremental_checkpoint" -value "" -objects $obj
set_property -name "auto_incremental_checkpoint" -value "0" -objects $obj
set_property -name "gen_reports_parallel" -value "1" -objects $obj
set_property -name "include_in_archive" -value "1" -objects $obj
set_property -name "gen_full_bitstream" -value "1" -objects $obj
set_property -name "write_incremental_synth_checkpoint" -value "0" -objects $obj
set_property -name "auto_incremental_checkpoint.directory" -value "$proj_dir/${_xil_proj_name_}.srcs/utils_1/imports/synth_1" -objects $obj
set_property -name "min_rqa_score" -value "0" -objects $obj
set_property -name "strategy" -value "Flow_PerfOptimized_high" -objects $obj
set_property -name "steps.synth_design.tcl.pre" -value "" -objects $obj
set_property -name "steps.synth_design.tcl.post" -value "" -objects $obj
set_property -name "steps.synth_design.args.flatten_hierarchy" -value "rebuilt" -objects $obj
set_property -name "steps.synth_design.args.gated_clock_conversion" -value "off" -objects $obj
set_property -name "steps.synth_design.args.bufg" -value "12" -objects $obj
set_property -name "steps.synth_design.args.directive" -value "PerformanceOptimized" -objects $obj
set_property -name "steps.synth_design.args.global_retiming" -value "auto" -objects $obj
set_property -name "steps.synth_design.args.fsm_extraction" -value "one_hot" -objects $obj
set_property -name "steps.synth_design.args.keep_equivalent_registers" -value "1" -objects $obj
set_property -name "steps.synth_design.args.resource_sharing" -value "off" -objects $obj
set_property -name "steps.synth_design.args.control_set_opt_threshold" -value "auto" -objects $obj
set_property -name "steps.synth_design.args.no_lc" -value "1" -objects $obj
set_property -name "steps.synth_design.args.no_srlextract" -value "0" -objects $obj
set_property -name "steps.synth_design.args.shreg_min_size" -value "5" -objects $obj
set_property -name "steps.synth_design.args.max_bram" -value "-1" -objects $obj
set_property -name "steps.synth_design.args.max_uram" -value "-1" -objects $obj
set_property -name "steps.synth_design.args.max_dsp" -value "-1" -objects $obj
set_property -name "steps.synth_design.args.max_bram_cascade_height" -value "-1" -objects $obj
set_property -name "steps.synth_design.args.max_uram_cascade_height" -value "-1" -objects $obj
set_property -name "steps.synth_design.args.cascade_dsp" -value "auto" -objects $obj
set_property -name "steps.synth_design.args.assert" -value "0" -objects $obj
set_property -name "steps.synth_design.args.incremental_mode" -value "default" -objects $obj
set_property -name "steps.synth_design.args.more options" -value {} -objects $obj

if {[string equal [get_runs -quiet impl_1] ""]} {
  create_run -name impl_1 -part xc7z007sclg400-1 -flow {Vivado Implementation 2025} -strategy "Performance_ExplorePostRoutePhysOpt" -report_strategy {No Reports} -constrset constrs_1 -parent_run synth_1
} else {
  set_property strategy "Performance_ExplorePostRoutePhysOpt" [get_runs impl_1]
  set_property flow "Vivado Implementation 2025" [get_runs impl_1]
}
set obj [get_runs impl_1]
set_property -name "constrset" -value "constrs_1" -objects $obj
set_property -name "description" -value "Similar to Peformance_Explore, but enables the physical optimization step (phys_opt_design) with the Explore directive after routing." -objects $obj
set_property -name "flow" -value "Vivado Implementation 2025" -objects $obj
set_property -name "srcset" -value "sources_1" -objects $obj
set_property -name "incremental_checkpoint" -value "" -objects $obj
set_property -name "auto_incremental_checkpoint" -value "0" -objects $obj
set_property -name "gen_reports_parallel" -value "1" -objects $obj
set_property -name "include_in_archive" -value "1" -objects $obj
set_property -name "gen_full_bitstream" -value "1" -objects $obj
set_property -name "auto_incremental_checkpoint.directory" -value "$proj_dir/${_xil_proj_name_}.srcs/utils_1/imports/impl_1" -objects $obj
set_property -name "min_rqa_score" -value "0" -objects $obj
set_property -name "strategy" -value "Performance_ExplorePostRoutePhysOpt" -objects $obj
set_property -name "steps.init_design.tcl.pre" -value "" -objects $obj
set_property -name "steps.init_design.tcl.post" -value "" -objects $obj
set_property -name "steps.init_design.args.more options" -value {} -objects $obj
set_property -name "steps.opt_design.is_enabled" -value "1" -objects $obj
set_property -name "steps.opt_design.tcl.pre" -value "" -objects $obj
set_property -name "steps.opt_design.tcl.post" -value "" -objects $obj
set_property -name "steps.opt_design.args.verbose" -value "0" -objects $obj
set_property -name "steps.opt_design.args.directive" -value "Explore" -objects $obj
set_property -name "steps.opt_design.args.more options" -value {} -objects $obj
set_property -name "steps.power_opt_design.is_enabled" -value "0" -objects $obj
set_property -name "steps.power_opt_design.tcl.pre" -value "" -objects $obj
set_property -name "steps.power_opt_design.tcl.post" -value "" -objects $obj
set_property -name "steps.power_opt_design.args.more options" -value {} -objects $obj
set_property -name "steps.place_design.tcl.pre" -value "" -objects $obj
set_property -name "steps.place_design.tcl.post" -value "" -objects $obj
set_property -name "steps.place_design.args.directive" -value "Explore" -objects $obj
set_property -name "steps.place_design.args.more options" -value {} -objects $obj
set_property -name "steps.post_place_power_opt_design.is_enabled" -value "0" -objects $obj
set_property -name "steps.post_place_power_opt_design.tcl.pre" -value "" -objects $obj
set_property -name "steps.post_place_power_opt_design.tcl.post" -value "" -objects $obj
set_property -name "steps.post_place_power_opt_design.args.more options" -value {} -objects $obj
set_property -name "steps.phys_opt_design.is_enabled" -value "1" -objects $obj
set_property -name "steps.phys_opt_design.tcl.pre" -value "" -objects $obj
set_property -name "steps.phys_opt_design.tcl.post" -value "" -objects $obj
set_property -name "steps.phys_opt_design.args.directive" -value "Explore" -objects $obj
set_property -name "steps.phys_opt_design.args.more options" -value {} -objects $obj
set_property -name "steps.route_design.tcl.pre" -value "" -objects $obj
set_property -name "steps.route_design.tcl.post" -value "" -objects $obj
set_property -name "steps.route_design.args.directive" -value "Explore" -objects $obj
set_property -name "steps.route_design.args.more options" -value {-tns_cleanup} -objects $obj
set_property -name "steps.post_route_phys_opt_design.is_enabled" -value "1" -objects $obj
set_property -name "steps.post_route_phys_opt_design.tcl.pre" -value "" -objects $obj
set_property -name "steps.post_route_phys_opt_design.tcl.post" -value "" -objects $obj
set_property -name "steps.post_route_phys_opt_design.args.directive" -value "Explore" -objects $obj
set_property -name "steps.post_route_phys_opt_design.args.more options" -value {} -objects $obj
set_property -name "steps.write_bitstream.tcl.pre" -value "" -objects $obj
set_property -name "steps.write_bitstream.tcl.post" -value "" -objects $obj
set_property -name "steps.write_bitstream.args.raw_bitfile" -value "0" -objects $obj
set_property -name "steps.write_bitstream.args.mask_file" -value "0" -objects $obj
set_property -name "steps.write_bitstream.args.no_binary_bitfile" -value "0" -objects $obj
set_property -name "steps.write_bitstream.args.bin_file" -value "0" -objects $obj
set_property -name "steps.write_bitstream.args.readback_file" -value "0" -objects $obj
set_property -name "steps.write_bitstream.args.logic_location_file" -value "0" -objects $obj
set_property -name "steps.write_bitstream.args.verbose" -value "0" -objects $obj
set_property -name "steps.write_bitstream.args.more options" -value {} -objects $obj

current_run -synthesis [get_runs synth_1]
current_run -implementation [get_runs impl_1]

puts "Project '${_xil_proj_name_}' created in: $proj_dir"
puts "Main runs configured: synth_1 / impl_1"

proc fail_and_exit {msg} {
  puts "ERROR: $msg"
  catch {close_sim -force}
  catch {close_project}
  return -code error $msg
}

proc run_behavioral_simulation {} {
  puts ""
  puts "============================================================"
  puts "Running behavioral simulation"
  puts "============================================================"

  if {[catch {
    launch_simulation
    close_sim -force
  } result]} {
    fail_and_exit "Simulation failed: $result"
  }

  puts "Simulation completed successfully."
}

proc run_bitstream_and_xsa {} {
  global origin_dir _xil_proj_name_

  puts ""
  puts "============================================================"
  puts "Running implementation to bitstream"
  puts "============================================================"

  launch_runs impl_1 -to_step write_bitstream -jobs 8
  wait_on_run impl_1

  set impl_status [get_property STATUS [get_runs impl_1]]
  puts "impl_1 status: $impl_status"

  if {![regexp {write_bitstream Complete} $impl_status]} {
    fail_and_exit "Implementation/bitstream failed: $impl_status"
  }

  open_run impl_1

  set export_dir "./"
  file mkdir $export_dir

  set bit_file [file join $export_dir "${_xil_proj_name_}.bit"]
  set xsa_file [file join $export_dir "${_xil_proj_name_}.xsa"]
  set bif_file [file join $export_dir "${_xil_proj_name_}.bif"]
  set bin_file [file join $export_dir "${_xil_proj_name_}.bin"]

  # Export .bit
  write_bitstream -force $bit_file

  # Export XSA with bitstream included
  write_hw_platform -fixed -include_bit -force -file $xsa_file

  # Generate Bootgen BIF for Zynq-7000 PL programming
  # IMPORTANT: no [destination_device = pl] for -arch zynq
  set fh [open $bif_file "w"]
  puts $fh "all:"
  puts $fh "{"
  puts $fh "  $bit_file"
  puts $fh "}"
  close $fh

  # Generate .bin with Bootgen for Zynq-7000
  if {[catch {
    exec bootgen -image $bif_file -arch zynq -process_bitstream bin -o $bin_file -w on
  } err]} {
    puts "WARNING: bootgen failed, .bin not generated"
    puts "bootgen error: $err"
  } else {
    puts "BIN exported to      : $bin_file"
    puts "BIF exported to      : $bif_file"
  }

  puts "Bitstream exported to: $bit_file"
  puts "XSA exported to      : $xsa_file"
}

# ============================================================
# Automated flow selection
# ============================================================

switch -- $::CORA_Z7_07S_VIVADO_FLOW {
  "simulation" {
    run_behavioral_simulation

    puts ""
    puts "============================================================"
    puts "Simulation flow completed successfully"
    puts "============================================================"
  }

  "design" {
    run_bitstream_and_xsa

    puts ""
    puts "============================================================"
    puts "Design flow completed successfully"
    puts "============================================================"
  }

  "both" {
    run_behavioral_simulation
    run_bitstream_and_xsa

    puts ""
    puts "============================================================"
    puts "Full flow completed successfully"
    puts "============================================================"
  }

  default {
    fail_and_exit "Internal error: unsupported Vivado flow '$::CORA_Z7_07S_VIVADO_FLOW'"
  }
}
