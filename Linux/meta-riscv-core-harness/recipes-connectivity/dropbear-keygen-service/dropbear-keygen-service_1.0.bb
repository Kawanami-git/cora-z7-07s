SUMMARY = ""
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/files/common-licenses/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += " \
    file://dropbear-keygen.sh \
    file://dropbear-keygen.service \
"
inherit systemd

SYSTEMD_SERVICE:${PN} = "dropbear-keygen.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    # Dropbear key generation script
    install -d ${D}${sysconfdir}/init.d
    install -m 0755 ${WORKDIR}/dropbear-keygen.sh ${D}${sysconfdir}/init.d/

    # systemd Services
    install -d ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/dropbear-keygen.service ${D}${systemd_system_unitdir}/
}
FILES:${PN} += "${sysconfdir}/init.d/dropbear-keygen.sh"
