# SPDX-License-Identifier: MIT
# /*!
# ********************************************************************************
# \file       cora_z7_07s.mk
# \brief      cora-z7-07s build and deployment targets for riscv-core-harness.
# \author     Kawanami
# \version    1.0
# \date       19/06/2026
#
# \details
#   This Makefile fragment contains all targets and variables specific to the
#   Digilent cora-z7-07s Kit flow.
#
#   It provides:
#     - FPGA bitstream build and programming targets
#     - Linux build, download, and SD-card programming targets
#     - helper targets to deploy firmware and host utilities through SSH or UART
#     - a helper target to launch Vivado in the configured Xilinx environment
#
#   This file is intended to be included by the top-level Makefile and relies on
#   shared variables and helper targets defined in the common project Makefiles.
#
# \remarks
#   - Requires the Xilinx toolchain environment for Vivado.
#   - Linux-related targets rely on the repository build scripts and Yocto layers.
#   - Deployment helpers rely on SSH, SCP, UART utilities, and the CORA SDK.
#   - See `make help` for a summary of available targets and variables.
#
# \section cora_z7_07s_mk_version_history Version history
# | Version | Date       | Author   | Description                                |
# |:-------:|:----------:|:---------|:-------------------------------------------|
# | 1.0     | 19/06/2026 | Kawanami | Initial split from the top-level Makefile. |
# ********************************************************************************
# */

#################################### Directories ####################################
# Xilinx source script
XILINX_SOURCE           	= /opt/Xilinx/xilinx_env.sh

# CORA z7-07s support repository directory name.
CORA_Z7_07S_NAME := cora-z7-07s/

# cora-z7-07s source root directory inside the repository.
# This path is absolute and must never be prefixed by WORK_DIR.
CORA_Z7_07S_ROOT_DIR       = $(abspath $(RISCV_CORE_HARNESS_DIR)$(CORA_Z7_07S_NAME))/

# cora-z7-07s source directories.
CORA_Z7_07S_SCRIPTS_DIR    = $(CORA_Z7_07S_ROOT_DIR)scripts/
CORA_Z7_07S_FPGA_DIR       = $(CORA_Z7_07S_ROOT_DIR)FPGA/
CORA_Z7_07S_LINUX_DIR      = $(CORA_Z7_07S_ROOT_DIR)Linux/
CORA_Z7_07S_LAYER_DIR      = $(CORA_Z7_07S_LINUX_DIR)meta-riscv-core-harness/

# cora-z7-07s working copy directories.
# Keep the generated Vivado/Yocto artifacts under WORK_DIR only.
CORA_Z7_07S_WORK_ROOT_DIR  = $(WORK_DIR)$(CORA_Z7_07S_NAME)
CORA_Z7_07S_WORK_FPGA_DIR  = $(CORA_Z7_07S_WORK_ROOT_DIR)FPGA/
CORA_Z7_07S_WORK_LINUX_DIR = $(CORA_Z7_07S_WORK_ROOT_DIR)Linux/
CORA_Z7_07S_BOARD          = $(CORA_Z7_07S_WORK_ROOT_DIR)board/

# Vivado-exported XSA used as hardware input for the Yocto/Linux build.
XILINX_XSA                 = $(CORA_Z7_07S_WORK_FPGA_DIR)riscv-core-harness.xsa
#################################### 			 ####################################

#################################### Linux & SDK ####################################
# Prebuilt CORA z7-07s Linux image download link
CORA_Z7_07S_LINUX_LINK=https://github.com/Kawanami-git/cora-z7-07s/releases/download/Linux-19-06-2026/core-image-custom-cora-z7-07s-sdt.rootfs.wic

# Prebuilt CORA z7-07s SDK download link
CORA_Z7_07S_SDK_LINK=https://github.com/Kawanami-git/cora-z7-07s/releases/download/Linux-19-06-2026/poky-glibc-x86_64-core-image-custom-cora-z7-07s-sdt-toolchain.sh

# Environment setup script used for CORA z7-07s cross-compilation
CORA_Z7_07S_SDK_ENV ?= $(CORA_Z7_07S_WORK_LINUX_DIR)sdk/environment-setup-cortexa9t2hf-neon-poky-linux-gnueabi

# Directory containing CORA z7-07s cross-compilation binaries
CORA_Z7_07S_SDK_BIN ?= $(CORA_Z7_07S_WORK_LINUX_DIR)sdk/sysroots/x86_64-pokysdk-linux/usr/bin/arm-poky-linux/

# Helper to activate the CORA z7-07s environment before running the build
define CORA_Z7_07S_SDK_RUN
bash -lc 'source "$(CORA_Z7_07S_SDK_ENV)"; export PATH="$$PATH:$(CORA_Z7_07S_SDK_BIN)"; $(1)'
endef

# Helper to run AMD/Xilinx tools with host GCC CRT paths visible to XSim.
# This is mostly useful on Ubuntu-like systems where xelab may call /usr/bin/ld
# without inheriting the full GCC startup-file search path.
define XILINX_RUN
bash -lc '\
	source "$(XILINX_SOURCE)"; \
	CRT_DIR="$$(dirname "$$(gcc -print-file-name=crt1.o)")"; \
	GCC_LIB_DIR="$$(dirname "$$(gcc -print-libgcc-file-name)")"; \
	if [ -d "$$CRT_DIR" ] && [ "$$CRT_DIR" != "." ]; then \
	  export LIBRARY_PATH="$$CRT_DIR$${LIBRARY_PATH:+:$$LIBRARY_PATH}"; \
	fi; \
	if [ -d "$$GCC_LIB_DIR" ] && [ "$$GCC_LIB_DIR" != "." ]; then \
	  export LIBRARY_PATH="$$GCC_LIB_DIR$${LIBRARY_PATH:+:$$LIBRARY_PATH}"; \
	  export COMPILER_PATH="$$GCC_LIB_DIR$${COMPILER_PATH:+:$$COMPILER_PATH}"; \
	fi; \
	$(1)'
endef
####################################					####################################

#################################### Misc ####################################
# Default risc-v core clock for the CORA z7-07s board implementation
CORA_Z7_07S_CORE_CLK_FREQ_MHZ ?= 50.000

# Default IP address of the CORA z7-07s board
CORA_Z7_07S_IP           ?= 192.168.8.2

# Default SSH user of the CORA z7-07s board
CORA_Z7_07S_USER         ?= root

# Default serial device of the CORA z7-07s board
CORA_Z7_07S_TTY          ?= /dev/ttyUSB1

# Default serial baud rate of the CORA z7-07s board
CORA_Z7_07S_TTY_BAUDRATE ?= 115200
####################################		  ####################################

# Display help for cora z7-07s-related targets
.PHONY: cora_z7_07s_help
cora_z7_07s_help:
	@echo
	@echo "riscv-core-harness — cora-z7-07s Makefile helper"
	@echo "Usage: make <target> [XLEN=XLEN32|XLEN64]"
	@echo
	@printf "Targets:\n"
	@printf "  %-35s %s\n" "cora_z7_07s_bitstream"   		    "Build the bitstream for the cora-z7-07s"
	@printf "  %-35s %s\n" "cora_z7_07s_program_bitstream"  "Program the bitstream in the cora-z7-07s"
	@printf "  %-35s %s\n" "cora_z7_07s_linux"   			      "Build the Linux (and sdk) for the cora-z7-07s"
	@printf "  %-35s %s\n" "cora_z7_07s_get_linux"   		    "Retreive the Linux (and sdk) for the cora-z7-07s"
	@printf "  %-35s %s\n" "cora_z7_07s_program_linux"   	  "Program the Linux in an SD card"
	@printf "  %-35s %s\n" "cora_z7_07s_ssh"   			        "Establish an ssh connection with the cora-z7-07s"
	@printf "  %-35s %s\n" "cora_z7_07s_ssh_setup"   			  "Setup the cora-z7-07s with all the necessary files to run 'loader', 'echo' & 'cyclemark' on the board through ssh"
	@printf "  %-35s %s\n" "cora_z7_07s_minicom"   			    "Open a serial console on the cora-z7-07s"
	@printf "  %-35s %s\n" "cora_z7_07s_usb_setup"   			  "Setup the cora-z7-07s with all the necessary files to run 'loader', 'echo' & 'cyclemark' on the board through usb (uart)"
	@printf "  %-35s %s\n" "clean_cora_z7_07s_bitstream"    "Clean the cora-z7-07s FPGA work directory"
	@printf "  %-35s %s\n" "clean_cora_z7_07s_linux"   			"Clean the cora-z7-07s Linux work directory"
	@printf "  %-35s %s\n" "clean_cora_z7_07s_board"   			"Clean the cora-z7-07s board work directory"
	@printf "  %-35s %s\n" "clean_all_cora_z7_07s"   			  "Clean the cora-z7-07s work directory"
	@printf "  %-35s %s\n" "vivado"               				  "Launch Vivado in the Xilinx environment"
	@echo
	@printf "Key variables:\n"
	@printf "  %-35s %s\n" "XLEN"                               "Architecture (32-bit or 64-bit). Default is 32."
	@echo
	@echo "Examples:"
	@echo "  make isa XLEN=XLEN32"
	@echo "  make cora_z7_07s_usb_setup"
	@echo
	@echo





# Create the working directories required by the CORA z7-07s flow
cora_z7_07s_work:
	@mkdir -p $(CORA_Z7_07S_WORK_LINUX_DIR)
	@mkdir -p $(CORA_Z7_07S_BOARD)


# Simulate the FPGA design for the cora-z7-07s
.PHONY: cora_z7_07s_sim
cora_z7_07s_sim: cora_z7_07s_work echo_firmware
	@rm -rf "$(CORA_Z7_07S_WORK_FPGA_DIR)"
	@mkdir -p "$(CORA_Z7_07S_WORK_ROOT_DIR)"
	@cp -a "$(CORA_Z7_07S_FPGA_DIR)" "$(CORA_Z7_07S_WORK_ROOT_DIR)"
	@echo "➡️  Running simulation script..."
	@$(call XILINX_RUN,cd "$(CORA_Z7_07S_WORK_FPGA_DIR)" && \
	vivado \
	-mode batch \
	-source build.tcl \
	-notrace \
	-journal ./riscv-core-harness.jou \
	-log ./riscv-core-harness.log \
	-tclargs \
	--xlen $(CPU_XLEN) \
	--origin_dir "$(CORA_Z7_07S_FPGA_DIR)" \
	--dut_dir "$(abspath $(DUT_DIR))" \
	--board_repo /opt/Xilinx/board_files/digilent/new/board_files \
	--core_clk_freq_mhz $(CORA_Z7_07S_CORE_CLK_FREQ_MHZ) \
	--flow simulation)
	@echo "✅ Done."

# Build the CORA z7-07s XSA for Yocto
$(XILINX_XSA):
	@rm -rf "$(CORA_Z7_07S_WORK_FPGA_DIR)"
	@mkdir -p "$(CORA_Z7_07S_WORK_ROOT_DIR)"
	@cp -a "$(CORA_Z7_07S_FPGA_DIR)" "$(CORA_Z7_07S_WORK_ROOT_DIR)"
	@echo "➡️  Running bitstream building script..."
	@$(call XILINX_RUN,cd "$(CORA_Z7_07S_WORK_FPGA_DIR)" && \
	vivado \
	-mode batch \
	-source build.tcl \
	-notrace \
	-journal ./riscv-core-harness.jou \
	-log ./riscv-core-harness.log \
	-tclargs \
	--xlen $(CPU_XLEN) \
	--origin_dir "$(CORA_Z7_07S_FPGA_DIR)" \
	--dut_dir "$(abspath $(DUT_DIR))" \
	--board_repo /opt/Xilinx/board_files/digilent/new/board_files \
	--core_clk_freq_mhz $(CORA_Z7_07S_CORE_CLK_FREQ_MHZ) \
	--flow design)
	@echo "✅ Done."
	@test -f "$(XILINX_XSA)" || (echo "❌ XSA not generated: $(XILINX_XSA)"; exit 1)

# Build the FPGA bitstream for the CORA z7-07s
.PHONY: cora_z7_07s_bitstream
cora_z7_07s_bitstream: $(XILINX_XSA)

# Program the FPGA bitstream for the CORA z7-07s
.PHONY: cora_z7_07s_program_bitstream
cora_z7_07s_program_bitstream:
	@echo "Programming bitstream on Cora z7-07s..."
	@test -f "$(CORA_Z7_07S_WORK_FPGA_DIR)riscv-core-harness.bin" || (echo "Missing bitstream: $(CORA_Z7_07S_WORK_FPGA_DIR)riscv-core-harness.bin" && exit 1)
	@ssh -T $(CORA_Z7_07S_USER)@$(CORA_Z7_07S_IP) "mkdir -p /lib/firmware"
	@scp "$(CORA_Z7_07S_WORK_FPGA_DIR)riscv-core-harness.bin" "$(CORA_Z7_07S_USER)@$(CORA_Z7_07S_IP):/lib/firmware/riscv-core-harness.bin"
	@ssh -T $(CORA_Z7_07S_USER)@$(CORA_Z7_07S_IP) "\
		echo 0 > /sys/class/fpga_manager/fpga0/flags && \
		echo riscv-core-harness.bin > /sys/class/fpga_manager/fpga0/firmware && \
		cat /sys/class/fpga_manager/fpga0/state"

# Clean CORA z7-07s FPGA build artifacts
.PHONY: clean_cora_z7_07s_bitstream
clean_cora_z7_07s_bitstream:
	@echo "➡️  Cleaning bitstream directories..."
	@rm -rf "$(CORA_Z7_07S_WORK_FPGA_DIR)"
	@echo "✅ Done."




# Build the Linux system for the CORA z7-07s
.PHONY: cora_z7_07s_linux
cora_z7_07s_linux: cora_z7_07s_work $(XILINX_XSA)
# 	@rm -rf "$(CORA_Z7_07S_WORK_LINUX_DIR)"
	@mkdir -p "$(CORA_Z7_07S_WORK_ROOT_DIR)"
	@cp -a "$(CORA_Z7_07S_LINUX_DIR)" "$(CORA_Z7_07S_WORK_ROOT_DIR)"
	@cp $(CORA_Z7_07S_SCRIPTS_DIR)build_linux.sh $(CORA_Z7_07S_WORK_LINUX_DIR)
	@echo "➡️  Running Linux building script..."
	@echo
	@bash $(CORA_Z7_07S_WORK_LINUX_DIR)build_linux.sh

	@cp $(CORA_Z7_07S_WORK_LINUX_DIR)build-cora/tmp/deploy/images/cora-z7-07s-sdt/core-image-custom-cora-z7-07s-sdt.rootfs-*.wic* $(CORA_Z7_07S_WORK_LINUX_DIR)core-image-custom-cora-z7-07s-sdt.rootfs.wic

	@cp $(CORA_Z7_07S_WORK_LINUX_DIR)build-cora/tmp/deploy/sdk/poky-glibc-x86_64-core-image-custom-cortexa9t2hf-neon-cora-z7-07s-sdt-toolchain-*.sh $(CORA_Z7_07S_WORK_LINUX_DIR)poky-glibc-x86_64-core-image-custom-cora-z7-07s-sdt-toolchain.sh
	@if [ -d $(CORA_Z7_07S_WORK_LINUX_DIR)/sdk/ ]; \
  then rm -rf $(CORA_Z7_07S_WORK_LINUX_DIR)/sdk/; \
  fi
	@chmod +x $(CORA_Z7_07S_WORK_LINUX_DIR)poky-glibc-x86_64-core-image-custom-cora-z7-07s-sdt-toolchain.sh
	@$(CORA_Z7_07S_WORK_LINUX_DIR)poky-glibc-x86_64-core-image-custom-cora-z7-07s-sdt-toolchain.sh -y -d "$(CORA_Z7_07S_WORK_LINUX_DIR)/sdk/"

	@echo "✅ Done."

# Download the prebuilt Linux image and SDK for the CORA z7-07s
.PHONY: cora_z7_07s_get_linux
cora_z7_07s_get_linux: cora_z7_07s_work
	@wget -P $(CORA_Z7_07S_WORK_LINUX_DIR) $(CORA_Z7_07S_LINUX_LINK)
	@wget -P $(CORA_Z7_07S_WORK_LINUX_DIR) $(CORA_Z7_07S_SDK_LINK)

	@chmod +x $(CORA_Z7_07S_WORK_LINUX_DIR)poky-glibc-x86_64-core-image-custom-cora-z7-07s-sdt-toolchain.sh
	@if [ -d $(CORA_Z7_07S_WORK_LINUX_DIR)/sdk/ ]; \
  then rm -rf $(CORA_Z7_07S_WORK_LINUX_DIR)/sdk/; \
  fi
	@$(CORA_Z7_07S_WORK_LINUX_DIR)poky-glibc-x86_64-core-image-custom-cora-z7-07s-sdt-toolchain.sh -y -d "$(CORA_Z7_07S_WORK_LINUX_DIR)/sdk/"

# Program the Linux image onto the target SD card
.PHONY: cora_z7_07s_program_linux
cora_z7_07s_program_linux:
	@echo "➡️  Running Linux programming script..."
	@echo
ifdef path
	@bash $(CORA_Z7_07S_SCRIPTS_DIR)program_linux.sh $(path)
else
	@bash $(CORA_Z7_07S_SCRIPTS_DIR)program_linux.sh $(CORA_Z7_07S_WORK_LINUX_DIR)core-image-custom-cora-z7-07s-sdt.rootfs.wic
endif
	@echo "✅ Done."

# Clean the Linux working directory
.PHONY: clean_cora_z7_07s_linux
clean_cora_z7_07s_linux:
	@echo "➡️  Cleaning Linux directories..."
	@rm -rf "$(CORA_Z7_07S_WORK_LINUX_DIR)"
	@echo "✅ Done."





# Establish an SSH connection
.PHONY: cora_z7_07s_ssh
cora_z7_07s_ssh:
	@ssh $(CORA_Z7_07S_USER)@$(CORA_Z7_07S_IP)

# Build the firmware and platform utility, then deploy them through SSH
.PHONY: cora_z7_07s_ssh_setup
cora_z7_07s_ssh_setup: CORA_Z7_07S_FIRMWARE_DIR:=$(patsubst $(WORK_DIR)%,%,$(FIRMWARE_BUILD_DIR))
cora_z7_07s_ssh_setup: CXX_FLAGS := -O3 -D$(XLEN) -I$(VERILATOR_BUILD_DIR) -I$(SOFTWARE_DIR) -I$(PLATFORM_DIR) -I$(SIM_FILES_DIR)
cora_z7_07s_ssh_setup:
	@$(MAKE) --no-print-directory loader_firmware
	@$(MAKE) --no-print-directory echo_firmware
	@$(MAKE) --no-print-directory cyclemark_firmware
	@ssh -T $(CORA_Z7_07S_USER)@$(CORA_Z7_07S_IP) "mkdir -p $(CORA_Z7_07S_FIRMWARE_DIR)"
	@scp -T -r $(FIRMWARE_BUILD_DIR)/*.hex $(CORA_Z7_07S_USER)@$(CORA_Z7_07S_IP):./$(CORA_Z7_07S_FIRMWARE_DIR)
	@$(call CORA_Z7_07S_SDK_RUN,$$CXX $(CXX_FLAGS) $(PLATFORM_FILES) -o $(CORA_Z7_07S_BOARD)platform)
	@scp -T -r $(CORA_Z7_07S_BOARD)platform $(CORA_Z7_07S_USER)@$(CORA_Z7_07S_IP):./
	@scp -T -r $(PLATFORM_DIR)Makefile $(CORA_Z7_07S_USER)@$(CORA_Z7_07S_IP):./





# Open a serial console on the selected TTY device
.PHONY: cora_z7_07s_minicom
cora_z7_07s_minicom:
	@sudo minicom -D $(CORA_Z7_07S_TTY) -b $(CORA_Z7_07S_TTY_BAUDRATE)

# Build the firmware and platform utility, then deploy them through UART
.PHONY: cora_z7_07s_usb_setup
cora_z7_07s_usb_setup: CORA_Z7_07S_FIRMWARE_DIR:=$(patsubst $(WORK_DIR)%,%,$(FIRMWARE_BUILD_DIR))
cora_z7_07s_usb_setup: CXX_FLAGS := -O3 -D$(XLEN) -I$(VERILATOR_BUILD_DIR) -I$(SOFTWARE_DIR) -I$(PLATFORM_DIR) -I$(SIM_FILES_DIR)
cora_z7_07s_usb_setup: cora_z7_07s_work
	@$(MAKE) --no-print-directory loader_firmware
	@$(MAKE) --no-print-directory echo_firmware
	@$(MAKE) --no-print-directory cyclemark_firmware
	@$(call CORA_Z7_07S_SDK_RUN,$$CXX $(CXX_FLAGS) $(PLATFORM_FILES) -o $(CORA_Z7_07S_BOARD)platform)

	@for f in $(FIRMWARE_BUILD_DIR)/*.hex; do \
	  $(MAKE) --no-print-directory uart_ft TTY=$(CORA_Z7_07S_TTY) TTY_BAUDRATE=$(CORA_Z7_07S_TTY_BAUDRATE) UART_FILE="$$f" \
	  UART_DEST_DIR="./$(CORA_Z7_07S_FIRMWARE_DIR)"; \
	done

	@$(MAKE) --no-print-directory uart_ft TTY=$(CORA_Z7_07S_TTY) TTY_BAUDRATE=$(CORA_Z7_07S_TTY_BAUDRATE) UART_FILE=$(CORA_Z7_07S_BOARD)platform \
	UART_DEST_DIR="./"

	@$(MAKE) --no-print-directory uart_ft TTY=$(CORA_Z7_07S_TTY) TTY_BAUDRATE=$(CORA_Z7_07S_TTY_BAUDRATE) UART_FILE=$(PLATFORM_DIR)Makefile \
	UART_DEST_DIR="./"

# Clean the board directory
.PHONY: clean_cora_z7_07s_board
clean_cora_z7_07s_board:
	@echo "➡️  Cleaning board directory..."
	@rm -rf $(CORA_Z7_07S_BOARD)
	@echo "✅ Done."





# Clean the CORA z7-07s working directory
.PHONY: clean_all_cora_z7_07s
clean_all_cora_z7_07s:
	@echo "➡️  Cleaning working directory..."
	@rm -rf "$(CORA_Z7_07S_WORK_ROOT_DIR)"
	@echo "✅ Done."





# Launch Vivado in the configured Xilinx environment
.PHONY: vivado
vivado:
	@mkdir -p "$(CORA_Z7_07S_WORK_ROOT_DIR)"
	@if [ ! -d "$(CORA_Z7_07S_WORK_FPGA_DIR)" ]; then cp -a "$(CORA_Z7_07S_FPGA_DIR)" "$(CORA_Z7_07S_WORK_ROOT_DIR)"; fi
	@$(call XILINX_RUN,cd "$(CORA_Z7_07S_WORK_FPGA_DIR)" && env QT_QPA_PLATFORM=xcb vivado -journal ./riscv-core-harness.jou -log ./riscv-core-harness.log)
	@echo "✅ Done."

