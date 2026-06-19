FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI += "file://dnsmasq.conf \
            file://override.conf"

do_install:append() {
    # dnsmasq.conf
    install -d ${D}${sysconfdir}
    install -m 0644 ${WORKDIR}/dnsmasq.conf ${D}${sysconfdir}/dnsmasq.conf

    # override.conf dans le bon dossier systemd
    install -d ${D}${systemd_system_unitdir}/dnsmasq.service.d
    install -m 0644 ${WORKDIR}/override.conf ${D}${systemd_system_unitdir}/dnsmasq.service.d/override.conf
}

FILES:${PN} += "${systemd_system_unitdir}/dnsmasq.service.d/override.conf"
