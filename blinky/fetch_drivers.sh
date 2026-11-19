#!/usr/bin/env bash
# fetch_drivers.sh - download ST CMSIS + HAL drivers (pinned versions) into Drivers/.
# Resulting layout matches an STM32CubeF4 project:
#   Drivers/CMSIS/Include                    <- ARM CMSIS core headers (core_cm4.h ...)
#   Drivers/CMSIS/Device/ST/STM32F4xx        <- STM32F4 device headers, startup, system file
#   Drivers/STM32F4xx_HAL_Driver             <- ST HAL / LL drivers
# Safe to re-run: existing parts are skipped. Use --force to re-download everything.
set -euo pipefail

cd "$(dirname "$0")"
DRIVERS=Drivers

CMSIS_CORE_TAG=v5.9.0_20250520
CMSIS_DEVICE_TAG=v2.6.12
HAL_TAG=v1.8.6

[ "${1:-}" = "--force" ] && rm -rf "$DRIVERS"

# clone <repo> <tag> <dest>: shallow clone of a tag, without git metadata
clone() {
  echo "fetch $1@$2 -> $3"
  git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$2" \
      "https://github.com/$1.git" "$3" 2> >(grep -v 'is not a commit' >&2)
  rm -rf "$3/.git"
}

if [ ! -d "$DRIVERS/CMSIS/Include" ]; then
  # Only the core headers are needed from the (large) CMSIS repo.
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  clone STMicroelectronics/cmsis_core "$CMSIS_CORE_TAG" "$tmp/cmsis_core"
  mkdir -p "$DRIVERS/CMSIS"
  cp -r "$tmp/cmsis_core/Core/Include" "$DRIVERS/CMSIS/Include"
  cp "$tmp/cmsis_core/LICENSE.md" "$DRIVERS/CMSIS/LICENSE.md"
else
  echo "skip  $DRIVERS/CMSIS/Include (already present)"
fi

if [ ! -d "$DRIVERS/CMSIS/Device/ST/STM32F4xx" ]; then
  clone STMicroelectronics/cmsis_device_f4 "$CMSIS_DEVICE_TAG" "$DRIVERS/CMSIS/Device/ST/STM32F4xx"
else
  echo "skip  $DRIVERS/CMSIS/Device/ST/STM32F4xx (already present)"
fi

if [ ! -d "$DRIVERS/STM32F4xx_HAL_Driver" ]; then
  clone STMicroelectronics/stm32f4xx_hal_driver "$HAL_TAG" "$DRIVERS/STM32F4xx_HAL_Driver"
else
  echo "skip  $DRIVERS/STM32F4xx_HAL_Driver (already present)"
fi

echo "Drivers ready ($(du -sh "$DRIVERS" | cut -f1))."
