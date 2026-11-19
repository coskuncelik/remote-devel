# blinky – NUCLEO-F411RE, built and debugged from a GitHub Codespace

LED blink for the ST **NUCLEO-F411RE** (STM32F411RE, Cortex-M4F) using the STM32 HAL and CMake.
Everything (compiler, debugger, editor) runs in a GitHub Codespace in the browser. The board
is plugged into a Windows PC. The debugger reaches the board through a **reverse SSH tunnel**.

```
 Codespace (cloud)                                 Windows PC (desk)
┌──────────────────────────────┐   SSH -R tunnel  ┌───────────────────────────┐  USB   ┌────────────┐
│ VS Code (browser) + Cortex-  │   (gh codespace  │ OpenOCD 127.0.0.1:3333    │───────►│ ST-LINK    │
│ Debug ─► gdb-multiarch ─►    │═══ ssh -R ...) ══│        127.0.0.1:4444     │        │  ─SWD─►    │
│ localhost:3333 / :4444       │                  │ tools/debug-bridge.ps1    │        │ STM32F411  │
└──────────────────────────────┘                  └───────────────────────────┘        └────────────┘
```

**Firmware behaviour:** LD2 (green, PA5) double-blinks: 200 ms on, 200 ms off, 200 ms on, then 1 s off.
**Clock:** 100 MHz SYSCLK from the HSI (16 MHz) via the PLL.

---

## Project layout

| Path | Purpose |
|---|---|
| `Core/Src/main.c` | Clock setup, GPIO setup, LED pattern loop |
| `Core/Inc/main.h` | Board pins and **LED pattern settings** |
| `Core/Src/stm32f4xx_it.c` | Fault handlers, SysTick (1 ms tick for `HAL_Delay`) |
| `Core/Src/syscalls.c` | Minimal newlib stubs |
| `Core/Inc/stm32f4xx_hal_conf.h` | HAL modules in use; `HSE_VALUE` = 8 MHz |
| `STM32F411RETX_FLASH.ld` | Linker script (512 KB flash, 128 KB RAM) |
| `CMakeLists.txt`, `CMakePresets.json`, `cmake/arm-none-eabi.cmake` | Build system (presets `debug`, `release`) |
| `fetch_drivers.sh` | Downloads ST CMSIS + HAL drivers (pinned versions) into `Drivers/` |
| `STM32F411.svd` | Register description for the debugger's peripheral view |
| `tools/debug-bridge.ps1` | **Runs on the Windows PC**: starts OpenOCD + the tunnel |
| `../setup_toolchain.sh` | Checks the Codespace toolchain, prints missing `apt` commands |
| `../.vscode/launch.json`, `tasks.json` | F5 debug configs and build/flash tasks (open the repo root as the VS Code workspace) |

ST driver versions (see `fetch_drivers.sh`): CMSIS core `v5.9.0_20250520`,
`cmsis_device_f4` `v2.6.12`, `stm32f4xx_hal_driver` `v1.8.6`.

---

## 1. One-time setup

### Codespace
```bash
cd /workspaces/codespaces-blank/remote-devel
./setup_toolchain.sh            # lists missing tools + the apt command to install them
cd blinky
./fetch_drivers.sh              # ~40 MB into Drivers/ (not in git)
code --install-extension marus25.cortex-debug
```
Required tools: `gcc-arm-none-eabi`, `libnewlib-arm-none-eabi`, `gdb-multiarch`, `cmake`,
`ninja-build`, `git`. The apt packages are lost when the Codespace is **rebuilt**: re-run
`setup_toolchain.sh` after a rebuild.

### Windows PC
| Tool | Notes |
|---|---|
| **ST-LINK USB driver** (ST *STSW-LINK009*) | Needs admin. Without it the ST-LINK shows a yellow ⚠ in Device Manager and OpenOCD reports `open failed` / `LIBUSB_ERROR`. Drag-and-drop flashing works without it. |
| **OpenOCD** (xPack build) | Unzip, add `bin\` to PATH. Check: `openocd --version` |
| **GitHub CLI** | `winget install GitHub.cli`, then `gh auth login` and `gh auth refresh -h github.com -s codespace` |
| **ssh** | Built into Windows 10/11. Check: `ssh -V` |

Check the probe once (board plugged in):
```powershell
openocd -f board/st_nucleo_f4.cfg -c "init; targets; shutdown"
```
Expect `STLINK V2J...`, `Target voltage: 3.2...`, `Cortex-M4 r0p1 processor detected`.

---

## 2. Build

In VS Code: **Ctrl+Shift+B** (task *blinky: build (debug)*). Or in a terminal:
```bash
cmake --preset debug && cmake --build --preset debug
# -> build/debug/blinky.elf / .bin / .hex / .map
```
Release (`-Os`): `cmake --preset release && cmake --build --preset release`.

### Change the LED pattern
Edit `Core/Inc/main.h`:
```c
#define LED_PULSES        2U     // pulses per group
#define LED_PULSE_ON_MS   200U
#define LED_PULSE_OFF_MS  200U   // gap between pulses
#define LED_PAUSE_MS      1000U  // pause after the group
```

---

## 3. Start the debug bridge (on the Windows PC)

Download `tools/debug-bridge.ps1` to the PC (in the Codespace explorer: right-click → *Download*),
plug in the board and run:
```powershell
powershell -ExecutionPolicy Bypass -File .\debug-bridge.ps1
```
The script:
1. checks `gh`, `ssh`, `openocd` and the GitHub login,
2. finds your running Codespace (or use `-Codespace <full-name>`),
3. starts OpenOCD on `127.0.0.1:3333` (GDB) and `:4444` (telnet), log in `%TEMP%\openocd-debug-bridge.log`,
4. opens the reverse tunnel and re-opens it if it drops.

Leave it running. **Ctrl+C** stops the tunnel and OpenOCD.

<details>
<summary>Manual alternative (two PowerShell windows)</summary>

```powershell
openocd -f board/st_nucleo_f4.cfg -c "bindto 127.0.0.1"
gh codespace ssh -c <full-codespace-name> -- -N -R 3333:127.0.0.1:3333 -R 4444:127.0.0.1:4444
```
The full Codespace name is shown by `gh codespace list`, or inside the Codespace by `echo $CODESPACE_NAME`.
</details>

In the Codespace, the task **blinky: check tunnel** tells you whether the bridge is reachable.

---

## 4. Debug (F5) and flash

**Run and Debug** (Ctrl+Shift+D) → choose a configuration → **F5**:

| Configuration | What it does |
|---|---|
| **Blinky: Flash & Debug (remote OpenOCD)** | Builds, flashes, resets, stops at `main()` |
| **Blinky: Attach to running board (no flash)** | Halts the running firmware where it is |

Useful views: *Variables*, *Watch* (e.g. `blink_count`), **XPERIPHERALS** (e.g. GPIOA → ODR → ODR5 = LED),
*Registers*, *Disassembly*. If the configurations are missing after installing Cortex-Debug,
run **Developer: Reload Window** once.

Flash without debugging: task **blinky: flash & run (remote OpenOCD)**.

Flash without any tools: download `build/debug/blinky.bin`, then drag it onto the **NODE_F411RE**
USB drive. The file disappears after copying: that is normal.

Over the tunnel, flashing runs at about 1 KB/s and each debugger step costs one internet round trip.
That is fine for small programs, but slower than a probe connected locally.

---

## 5. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `gh codespace ssh`: `HTTP 404: Not Found` | `-c` needs the **full** name (`ubiquitous-enigma-7vxj…`), not the display name. Or `gh` is logged into another GitHub account (`gh auth status`). |
| GDB: `Remote connection closed` immediately, tunnel window: `connect_to localhost port 3333: failed` | Tunnel uses `localhost` → Windows picks IPv6 `::1`, OpenOCD listens on IPv4. Use `-R 3333:127.0.0.1:3333` (the script does). |
| `openocd`: `Access is denied` | A company policy (AppLocker/WDAC) blocks unsigned programs. Ask IT, or use another machine. |
| OpenOCD: `open failed`, `LIBUSB_ERROR_*`; ST-LINK has a yellow ⚠ | ST-LINK driver missing (needs admin). |
| OpenOCD: `init mode failed`, `unable to connect to the target` | USB cable, CN2 jumpers (both fitted), or firmware put the chip into a bad state: hold RESET while connecting. |
| `Port 3333 or 4444 is already in use` (script) | An old OpenOCD is still running. Close it (Task Manager → `openocd.exe`). |
| `Unable to match requested speed 2000 kHz, using 1800 kHz` | Harmless. The ST-LINK/V2-1 supports only fixed SWD speeds. |
| `Error: Failed to read memory at 0x20020004` | Harmless. Right after a reset SP = `0x20020000` (top of RAM); GDB reads just above it while unwinding. |
| F5: *Configured debug type 'cortex-debug' is not supported* | Cortex-Debug not active: **Developer: Reload Window**. |
| F5 hangs / times out | Bridge not running or Codespace name wrong: run task *blinky: check tunnel*. |
| Drag-and-drop shows `FAIL.TXT` | Read it; usually wrong file (`.elf` instead of `.bin`) or old ST-LINK firmware. |
| `ST drivers missing. Run ./fetch_drivers.sh first.` | `Drivers/` is not in git; run `./fetch_drivers.sh`. |
