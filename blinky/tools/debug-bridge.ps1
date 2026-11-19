<#
.SYNOPSIS
    Debug bridge for NUCLEO-F411RE: starts OpenOCD on this PC and opens a reverse
    SSH tunnel to your GitHub Codespace, so the debugger in the Codespace can reach
    the board at localhost:3333 (GDB) and localhost:4444 (OpenOCD telnet).

.DESCRIPTION
    Codespace (gdb / Cortex-Debug) -> localhost:3333 == SSH -R tunnel ==> this PC
    -> OpenOCD 127.0.0.1:3333 -> ST-LINK (USB) -> STM32F411 (SWD)

    Press Ctrl+C to stop. OpenOCD is stopped automatically.
    If the tunnel drops, it is re-opened after a few seconds.

.PARAMETER Codespace
    Full Codespace name (e.g. ubiquitous-enigma-7vxj4vg5wr9cwr9q).
    If omitted, the only "Available" Codespace is used; with several, you are asked.

.PARAMETER OpenOcd
    Path to openocd.exe. Default: "openocd" from PATH.

.PARAMETER Board
    OpenOCD board config. Default: board/st_nucleo_f4.cfg

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\debug-bridge.ps1
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\debug-bridge.ps1 -Codespace ubiquitous-enigma-7vxj4vg5wr9cwr9q
#>
param(
    [string]$Codespace = "",
    [string]$OpenOcd = "openocd",
    [string]$Board = "board/st_nucleo_f4.cfg",
    [int]$GdbPort = 3333,
    [int]$TelnetPort = 4444
)

# "Continue": with "Stop", Windows PowerShell 5.1 treats any stderr output of
# native tools (gh, ssh) as a fatal error. Exit codes are checked instead.
$ErrorActionPreference = "Continue"
$LogFile = Join-Path $env:TEMP "openocd-debug-bridge.log"

function Write-Step([string]$msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok([string]$msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Fail([string]$msg)       { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }

# True if something accepts TCP connections on 127.0.0.1:<port>.
function Test-LocalPort([int]$port) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect("127.0.0.1", $port, $null, $null)
        if ($async.AsyncWaitHandle.WaitOne(300) -and $client.Connected) { return $true }
        return $false
    } catch {
        return $false
    } finally {
        $client.Close()
    }
}

# --- 1. Tools --------------------------------------------------------------
Write-Step "Checking tools"
foreach ($tool in @("gh", "ssh", $OpenOcd)) {
    $cmd = Get-Command $tool -ErrorAction SilentlyContinue
    if (-not $cmd) { Fail "'$tool' not found. Install it or add it to PATH." }
    Write-Ok "$tool -> $($cmd.Source)"
    if ($tool -eq $OpenOcd) { $OpenOcdExe = $cmd.Source }
}

# --- 2. GitHub login + Codespace -------------------------------------------
Write-Step "Checking GitHub login"
gh auth status *> $null
if ($LASTEXITCODE -ne 0) { Fail "gh is not logged in. Run: gh auth login" }
Write-Ok "gh is logged in"

if (-not $Codespace) {
    Write-Step "Looking for your Codespace"
    $json = gh codespace list --json name,displayName,state
    if ($LASTEXITCODE -ne 0) {
        Fail "Cannot list Codespaces. Run: gh auth refresh -h github.com -s codespace"
    }
    # Assign first: in PowerShell 5.1 ConvertFrom-Json emits a JSON array as ONE object.
    $list = ($json -join "") | ConvertFrom-Json
    $available = @($list | Where-Object { $_.state -eq "Available" })
    if ($available.Count -eq 0) {
        Fail "No running Codespace. Open it in the browser first (it must be 'Available')."
    } elseif ($available.Count -eq 1) {
        $Codespace = $available[0].name
    } else {
        for ($i = 0; $i -lt $available.Count; $i++) {
            Write-Host ("    [{0}] {1}  ({2})" -f $i, $available[$i].name, $available[$i].displayName)
        }
        $choice = Read-Host "Select Codespace number"
        $Codespace = $available[[int]$choice].name
    }
}
Write-Ok "Codespace: $Codespace"

# --- 3. Start OpenOCD ------------------------------------------------------
Write-Step "Starting OpenOCD"
if ((Test-LocalPort $GdbPort) -or (Test-LocalPort $TelnetPort)) {
    Fail "Port $GdbPort or $TelnetPort is already in use. Is another OpenOCD still running? Close it first."
}

$ocdArgs = "-f $Board -c `"bindto 127.0.0.1`" -c `"gdb_port $GdbPort`" -c `"telnet_port $TelnetPort`""
$ocd = Start-Process -FilePath $OpenOcdExe -ArgumentList $ocdArgs -PassThru -NoNewWindow `
    -RedirectStandardError $LogFile -RedirectStandardOutput "$LogFile.out" -ErrorAction Stop

# Wait until OpenOCD listens. Probe the telnet port: a connection to the GDB port
# would make OpenOCD halt the target.
$ready = $false
for ($i = 0; $i -lt 50; $i++) {
    if ($ocd.HasExited) { break }
    if (Test-LocalPort $TelnetPort) { $ready = $true; break }
    Start-Sleep -Milliseconds 200
}
if (-not $ready) {
    Write-Host "---- OpenOCD log ($LogFile) ----" -ForegroundColor Yellow
    if (Test-Path $LogFile) { Get-Content $LogFile -Tail 20 -ErrorAction SilentlyContinue }
    if (-not $ocd.HasExited) { Stop-Process -Id $ocd.Id -Force }
    Fail "OpenOCD did not start. Check the USB cable, the ST-LINK driver and the log above."
}
Write-Ok "OpenOCD running (PID $($ocd.Id)), log: $LogFile"
Get-Content $LogFile -ErrorAction SilentlyContinue | Select-String -Pattern "STLINK|Target voltage|processor detected" |
    ForEach-Object { Write-Ok $_.Line }

# --- 4. Reverse tunnel (re-opened if it drops) -----------------------------
Write-Step "Opening tunnel to $Codespace"
Write-Host "    Codespace localhost:$GdbPort -> this PC 127.0.0.1:$GdbPort (GDB)"
Write-Host "    Codespace localhost:$TelnetPort -> this PC 127.0.0.1:$TelnetPort (OpenOCD telnet)"
Write-Host "    Ready: press F5 in the Codespace. Press Ctrl+C here to stop." -ForegroundColor Green

try {
    while ($true) {
        # 127.0.0.1 (not "localhost"): Windows resolves localhost to ::1 first,
        # but OpenOCD only listens on IPv4.
        gh codespace ssh -c $Codespace -- -N `
            -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 `
            -R "${GdbPort}:127.0.0.1:${GdbPort}" -R "${TelnetPort}:127.0.0.1:${TelnetPort}"

        if ($ocd.HasExited) {
            Write-Host "OpenOCD has stopped (board unplugged?). Last log lines:" -ForegroundColor Yellow
            Get-Content $LogFile -Tail 10 -ErrorAction SilentlyContinue
            break
        }
        Write-Host "Tunnel closed (exit code $LASTEXITCODE). Reconnecting in 5 s... (Ctrl+C to stop)" -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
} finally {
    if (-not $ocd.HasExited) {
        Write-Step "Stopping OpenOCD"
        Stop-Process -Id $ocd.Id -Force
    }
}
