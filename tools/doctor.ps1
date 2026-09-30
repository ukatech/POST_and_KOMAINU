<#
.SYNOPSIS
    Checks the development environment and tells what is missing and how to get it.
.DESCRIPTION
    Read-only: nothing is installed or changed.
    Each item has a level: required (the checks cannot run without it), recommended, or optional.
    Exit codes: 0 = all required items are ready, 1 = a required item is missing.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools/doctor.ps1
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools/doctor.ps1 -Json
#>
[CmdletBinding()]
param(
    # Print the result as JSON (for agents).
    [switch]$Json
)
$ErrorActionPreference = 'Stop'
$WarningPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/devkit.ps1')
. (Join-Path $PSScriptRoot 'lib/satori.ps1')
Initialize-DevkitConsole

$items = New-Object System.Collections.Generic.List[object]
function Add-DoctorItem {
    param([string]$Id, [string]$Name, [string]$Level, [bool]$Ok, [string]$Purpose, [string]$Detail, [string]$Fix)
    $items.Add([pscustomobject]@{ id = $Id; name = $Name; level = $Level; ok = $Ok; purpose = $Purpose; detail = $Detail; fix = $Fix })
}

$ps = 'powershell -NoProfile -ExecutionPolicy Bypass -File'
$hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
$isGitWorkingCopy = Test-Path -LiteralPath (Join-Path $DevkitRoot '.git')

# --- Windows ---------------------------------------------------------------------------
$isWindowsOs = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
Add-DoctorItem -Id 'windows' -Name 'Windows' -Level 'required' -Ok $isWindowsOs `
    -Purpose 'SSP, SATORI and tamac.exe run only on Windows' `
    -Detail ([Environment]::OSVersion.VersionString) `
    -Fix 'Use a Windows PC.'

# --- Windows PowerShell (used by tools/*.ps1 and the Claude Code hooks) ------------------
$windowsPowerShell = Get-Command powershell.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
Add-DoctorItem -Id 'powershell' -Name 'Windows PowerShell' -Level 'required' -Ok ([bool]$windowsPowerShell) `
    -Purpose 'Runs tools/*.ps1 and the Claude Code hooks' `
    -Detail $(if ($windowsPowerShell) { "PowerShell $($PSVersionTable.PSVersion) is running; powershell.exe found" } else { 'powershell.exe was not found' }) `
    -Fix 'Windows PowerShell is part of Windows. Check that it has not been removed or blocked.'

# --- ghost files -----------------------------------------------------------------------
$ghostMaster = Join-Path $DevkitRoot 'ghost/master'
$dll = Join-Path $ghostMaster 'satori.dll'
$dictionaryCount = 0
if (Test-Path -LiteralPath $ghostMaster -PathType Container) {
    $dictionaryCount = @(Get-ChildItem -LiteralPath $ghostMaster -File -Filter 'dic*.txt' -ErrorAction SilentlyContinue).Count
}
$ghostOk = (Test-Path -LiteralPath $dll) -and $dictionaryCount -gt 0
$satoriVersion = Get-DevkitSatoriVersion $dll
Add-DoctorItem -Id 'ghost' -Name 'ghost files' -Level 'required' -Ok $ghostOk `
    -Purpose 'The ghost itself' `
    -Detail $(if ($ghostOk) { "satori.dll $($satoriVersion.Text), $dictionaryCount dictionaries (dic*.txt)" } elseif (-not (Test-Path -LiteralPath $dll)) { 'ghost/master/satori.dll is missing' } else { 'no ghost/master/dic*.txt' }) `
    -Fix 'Work in the ghost root folder (the one that contains ghost/ and shell/).'

# A ghost whose descript.txt says UTF-8 needs the Unicode build of SATORI (Mc2XX); the ACP build (Mc1XX) reads
# dictionaries in the system code page. The Unicode build reads UTF-8 and Shift_JIS dictionaries.
$charset = Get-DevkitDescriptValue (Join-Path $ghostMaster 'descript.txt') 'charset'
$charsetOk = -not ($satoriVersion -and $satoriVersion.Variant -eq 'ACP' -and $charset -match '^(?i:utf-?8)$')
Add-DoctorItem -Id 'satori-build' -Name 'SATORI build' -Level 'recommended' -Ok $charsetOk `
    -Purpose 'Dictionaries and descript.txt are UTF-8, which the Unicode build of SATORI (Mc2XX) reads' `
    -Detail $(if ($satoriVersion) { "$($satoriVersion.Text); charset in descript.txt: $(if ($charset) { $charset } else { '(none)' })" } else { 'satori.dll not found' }) `
    -Fix "Run: $ps tools/update-satori.ps1 -Variant Unicode (see docs/agents/workflows/update-satori.md)"

# --- ghost profile and kit updates -----------------------------------------------------
$ghostProfile = Join-Path $DevkitRoot 'GHOST.md'
$profileState = 'ok'
if (-not (Test-Path -LiteralPath $ghostProfile -PathType Leaf)) {
    $profileState = 'missing'
} elseif ([IO.File]::ReadAllText($ghostProfile, $DevkitUtf8).Contains($DevkitGhostTemplateMarker)) {
    $profileState = 'template'
}
Add-DoctorItem -Id 'ghost-profile' -Name 'GHOST.md' -Level 'recommended' -Ok ($profileState -eq 'ok') `
    -Purpose 'Ghost-specific notes that agents read before working: characters, surfaces, license, dictionary files' `
    -Detail $(if ($profileState -eq 'ok') { 'filled in' } elseif ($profileState -eq 'template') { 'still the blank template' } else { 'missing' }) `
    -Fix $(if ($profileState -eq 'missing') { 'Copy tools/devkit/seed/GHOST.md to GHOST.md and fill it in from the dictionaries and the shell (docs/agents/workflows/setup.md).' } else { 'Fill it in from the dictionaries and the shell, confirm it with the author, then remove the devkit:ghost-template marker lines (docs/agents/workflows/setup.md).' })

$conflicts = @(Get-DevkitConflictFiles $DevkitRoot)
Add-DoctorItem -Id 'devkit-conflicts' -Name 'development kit merges' -Level 'recommended' -Ok ($conflicts.Count -eq 0) `
    -Purpose 'Kit files changed both locally and upstream by tools/update-devkit.ps1' `
    -Detail $(if ($conflicts.Count -eq 0) { 'nothing to merge' } else { 'waiting to be merged: ' + ($conflicts -join ', ') }) `
    -Fix $('Merge each <file>.devkit-new into <file>, then delete the .devkit-new file (docs/agents/workflows/update-devkit.md).' + $(if ($conflicts -contains 'AGENTS.md.devkit-new') { ' Start with AGENTS.md.devkit-new.' } else { '' }))

# --- downloaded tools ------------------------------------------------------------------
$manifest = Get-DevkitToolManifest
$tamacPath = Get-DevkitToolPath 'tamac'
$tamacCurrent = Test-DevkitToolCurrent 'tamac'
$tamacVersion = if ($null -ne $tamacCurrent) { Get-DevkitFileVersion $tamacPath } else { $null }
Add-DoctorItem -Id 'tamac' -Name 'tamac.exe' -Level 'required' -Ok ($null -ne $tamacCurrent) `
    -Purpose 'Dictionary check (tools/check-dic.ps1 and the check after each edit) and SHIORI requests (tools/shiori.ps1)' `
    -Detail $(if ($null -eq $tamacCurrent) { 'not installed' } elseif ($tamacVersion) { "v$tamacVersion in tools/bin" } else { 'in tools/bin (version unknown)' }) `
    -Fix "Run: $ps tools/setup.ps1"

# An older tamac.exe still checks the dictionaries, so being out of date is only recommended.
$tamacMinimum = $manifest.tamac.minimumVersion
Add-DoctorItem -Id 'tamac-version' -Name "tamac.exe $tamacMinimum or later" -Level 'recommended' -Ok ($tamacCurrent -ne $false) `
    -Purpose 'SHIORI requests without SSP (tools/shiori.ps1); older versions have no -r option' `
    -Detail $(if ($null -eq $tamacCurrent) { 'not installed (see tamac.exe)' } elseif ($tamacCurrent) { 'ok' } else { "v$tamacVersion is older than $tamacMinimum" }) `
    -Fix "Run: $ps tools/setup.ps1 -Tool tamac (downloads the latest release)"

# --- SSP -------------------------------------------------------------------------------
$ssp = Resolve-SspPath
$sspOk = [bool]$ssp
$sspFix = 'Get SSP from https://ssp.shillest.net/ . If it is already installed, ask where ssp.exe is and write it to tools/local.json as {"sspPath": "C:\\path\\to\\ssp.exe"}.'
$sspDetail = 'not found'
if ($ssp) {
    $sspVersion = Get-DevkitSspVersion $ssp.Path
    $sspDetail = "$($ssp.Path) $(if ($sspVersion) { Format-DevkitSspVersion $sspVersion } else { '(version unknown)' }) (found via $($ssp.Source))"
    $sspRecommended = Format-DevkitSspVersion $DevkitSspRecommendedVersion
    if ($sspVersion -and $sspVersion -lt $DevkitSspRecommendedVersion) {
        $sspOk = $false
        $sspDetail += "; older than $sspRecommended"
        $sspFix = "Update SSP to $sspRecommended or later (https://ssp.shillest.net/ , or the network update of SSP itself). The scripts in tools/ are written for it, and may fail or miss problems with older versions."
    }
} else {
    $local = Get-DevkitLocalConfig
    if ($env:SSP_PATH -or ($local -and ($local.PSObject.Properties.Name -contains 'sspPath'))) {
        $sspDetail = 'not found; the path in SSP_PATH or tools/local.json does not exist'
    }
}
Add-DoctorItem -Id 'ssp' -Name "SSP $(Format-DevkitSspVersion $DevkitSspRecommendedVersion)+" -Level 'recommended' -Ok $sspOk `
    -Purpose 'Shell check (tools/check-shell.ps1), running the ghost (tools/run-ssp.ps1), trying talks (tools/sstp.ps1) and reading its logs (tools/ssp-log.ps1), building the nar and network update files (tools/build-nar.ps1)' `
    -Detail $sspDetail `
    -Fix $sspFix

# --- git -------------------------------------------------------------------------------
$git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$gitDetail = 'not found'
if ($git) { $gitDetail = (Invoke-DevkitProcess -FilePath $git.Source -Arguments @('--version') -TimeoutSeconds 30).StdOut.Trim() }
Add-DoctorItem -Id 'git' -Name 'Git' -Level 'recommended' -Ok ([bool]$git) `
    -Purpose 'Version history and GitHub (checks and automatic releases)' `
    -Detail $gitDetail `
    -Fix $(if ($hasWinget) { 'After the user agrees, run: winget install --id Git.Git -e (then restart the terminal)' } else { 'Download from https://git-scm.com/download/win' })

# --- output ----------------------------------------------------------------------------
$missingRequired = @($items | Where-Object { $_.level -eq 'required' -and -not $_.ok })
$ready = $missingRequired.Count -eq 0
if ($Json) {
    Write-Output ([pscustomobject]@{ ready = $ready; root = $DevkitRoot; gitWorkingCopy = $isGitWorkingCopy; winget = $hasWinget; items = $items.ToArray() } | ConvertTo-Json -Depth 4)
} else {
    foreach ($item in $items) {
        $mark = if ($item.ok) { '[ok]     ' } elseif ($item.level -eq 'required') { '[MISSING]' } else { '[missing]' }
        Write-Host ('{0} {1} ({2}): {3}' -f $mark, $item.name, $item.level, $item.detail)
        if (-not $item.ok) {
            Write-Host "          purpose: $($item.purpose)"
            Write-Host "          fix    : $($item.fix)"
        }
    }
    if ($ready) {
        Write-Host 'doctor: all required items are ready'
    } else {
        Write-Host "doctor: missing required item(s): $(($missingRequired | ForEach-Object { $_.name }) -join ', ')"
    }
}
if ($ready) { exit 0 }
exit 1
