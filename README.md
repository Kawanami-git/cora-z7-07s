# riscv-core-harness Cora z7-07s support

This repository contains the necessary files to configure and use the [Cora z7-07s](https://digilent.com/reference/programmable-logic/cora-z7/start) from Digilent with the [riscv-core-harness](https://github.com/Kawanami-git/riscv-core-harness) project.

If you haven’t already, please refer to the [**simulation README**](https://github.com/Kawanami-git/riscv-core-harness/tree/main/simulation), which contains useful information about the tests that can be executed to validate a **RISC-V**.

This repository is intended to be used as a submodule of the **riscv-core-harness** GitHub repository, and cannot be used independently.

> 📝
> If your AMD/Xilinx install directory is not **/opt/Xilinx**, the following values in the [**cora_z7_07s.mk**](./cora_z7_07s.mk) Makefile should be updated:
>- **XILINX_SOURCE**	 : Path to the Xilinx settings64.sh source script.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Table of Contents

- [License](#license)
- [Overview](#overview)
- [Project Organization](#project-organization)
- [Structure](#structure)
- [Dependencies](#dependencies)
- [Retrieving or Building the Linux Image and Programming it](#retrieving-or-building-the-linux-image-and-programming-it)
- [Building and Programming the FPGA Bitstream](#building-and-programming-the-fpga-bitstream)
- [Running Tests on the Board](#running-tests-on-the-board)
- [Running Your Own Tests](#running-your-own-tests)
- [Known Bugs](#known-bugs)

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## License

This repository is licensed under the **MIT License**.  See the [LICENSE](LICENSE) file for details.

Some files, generated artifacts, or external components used during the build process may come from Xilinx, Digilent, Yocto, or other third-party projects, and therefore remain subject to their respective licenses.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Overview

The **riscv-core-harness** project is a reusable validation platform for RISC-V cores.

It provides both simulation support and board-level integration flows, allowing a RISC-V core to be tested in software simulation and on real FPGA hardware.

This repository contains the **cora z7 07s** support files for **riscv-core-harness**. It provides everything needed to:
- Prepare the cora-z7-07s software environment, including the bootloader and Linux image.
- Build a **riscv-core-harness** FPGA bitstream containing the RISC-V core under test.
- Program and run the generated design on the cora-z7-07s FPGA.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Project Organization

This repository is a Git submodule used by the **riscv-core-harness** project.<br>
It is updated as needed to support the evolution of the project.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Structure

- **[`Linux/`](./Linux/)**  
  A set of useful scripts to build and load the Linux system, and to communicate with the Cora board. It also contains the **Linux/meta-riscv-core-harness/** layers.

- **[`Linux/meta-riscv-core-harness/`](./Linux/meta-riscv-core-harness/)**  
  Contains layers which provide the source files for building the U-BOOT (Micro BOOT) and the Linux system.

- **[`FPGA/`](./FPGA/)**  
  FPGA implementation files for the **Digilent Cora z7-07s**, enabling the riscv-core-harness to be synthesized and run on hardware.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Dependencies

All dependencies are explicitly described in the [riscv-core-harness project – board_support](https://github.com/Kawanami-git/riscv-core-harness/tree/main/docs/board_support/mpfs-discovery-kit/) directory.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Retrieving or Building the Linux Image and Programming It

The **Cora z7-07s** contains the **Zinq-7000 APSoC** from **Xilinx**. This chip is a Linux-capable SoC with an FPGA.<br>
To avoid running baremetal applications, a Linux image can be installed on the board using a microSD card.

<br>
<br>

### Retrieving the Linux Image
The custom Linux image and the SDK can be found [here]().

They can be retrieved with the following command:
```bash
make cora_z7_07s_get_linux
```

<br>
<br>

### Building the Linux image 
Alternatively, to build the custom Linux image and the SDK, simply run the following command in your terminal:

```bash
make cora_z7_07s_linux
```

This command will build the custom Linux (and its SDK) developed in this project for the **Cora z7-07s**.

> 📝 
>
> Please note that this build can take several hours and requires at least 75GB of available storage on your computer.
>
> During the build, several packages installation may be required by Yocto. Please, install all of these packages.
>
> The bitstream must be built first as it is part of the Linux image.
>
> Issues can occur during the build. Please, see the [**Known issues**](#🐞-known-issues) section.


<br>
<br>

### Programming the Linux Image onto the SD Card

Once the SD card is plugged into your computer, you can flash the Linux image using one of the following commands:
```bash
make cora_z7_07s_program_linux
```

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Building and Programming the FPGA Bitstream

The FPGA bitstream can be built using the following command:

```bash
make cora_z7_07s_bitstream
```

If the **Cora z7-07s** board is connected to your computer via an Ethernet cable, you can program the bitstream with:

```bash
make cora_z7_07s_program_bitstream
```
> 📝
>
> This command will provide the board linux with the bitstream, allowing it to update the FPGA configuration.
>
> Another path is to build the FPGA bitstream (which also produces an xsa) and then build the linux.<br>
> The bitstream will be contained in the linux image.

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Running Tests on the Board

Except for the ISA tests, all other tests can be executed directly on the **Cora z7-07s** board.  
To do so, make sure the board is connected to your computer via **USB-C** and eventually **Ethernet**.

<br>
<br>

### Setup the board

Use one of the following commands to set up the board with either the USB or the Ethernet:

```bash
make cora_z7_07s_ssh_setup
```

```bash
make cora_z7_07s_usb_setup
```

These commands will compile all the firmware (loader, echo, cyclemark) and the software allowing to load firmware in the RISC-V softcore and to communicate with them.<br>
It will also copy the built binaries to the board and a Makefile.

> 📝
>
> For the software to be built, the board SDK must be available. It can be retreived with 'make cora_z7_07s_get_linux' or built with 'make cora_z7_07s_linux'.
>
> Please note that setting up the boad using usb requires root access for ttyUSBx.<br>
> Default ttyUSB used is ttyUSB1. It can be changed in the branch Makefile through the variable **CORA_Z7_07S_TTY**.

<br>
<br>

### Connect to the Board via USB or SSH
To interact with the board through an SSH session (Ethernet required):
```bash
make cora_z7_07s_ssh
```

Through a USB session:
```bash
make cora_z7_07s_minicom
```

> 📝
>
> Please note that establishing a session through usb requires root access for ttyUSBx.<br>
> Default ttyUSB used is ttyUSB1. It can be changed in the branch Makefile through the variable **CORA_Z7_07S_TTY**.

<br>
<br>

### Run the Tests

Once connected, run one of the following commands to execute a test:
```bash
make loader
make echo
make cyclemark
```

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Running Your Own Tests
If you haven’t already, please refer to the [**Running Your Own Firmwares**](https://github.com/Kawanami-git/riscv-core-harness/tree/main/simulation) section of the simulation environment README — it contains mandatory steps required before running your own tests on the boards.

Please, also refer to the [Running Tests on the Board](#running-tests-on-the-board) section for detailed instructions on how to run a test on the board.

<br>
<br>

### Modify cora_z7_07s.mk

Once your firmware is running correctly in the simulation environment, you can modify the **cora_z7_07s.mk** to build and send your custom firmware to the board.

Locate the target:
```
# Build the firmware and platform utility, then deploy them through UART
.PHONY: cora_z7_07s_usb_setup
cora_z7_07s_usb_setup: CORA_Z7_07S_FIRMWARE_DIR:=$(patsubst $(WORK_DIR)%,%,$(FIRMWARE_BUILD_DIR))
cora_z7_07s_usb_setup: CXX_FLAGS := -O3 -D$(XLEN) -I$(VERILATOR_BUILD_DIR) -I$(SOFTWARE_DIR) -I$(PLATFORM_DIR) -I$(SIM_FILES_DIR)
cora_z7_07s_usb_setup: work
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
```

And add it your firmware build command (**@$(MAKE) --no-print-directory custom_firmware**):
```
# Build the firmware and platform utility, then deploy them through UART
.PHONY: cora_z7_07s_usb_setup
cora_z7_07s_usb_setup: CORA_Z7_07S_FIRMWARE_DIR:=$(patsubst $(WORK_DIR)%,%,$(FIRMWARE_BUILD_DIR))
cora_z7_07s_usb_setup: CXX_FLAGS := -O3 -D$(XLEN) -I$(VERILATOR_BUILD_DIR) -I$(SOFTWARE_DIR) -I$(PLATFORM_DIR) -I$(SIM_FILES_DIR)
cora_z7_07s_usb_setup: work
	@$(MAKE) --no-print-directory loader_firmware
	@$(MAKE) --no-print-directory echo_firmware
	@$(MAKE) --no-print-directory cyclemark_firmware
->  @$(MAKE) --no-print-directory custom_firmware
	@$(call CORA_Z7_07S_SDK_RUN,$$CXX $(CXX_FLAGS) $(PLATFORM_FILES) -o $(CORA_Z7_07S_BOARD)platform)

	@for f in $(FIRMWARE_BUILD_DIR)/*.hex; do \
	  $(MAKE) --no-print-directory uart_ft TTY=$(CORA_Z7_07S_TTY) TTY_BAUDRATE=$(CORA_Z7_07S_TTY_BAUDRATE) UART_FILE="$$f" \
	  UART_DEST_DIR="./$(CORA_Z7_07S_FIRMWARE_DIR)"; \
	done

	@$(MAKE) --no-print-directory uart_ft TTY=$(CORA_Z7_07S_TTY) TTY_BAUDRATE=$(CORA_Z7_07S_TTY_BAUDRATE) UART_FILE=$(CORA_Z7_07S_BOARD)platform \
	UART_DEST_DIR="./"

	@$(MAKE) --no-print-directory uart_ft TTY=$(CORA_Z7_07S_TTY) TTY_BAUDRATE=$(CORA_Z7_07S_TTY_BAUDRATE) UART_FILE=$(PLATFORM_DIR)Makefile \
	UART_DEST_DIR="./"
```

This will build your firmware along the others and send it to the board. If you work with ssh, you can apply the same process to **cora_z7_07s_ssh_setup**.

<br>
<br>

### Modify the platform Makefile

The [**platform makefile**](https://github.com/Kawanami-git/riscv-core-harness/tree/main/software/platform/Makefile) is meant to be used on a development board supporting Linux.<br>
Its purpose is to make the use of the built binaries easier.

To add your firmware, just add the following variables:
```
CUSTOM_FIRMWARE = $(FIRMWARE_DIR)custom.hex
CUSTOM_LOG      = $(LOG_DIR)custom.log
```

And add the following target:
```
.PHONY: custom
custom:
  ./platform --firmware $(CUSTOM_FIRMWARE) --log $(CUSTOM_LOG)
```

You can now run your test on the board by running the following command on the board:
```bash
make custom
```

<br>
<br>

---

<br>
<br>
<br>
<br>
<br>

## Known Bugs

- **Yocto Build Failures** 

Yocto may occasionally fail to fetch some external dependencies, leading to a Linux build failure.  
If this happens, simply rerun the build process **without cleaning** it:

```bash
make cora_z7_07s_linux
```

Yocto will resume from where it left off and attempt to fetch the missing files again.

<br>
<br>
