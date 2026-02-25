#!/usr/bin/env bash
set -euo pipefail

USERNAME="ravig31"

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Run this script as root (or via sudo from a root shell)."
  exit 1
fi

echo "==> Creating user: ${USERNAME}"

# Create user if it doesn't exist
if id -u "${USERNAME}" >/dev/null 2>&1; then
  echo "User ${USERNAME} already exists - skipping useradd."
else
  # Create with home dir + bash shell
  useradd -m -s /bin/bash "${USERNAME}"
  echo "User created."
fi

echo
echo "==> Set password for ${USERNAME}"
passwd "${USERNAME}"

# Add to sudo group if available (Debian/Ubuntu)
if getent group sudo >/dev/null; then
  usermod -aG sudo "${USERNAME}"
  echo "Added ${USERNAME} to sudo group."
elif getent group wheel >/dev/null; then
  usermod -aG wheel "${USERNAME}"
  echo "Added ${USERNAME} to wheel group."
else
  echo "WARNING: No sudo/wheel group found; skipping sudo-group assignment."
fi

# Detect package manager and install dependencies
echo
echo "==> Installing packages for C++ + libpcap + perf tooling"

if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive

  apt-get update -y

  # Core build + tooling
  apt-get install -y \
    build-essential \
    gcc g++ \
    clang clang-format clang-tidy lld \
    cmake ninja-build make \
    pkg-config \
    git \
    ccache \
    gdb \
    valgrind \
    strace ltrace \
    linux-tools-common \
    linux-tools-generic \
    linux-tools-$(uname -r) \
    perf-tools-unstable \
    libpcap-dev \
    tcpdump \
    python3 python3-pip \
    unzip tar \
    ca-certificates curl wget \
    doxygen graphviz

  # Optional but useful libraries for clean C++ output / formatting
  apt-get install -y \
    libfmt-dev || true

  # Unit test support (gtest headers + sources; you can build/link yourself via CMake FetchContent too)
  apt-get install -y \
    libgtest-dev || true

  # Docker (common for the take-home Dockerfile workflow)
  apt-get install -y docker.io docker-compose-plugin || true
  systemctl enable --now docker >/dev/null 2>&1 || true

elif command -v dnf >/dev/null 2>&1; then
  dnf -y update

  dnf -y install \
    gcc gcc-c++ \
    clang clang-tools-extra lld \
    cmake ninja-build make \
    pkgconf-pkg-config \
    git \
    ccache \
    gdb \
    valgrind \
    strace ltrace \
    perf \
    libpcap libpcap-devel \
    tcpdump \
    python3 python3-pip \
    unzip tar \
    ca-certificates curl wget \
    doxygen graphviz \
    fmt fmt-devel \
    gtest gtest-devel \
    docker docker-compose-plugin

  systemctl enable --now docker >/dev/null 2>&1 || true

elif command -v pacman >/dev/null 2>&1; then
  pacman -Syu --noconfirm

  pacman -S --noconfirm \
    base-devel \
    gcc clang lld \
    cmake ninja make \
    pkgconf \
    git \
    ccache \
    gdb \
    valgrind \
    strace ltrace \
    perf \
    libpcap \
    tcpdump \
    python python-pip \
    unzip tar \
    ca-certificates curl wget \
    doxygen graphviz \
    fmt \
    gtest \
    docker docker-compose

  systemctl enable --now docker >/dev/null 2>&1 || true
else
  echo "ERROR: Unsupported distro (no apt-get/dnf/pacman found)."
  exit 1
fi

# Add user to docker group if docker group exists (so you can run docker without sudo)
if getent group docker >/dev/null 2>&1; then
  usermod -aG docker "${USERNAME}"
  echo "Added ${USERNAME} to docker group."
fi

# Useful defaults for perf on some distros (may still require kernel perf_event settings)
echo
echo "==> Applying a couple of sensible perf-related sysctls (best-effort)"
sysctl -w kernel.perf_event_paranoid=1 >/dev/null 2>&1 || true
sysctl -w kernel.kptr_restrict=1 >/dev/null 2>&1 || true

echo
echo "==> Done."
echo "You can now login as ${USERNAME}."
echo "Switching to ${USERNAME} shell now..."

exec su - "${USERNAME}"
