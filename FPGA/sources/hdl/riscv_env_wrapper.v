// SPDX-License-Identifier: MIT
/*
********************************************************************************
* \file       riscv_env_wrapper.v
* \brief      BD-friendly Verilog wrapper for riscv_core_harness
* \author     OpenAI
* \date       24/05/2026
* \version    3.0
*
* \details
*   This wrapper is intended for Vivado Block Design / Module Reference use.
*   It keeps the internal SystemVerilog top-level (riscv_core_harness.sv)
*   unchanged, while exposing AXI ports with standard AXI naming and Vivado
*   interface attributes so that IP Integrator can infer grouped AXI interfaces.
*
*   Exposed AXI slave interfaces:
*     - SYS_RESET_AXI    : system reset peripheral
*     - S_INSTR_AXI      : instruction memory loader/readback
*     - S_DATA_AXI       : data memory loader/readback
*     - S_PTC_FIFO_AXI   : platform-to-core FIFO
*     - S_CTP_FIFO_AXI   : core-to-platform FIFO
*
*   SPIKE-only simulation ports are intentionally not exposed here.
********************************************************************************
*/
module riscv_env_wrapper #(
    parameter             Target             = 2,
    parameter             Archi              = 32,
    parameter             ByteLength         = 8,
    parameter             BeWidth            = Archi / ByteLength,
    parameter             InstrWidth         = 32,
    parameter             InstrBeWidth       = InstrWidth / ByteLength,
    parameter             NoPerfectMemory    = 0,
    parameter [Archi-1:0] StartAddr          = 'h00100000,
    parameter             EnablePerfCounters = 1'b1
) (
    /*
     * Clocks / reset
     */
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 axi_clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF SYS_RESET_AXI:S_INSTR_AXI:S_DATA_AXI:S_PTC_FIFO_AXI:S_CTP_FIFO_AXI, ASSOCIATED_RESET axi_rstn" *)
    input wire axi_clk, (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 axi_rstn RST" *)
        (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input wire axi_rstn, (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 core_clk CLK" *)
    input wire core_clk,

    /*
     * AXI slave interface: system reset peripheral
     */
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI AWID" *)
    input wire [7:0] SYS_RESET_AXI_AWID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI AWADDR" *)
    input wire [Archi-1:0] SYS_RESET_AXI_AWADDR,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI AWLEN" *)
    input wire [7:0] SYS_RESET_AXI_AWLEN,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI AWSIZE" *)
    input wire [2:0] SYS_RESET_AXI_AWSIZE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI AWBURST" *)
    input wire [1:0] SYS_RESET_AXI_AWBURST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI AWLOCK" *)
    input wire [1:0] SYS_RESET_AXI_AWLOCK,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI AWCACHE" *)
    input wire [3:0] SYS_RESET_AXI_AWCACHE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI AWPROT" *)
    input wire [2:0] SYS_RESET_AXI_AWPROT,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI AWVALID" *)
    input wire SYS_RESET_AXI_AWVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI AWREADY" *)
    output wire SYS_RESET_AXI_AWREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI WDATA" *)
    input wire [Archi-1:0] SYS_RESET_AXI_WDATA,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI WSTRB" *)
    input wire [BeWidth-1:0] SYS_RESET_AXI_WSTRB,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI WLAST" *)
    input wire SYS_RESET_AXI_WLAST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI WVALID" *)
    input wire SYS_RESET_AXI_WVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI WREADY" *)
    output wire SYS_RESET_AXI_WREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI BID" *)
    output wire [7:0] SYS_RESET_AXI_BID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI BRESP" *)
    output wire [1:0] SYS_RESET_AXI_BRESP,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI BVALID" *)
    output wire SYS_RESET_AXI_BVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI BREADY" *)
    input wire SYS_RESET_AXI_BREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI ARID" *)
    input wire [7:0] SYS_RESET_AXI_ARID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI ARADDR" *)
    input wire [Archi-1:0] SYS_RESET_AXI_ARADDR,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI ARLEN" *)
    input wire [7:0] SYS_RESET_AXI_ARLEN,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI ARSIZE" *)
    input wire [2:0] SYS_RESET_AXI_ARSIZE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI ARBURST" *)
    input wire [1:0] SYS_RESET_AXI_ARBURST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI ARLOCK" *)
    input wire [1:0] SYS_RESET_AXI_ARLOCK,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI ARCACHE" *)
    input wire [3:0] SYS_RESET_AXI_ARCACHE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI ARPROT" *)
    input wire [2:0] SYS_RESET_AXI_ARPROT,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI ARVALID" *)
    input wire SYS_RESET_AXI_ARVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI ARREADY" *)
    output wire SYS_RESET_AXI_ARREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI RID" *)
    output wire [7:0] SYS_RESET_AXI_RID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI RDATA" *)
    output wire [Archi-1:0] SYS_RESET_AXI_RDATA,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI RRESP" *)
    output wire [1:0] SYS_RESET_AXI_RRESP,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI RLAST" *)
    output wire SYS_RESET_AXI_RLAST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI RVALID" *)
    output wire SYS_RESET_AXI_RVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 SYS_RESET_AXI RREADY" *)
    input wire SYS_RESET_AXI_RREADY,

    /*
     * AXI slave interface: instruction memory loader
     */
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI AWID" *)
    input wire [7:0] S_INSTR_AXI_AWID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI AWADDR" *)
    input wire [Archi-1:0] S_INSTR_AXI_AWADDR,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI AWLEN" *)
    input wire [7:0] S_INSTR_AXI_AWLEN,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI AWSIZE" *)
    input wire [2:0] S_INSTR_AXI_AWSIZE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI AWBURST" *)
    input wire [1:0] S_INSTR_AXI_AWBURST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI AWLOCK" *)
    input wire [1:0] S_INSTR_AXI_AWLOCK,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI AWCACHE" *)
    input wire [3:0] S_INSTR_AXI_AWCACHE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI AWPROT" *)
    input wire [2:0] S_INSTR_AXI_AWPROT,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI AWVALID" *)
    input wire S_INSTR_AXI_AWVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI AWREADY" *)
    output wire S_INSTR_AXI_AWREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI WDATA" *)
    input wire [InstrWidth-1:0] S_INSTR_AXI_WDATA,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI WSTRB" *)
    input wire [InstrBeWidth-1:0] S_INSTR_AXI_WSTRB,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI WLAST" *)
    input wire S_INSTR_AXI_WLAST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI WVALID" *)
    input wire S_INSTR_AXI_WVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI WREADY" *)
    output wire S_INSTR_AXI_WREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI BID" *)
    output wire [7:0] S_INSTR_AXI_BID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI BRESP" *)
    output wire [1:0] S_INSTR_AXI_BRESP,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI BVALID" *)
    output wire S_INSTR_AXI_BVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI BREADY" *)
    input wire S_INSTR_AXI_BREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI ARID" *)
    input wire [7:0] S_INSTR_AXI_ARID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI ARADDR" *)
    input wire [Archi-1:0] S_INSTR_AXI_ARADDR,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI ARLEN" *)
    input wire [7:0] S_INSTR_AXI_ARLEN,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI ARSIZE" *)
    input wire [2:0] S_INSTR_AXI_ARSIZE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI ARBURST" *)
    input wire [1:0] S_INSTR_AXI_ARBURST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI ARLOCK" *)
    input wire [1:0] S_INSTR_AXI_ARLOCK,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI ARCACHE" *)
    input wire [3:0] S_INSTR_AXI_ARCACHE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI ARPROT" *)
    input wire [2:0] S_INSTR_AXI_ARPROT,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI ARVALID" *)
    input wire S_INSTR_AXI_ARVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI ARREADY" *)
    output wire S_INSTR_AXI_ARREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI RID" *)
    output wire [7:0] S_INSTR_AXI_RID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI RDATA" *)
    output wire [InstrWidth-1:0] S_INSTR_AXI_RDATA,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI RRESP" *)
    output wire [1:0] S_INSTR_AXI_RRESP,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI RLAST" *)
    output wire S_INSTR_AXI_RLAST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI RVALID" *)
    output wire S_INSTR_AXI_RVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_INSTR_AXI RREADY" *)
    input wire S_INSTR_AXI_RREADY,

    /*
     * AXI slave interface: data memory loader/access
     */
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI AWID" *)
    input wire [7:0] S_DATA_AXI_AWID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI AWADDR" *)
    input wire [Archi-1:0] S_DATA_AXI_AWADDR,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI AWLEN" *)
    input wire [7:0] S_DATA_AXI_AWLEN,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI AWSIZE" *)
    input wire [2:0] S_DATA_AXI_AWSIZE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI AWBURST" *)
    input wire [1:0] S_DATA_AXI_AWBURST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI AWLOCK" *)
    input wire [1:0] S_DATA_AXI_AWLOCK,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI AWCACHE" *)
    input wire [3:0] S_DATA_AXI_AWCACHE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI AWPROT" *)
    input wire [2:0] S_DATA_AXI_AWPROT,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI AWVALID" *)
    input wire S_DATA_AXI_AWVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI AWREADY" *)
    output wire S_DATA_AXI_AWREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI WDATA" *)
    input wire [Archi-1:0] S_DATA_AXI_WDATA,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI WSTRB" *)
    input wire [BeWidth-1:0] S_DATA_AXI_WSTRB,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI WLAST" *)
    input wire S_DATA_AXI_WLAST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI WVALID" *)
    input wire S_DATA_AXI_WVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI WREADY" *)
    output wire S_DATA_AXI_WREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI BID" *)
    output wire [7:0] S_DATA_AXI_BID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI BRESP" *)
    output wire [1:0] S_DATA_AXI_BRESP,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI BVALID" *)
    output wire S_DATA_AXI_BVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI BREADY" *)
    input wire S_DATA_AXI_BREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI ARID" *)
    input wire [7:0] S_DATA_AXI_ARID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI ARADDR" *)
    input wire [Archi-1:0] S_DATA_AXI_ARADDR,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI ARLEN" *)
    input wire [7:0] S_DATA_AXI_ARLEN,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI ARSIZE" *)
    input wire [2:0] S_DATA_AXI_ARSIZE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI ARBURST" *)
    input wire [1:0] S_DATA_AXI_ARBURST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI ARLOCK" *)
    input wire [1:0] S_DATA_AXI_ARLOCK,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI ARCACHE" *)
    input wire [3:0] S_DATA_AXI_ARCACHE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI ARPROT" *)
    input wire [2:0] S_DATA_AXI_ARPROT,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI ARVALID" *)
    input wire S_DATA_AXI_ARVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI ARREADY" *)
    output wire S_DATA_AXI_ARREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI RID" *)
    output wire [7:0] S_DATA_AXI_RID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI RDATA" *)
    output wire [Archi-1:0] S_DATA_AXI_RDATA,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI RRESP" *)
    output wire [1:0] S_DATA_AXI_RRESP,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI RLAST" *)
    output wire S_DATA_AXI_RLAST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI RVALID" *)
    output wire S_DATA_AXI_RVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_DATA_AXI RREADY" *)
    input wire S_DATA_AXI_RREADY,

    /*
     * AXI slave interface: platform-to-core FIFO
     */
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI AWID" *)
    input wire [7:0] S_PTC_FIFO_AXI_AWID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI AWADDR" *)
    input wire [Archi-1:0] S_PTC_FIFO_AXI_AWADDR,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI AWLEN" *)
    input wire [7:0] S_PTC_FIFO_AXI_AWLEN,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI AWSIZE" *)
    input wire [2:0] S_PTC_FIFO_AXI_AWSIZE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI AWBURST" *)
    input wire [1:0] S_PTC_FIFO_AXI_AWBURST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI AWLOCK" *)
    input wire [1:0] S_PTC_FIFO_AXI_AWLOCK,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI AWCACHE" *)
    input wire [3:0] S_PTC_FIFO_AXI_AWCACHE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI AWPROT" *)
    input wire [2:0] S_PTC_FIFO_AXI_AWPROT,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI AWVALID" *)
    input wire S_PTC_FIFO_AXI_AWVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI AWREADY" *)
    output wire S_PTC_FIFO_AXI_AWREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI WDATA" *)
    input wire [Archi-1:0] S_PTC_FIFO_AXI_WDATA,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI WSTRB" *)
    input wire [BeWidth-1:0] S_PTC_FIFO_AXI_WSTRB,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI WLAST" *)
    input wire S_PTC_FIFO_AXI_WLAST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI WVALID" *)
    input wire S_PTC_FIFO_AXI_WVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI WREADY" *)
    output wire S_PTC_FIFO_AXI_WREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI BID" *)
    output wire [7:0] S_PTC_FIFO_AXI_BID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI BRESP" *)
    output wire [1:0] S_PTC_FIFO_AXI_BRESP,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI BVALID" *)
    output wire S_PTC_FIFO_AXI_BVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI BREADY" *)
    input wire S_PTC_FIFO_AXI_BREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI ARID" *)
    input wire [7:0] S_PTC_FIFO_AXI_ARID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI ARADDR" *)
    input wire [Archi-1:0] S_PTC_FIFO_AXI_ARADDR,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI ARLEN" *)
    input wire [7:0] S_PTC_FIFO_AXI_ARLEN,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI ARSIZE" *)
    input wire [2:0] S_PTC_FIFO_AXI_ARSIZE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI ARBURST" *)
    input wire [1:0] S_PTC_FIFO_AXI_ARBURST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI ARLOCK" *)
    input wire [1:0] S_PTC_FIFO_AXI_ARLOCK,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI ARCACHE" *)
    input wire [3:0] S_PTC_FIFO_AXI_ARCACHE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI ARPROT" *)
    input wire [2:0] S_PTC_FIFO_AXI_ARPROT,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI ARVALID" *)
    input wire S_PTC_FIFO_AXI_ARVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI ARREADY" *)
    output wire S_PTC_FIFO_AXI_ARREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI RID" *)
    output wire [7:0] S_PTC_FIFO_AXI_RID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI RDATA" *)
    output wire [Archi-1:0] S_PTC_FIFO_AXI_RDATA,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI RRESP" *)
    output wire [1:0] S_PTC_FIFO_AXI_RRESP,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI RLAST" *)
    output wire S_PTC_FIFO_AXI_RLAST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI RVALID" *)
    output wire S_PTC_FIFO_AXI_RVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_PTC_FIFO_AXI RREADY" *)
    input wire S_PTC_FIFO_AXI_RREADY,

    /*
     * AXI slave interface: core-to-platform FIFO
     */
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI AWID" *)
    input wire [7:0] S_CTP_FIFO_AXI_AWID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI AWADDR" *)
    input wire [Archi-1:0] S_CTP_FIFO_AXI_AWADDR,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI AWLEN" *)
    input wire [7:0] S_CTP_FIFO_AXI_AWLEN,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI AWSIZE" *)
    input wire [2:0] S_CTP_FIFO_AXI_AWSIZE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI AWBURST" *)
    input wire [1:0] S_CTP_FIFO_AXI_AWBURST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI AWLOCK" *)
    input wire [1:0] S_CTP_FIFO_AXI_AWLOCK,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI AWCACHE" *)
    input wire [3:0] S_CTP_FIFO_AXI_AWCACHE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI AWPROT" *)
    input wire [2:0] S_CTP_FIFO_AXI_AWPROT,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI AWVALID" *)
    input wire S_CTP_FIFO_AXI_AWVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI AWREADY" *)
    output wire S_CTP_FIFO_AXI_AWREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI WDATA" *)
    input wire [Archi-1:0] S_CTP_FIFO_AXI_WDATA,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI WSTRB" *)
    input wire [BeWidth-1:0] S_CTP_FIFO_AXI_WSTRB,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI WLAST" *)
    input wire S_CTP_FIFO_AXI_WLAST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI WVALID" *)
    input wire S_CTP_FIFO_AXI_WVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI WREADY" *)
    output wire S_CTP_FIFO_AXI_WREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI BID" *)
    output wire [7:0] S_CTP_FIFO_AXI_BID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI BRESP" *)
    output wire [1:0] S_CTP_FIFO_AXI_BRESP,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI BVALID" *)
    output wire S_CTP_FIFO_AXI_BVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI BREADY" *)
    input wire S_CTP_FIFO_AXI_BREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI ARID" *)
    input wire [7:0] S_CTP_FIFO_AXI_ARID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI ARADDR" *)
    input wire [Archi-1:0] S_CTP_FIFO_AXI_ARADDR,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI ARLEN" *)
    input wire [7:0] S_CTP_FIFO_AXI_ARLEN,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI ARSIZE" *)
    input wire [2:0] S_CTP_FIFO_AXI_ARSIZE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI ARBURST" *)
    input wire [1:0] S_CTP_FIFO_AXI_ARBURST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI ARLOCK" *)
    input wire [1:0] S_CTP_FIFO_AXI_ARLOCK,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI ARCACHE" *)
    input wire [3:0] S_CTP_FIFO_AXI_ARCACHE,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI ARPROT" *)
    input wire [2:0] S_CTP_FIFO_AXI_ARPROT,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI ARVALID" *)
    input wire S_CTP_FIFO_AXI_ARVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI ARREADY" *)
    output wire S_CTP_FIFO_AXI_ARREADY,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI RID" *)
    output wire [7:0] S_CTP_FIFO_AXI_RID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI RDATA" *)
    output wire [Archi-1:0] S_CTP_FIFO_AXI_RDATA,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI RRESP" *)
    output wire [1:0] S_CTP_FIFO_AXI_RRESP,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI RLAST" *)
    output wire S_CTP_FIFO_AXI_RLAST,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI RVALID" *)
    output wire S_CTP_FIFO_AXI_RVALID,
        (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_CTP_FIFO_AXI RREADY" *)
    input wire S_CTP_FIFO_AXI_RREADY
);

  riscv_core_harness #(
      .Target            (Target),
      .Archi             (Archi),
      .ByteLength        (ByteLength),
      .BeWidth           (BeWidth),
      .InstrWidth        (InstrWidth),
      .InstrBeWidth      (InstrBeWidth),
      .NoPerfectMemory   (NoPerfectMemory),
      .StartAddr         (StartAddr),
      .EnablePerfCounters(EnablePerfCounters)
  ) u_riscv_core_harness (
      .core_clk_i(core_clk),
      .axi_clk_i (axi_clk),
      .axi_rstn_i(axi_rstn),

      .s_sys_reset_awid_i   (SYS_RESET_AXI_AWID),
      .s_sys_reset_awaddr_i (SYS_RESET_AXI_AWADDR),
      .s_sys_reset_awlen_i  (SYS_RESET_AXI_AWLEN),
      .s_sys_reset_awsize_i (SYS_RESET_AXI_AWSIZE),
      .s_sys_reset_awburst_i(SYS_RESET_AXI_AWBURST),
      .s_sys_reset_awlock_i (SYS_RESET_AXI_AWLOCK),
      .s_sys_reset_awcache_i(SYS_RESET_AXI_AWCACHE),
      .s_sys_reset_awprot_i (SYS_RESET_AXI_AWPROT),
      .s_sys_reset_awvalid_i(SYS_RESET_AXI_AWVALID),
      .s_sys_reset_awready_o(SYS_RESET_AXI_AWREADY),
      .s_sys_reset_wdata_i  (SYS_RESET_AXI_WDATA),
      .s_sys_reset_wstrb_i  (SYS_RESET_AXI_WSTRB),
      .s_sys_reset_wlast_i  (SYS_RESET_AXI_WLAST),
      .s_sys_reset_wvalid_i (SYS_RESET_AXI_WVALID),
      .s_sys_reset_wready_o (SYS_RESET_AXI_WREADY),
      .s_sys_reset_bid_o    (SYS_RESET_AXI_BID),
      .s_sys_reset_bresp_o  (SYS_RESET_AXI_BRESP),
      .s_sys_reset_bvalid_o (SYS_RESET_AXI_BVALID),
      .s_sys_reset_bready_i (SYS_RESET_AXI_BREADY),
      .s_sys_reset_arid_i   (SYS_RESET_AXI_ARID),
      .s_sys_reset_araddr_i (SYS_RESET_AXI_ARADDR),
      .s_sys_reset_arlen_i  (SYS_RESET_AXI_ARLEN),
      .s_sys_reset_arsize_i (SYS_RESET_AXI_ARSIZE),
      .s_sys_reset_arburst_i(SYS_RESET_AXI_ARBURST),
      .s_sys_reset_arlock_i (SYS_RESET_AXI_ARLOCK),
      .s_sys_reset_arcache_i(SYS_RESET_AXI_ARCACHE),
      .s_sys_reset_arprot_i (SYS_RESET_AXI_ARPROT),
      .s_sys_reset_arvalid_i(SYS_RESET_AXI_ARVALID),
      .s_sys_reset_arready_o(SYS_RESET_AXI_ARREADY),
      .s_sys_reset_rid_o    (SYS_RESET_AXI_RID),
      .s_sys_reset_rdata_o  (SYS_RESET_AXI_RDATA),
      .s_sys_reset_rresp_o  (SYS_RESET_AXI_RRESP),
      .s_sys_reset_rlast_o  (SYS_RESET_AXI_RLAST),
      .s_sys_reset_rvalid_o (SYS_RESET_AXI_RVALID),
      .s_sys_reset_rready_i (SYS_RESET_AXI_RREADY),

      .s_instr_awid_i   (S_INSTR_AXI_AWID),
      .s_instr_awaddr_i (S_INSTR_AXI_AWADDR),
      .s_instr_awlen_i  (S_INSTR_AXI_AWLEN),
      .s_instr_awsize_i (S_INSTR_AXI_AWSIZE),
      .s_instr_awburst_i(S_INSTR_AXI_AWBURST),
      .s_instr_awlock_i (S_INSTR_AXI_AWLOCK),
      .s_instr_awcache_i(S_INSTR_AXI_AWCACHE),
      .s_instr_awprot_i (S_INSTR_AXI_AWPROT),
      .s_instr_awvalid_i(S_INSTR_AXI_AWVALID),
      .s_instr_awready_o(S_INSTR_AXI_AWREADY),
      .s_instr_wdata_i  (S_INSTR_AXI_WDATA),
      .s_instr_wstrb_i  (S_INSTR_AXI_WSTRB),
      .s_instr_wlast_i  (S_INSTR_AXI_WLAST),
      .s_instr_wvalid_i (S_INSTR_AXI_WVALID),
      .s_instr_wready_o (S_INSTR_AXI_WREADY),
      .s_instr_bid_o    (S_INSTR_AXI_BID),
      .s_instr_bresp_o  (S_INSTR_AXI_BRESP),
      .s_instr_bvalid_o (S_INSTR_AXI_BVALID),
      .s_instr_bready_i (S_INSTR_AXI_BREADY),
      .s_instr_arid_i   (S_INSTR_AXI_ARID),
      .s_instr_araddr_i (S_INSTR_AXI_ARADDR),
      .s_instr_arlen_i  (S_INSTR_AXI_ARLEN),
      .s_instr_arsize_i (S_INSTR_AXI_ARSIZE),
      .s_instr_arburst_i(S_INSTR_AXI_ARBURST),
      .s_instr_arlock_i (S_INSTR_AXI_ARLOCK),
      .s_instr_arcache_i(S_INSTR_AXI_ARCACHE),
      .s_instr_arprot_i (S_INSTR_AXI_ARPROT),
      .s_instr_arvalid_i(S_INSTR_AXI_ARVALID),
      .s_instr_arready_o(S_INSTR_AXI_ARREADY),
      .s_instr_rid_o    (S_INSTR_AXI_RID),
      .s_instr_rdata_o  (S_INSTR_AXI_RDATA),
      .s_instr_rresp_o  (S_INSTR_AXI_RRESP),
      .s_instr_rlast_o  (S_INSTR_AXI_RLAST),
      .s_instr_rvalid_o (S_INSTR_AXI_RVALID),
      .s_instr_rready_i (S_INSTR_AXI_RREADY),

      .s_data_awid_i   (S_DATA_AXI_AWID),
      .s_data_awaddr_i (S_DATA_AXI_AWADDR),
      .s_data_awlen_i  (S_DATA_AXI_AWLEN),
      .s_data_awsize_i (S_DATA_AXI_AWSIZE),
      .s_data_awburst_i(S_DATA_AXI_AWBURST),
      .s_data_awlock_i (S_DATA_AXI_AWLOCK),
      .s_data_awcache_i(S_DATA_AXI_AWCACHE),
      .s_data_awprot_i (S_DATA_AXI_AWPROT),
      .s_data_awvalid_i(S_DATA_AXI_AWVALID),
      .s_data_awready_o(S_DATA_AXI_AWREADY),
      .s_data_wdata_i  (S_DATA_AXI_WDATA),
      .s_data_wstrb_i  (S_DATA_AXI_WSTRB),
      .s_data_wlast_i  (S_DATA_AXI_WLAST),
      .s_data_wvalid_i (S_DATA_AXI_WVALID),
      .s_data_wready_o (S_DATA_AXI_WREADY),
      .s_data_bid_o    (S_DATA_AXI_BID),
      .s_data_bresp_o  (S_DATA_AXI_BRESP),
      .s_data_bvalid_o (S_DATA_AXI_BVALID),
      .s_data_bready_i (S_DATA_AXI_BREADY),
      .s_data_arid_i   (S_DATA_AXI_ARID),
      .s_data_araddr_i (S_DATA_AXI_ARADDR),
      .s_data_arlen_i  (S_DATA_AXI_ARLEN),
      .s_data_arsize_i (S_DATA_AXI_ARSIZE),
      .s_data_arburst_i(S_DATA_AXI_ARBURST),
      .s_data_arlock_i (S_DATA_AXI_ARLOCK),
      .s_data_arcache_i(S_DATA_AXI_ARCACHE),
      .s_data_arprot_i (S_DATA_AXI_ARPROT),
      .s_data_arvalid_i(S_DATA_AXI_ARVALID),
      .s_data_arready_o(S_DATA_AXI_ARREADY),
      .s_data_rid_o    (S_DATA_AXI_RID),
      .s_data_rdata_o  (S_DATA_AXI_RDATA),
      .s_data_rresp_o  (S_DATA_AXI_RRESP),
      .s_data_rlast_o  (S_DATA_AXI_RLAST),
      .s_data_rvalid_o (S_DATA_AXI_RVALID),
      .s_data_rready_i (S_DATA_AXI_RREADY),

      .s_ptc_awid_i   (S_PTC_FIFO_AXI_AWID),
      .s_ptc_awaddr_i (S_PTC_FIFO_AXI_AWADDR),
      .s_ptc_awlen_i  (S_PTC_FIFO_AXI_AWLEN),
      .s_ptc_awsize_i (S_PTC_FIFO_AXI_AWSIZE),
      .s_ptc_awburst_i(S_PTC_FIFO_AXI_AWBURST),
      .s_ptc_awlock_i (S_PTC_FIFO_AXI_AWLOCK),
      .s_ptc_awcache_i(S_PTC_FIFO_AXI_AWCACHE),
      .s_ptc_awprot_i (S_PTC_FIFO_AXI_AWPROT),
      .s_ptc_awvalid_i(S_PTC_FIFO_AXI_AWVALID),
      .s_ptc_awready_o(S_PTC_FIFO_AXI_AWREADY),
      .s_ptc_wdata_i  (S_PTC_FIFO_AXI_WDATA),
      .s_ptc_wstrb_i  (S_PTC_FIFO_AXI_WSTRB),
      .s_ptc_wlast_i  (S_PTC_FIFO_AXI_WLAST),
      .s_ptc_wvalid_i (S_PTC_FIFO_AXI_WVALID),
      .s_ptc_wready_o (S_PTC_FIFO_AXI_WREADY),
      .s_ptc_bid_o    (S_PTC_FIFO_AXI_BID),
      .s_ptc_bresp_o  (S_PTC_FIFO_AXI_BRESP),
      .s_ptc_bvalid_o (S_PTC_FIFO_AXI_BVALID),
      .s_ptc_bready_i (S_PTC_FIFO_AXI_BREADY),
      .s_ptc_arid_i   (S_PTC_FIFO_AXI_ARID),
      .s_ptc_araddr_i (S_PTC_FIFO_AXI_ARADDR),
      .s_ptc_arlen_i  (S_PTC_FIFO_AXI_ARLEN),
      .s_ptc_arsize_i (S_PTC_FIFO_AXI_ARSIZE),
      .s_ptc_arburst_i(S_PTC_FIFO_AXI_ARBURST),
      .s_ptc_arlock_i (S_PTC_FIFO_AXI_ARLOCK),
      .s_ptc_arcache_i(S_PTC_FIFO_AXI_ARCACHE),
      .s_ptc_arprot_i (S_PTC_FIFO_AXI_ARPROT),
      .s_ptc_arvalid_i(S_PTC_FIFO_AXI_ARVALID),
      .s_ptc_arready_o(S_PTC_FIFO_AXI_ARREADY),
      .s_ptc_rid_o    (S_PTC_FIFO_AXI_RID),
      .s_ptc_rdata_o  (S_PTC_FIFO_AXI_RDATA),
      .s_ptc_rresp_o  (S_PTC_FIFO_AXI_RRESP),
      .s_ptc_rlast_o  (S_PTC_FIFO_AXI_RLAST),
      .s_ptc_rvalid_o (S_PTC_FIFO_AXI_RVALID),
      .s_ptc_rready_i (S_PTC_FIFO_AXI_RREADY),

      .s_ctp_awid_i   (S_CTP_FIFO_AXI_AWID),
      .s_ctp_awaddr_i (S_CTP_FIFO_AXI_AWADDR),
      .s_ctp_awlen_i  (S_CTP_FIFO_AXI_AWLEN),
      .s_ctp_awsize_i (S_CTP_FIFO_AXI_AWSIZE),
      .s_ctp_awburst_i(S_CTP_FIFO_AXI_AWBURST),
      .s_ctp_awlock_i (S_CTP_FIFO_AXI_AWLOCK),
      .s_ctp_awcache_i(S_CTP_FIFO_AXI_AWCACHE),
      .s_ctp_awprot_i (S_CTP_FIFO_AXI_AWPROT),
      .s_ctp_awvalid_i(S_CTP_FIFO_AXI_AWVALID),
      .s_ctp_awready_o(S_CTP_FIFO_AXI_AWREADY),
      .s_ctp_wdata_i  (S_CTP_FIFO_AXI_WDATA),
      .s_ctp_wstrb_i  (S_CTP_FIFO_AXI_WSTRB),
      .s_ctp_wlast_i  (S_CTP_FIFO_AXI_WLAST),
      .s_ctp_wvalid_i (S_CTP_FIFO_AXI_WVALID),
      .s_ctp_wready_o (S_CTP_FIFO_AXI_WREADY),
      .s_ctp_bid_o    (S_CTP_FIFO_AXI_BID),
      .s_ctp_bresp_o  (S_CTP_FIFO_AXI_BRESP),
      .s_ctp_bvalid_o (S_CTP_FIFO_AXI_BVALID),
      .s_ctp_bready_i (S_CTP_FIFO_AXI_BREADY),
      .s_ctp_arid_i   (S_CTP_FIFO_AXI_ARID),
      .s_ctp_araddr_i (S_CTP_FIFO_AXI_ARADDR),
      .s_ctp_arlen_i  (S_CTP_FIFO_AXI_ARLEN),
      .s_ctp_arsize_i (S_CTP_FIFO_AXI_ARSIZE),
      .s_ctp_arburst_i(S_CTP_FIFO_AXI_ARBURST),
      .s_ctp_arlock_i (S_CTP_FIFO_AXI_ARLOCK),
      .s_ctp_arcache_i(S_CTP_FIFO_AXI_ARCACHE),
      .s_ctp_arprot_i (S_CTP_FIFO_AXI_ARPROT),
      .s_ctp_arvalid_i(S_CTP_FIFO_AXI_ARVALID),
      .s_ctp_arready_o(S_CTP_FIFO_AXI_ARREADY),
      .s_ctp_rid_o    (S_CTP_FIFO_AXI_RID),
      .s_ctp_rdata_o  (S_CTP_FIFO_AXI_RDATA),
      .s_ctp_rresp_o  (S_CTP_FIFO_AXI_RRESP),
      .s_ctp_rlast_o  (S_CTP_FIFO_AXI_RLAST),
      .s_ctp_rvalid_o (S_CTP_FIFO_AXI_RVALID),
      .s_ctp_rready_i (S_CTP_FIFO_AXI_RREADY)
  );

endmodule
