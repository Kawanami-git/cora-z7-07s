# SPDX-License-Identifier: MIT
#
# CORA Z7-07S Vivado hardware design creation script.
#
# This script is sourced by build.tcl from a Vivado project. It imports the
# selected DUT recursively from DUT_DIR, then imports the fixed riscv-core-harness
# support RTL and creates the Zynq-7000 block design.

if { [current_project -quiet] eq "" } {
  error "design.tcl must be sourced from an open Vivado project."
}

if { ![info exists origin_dir] } {
  set origin_dir [file normalize [file dirname [info script]]]
}

if { ![info exists ::ARCHI] } {
  set ::ARCHI 32
}

set origin_dir [file normalize $origin_dir]
set harness_root [file normalize [file join $origin_dir "../.."]]
set project_root [file normalize [file join $harness_root ".."]]

# DUT_DIR is normally passed by build.tcl through --dut_dir.
if {![info exists dut_dir]} {
  set dut_dir ""
}
set dut_dir [string trim $dut_dir]
if {$dut_dir eq ""} {
  set dut_dir [file normalize [file join $project_root "risc-v"]]
} else {
  set dut_dir [file normalize $dut_dir]
}

puts "Using origin_dir : $origin_dir"
puts "Harness root     : $harness_root"
puts "Project root     : $project_root"
puts "DUT directory    : $dut_dir"
puts "ARCHI            : $::ARCHI"

if {![file isdirectory $dut_dir]} {
  error "DUT directory does not exist: $dut_dir"
}

if {![file isdirectory $harness_root]} {
  error "Harness root does not exist: $harness_root"
}

# ==========================================================
# Helpers
# ==========================================================

proc _sr_normalize_input_path {path} {
  global origin_dir

  if {[file pathtype $path] eq "absolute"} {
    return [file normalize $path]
  }

  return [file normalize [file join $origin_dir $path]]
}

proc _sr_collect_files_recursive {root_dir pattern} {
  set files {}

  foreach file [glob -nocomplain -types f -directory $root_dir $pattern] {
    lappend files [file normalize $file]
  }

  foreach dir [glob -nocomplain -types d -directory $root_dir *] {
    set files [concat $files [_sr_collect_files_recursive $dir $pattern]]
  }

  return [lsort -dictionary $files]
}

proc _sr_collect_files_recursive_multi {root_dir patterns} {
  set files {}

  foreach pattern $patterns {
    set files [concat $files [_sr_collect_files_recursive $root_dir $pattern]]
  }

  return [lsort -unique -dictionary $files]
}

# Sort HDL files by practical import/compile priority:
#   1. headers       (*.svh, *.vh)
#   2. packages      (*_pkg.sv, *pkg.sv)
#   3. interfaces    (*_if.sv, *if.sv)
#   4. remaining RTL (*.sv, *.v)
proc _sr_order_hdl_files {files} {
  set headers    {}
  set packages   {}
  set interfaces {}
  set modules    {}

  foreach file $files {
    set name [file tail $file]

    if {[string match "*.svh" $name] || [string match "*.vh" $name]} {
      lappend headers $file
    } elseif {[string match "*_pkg.sv" $name] || [string match "*pkg.sv" $name]} {
      lappend packages $file
    } elseif {[string match "*_if.sv" $name] || [string match "*if.sv" $name]} {
      lappend interfaces $file
    } else {
      lappend modules $file
    }
  }

  return [concat \
    [lsort -dictionary $headers] \
    [lsort -dictionary $packages] \
    [lsort -dictionary $interfaces] \
    [lsort -dictionary $modules]]
}

proc _sr_import_hdl {fileset path} {
  set abs_path [_sr_normalize_input_path $path]

  if { ![file exists $abs_path] } {
    error "Missing HDL file: $abs_path"
  }

  set basename [file tail $abs_path]
  set file_obj [get_files -quiet -of_objects [get_filesets $fileset] [list $abs_path]]

  if { $file_obj eq "" } {
    import_files -quiet -fileset $fileset $abs_path
    set file_obj [get_files -quiet -of_objects [get_filesets $fileset] [list $abs_path]]
  }

  # Fallback for Vivado versions that match imported files by basename only.
  if { $file_obj eq "" } {
    set file_obj [get_files -quiet -of_objects [get_filesets $fileset] [list "*$basename"]]
  }

  if { $file_obj eq "" } {
    return
  }

  if { [string match "*.sv" $basename] } {
    set_property file_type SystemVerilog $file_obj
  } elseif { [string match "*.v" $basename] } {
    set_property file_type Verilog $file_obj
  }

  set_property is_enabled 1 $file_obj
  set_property is_global_include 0 $file_obj
  set_property library xil_defaultlib $file_obj
  set_property path_mode RelativeFirst $file_obj
  set_property used_in "synthesis implementation simulation" $file_obj
  set_property used_in_implementation 1 $file_obj
  set_property used_in_simulation 1 $file_obj
  set_property used_in_synthesis 1 $file_obj
}

proc _sr_import_hdl_list {fileset files} {
  foreach file $files {
    puts "Import HDL source: $file"
    _sr_import_hdl $fileset $file
  }
}

proc _sr_import_xci {fileset relpath} {
  global origin_dir
  set abs_path [file normalize [file join $origin_dir $relpath]]
  if { ![file exists $abs_path] } {
    error "Missing IP file: $abs_path"
  }

  set basename [file tail $abs_path]
  if { [llength [get_files -quiet -of_objects [get_filesets $fileset] [list "*$basename"]]] == 0 } {
    import_files -quiet -fileset $fileset $abs_path
  }

  set file_obj [get_files -quiet -of_objects [get_filesets $fileset] [list "*$basename"]]
  if { $file_obj eq "" } {
    return
  }

  set_property generate_files_for_reference 0 $file_obj
  set_property is_enabled 1 $file_obj
  set_property is_global_include 0 $file_obj
  set_property path_mode RelativeFirst $file_obj
  set_property registered_with_manager 1 $file_obj
  set_property used_in "synthesis implementation simulation" $file_obj
  set_property used_in_implementation 1 $file_obj
  set_property used_in_simulation 1 $file_obj
  set_property used_in_synthesis 1 $file_obj
}

proc _sr_import_constraint {relpath} {
  global origin_dir
  if {[string equal [get_filesets -quiet constrs_1] ""]} {
    create_fileset -constrset constrs_1
  }

  set abs_path [file normalize [file join $origin_dir $relpath]]
  if { ![file exists $abs_path] } {
    error "Missing constraint file: $abs_path"
  }

  if { [llength [get_files -quiet -of_objects [get_filesets constrs_1] [list "*[file tail $abs_path]"]]] == 0 } {
    import_files -quiet -fileset constrs_1 [list $abs_path]
  }

  set file_obj [get_files -quiet -of_objects [get_filesets constrs_1] [list "*[file tail $abs_path]"]]
  set_property file_type XDC $file_obj
  set_property is_enabled 1 $file_obj
  set_property is_global_include 0 $file_obj
  set_property path_mode RelativeFirst $file_obj
  set_property processing_order NORMAL $file_obj
  set_property used_in "synthesis implementation" $file_obj
  set_property used_in_implementation 1 $file_obj
  set_property used_in_synthesis 1 $file_obj
}

# ==========================================================
# Filesets
# ==========================================================

if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# ==========================================================
# HDL import
# ==========================================================

if {$::ARCHI == 64} {
  set wrapper_file [file normalize [file join $origin_dir "sources/hdl/riscv_env_wrapper_64.v"]]
} else {
  set wrapper_file [file normalize [file join $origin_dir "sources/hdl/riscv_env_wrapper.v"]]
}

set common_hdl_files [list \
  [file join $harness_root "hardware/common/target_pkg.sv"] \
  [file join $harness_root "hardware/common/axi_if.sv"]]

set harness_hdl_files [list \
  [file join $harness_root "hardware/harness/axi2obi.sv"] \
  [file join $harness_root "hardware/harness/async_fifo.sv"] \
  [file join $harness_root "hardware/harness/dpram.sv"] \
  [file join $harness_root "hardware/harness/sys_reset.sv"] \
  [file join $harness_root "hardware/harness/xbar.sv"] \
  [file join $harness_root "hardware/harness/riscv_core_harness.sv"]]

set dut_files [_sr_collect_files_recursive_multi $dut_dir [list "*.sv" "*.svh" "*.v" "*.vh"]]
set ordered_dut_files [_sr_order_hdl_files $dut_files]

puts "DUT HDL files found: [llength $dut_files]"
foreach file $ordered_dut_files {
  puts "  DUT HDL: $file"
}

if {[llength $dut_files] == 0} {
  error "No HDL files found in DUT directory: $dut_dir"
}

set ordered_hdl_files [concat \
  $common_hdl_files \
  $ordered_dut_files \
  $harness_hdl_files \
  [list $wrapper_file]]

_sr_import_hdl_list sources_1 $ordered_hdl_files

# Give Vivado explicit include directories for any .svh/.vh found under the DUT
# and for the fixed harness/common source trees.
set include_dirs {}
foreach file $dut_files {
  set name [file tail $file]
  if {[string match "*.svh" $name] || [string match "*.vh" $name]} {
    lappend include_dirs [file dirname $file]
  }
}
lappend include_dirs [file join $harness_root "hardware/common"]
lappend include_dirs [file join $harness_root "hardware/harness"]
set include_dirs [lsort -unique -dictionary $include_dirs]
if {[llength $include_dirs] > 0} {
  puts "Vivado include_dirs: $include_dirs"
  set_property include_dirs $include_dirs [get_filesets sources_1]
}

# Optional extra board-local RTL.
foreach extra_glob [list \
    [file join $origin_dir sources new *.sv] \
    [file join $origin_dir sources new *.v] \
    [file join $origin_dir sources new *.svh]] {
  foreach f [lsort -dictionary [glob -nocomplain $extra_glob]] {
    puts "Import optional board-local HDL: $f"
    _sr_import_hdl sources_1 $f
  }
}

# ==========================================================
# IP import
# ==========================================================

set preferred_ip_relpaths [list \
  "sources/ip/dpram32/dpram32.xci" \
  "sources/ip/dpram64/dpram64.xci" \
]

foreach relpath $preferred_ip_relpaths {
  _sr_import_xci sources_1 $relpath
}

# Any additional XCI present in sources/ip
foreach f [lsort -dictionary [glob -nocomplain [file join $origin_dir sources ip * *.xci]]] {
  set basename [file tail $f]
  if { [llength [get_files -quiet -of_objects [get_filesets sources_1] [list "*$basename"]]] == 0 } {
    import_files -quiet -fileset sources_1 $f
  }
}

# Update / generate IP products
update_compile_order -fileset sources_1
set ips [get_ips -quiet]
if {[llength $ips] > 0} {
  puts "Checking IP status..."
  foreach ip $ips {
    if {[get_property IS_LOCKED $ip]} {
      puts "Upgrading locked IP: $ip"
      upgrade_ip $ip
    }
  }
  puts "Generating IP targets..."
  generate_target all $ips
  export_ip_user_files -of_objects $ips -no_script -force
}
update_compile_order -fileset sources_1

# ==========================================================
# Fileset properties
# ==========================================================

set src_fs [get_filesets sources_1]
set_property design_mode RTL $src_fs
set_property top_auto_set 0 $src_fs
set_property verilog_version verilog_2001 $src_fs
set_property vhdl_version vhdl_2k $src_fs
set_property elab_link_dcps 1 $src_fs
set_property elab_load_timing_constraints 1 $src_fs

# ==========================================================
# Constraints
# ==========================================================

_sr_import_constraint "constrs/riscv-core-harness.xdc"

set impl_xdc [get_files -of_objects [get_filesets constrs_1] "*riscv-core-harness.xdc"]

set_property USED_IN_SYNTHESIS false $impl_xdc
set_property USED_IN_IMPLEMENTATION true $impl_xdc
set_property PROCESSING_ORDER LATE $impl_xdc

set constr_fs [get_filesets constrs_1]
set_property constrs_type XDC $constr_fs





# ==========================================================
# Block design creation
# ==========================================================

proc cr_bd_block_design { parentCell } {
  set design_name block_design

  common::send_gid_msg -ssname BD::TCL -id 2010 -severity "INFO" \
    "Currently there is no design <$design_name> in project, so creating one..."

  create_bd_design $design_name

  # Check IP catalog entries
  set list_check_ips [list \
    "xilinx.com:ip:processing_system7:5.5" \
    "xilinx.com:ip:smartconnect:1.0" \
    "xilinx.com:ip:clk_wiz:6.0" \
    "xilinx.com:ip:proc_sys_reset:5.0" \
  ]

  set list_ips_missing {}
  foreach ip_vlnv $list_check_ips {
    if {[get_ipdefs -all $ip_vlnv] eq ""} {
      lappend list_ips_missing $ip_vlnv
    }
  }
  if {$list_ips_missing ne ""} {
    error "Missing IPs in catalog: $list_ips_missing"
  }

  # Check wrapper module
  if {$::ARCHI == 64} {
    set wrapper_name riscv_env_wrapper_64
  } else {
    set wrapper_name riscv_env_wrapper
  }
  if {[can_resolve_reference $wrapper_name] == 0} {
    error "Module reference '$wrapper_name' is not resolvable."
  }

  # Root instance
  if { $parentCell eq "" } {
    set parentCell [get_bd_cells /]
  }
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj eq "" } {
    error "Unable to find parent cell <$parentCell>."
  }

  set oldCurInst [current_bd_instance .]
  current_bd_instance $parentObj

  # --------------------------------------------------------
  # External interfaces and ports
  # --------------------------------------------------------
  # set DDR      [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 DDR]
  # set FIXED_IO [create_bd_intf_port -mode Master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 FIXED_IO]

  set sys_clock [create_bd_port -dir I -type clk -freq_hz 125000000 sys_clock]
  set_property CONFIG.PHASE {0.0} $sys_clock

  # --------------------------------------------------------
  # PS7
  # --------------------------------------------------------
  set processing_system7_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0]
  apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
      -config {apply_board_preset "1"} $processing_system7_0

  set_property -dict [list \
    CONFIG.PCW_FPGA_FCLK0_ENABLE {1} \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_CLK0_FREQ {50000000} \
  ] $processing_system7_0

  # --------------------------------------------------------
  # SmartConnect
  # --------------------------------------------------------
  set smartconnect_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0]
  set_property -dict [list \
    CONFIG.NUM_MI {5} \
    CONFIG.NUM_SI {1} \
  ] $smartconnect_0

  # --------------------------------------------------------
  # Clock Wizard
  # --------------------------------------------------------
  set clk_wiz_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0]
  set_property -dict [list \
    CONFIG.CLKOUT1_DRIVES {BUFGCE} \
    CONFIG.CLKOUT1_JITTER {157.214} \
    CONFIG.CLKOUT1_PHASE_ERROR {218.946} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $::CORE_CLK_FREQ_MHZ \
    CONFIG.CLK_IN1_BOARD_INTERFACE {sys_clock} \
    CONFIG.FEEDBACK_SOURCE {FDBK_AUTO} \
    CONFIG.JITTER_SEL {Min_O_Jitter} \
    CONFIG.MMCM_BANDWIDTH {HIGH} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {52} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.000} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {10} \
    CONFIG.MMCM_COMPENSATION {ZHOLD} \
    CONFIG.MMCM_DIVCLK_DIVIDE {5} \
    CONFIG.PRIMITIVE {PLL} \
    CONFIG.PRIM_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.SECONDARY_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.USE_BOARD_FLOW {true} \
    CONFIG.USE_LOCKED {false} \
    CONFIG.USE_PHASE_ALIGNMENT {true} \
    CONFIG.USE_RESET {false} \
    CONFIG.USE_SAFE_CLOCK_STARTUP {true} \
  ] $clk_wiz_0


  # --------------------------------------------------------
  # Reset controller
  # --------------------------------------------------------
  set proc_sys_reset_0 [create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0]

  # --------------------------------------------------------
  # Wrapper
  # --------------------------------------------------------
  set wrapper_inst [create_bd_cell -type module -reference $wrapper_name ${wrapper_name}_0]

  # --------------------------------------------------------
  # Interface connections
  # --------------------------------------------------------
  connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] [get_bd_intf_pins smartconnect_0/S00_AXI]
  connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M00_AXI] [get_bd_intf_pins ${wrapper_name}_0/SYS_RESET_AXI]
  connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M01_AXI] [get_bd_intf_pins ${wrapper_name}_0/S_INSTR_AXI]
  connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M02_AXI] [get_bd_intf_pins ${wrapper_name}_0/S_DATA_AXI]
  connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M03_AXI] [get_bd_intf_pins ${wrapper_name}_0/S_PTC_FIFO_AXI]
  connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M04_AXI] [get_bd_intf_pins ${wrapper_name}_0/S_CTP_FIFO_AXI]



  # --------------------------------------------------------
  # Clock / reset connections
  # --------------------------------------------------------
  connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins ${wrapper_name}_0/core_clk]

  connect_bd_net [get_bd_pins proc_sys_reset_0/interconnect_aresetn] \
                 [get_bd_pins smartconnect_0/aresetn]

  connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
                 [get_bd_pins ${wrapper_name}_0/axi_rstn]

  connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] \
                 [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK] \
                 [get_bd_pins smartconnect_0/aclk] \
                 [get_bd_pins proc_sys_reset_0/slowest_sync_clk] \
                 [get_bd_pins ${wrapper_name}_0/axi_clk]

  connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] \
                 [get_bd_pins proc_sys_reset_0/ext_reset_in]

  connect_bd_net [get_bd_ports sys_clock] \
                 [get_bd_pins clk_wiz_0/clk_in1]

  # --------------------------------------------------------
  # Address map
  # --------------------------------------------------------
  assign_bd_address -offset 0x60000000 -range 0x00010000 \
    -target_address_space [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs ${wrapper_name}_0/SYS_RESET_AXI/reg0] -force

  assign_bd_address -offset 0x60100000 -range 0x00010000 \
    -target_address_space [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs ${wrapper_name}_0/S_INSTR_AXI/reg0] -force

  assign_bd_address -offset 0x60140000 -range 0x00010000 \
    -target_address_space [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs ${wrapper_name}_0/S_DATA_AXI/reg0] -force

  assign_bd_address -offset 0x60150000 -range 0x00010000 \
    -target_address_space [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs ${wrapper_name}_0/S_PTC_FIFO_AXI/reg0] -force

  assign_bd_address -offset 0x60160000 -range 0x00010000 \
    -target_address_space [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs ${wrapper_name}_0/S_CTP_FIFO_AXI/reg0] -force

  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
  close_bd_design $design_name
}

if { [llength [get_files -quiet -norecurse [list block_design.bd]]] == 0 } {
  set rc [cr_bd_block_design ""]
  if { $rc ne "" && $rc != 0 } {
    error "block_design creation failed with return code $rc"
  }
}

# ==========================================================
# Generated products + wrapper
# ==========================================================

set bd_file [get_files block_design.bd]
generate_target all $bd_file

set wrapper_paths [make_wrapper -files [get_files block_design.bd] -top -force]
foreach wp $wrapper_paths {
  if { [llength [get_files -quiet -of_objects [get_filesets sources_1] [list "*[file tail $wp]"]]] == 0 } {
    add_files -norecurse -fileset sources_1 $wp
  }
}

set_property top block_design_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "design.tcl completed successfully."
