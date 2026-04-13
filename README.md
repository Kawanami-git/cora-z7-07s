# SCHOLAR_RISC-V Cora z7-07s support

This repository contains the necessary files to configure and use the [Cora z7-07s](https://digilent.com/reference/programmable-logic/cora-z7/start) from Digilent with the [SCHOLAR RISC-V](https://github.com/Kawanami-git/SCHOLAR_RISC-V) processor.

It is intended to be used as a submodule of the SCHOLAR RISC-V GitHub repository, and cannot be used independently.

<br>

## 📚 Table of Contents

- [License](#license)
- [Overview](#overview)
- [Project Organization](#project-organization)
- [Dependencies](#dependencies)
- [Known Bugs](#known-bugs)

<br>

## License

This project is licensed under the **MIT License** – see the [LICENSE](LICENSE) file for details.

Some files, generated artifacts, or external components used during the build process may come from Xilinx, Digilent, Yocto, or other third-party projects, and therefore remain subject to their respective licenses.

<br>

## Overview

**SCHOLAR_RISC-V** is a learning-oriented project designed to guide you step-by-step through the inner workings of a processor, using the RISC-V architecture as a foundation.

In addition to simulation, SCHOLAR_RISC-V aims to be usable on several development boards, including the **Cora z7-07s** from Digilent.

This repository provides all the necessary files to:
- Configure the Cora z7-07s (bootloader, Linux).
- Build a valid SCHOLAR_RISC-V bitstream and load it on the FPGA.

<br>

## Project Organization

This repository is a Git submodule used by the **SCHOLAR_RISC-V** project.<br>
It is updated as needed to support the evolution of the core.

Branches in this repository are aligned with the parent repository branches.<br>
For example:
- `Single-Cycle` ↔ used by `SCHOLAR_RISC-V/Single-Cycle`
- `pipeline`     ↔ used by `SCHOLAR_RISC-V/pipeline`

Each parent branch pins this submodule to the matching branch/commit.

<br>

## Dependencies

All dependencies are explicitly described in the [SCHOLAR_RISC-V project – board support](https://github.com/Kawanami-git/SCHOLAR_RISC-V/tree/main/board_support/CORA_Z7_07S/) directory.

<br>

## Known Issues

Yocto may occasionally fail to fetch some external dependencies, which can lead to a build failure. <br>
If this happens, simply rerun the build process **without cleaning** it. <br>
Yocto will resume from where it left off and attempt to fetch the missing files again.


