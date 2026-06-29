#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Error at line ${LINENO}: ${BASH_COMMAND}" >&2' ERR

# Install ROOT and musrfit on Ubuntu 24.04.
# Usage:
#   bash installer_v1.9.5.sh
#
# Optional environment variables:
#   INSTALL_HOME=${HOME}
#   ROOT_URL=https://root.cern/download/root_v6.32.02.Linux-ubuntu24.04-x86_64-gcc13.2.tar.gz
#   MUSRFIT_REPO=https://bitbucket.org/muonspin/musrfit.git
#   MUSRFIT_SRC=${INSTALL_HOME}/apps/musrfit
#   MUSRFIT_REF=ebefcf7af9fed9524be78afcf39d81d97577b48b
#   BUILD_JOBS=$(nproc)

INSTALL_HOME="${INSTALL_HOME:-${HOME}}"
APPS_DIR="${INSTALL_HOME}/apps"
ROOT_URL="${ROOT_URL:-https://root.cern/download/root_v6.32.02.Linux-ubuntu24.04-x86_64-gcc13.2.tar.gz}"
ROOT_ARCHIVE="${ROOT_URL##*/}"
TARGET_ROOT_VERSION="${ROOT_ARCHIVE#root_v}"
TARGET_ROOT_VERSION="${TARGET_ROOT_VERSION%%.Linux-*}"
ROOTSYS="${APPS_DIR}/root"
MUSRFIT_REPO="${MUSRFIT_REPO:-https://bitbucket.org/muonspin/musrfit.git}"
MUSRFIT_SRC="${MUSRFIT_SRC:-${APPS_DIR}/musrfit}"
MUSRFIT_REF="${MUSRFIT_REF:-ebefcf7af9fed9524be78afcf39d81d97577b48b}"
BUILD_JOBS="${BUILD_JOBS:-$(command -v nproc >/dev/null 2>&1 && nproc || printf '8')}"
ENV_BLOCK_START="# >>> ROOT and musrfit >>>"
ENV_BLOCK_END="# <<< ROOT and musrfit <<<"
SUDO=()

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

check_not_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    echo "Please do not run this script as root."
    echo "Run it as a normal WSL user. The script will use sudo when needed."
    exit 1
  fi
}

init_sudo() {
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo is required when the script is not run as root." >&2
    exit 1
  fi
  sudo -v
  SUDO=(sudo)
}

check_ubuntu_version() {
  if [[ ! -r /etc/os-release ]]; then
    echo "Cannot read /etc/os-release. This script is intended for Ubuntu 24.04." >&2
    exit 1
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "24.04" ]]; then
    log "Detected Ubuntu 24.04."
    return
  fi

  echo "Detected ${PRETTY_NAME:-unknown OS}; this script is tested for Ubuntu 24.04." >&2
  read -r -p "Continue anyway? [y/N] " answer
  case "${answer}" in
    y|Y|yes|YES) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
}

install_packages() {
  log "Enabling universe repository and installing build dependencies."
  "${SUDO[@]}" apt-get update
  "${SUDO[@]}" apt-get install -y software-properties-common
  "${SUDO[@]}" add-apt-repository -y universe
  "${SUDO[@]}" apt-get update

  local packages=(
    build-essential g++ git cmake wget ca-certificates
    libboost-all-dev
    libgsl-dev libfftw3-dev libxml2-dev
    libhdf4-dev libhdf5-dev libnexus-dev nexus-tools
    qt6-base-dev qt6-base-dev-tools qt6-tools-dev qt6-tools-dev-tools qt6-svg-dev
    libx11-dev libxft-dev libxpm-dev libxext-dev
    zlib1g-dev liblzma-dev liblz4-dev libzstd-dev libssl-dev
    libfreetype-dev libjpeg-dev libpng-dev libgif-dev
    libvdt-dev libtbb12 libtbb-dev
  )
  "${SUDO[@]}" apt-get install -y "${packages[@]}"
}

prepare_directories() {
  log "Preparing ${APPS_DIR}."
  if mkdir -p "${APPS_DIR}" 2>/dev/null && [[ -w "${APPS_DIR}" ]]; then
    return
  fi

  local owner="${USER:-$(id -un)}"
  "${SUDO[@]}" mkdir -p "${APPS_DIR}"
  if id "${owner}" >/dev/null 2>&1; then
    "${SUDO[@]}" chown -R "${owner}:${owner}" "${APPS_DIR}"
  fi
}

install_root() {
  if [[ -x "${ROOTSYS}/bin/root-config" ]]; then
    local installed_root_version
    installed_root_version="$("${ROOTSYS}/bin/root-config" --version)"
    if [[ "${installed_root_version}" == "${TARGET_ROOT_VERSION}" ]]; then
      log "ROOT ${installed_root_version} already exists at ${ROOTSYS}; skipping download."
      return
    fi

    echo "ROOT already exists at ${ROOTSYS}, but its version is ${installed_root_version}." >&2
    echo "This installer expects ROOT ${TARGET_ROOT_VERSION}." >&2
    echo "Move the existing ROOT directory away or set INSTALL_HOME to a different path." >&2
    exit 1
  fi

  log "Checking ROOT download URL."
  if ! wget --spider -q "${ROOT_URL}"; then
    echo "Cannot access ROOT_URL: ${ROOT_URL}" >&2
    echo "Please check whether the ROOT version exists or the network is available." >&2
    exit 1
  fi

  log "Downloading ROOT from ${ROOT_URL}."
  cd "${APPS_DIR}"
  wget -c "${ROOT_URL}"

  log "Extracting ${ROOT_ARCHIVE}."
  tar -xzf "${ROOT_ARCHIVE}"

  if [[ ! -x "${ROOTSYS}/bin/root-config" ]]; then
    echo "ROOT extraction finished, but ${ROOTSYS}/bin/root-config was not found." >&2
    exit 1
  fi
}

configure_dynamic_linker() {
  log "Configuring dynamic linker for ROOT."
  echo "${ROOTSYS}/lib" | "${SUDO[@]}" tee /etc/ld.so.conf.d/cern-root.conf >/dev/null
  "${SUDO[@]}" /sbin/ldconfig
}

upsert_env_block() {
  local target="$1"
  local tmp
  tmp="$(mktemp)"

  mkdir -p "$(dirname "${target}")"
  touch "${target}"

  sed "/^${ENV_BLOCK_START}$/,/^${ENV_BLOCK_END}$/d" "${target}" > "${tmp}"
  cat >> "${tmp}" <<EOF
${ENV_BLOCK_START}
export ROOTSYS=${ROOTSYS}
export PATH=\$ROOTSYS/bin:\$PATH
export MUSRFITPATH=\$ROOTSYS/bin
${ENV_BLOCK_END}
EOF
  mv "${tmp}" "${target}"
}

configure_shell_profiles() {
  log "Adding ROOT and musrfit environment variables to shell profiles."
  upsert_env_block "${INSTALL_HOME}/.bashrc"
}

clone_or_update_musrfit() {
  log "Using musrfit ref: ${MUSRFIT_REF}"

  if [[ -d "${MUSRFIT_SRC}/.git" ]]; then
    log "Fetching musrfit refs and tags in existing source tree."
    git -C "${MUSRFIT_SRC}" fetch --all --tags
  elif [[ -e "${MUSRFIT_SRC}" ]]; then
    echo "${MUSRFIT_SRC} exists but is not a git repository." >&2
    echo "Please move it away or set MUSRFIT_SRC to a different path." >&2
    exit 1
  else
    log "Cloning musrfit from ${MUSRFIT_REPO}."
    git clone "${MUSRFIT_REPO}" "${MUSRFIT_SRC}"
  fi

  git -C "${MUSRFIT_SRC}" checkout "${MUSRFIT_REF}"
}

build_musrfit() {
  log "Building musrfit with ${BUILD_JOBS} parallel jobs."
  rm -rf "${MUSRFIT_SRC}/build"
  mkdir -p "${MUSRFIT_SRC}/build"
  cd "${MUSRFIT_SRC}/build"

  # shellcheck disable=SC1091
  source "${ROOTSYS}/bin/thisroot.sh"
  cmake .. \
    -DCMAKE_INSTALL_PREFIX="${ROOTSYS}" \
    -DCMAKE_BUILD_TYPE=Release \
    -Dnexus=1 \
    -DHAVE_HDF4=1 \
    -DNEXUS_INCLUDE_DIR=/usr/include/nexus \
    -DNEXUS_LIBRARY=/usr/lib/x86_64-linux-gnu/libNeXus.so
  cmake --build . --clean-first -- -j"${BUILD_JOBS}"
  cmake --install .
  "${SUDO[@]}" /sbin/ldconfig
}

report_versions() {
  log "Installation report."

  # shellcheck disable=SC1091
  source "${ROOTSYS}/bin/thisroot.sh"

  root-config --version || true
  root-config --prefix || true
  which musrfit || true
  which musredit || true
  which musrview || true
  git -C "${MUSRFIT_SRC}" rev-parse --short HEAD || true
  git -C "${MUSRFIT_SRC}" log -1 --oneline || true
}

main() {
  check_not_root
  check_ubuntu_version
  init_sudo
  install_packages
  prepare_directories
  install_root
  configure_dynamic_linker
  configure_shell_profiles
  clone_or_update_musrfit
  build_musrfit
  report_versions

  printf '\n'
  printf '\033[1;32m============================================================\033[0m\n'
  printf '\033[1;32m                  INSTALLATION SUCCESSFUL                  \033[0m\n'
  printf '\033[1;32m============================================================\033[0m\n\n'

  printf '\033[1;36mAuthor:\033[0m EC, from Fudan University.\n'
  printf '\033[1;35mPlease leave your comment in this GitHub project at https://github.com/empressfiona01-eng/Fast-Installation-for-Musrfit.\033[0m\n\n'

  cat <<'EOF'

            /\___/\
            )     (
           =\     /=
             )   (
            /     \
            )     (
           /       \     
           \       /
            \__ __/
               ))
              //
             ((
              \)

EOF
  printf '\033[1;33mOpen a new shell, or run:\033[0m\n'
  printf '\033[1;37;44m  source ~/.bashrc  \033[0m\n'
  printf '\033[1;33mThen run:\033[0m\n'
  printf '\033[1;37;44m  musredit  \033[0m\n'
  printf '\033[1;33mRun source ~/.bashrc and musredit to open musrfit immediately.\033[0m\n'
}

main "$@"
