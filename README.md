# remote-devel

STM32 (NUCLEO-F411RE) firmware development in a GitHub Codespace, with the board on a local
Windows PC and debugging through a reverse SSH tunnel (OpenOCD + `gh codespace ssh -R`).

| Path | Content |
|---|---|
| [`setup_toolchain.sh`](setup_toolchain.sh) | Checks the Codespace toolchain, prints the `apt` commands for missing tools |
| [`blinky/`](blinky/) | HAL + CMake LED blink project, PC-side debug bridge script, full guide in [`blinky/README.md`](blinky/README.md) |
| [`.vscode/`](.vscode/) | Cortex-Debug F5 configs and build/flash tasks (open this folder as the workspace) |

Quick start (in the Codespace):
```bash
./setup_toolchain.sh
cd blinky && ./fetch_drivers.sh
cmake --preset debug && cmake --build --preset debug
```
