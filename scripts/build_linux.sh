#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# /*!
# ********************************************************************************
# \file       build_cora.sh
# \brief      Cora Z7-07S Yocto SDT bootstrap and build script
# \author     Kawanami
# \version    1.0
# \date       18/06/2026
#
# \details
#   Builds the SCHOLAR RISC-V Yocto board support environment for the
#   Digilent Cora Z7-07S target
#
#   This script provides a one-command SDT-based Yocto flow for a Zynq-7000S
#   design exported from Vivado as an XSA file
#
#   The script:
#     1) checks the required host commands
#     2) optionally applies the Ubuntu 24.04 user namespace workaround
#     3) clones or updates the required Yocto, OpenEmbedded and Xilinx layers
#     4) creates the local SCHOLAR RISC-V BSP layer when missing
#     5) generates the System Device Tree from the selected XSA file
#     6) initializes the Yocto build directory
#     7) enables the required Yocto layers
#     8) builds kconfig-frontends-native for gen-machine-conf
#     9) generates the machine configuration from the SDT output
#    10) updates local.conf for the selected machine and image
#    11) optionally installs local device-tree fixups
#    12) builds the device tree, target image and SDK
#    13) lists the generated deployment artifacts and WIC contents
#
# \remarks
#   - Requires Bash because the script uses Bash-specific syntax
#   - Requires network access to clone Yocto, OpenEmbedded and Xilinx repositories
#   - Requires a valid XSA file generated from the Vivado hardware design
#   - Requires an executable Vitis sdtgen binary
#   - The default XSA path is ../FPGA/riscv-core-harness.xsa
#   - The default Vitis SDT generator path is /opt/Xilinx/2025.2/Vitis/bin/sdtgen
#   - The default MACHINE is cora-z7-07s-sdt
#   - The default image target is core-image-custom
#   - The Ubuntu 24.04 user namespace workaround is non-persistent
#   - Xilinx compatibility libraries are used from /opt/Xilinx/.compat/2025.2 when available
#
# \section build_cora_sh_usage Usage
#   ./build_cora.sh
#
# \section build_cora_sh_env_overrides Environment overrides
#   XSA_PATH=/abs/path/to/design.xsa
#   VITIS_SDTGEN=/opt/Xilinx/2025.2/Vitis/bin/sdtgen
#   MACHINE_NAME=cora-z7-07s-sdt
#   IMAGE_TARGET=core-image-custom
#   BUILD_DIR=build-cora
#   APPLY_USERNS_SYSCTL=1|0
#   ENABLE_SYSTEM_USER_DTSI=1|0
#   ACCEPT_XILINX_LICENSE_FLAGS=1|0
#
# \section build_cora_sh_version_history Version history
# | Version | Date       | Author   | Description                         |
# |:-------:|:----------:|:---------|:------------------------------------|
# | 1.0     | 18/06/2026 | Kawanami | Initial Cora Z7-07S Yocto SDT build |
# |         |            |          | automation script                   |
# ********************************************************************************
# */

set -euo pipefail

log()  { echo -e "\n\033[1;34m[INFO]\033[0m $*"; }
warn() { echo -e "\n\033[1;33m[WARN]\033[0m $*"; }
die()  { echo -e "\n\033[1;31m[ERR ]\033[0m $*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1 \n"
}

# ----------------------------
# User-configurable defaults
# ----------------------------
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build-cora}"

XSA_PATH="${XSA_PATH:-$ROOT_DIR/../FPGA/riscv-core-harness.xsa}"

# IMPORTANT: set to your Vitis sdtgen path (no XSCT warning)
VITIS_SDTGEN="${VITIS_SDTGEN:-/opt/Xilinx/2025.2/Vitis/bin/sdtgen}"

MACHINE_NAME="${MACHINE_NAME:-cora-z7-07s-sdt}"
IMAGE_TARGET="${IMAGE_TARGET:-core-image-custom}"

APPLY_USERNS_SYSCTL="${APPLY_USERNS_SYSCTL:-1}"     # non-persistent sysctl on Ubuntu 24.04
ENABLE_SYSTEM_USER_DTSI="${ENABLE_SYSTEM_USER_DTSI:-1}"  # keep fixup available (safe)
ACCEPT_XILINX_LICENSE_FLAGS="${ACCEPT_XILINX_LICENSE_FLAGS:-0}"

# Branches / versions
POKY_BRANCH="${POKY_BRANCH:-scarthgap}"
META_OE_BRANCH="${META_OE_BRANCH:-scarthgap}"
META_ARM_BRANCH="${META_ARM_BRANCH:-scarthgap}"
META_VIRT_BRANCH="${META_VIRT_BRANCH:-scarthgap}"
META_XILINX_BRANCH="${META_XILINX_BRANCH:-rel-v2025.1}"
GEN_MACHINE_CONF_BRANCH="${GEN_MACHINE_CONF_BRANCH:-main}"

# Repo URLs
POKY_URL="${POKY_URL:-https://git.yoctoproject.org/poky}"
META_OE_URL="${META_OE_URL:-https://github.com/openembedded/meta-openembedded.git}"
META_ARM_URL="${META_ARM_URL:-https://git.yoctoproject.org/meta-arm}"
META_VIRT_URL="${META_VIRT_URL:-https://git.yoctoproject.org/meta-virtualization}"
META_XILINX_URL="${META_XILINX_URL:-https://github.com/Xilinx/meta-xilinx.git}"
GEN_MACHINE_CONF_URL="${GEN_MACHINE_CONF_URL:-https://github.com/Xilinx/gen-machine-conf.git}"

# Directories
POKY_DIR="$ROOT_DIR/poky"
META_OE_DIR="$ROOT_DIR/meta-openembedded"
META_ARM_DIR="$ROOT_DIR/meta-arm"
META_VIRT_DIR="$ROOT_DIR/meta-virtualization"
META_XILINX_DIR="$ROOT_DIR/meta-xilinx"
GEN_MACHINE_CONF_DIR="$ROOT_DIR/gen-machine-conf"
BSP_DIR="$ROOT_DIR/meta-riscv-core-harness"
SDT_OUT_DIR="$BUILD_DIR/sdt_out"

# ----------------------------
# git helpers
# ----------------------------
git_clone_or_update() {
  local url="$1" branch="$2" dir="$3"
  if [[ -d "$dir/.git" ]]; then
    log "Repo exists: $dir (ensuring branch $branch)"
    ( cd "$dir"
      git fetch --all --tags -q
      git checkout -q "$branch" || die "Cannot checkout branch $branch in $dir"
      git pull -q --rebase || true
    )
  else
    log "Cloning $url ($branch) -> $dir"
    git clone -q -b "$branch" "$url" "$dir"
  fi
}

# ----------------------------
# Yocto env helpers
# ----------------------------
run_in_oe_env() {
  local build_dir="$1"; shift

  # oe-init-build-env may read variables that are legitimately unset (e.g. BBSERVER).
  # With 'set -u' this becomes a hard error, so we disable nounset temporarily.
  set +u
  # shellcheck disable=SC1091
  source "$POKY_DIR/oe-init-build-env" "$build_dir" >/dev/null
  set -u

  "$@"
}

layer_is_enabled() {
  local build_dir="$1" layer_path="$2"

  # Query bitbake directly (authoritative)
  run_in_oe_env "$build_dir" bitbake-layers show-layers 2>/dev/null | awk '{print $2}' | grep -Fxq "$layer_path"
}

add_layer_if_missing() {
  local build_dir="$1" layer_path="$2"
  [[ -f "$layer_path/conf/layer.conf" ]] || die "Not a layer: $layer_path (missing conf/layer.conf)"
  if layer_is_enabled "$build_dir" "$layer_path"; then
    log "  -> already enabled: $layer_path"
    return 0
  fi
  log "  -> add-layer: $layer_path"
  run_in_oe_env "$build_dir" bitbake-layers add-layer "$layer_path"
}

remove_layer_if_present() {
  local build_dir="$1" layer_path="$2"
  set +e
  run_in_oe_env "$build_dir" bitbake-layers remove-layer "$layer_path" >/dev/null 2>&1
  set -e
}

# ----------------------------
# meta-riscv-core-harness bootstrap
# ----------------------------
ensure_bsp_layer_exists() {
  if [[ -f "$BSP_DIR/conf/layer.conf" ]]; then
    return 0
  fi
  log "Creating minimal BSP layer: $BSP_DIR"
  mkdir -p "$BSP_DIR/conf" "$BSP_DIR/conf/machine" "$BSP_DIR/recipes-bsp/device-tree/files"
  cat > "$BSP_DIR/conf/layer.conf" <<'EOF'
# Minimal BSP layer created by build_cora.sh
BBPATH .= ":${LAYERDIR}"
BBFILES += "${LAYERDIR}/recipes-*/*/*.bb ${LAYERDIR}/recipes-*/*/*.bbappend"
BBFILE_COLLECTIONS += "meta-riscv-core-harness"
BBFILE_PATTERN_meta-cora-bsp = "^${LAYERDIR}/"
BBFILE_PRIORITY_meta-cora-bsp = "6"
LAYERSERIES_COMPAT_meta-cora-bsp = "scarthgap"
EOF
}

# ----------------------------
# local.conf helpers
# ----------------------------
set_conf_kv() {
  local file="$1" key="$2" value="$3"
  if grep -Eq "^[# ]*${key}[[:space:]]*=" "$file"; then
    sed -i -E "s|^[# ]*${key}[[:space:]]*=.*|${key} = ${value}|" "$file"
  else
    echo "${key} = ${value}" >> "$file"
  fi
}

append_if_missing() {
  local file="$1" line="$2"
  grep -Fq "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

# ----------------------------
# Main
# ----------------------------
main() {
  need_cmd git
  need_cmd sed
  need_cmd grep
  need_cmd mkdir
  need_cmd rm

  [[ -f "$XSA_PATH" ]] || die "XSA not found: $XSA_PATH"
  [[ -x "$VITIS_SDTGEN" ]] || die "sdtgen not executable or not found: $VITIS_SDTGEN"

  if [[ "$APPLY_USERNS_SYSCTL" == "1" ]]; then
    # Non-persistent Ubuntu 24.04 fix for BitBake/AppArmor userns restriction
    # (resets after reboot)
    if command -v sudo >/dev/null 2>&1; then
      log "Applying non-persistent sysctl for unprivileged user namespaces (Ubuntu 24.04)..."
      sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0 >/dev/null || \
        warn "sysctl failed (maybe already enabled or sudo not permitted)."
    else
      warn "sudo not found; skipping sysctl. If BitBake fails with userns/AppArmor, run:"
      warn "  sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0"
    fi
  fi

  log "Workspace:  $ROOT_DIR"
  log "Build dir:  $BUILD_DIR"
  log "XSA:        $XSA_PATH"
  log "sdtgen:     $VITIS_SDTGEN"
  log "Machine:    $MACHINE_NAME"
  log "Image:      $IMAGE_TARGET"

  # 1) Clone/update repos
  git_clone_or_update "$POKY_URL" "$POKY_BRANCH" "$POKY_DIR"
  git_clone_or_update "$META_XILINX_URL" "$META_XILINX_BRANCH" "$META_XILINX_DIR"
  git_clone_or_update "$META_ARM_URL" "$META_ARM_BRANCH" "$META_ARM_DIR"
  git_clone_or_update "$META_OE_URL" "$META_OE_BRANCH" "$META_OE_DIR"
  git_clone_or_update "$META_VIRT_URL" "$META_VIRT_BRANCH" "$META_VIRT_DIR"
  git_clone_or_update "$GEN_MACHINE_CONF_URL" "$GEN_MACHINE_CONF_BRANCH" "$GEN_MACHINE_CONF_DIR"

  [[ -f "$POKY_DIR/oe-init-build-env" ]] || die "poky missing oe-init-build-env"

  ensure_bsp_layer_exists

  # 2) Generate SDT from XSA (no XSCT)
  log "Generating SDT output: $SDT_OUT_DIR"
  rm -rf "$SDT_OUT_DIR"
  mkdir -p "$SDT_OUT_DIR"

  local sdt_tcl="$ROOT_DIR/sdt.tcl"
  cat > "$sdt_tcl" <<'EOF'
set outdir [lindex $argv 1]
set xsa    [lindex $argv 0]

exec rm -rf $outdir
file mkdir $outdir

sdtgen set_dt_param -xsa $xsa -dir $outdir
sdtgen generate_sdt
EOF

  (
    cd "$BUILD_DIR" || exit 1
    # "$VITIS_SDTGEN" "$sdt_tcl" "$XSA_PATH" "$SDT_OUT_DIR"
    XILINX_COMPAT_LIB_DIR="${XILINX_COMPAT_LIB_DIR:-/opt/Xilinx/.compat/2025.2/}"

    if [[ -d "$XILINX_COMPAT_LIB_DIR" ]]; then
      log "Using Xilinx compatibility libraries: $XILINX_COMPAT_LIB_DIR"
      env LD_LIBRARY_PATH="$XILINX_COMPAT_LIB_DIR:${LD_LIBRARY_PATH:-}" \
        "$VITIS_SDTGEN" "$sdt_tcl" "$XSA_PATH" "$SDT_OUT_DIR"
    else
      warn "Xilinx compatibility library directory not found: $XILINX_COMPAT_LIB_DIR"
      "$VITIS_SDTGEN" "$sdt_tcl" "$XSA_PATH" "$SDT_OUT_DIR"
    fi
  )
  [[ -f "$SDT_OUT_DIR/system-top.dts" ]] || die "SDT generation failed: missing system-top.dts in $SDT_OUT_DIR"

  # 3) Init build dir & add layers
  log "Initializing Yocto build environment..."
  mkdir -p "$BUILD_DIR"
  run_in_oe_env "$BUILD_DIR" true

  log "Adding layers..."
  # core
  add_layer_if_missing "$BUILD_DIR" "$POKY_DIR/meta"
  add_layer_if_missing "$BUILD_DIR" "$POKY_DIR/meta-poky"
  add_layer_if_missing "$BUILD_DIR" "$POKY_DIR/meta-yocto-bsp"

  # OE
  add_layer_if_missing "$BUILD_DIR" "$META_OE_DIR/meta-oe"
  add_layer_if_missing "$BUILD_DIR" "$META_OE_DIR/meta-python"
  add_layer_if_missing "$BUILD_DIR" "$META_OE_DIR/meta-networking"
  add_layer_if_missing "$BUILD_DIR" "$META_OE_DIR/meta-filesystems"

  # meta-virtualization MUST be enabled before meta-xilinx-standalone-sdt
  add_layer_if_missing "$BUILD_DIR" "$META_VIRT_DIR"

  # meta-arm
  add_layer_if_missing "$BUILD_DIR" "$META_ARM_DIR/meta-arm-toolchain"
  add_layer_if_missing "$BUILD_DIR" "$META_ARM_DIR/meta-arm"

  # meta-xilinx
  add_layer_if_missing "$BUILD_DIR" "$META_XILINX_DIR/meta-xilinx-core"
  add_layer_if_missing "$BUILD_DIR" "$META_XILINX_DIR/meta-xilinx-standalone"

  # SDT support (Xilinx)
  add_layer_if_missing "$BUILD_DIR" "$META_XILINX_DIR/meta-microblaze"
  add_layer_if_missing "$BUILD_DIR" "$META_XILINX_DIR/meta-xilinx-standalone-sdt"

  # BSP
  add_layer_if_missing "$BUILD_DIR" "$BSP_DIR"

  # SDT workflow does NOT need meta-xilinx-tools; remove if present in a reused build dir
  # if [[ -d "$ROOT_DIR/meta-xilinx-tools" ]]; then
  #   remove_layer_if_present "$BUILD_DIR" "$ROOT_DIR/meta-xilinx-tools"
  # fi

  # 4) Build kconfig-frontends-native for mconf (needed by gen-machine-conf)
  log "Building kconfig-frontends-native (for mconf)..."
  run_in_oe_env "$BUILD_DIR" bitbake kconfig-frontends-native -c populate_sysroot

  local native_sysroot="$BUILD_DIR/tmp/sysroots-components/x86_64/kconfig-frontends-native"
  [[ -x "$native_sysroot/usr/bin/mconf" ]] || die "mconf not found after build: $native_sysroot/usr/bin/mconf"

  # 5) Run gen-machine-conf parse-sdt
  log "Generating MACHINE with gen-machine-conf (parse-sdt)..."
  local gen_machine="$GEN_MACHINE_CONF_DIR/gen-machine-conf"
  [[ -x "$gen_machine" ]] || die "gen-machine-conf not executable: $gen_machine"

  "$gen_machine" parse-sdt \
    --hw-description "$SDT_OUT_DIR" \
    --soc-family zynq \
    --machine-name "$MACHINE_NAME" \
    -c "$BSP_DIR/conf" \
    --native-sysroot "$native_sysroot"

  # 6) local.conf updates
  local localconf="$BUILD_DIR/conf/local.conf"
  log "Updating $localconf"
  set_conf_kv "$localconf" "MACHINE" "\"$MACHINE_NAME\""

  # Optional: silence sanity checks (safe; useful because we add meta-virt mainly for lopper)
  append_if_missing "$localconf" 'SKIP_META_VIRT_SANITY_CHECK = "1"'
  append_if_missing "$localconf" 'SKIP_META_SECURITY_SANITY_CHECK = "1"'
  append_if_missing "$localconf" 'SKIP_META_TPM_SANITY_CHECK = "1"'
  append_if_missing "$localconf" 'DISTRO_FEATURES:append = " systemd usrmerge"'
  append_if_missing "$localconf" 'VIRTUAL-RUNTIME_init_manager = "systemd"'
  append_if_missing "$localconf" 'VIRTUAL-RUNTIME_initscripts = ""'
  append_if_missing "$localconf" 'XILINX_WITH_ESW = "1"'
  append_if_missing "$localconf" 'ROOT_HOME = "/root"'

  if [[ "$ACCEPT_XILINX_LICENSE_FLAGS" == "1" ]]; then
    append_if_missing "$localconf" 'LICENSE_FLAGS_ACCEPTED:append = " xilinx"'
  fi

  # 7) Optional DT fixup include + file (safe to keep; only used if included)
  if [[ "$ENABLE_SYSTEM_USER_DTSI" == "1" ]]; then
    append_if_missing "$localconf" 'EXTRA_DT_INCLUDE_FILES:pn-device-tree = "system-user.dtsi"'
    local sysuser_dir="$BSP_DIR/recipes-bsp/device-tree/files/$MACHINE_NAME"
    mkdir -p "$sysuser_dir"
    local sysuser="$sysuser_dir/system-user.dtsi"
    if [[ ! -f "$sysuser" ]]; then
      log "Creating DT fixup: $sysuser"
      cat > "$sysuser" <<'EOF'
/* system-user.dtsi: compile-time fixups (single-core Z7-07S) */

 / {
     axi {
         /delete-node/ ptm@f889d000;

         funnel@f8804000 {
             in-ports {
                 /delete-node/ port@1;
             };
         };
     };
 };
EOF
    fi
  fi

  # 8) Build
  log "Cleaning before build..."
  run_in_oe_env "$BUILD_DIR" bitbake -c cleansstate "$IMAGE_TARGET"
  run_in_oe_env "$BUILD_DIR" bitbake -c cleansstate device-tree

  log "Building device-tree..."
  run_in_oe_env "$BUILD_DIR" bitbake device-tree

  log "Building image: $IMAGE_TARGET ..."
  run_in_oe_env "$BUILD_DIR" bitbake "$IMAGE_TARGET"
  run_in_oe_env "$BUILD_DIR" bitbake "$IMAGE_TARGET" -c populate_sdk

  log "Build complete."
  log "Artifacts:"
  run_in_oe_env "$BUILD_DIR" bash -lc 'ls -lah tmp/deploy/images/${MACHINE}/ || true'

  log ""
  # Inspect WIC contents (pick the newest .wic.qemu-sd)
  run_in_oe_env "$BUILD_DIR" bash -lc '
  set -e
  M="'${MACHINE_NAME}'"
  D="tmp/deploy/images/${M}"
  WIC_IMG=$(ls -t "${D}/"*.wic.qemu-sd 2>/dev/null | head -n 1 || true)
  if [ -z "$WIC_IMG" ]; then
    echo "[WARN] No *.wic.qemu-sd found in ${D}"
    exit 0
  fi
  echo "[INFO] WIC image: $WIC_IMG"
  echo ""
  wic ls "$WIC_IMG"
  echo ""
  wic ls "${WIC_IMG}:1" || true
  echo ""
  wic ls "${WIC_IMG}:2" || true
  '

  log "DONE."
}

main "$@"
