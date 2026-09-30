<#
.SYNOPSIS
    Loads the ghost's SATORI dictionaries with tamac.exe and reports load errors and problems in the SATORI log.
.DESCRIPTION
    Exit codes: 0 = OK, 1 = errors found, 3 = tamac.exe is not installed (run tools/setup.ps1).
    The check runs in a temporary copy of ghost/master, so the real folder is not touched (SATORI would write
    satori_savedata.txt and satori_savebackup.txt into it when it unloads).

    What is read from the SATORI log (the patterns are in tools/satori.json; see docs/agents/workflows/check.md):
      - a dictionary with an unclosed full-width bracket (the "brackets do not match" message, which SATORI
        reports as [ERROR])
      - a wrong line in the SAORI list of satori_conf.txt, or a SAORI dll that does not load
      - a dictionary file that cannot be read, or no dic*.txt at all
    SATORI checks nothing else when it loads: the dictionaries are interpreted when a sentence is run, so a
    misspelled function, a bad variable assignment line or a jump to a missing sentence shows up only then.
    -Run runs every sentence that has a plain name (no condition, one word) once with ShioriEcho in the temporary
    copy and reads the log of that too: a call with arguments to a name that does not exist, a calculation that
    failed, a wrong number of arguments, an assignment line without a tab or equal sign, and so on. Names that were
    not found are warnings (a variable that was never set is reported the same way); jumps to missing sentences
    are not reported, because dictionaries rely on them. -Run really calls SAORI (fill_desktop and so on) from the
    sentences, so use it when that is acceptable. Random talks (sentences without a name) and sentences with a
    condition are not run by -Run; try them with tools/shiori.ps1 -Event OnTalk.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools/check-dic.ps1
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools/check-dic.ps1 -Run
#>
[CmdletBinding()]
param(
    # Folder that contains satori.dll (default: ghost/master).
    [string]$GhostDir,
    # Also run every sentence that has a plain name once (in the temporary copy) and read the log of that.
    [switch]$Run,
    # Treat warnings as failures.
    [switch]$Strict,
    # Emit GitHub Actions annotations.
    [switch]$Ci,
    # Also print the whole SATORI log.
    [switch]$ShowLog,
    [int]$TimeoutSeconds = 120
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/satori.ps1')
Initialize-DevkitConsole

if (-not $GhostDir) { $GhostDir = Join-Path $DevkitRoot 'ghost/master' }
$GhostDir = (Resolve-DevkitFullPath $GhostDir).TrimEnd('\', '/')
$dll = Join-Path $GhostDir 'satori.dll'
if (-not (Test-Path -LiteralPath $dll)) {
    Write-Host "check-dic: FAILED - satori.dll was not found in $GhostDir"
    exit 1
}

$tamac = Get-DevkitToolPath 'tamac'
if (-not (Test-Path -LiteralPath $tamac)) {
    Write-Host 'check-dic: SKIPPED - tamac.exe is not installed. Run: powershell -NoProfile -ExecutionPolicy Bypass -File tools/setup.ps1'
    exit 3
}

# Paths in the output are shown relative to the ghost root (the folder with ghost/ and shell/).
$base = Split-Path (Split-Path $GhostDir -Parent) -Parent
$version = Get-DevkitSatoriVersion $dll
Write-Host "check-dic: satori.dll $($version.Text)"

# --- load ------------------------------------------------------------------------------------------------------
$result = Invoke-DevkitTamac -GhostDir $GhostDir -TimeoutSeconds $TimeoutSeconds
if ($ShowLog) {
    Write-Host '---- SATORI log (load) ----'
    foreach ($line in ($result.Log -split "`n")) { Write-Host (ConvertTo-DevkitGhostText $line $result.Sandbox $GhostDir $base) }
    Write-Host '---------------------------'
}
if ($result.TimedOut) {
    Write-Host 'check-dic: FAILED - tamac.exe timed out'
    exit 1
}
$diagnostics = @(Get-DevkitSatoriDiagnostics -Log $result.Log -Sandbox $result.Sandbox -GhostDir $GhostDir -Base $base)
$loaded = @([regex]::Matches($result.Log, '(?m)^\s+loading (?!satori_)\S+')).Count
$errors = Write-DevkitSatoriDiagnostics $diagnostics 'SATORI dictionary check' -Ci:$Ci
$warnings = @($diagnostics | Where-Object { $_.Level -eq 'warning' }).Count
if ($errors -eq 0 -and $result.ExitCode -ne 0) {
    Write-Host "check-dic: FAILED (tamac.exe exit code $($result.ExitCode)); no SATORI message explains it. Use -ShowLog."
    exit 1
}

# --- run the sentences ---------------------------------------------------------------------------------------
$ran = 0
if ($Run -and $errors -eq 0) {
    $names = @(Get-DevkitSatoriTalkNames $GhostDir)
    # A request holds at most 3800 bytes of sentence names and the sentences are run in as many tamac.exe runs
    # as needed (tamac.exe before 1.0.3.26 corrupted multi-byte characters in requests of more than 4096 bytes).
    $batches = New-Object System.Collections.Generic.List[object]
    $current = New-Object System.Collections.Generic.List[string]
    $bytes = 0
    foreach ($name in $names) {
        $size = $DevkitUtf8.GetByteCount("Reference999: " + [char]0xFF08 + $name + [char]0xFF09) + 1
        if ($current.Count -gt 0 -and ($bytes + $size) -gt 3800) {
            $batches.Add($current.ToArray())
            $current = New-Object System.Collections.Generic.List[string]
            $bytes = 0
        }
        $current.Add($name)
        $bytes += $size
    }
    if ($current.Count -gt 0) { $batches.Add($current.ToArray()) }
    foreach ($chunk in $batches) {
        $request = New-Object System.Collections.Generic.List[string]
        $request.Add('GET SHIORI/3.0')
        $request.Add('Charset: UTF-8')
        $request.Add('Sender: SSP')
        $request.Add('SecurityLevel: local')
        $request.Add('ID: ShioriEcho')
        for ($i = 0; $i -lt $chunk.Count; $i++) {
            $request.Add("Reference${i}: " + [char]0xFF08 + $chunk[$i] + [char]0xFF09)
        }
        $echoRun = Invoke-DevkitTamac -GhostDir $GhostDir -Arguments @('-r') -InputText ($request -join "`n") -EnableDebug -TimeoutSeconds $TimeoutSeconds
        if ($ShowLog) {
            Write-Host '---- SATORI log (run) ----'
            foreach ($line in ($echoRun.Log -split "`n")) { Write-Host (ConvertTo-DevkitGhostText $line $echoRun.Sandbox $GhostDir $base) }
            Write-Host '--------------------------'
        }
        if ($echoRun.TimedOut) {
            Write-Host 'check-dic: FAILED - tamac.exe timed out while running the sentences (an endless loop?)'
            exit 1
        }
        if ($echoRun.Response -notmatch '^SHIORI/\d\.\d\s+(200|204)') {
            Write-Host "check-dic: FAILED - ShioriEcho was not answered as expected: $(($echoRun.Response -split "`n")[0])"
            $errors++
            continue
        }
        $ran += $chunk.Count
        # The load messages were reported above; only what happened while running is new.
        $runDiagnostics = @(Get-DevkitSatoriDiagnostics -Log $echoRun.Log -Sandbox $echoRun.Sandbox -GhostDir $GhostDir -Base $base | Where-Object { $_.Phase -ne 'load' })
        $errors += Write-DevkitSatoriDiagnostics $runDiagnostics 'SATORI dictionary check' -Ci:$Ci
        $warnings += @($runDiagnostics | Where-Object { $_.Level -eq 'warning' }).Count
    }
}

$summary = "$loaded dictionaries" + $(if ($Run) { ", $ran sentences run" }) + ", errors: $errors, warnings: $warnings"
if ($errors -gt 0 -or ($Strict -and $warnings -gt 0)) {
    Write-Host "check-dic: FAILED ($summary). Fix the problems above; a dictionary with an unclosed bracket is not read correctly."
    exit 1
}
Write-Host "check-dic: OK ($summary)"
exit 0
