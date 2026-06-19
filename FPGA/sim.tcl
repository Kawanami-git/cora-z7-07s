# SPDX-License-Identifier: MIT
#
# Simulation fileset and AXI-VIP based simulation BD creation.
# Vivado 2025.2 project-mode compatible.

if { [current_project -quiet] eq "" } {
  error "sim.tcl must be sourced from an open Vivado project."
}
if { ![info exists origin_dir] } {
  set origin_dir [file normalize [file dirname [info script]]]
}
if { ![info exists ::ARCHI] } {
  set ::ARCHI 32
}

proc _sr_import_sim_file {fileset relpath} {
  global origin_dir
  set abs_path [file normalize [file join $origin_dir $relpath]]
  if { ![file exists $abs_path] } {
    error "Missing simulation file: $abs_path"
  }
  set basename [file tail $abs_path]
  if { [llength [get_files -quiet -of_objects [get_filesets $fileset] [list "*$basename"]]] == 0 } {
    import_files -quiet -fileset $fileset $abs_path
  }
  set file_obj [get_files -quiet -of_objects [get_filesets $fileset] [list "*$basename"]]
  if { $file_obj eq "" } {
    return
  }
  if {[string match "*.sv" $basename]} {
    set_property file_type SystemVerilog $file_obj
  }
  set_property is_enabled 1 $file_obj
  set_property is_global_include 0 $file_obj
  set_property library xil_defaultlib $file_obj
  set_property path_mode RelativeFirst $file_obj
  set_property used_in "simulation" $file_obj
  set_property used_in_implementation 0 $file_obj
  set_property used_in_simulation 1 $file_obj
  set_property used_in_synthesis 0 $file_obj
}

proc _sr_get_bd_addr_space {patterns} {
  foreach pattern $patterns {
    set spaces [get_bd_addr_spaces -quiet $pattern]
    if {[llength $spaces] > 0} {
      return [lindex $spaces 0]
    }
  }

  # Fallback for Vivado versions that do not match wildcarded address-space names
  # exactly the same way.
  set all_spaces [get_bd_addr_spaces -quiet]
  foreach pattern $patterns {
    foreach space $all_spaces {
      if {[string match $pattern $space]} {
        return $space
      }
    }
  }

  puts "ERROR: Unable to find a matching BD address space."
  puts "  Requested patterns: $patterns"
  puts "  Available address spaces:"
  foreach space $all_spaces {
    puts "    $space"
  }
  error "Missing BD address space"
}

proc _sr_get_bd_addr_seg {cell_name intf_name} {
  set candidates [list \
    "${cell_name}/${intf_name}/reg0" \
    "${cell_name}/${intf_name}/Reg" \
    "${cell_name}/${intf_name}/*" \
  ]

  foreach pattern $candidates {
    set segs [get_bd_addr_segs -quiet $pattern]
    if {[llength $segs] > 0} {
      return [lindex $segs 0]
    }
  }

  set all_segs [get_bd_addr_segs -quiet]
  puts "ERROR: Unable to find BD address segment for ${cell_name}/${intf_name}."
  puts "  Tried patterns: $candidates"
  puts "  Available address segments:"
  foreach seg $all_segs {
    puts "    $seg"
  }
  error "Missing BD address segment"
}

proc _sr_assign_bd_address {master_addr_space cell_name intf_name offset range} {
  set addr_seg [_sr_get_bd_addr_seg $cell_name $intf_name]
  puts "Assigning $addr_seg at offset $offset, range $range, master $master_addr_space"
  assign_bd_address \
    -offset $offset \
    -range $range \
    -target_address_space $master_addr_space \
    $addr_seg \
    -force
}

if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}

_sr_import_sim_file sim_1 "sim/tb_system_firmware.sv"

set sim_fs [get_filesets sim_1]
set_property source_set sources_1 $sim_fs
set_property top tb_system_firmware $sim_fs
set_property top_auto_set 0 $sim_fs
set_property top_lib xil_defaultlib $sim_fs
set_property simulator_launch_mode off $sim_fs
set_property xsim.compile.xvhdl.relax 1 $sim_fs
set_property xsim.compile.xvhdl.nosort 1 $sim_fs
set_property xsim.compile.xvlog.relax 1 $sim_fs
set_property xsim.compile.xvlog.nosort 1 $sim_fs
set_property xsim.elaborate.debug_level typical $sim_fs
set_property xsim.elaborate.relax 1 $sim_fs
set_property xsim.elaborate.load_glbl 1 $sim_fs
set_property xsim.simulate.runtime all $sim_fs

proc cr_bd_simulation { {parentCell ""} } {
  # The design created by this Tcl proc contains the following module references:
  #   riscv_env_wrapper / riscv_env_wrapper_64
  #
  # The simulation BD is AXI-VIP based. It does not instantiate processing_system7,
  # so the address map must target the AXI VIP master address space.

  set design_name simulation
  common::send_gid_msg -ssname BD::TCL -id 2010 -severity "INFO" \
    "Currently there is no design <$design_name> in project, so creating one..."

  create_bd_design $design_name

  # ----------------------------------------------------------
  # Check IP presence
  # ----------------------------------------------------------
  set list_check_ips "\
  xilinx.com:ip:axi_vip:1.1\
  xilinx.com:ip:clk_wiz:6.0\
  xilinx.com:ip:proc_sys_reset:5.0\
  xilinx.com:ip:smartconnect:1.0\
  "
  set list_ips_missing ""
  common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" \
    "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."
  foreach ip_vlnv $list_check_ips {
    if {[get_ipdefs -all $ip_vlnv] eq ""} {
      lappend list_ips_missing $ip_vlnv
    }
  }
  if {$list_ips_missing ne ""} {
    error "Missing IPs in catalog: $list_ips_missing"
  }

  # ----------------------------------------------------------
  # Check wrapper presence
  # ----------------------------------------------------------
  if {$::ARCHI == 64} {
    set wrapper_name riscv_env_wrapper_64
  } else {
    set wrapper_name riscv_env_wrapper
  }
  set wrapper_cell_name ${wrapper_name}_0
  common::send_gid_msg -ssname BD::TCL -id 2020 -severity "INFO" \
    "Checking if the following modules exist in the project's sources: $wrapper_name ."
  if { [can_resolve_reference $wrapper_name] == 0 } {
    error "Module $wrapper_name not found in project sources."
  }

  if { $parentCell eq "" } {
    set parentCell [get_bd_cells /]
  }
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
    error "Unable to find parent cell <$parentCell>!"
  }
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
    error "Parent <$parentObj> has TYPE = <$parentType>. Expected <hier>."
  }

  set oldCurInst [current_bd_instance .]
  current_bd_instance $parentObj

  # ----------------------------------------------------------
  # Ports
  # ----------------------------------------------------------
  set sys_clock [ create_bd_port -dir I -type clk -freq_hz 125000000 sys_clock ]
  set_property CONFIG.PHASE {0.0} $sys_clock

  # ACTIVE_HIGH reset for clk_wiz and proc_sys_reset ext_reset_in
  set reset_rtl [ create_bd_port -dir I -type rst reset_rtl ]
  set_property CONFIG.POLARITY {ACTIVE_HIGH} $reset_rtl

  # ----------------------------------------------------------
  # IPs
  # ----------------------------------------------------------
  set axi_vip_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_vip:1.1 axi_vip_0 ]
  set_property -dict [list \
    CONFIG.ADDR_WIDTH {32} \
    CONFIG.ARUSER_WIDTH {0} \
    CONFIG.AWUSER_WIDTH {0} \
    CONFIG.BUSER_WIDTH {0} \
    CONFIG.DATA_WIDTH {32} \
    CONFIG.HAS_BRESP {1} \
    CONFIG.HAS_BURST {1} \
    CONFIG.HAS_CACHE {1} \
    CONFIG.HAS_LOCK {1} \
    CONFIG.HAS_PROT {1} \
    CONFIG.HAS_QOS {1} \
    CONFIG.HAS_REGION {1} \
    CONFIG.HAS_RRESP {1} \
    CONFIG.HAS_WSTRB {1} \
    CONFIG.ID_WIDTH {8} \
    CONFIG.INTERFACE_MODE {MASTER} \
    CONFIG.PROTOCOL {AXI4} \
    CONFIG.READ_WRITE_MODE {READ_WRITE} \
    CONFIG.RUSER_BITS_PER_BYTE {0} \
    CONFIG.SUPPORTS_NARROW {1} \
    CONFIG.WUSER_BITS_PER_BYTE {0} \
  ] $axi_vip_0

  set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
  set_property -dict [list \
    CONFIG.CLK_IN1_BOARD_INTERFACE {sys_clock} \
    CONFIG.USE_BOARD_FLOW {true} \
  ] $clk_wiz_0

  set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]

  set wrapper_inst [create_bd_cell -type module -reference $wrapper_name $wrapper_cell_name]

  set smartconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_0 ]
  set_property -dict [list \
    CONFIG.NUM_MI {5} \
    CONFIG.NUM_SI {1} \
    CONFIG.NUM_CLKS {1} \
  ] $smartconnect_0

  # ----------------------------------------------------------
  # AXI connections
  # ----------------------------------------------------------
  connect_bd_intf_net [get_bd_intf_pins axi_vip_0/M_AXI] [get_bd_intf_pins smartconnect_0/S00_AXI]
  connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M00_AXI] [get_bd_intf_pins ${wrapper_cell_name}/SYS_RESET_AXI]
  connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M01_AXI] [get_bd_intf_pins ${wrapper_cell_name}/S_INSTR_AXI]
  connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M02_AXI] [get_bd_intf_pins ${wrapper_cell_name}/S_DATA_AXI]
  connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M03_AXI] [get_bd_intf_pins ${wrapper_cell_name}/S_PTC_FIFO_AXI]
  connect_bd_intf_net [get_bd_intf_pins smartconnect_0/M04_AXI] [get_bd_intf_pins ${wrapper_cell_name}/S_CTP_FIFO_AXI]
  

  # ----------------------------------------------------------
  # Clock / reset connections
  # ----------------------------------------------------------
  connect_bd_net [get_bd_ports sys_clock] [get_bd_pins clk_wiz_0/clk_in1]

  connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] \
    [get_bd_pins axi_vip_0/aclk] \
    [get_bd_pins proc_sys_reset_0/slowest_sync_clk] \
    [get_bd_pins smartconnect_0/aclk] \
    [get_bd_pins ${wrapper_cell_name}/axi_clk] \
    [get_bd_pins ${wrapper_cell_name}/core_clk]

  connect_bd_net [get_bd_pins clk_wiz_0/locked] \
    [get_bd_pins proc_sys_reset_0/dcm_locked]

  # External ACTIVE_HIGH reset request
  connect_bd_net [get_bd_ports reset_rtl] \
    [get_bd_pins proc_sys_reset_0/ext_reset_in] \
    [get_bd_pins clk_wiz_0/reset]

  connect_bd_net [get_bd_pins proc_sys_reset_0/peripheral_aresetn] \
    [get_bd_pins axi_vip_0/aresetn] \
    [get_bd_pins smartconnect_0/aresetn] \
    [get_bd_pins ${wrapper_cell_name}/axi_rstn]

  # ----------------------------------------------------------
  # Address map
  # ----------------------------------------------------------
  # This simulation BD has no processing_system7_0 cell. The AXI VIP is the
  # address-space master that drives the SmartConnect, so all slave segments must
  # be mapped into axi_vip_0/M_AXI.
  set axi_vip_addr_space [_sr_get_bd_addr_space [list \
    "axi_vip_0/M_AXI" \
    "axi_vip_0/*" \
    "*axi_vip_0*" \
  ]]

  _sr_assign_bd_address $axi_vip_addr_space $wrapper_cell_name SYS_RESET_AXI 0x60000000 0x00010000
  _sr_assign_bd_address $axi_vip_addr_space $wrapper_cell_name S_INSTR_AXI  0x60100000 0x00010000
  _sr_assign_bd_address $axi_vip_addr_space $wrapper_cell_name S_DATA_AXI   0x60140000 0x00010000
  _sr_assign_bd_address $axi_vip_addr_space $wrapper_cell_name S_PTC_FIFO_AXI 0x60150000 0x00010000
  _sr_assign_bd_address $axi_vip_addr_space $wrapper_cell_name S_CTP_FIFO_AXI 0x60160000 0x00010000

  current_bd_instance $oldCurInst
  validate_bd_design
  save_bd_design
  close_bd_design $design_name
}

if { [llength [get_files -quiet -norecurse [list simulation.bd]]] == 0 } {
  cr_bd_simulation ""
}

set bd_file [get_files simulation.bd]
set_property EXCLUDE_DEBUG_LOGIC 0 $bd_file
set_property GENERATE_SYNTH_CHECKPOINT 0 $bd_file
set_property IS_ENABLED 1 $bd_file
set_property IS_GLOBAL_INCLUDE 0 $bd_file
set_property PATH_MODE RelativeFirst $bd_file
set_property PFM_NAME "" $bd_file
set_property REGISTERED_WITH_MANAGER 1 $bd_file
set_property SYNTH_CHECKPOINT_MODE None $bd_file
set_property USED_IN simulation $bd_file
set_property USED_IN_IMPLEMENTATION 0 $bd_file
set_property USED_IN_SIMULATION 1 $bd_file
set_property USED_IN_SYNTHESIS 0 $bd_file

generate_target all $bd_file
export_ip_user_files -of_objects $bd_file -no_script -force -quiet

set wrapper_paths [make_wrapper -top -fileset sim_1 -files [get_files -norecurse [list simulation.bd]] -force]
foreach wp $wrapper_paths {
  set wp_norm [file normalize $wp]
  if { [llength [get_files -quiet -of_objects [get_filesets sim_1] [list "*[file tail $wp_norm]"]]] == 0 } {
    add_files -norecurse -fileset sim_1 $wp_norm
  }
}

if {$::ARCHI == 64} {
  set_property verilog_define {ARCHI=64} [get_filesets sim_1]
} else {
  set_property verilog_define {ARCHI=32} [get_filesets sim_1]
}


update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
