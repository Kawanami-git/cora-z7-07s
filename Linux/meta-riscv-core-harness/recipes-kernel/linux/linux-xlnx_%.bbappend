FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://kernel.cfg"

KERNEL_CONFIG_FRAGMENTS += "kernel.cfg"

