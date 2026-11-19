#!/usr/bin/env bash
# setup_toolchain.sh - check the STM32 (NUCLEO-F411RE) development toolchain.
# Prints the apt install command for every missing tool. Installs nothing.
# Exit code: 0 = all required tools present, 1 = at least one required tool missing.

set -u

if [ -t 1 ]; then
    GREEN=$'\e[32m'; RED=$'\e[31m'; YELLOW=$'\e[33m'; BOLD=$'\e[1m'; RESET=$'\e[0m'
else
    GREEN=""; RED=""; YELLOW=""; BOLD=""; RESET=""
fi

missing_required=()
missing_optional=()

# check <required|optional> <description> <apt package> <test command...>
check() {
    local kind=$1 desc=$2 pkg=$3
    shift 3
    local out
    if out=$("$@" 2>/dev/null); then
        printf "  ${GREEN}[ OK ]${RESET} %-28s %s\n" "$desc" "$out"
    else
        if [ "$kind" = required ]; then
            printf "  ${RED}[MISS]${RESET} %-28s -> sudo apt install -y %s\n" "$desc" "$pkg"
            missing_required+=("$pkg")
        else
            printf "  ${YELLOW}[MISS]${RESET} %-28s -> sudo apt install -y %s  (optional)\n" "$desc" "$pkg"
            missing_optional+=("$pkg")
        fi
    fi
}

# Prints the first line of "<cmd> --version" if <cmd> exists.
version_of() {
    command -v "$1" >/dev/null || return 1
    "$1" "${2:---version}" 2>&1 | head -n1
}

# newlib is a separate package; detect it by asking the compiler for nano.specs.
newlib_check() {
    command -v arm-none-eabi-gcc >/dev/null || return 1
    local f
    f=$(arm-none-eabi-gcc -print-file-name=nano.specs)
    [ -f "$f" ] && echo "$f"
}

echo "${BOLD}Required tools${RESET}"
check required "ARM GCC (arm-none-eabi-gcc)" gcc-arm-none-eabi        version_of arm-none-eabi-gcc
check required "binutils (objcopy/size)"     binutils-arm-none-eabi    version_of arm-none-eabi-objcopy
check required "newlib C library"            libnewlib-arm-none-eabi   newlib_check
check required "GDB (gdb-multiarch)"         gdb-multiarch             version_of gdb-multiarch
check required "CMake"                       cmake                     version_of cmake
check required "Ninja"                       ninja-build               version_of ninja
check required "Make"                        make                      version_of make
check required "Git (for HAL submodules)"    git                       version_of git
check required "OpenOCD (board configs)"     openocd                   version_of openocd

echo
echo "${BOLD}Optional tools${RESET}"
check optional "st-flash / st-info"          stlink-tools              version_of st-info --version
check optional "clangd (code navigation)"    clangd                    version_of clangd
check optional "telnet (OpenOCD console)"    telnet                    sh -c 'command -v telnet'
check optional "Python 3"                    python3                   version_of python3

echo
if [ ${#missing_required[@]} -eq 0 ] && [ ${#missing_optional[@]} -eq 0 ]; then
    echo "${GREEN}All tools are installed.${RESET}"
    exit 0
fi

if [ ${#missing_required[@]} -gt 0 ]; then
    echo "${BOLD}Install all missing required tools:${RESET}"
    echo "  sudo apt update && sudo apt install -y ${missing_required[*]}"
fi
if [ ${#missing_optional[@]} -gt 0 ]; then
    echo "${BOLD}Install all missing optional tools:${RESET}"
    echo "  sudo apt update && sudo apt install -y ${missing_optional[*]}"
fi

[ ${#missing_required[@]} -eq 0 ]
