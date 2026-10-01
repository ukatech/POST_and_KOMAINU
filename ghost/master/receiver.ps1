# Opens the window that shows the log of SATORI while the ghost runs in SSP (the log receiver).
# Started by receiver.bat (see receiver.txt). The window is tamacsw.exe of the development kit: it is built from
# tools/lib/tamacsw.cs with csc.exe of the .NET Framework on first use, so this works only in a folder that has
# the kit (tools/). Keep this file ASCII-only (Windows PowerShell 5.1 reads BOM-less files in the ANSI code page).
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$common = Join-Path $root 'tools\lib\common.ps1'
if (-not (Test-Path -LiteralPath $common -PathType Leaf)) {
    Write-Host "receiver: the development kit was not found ($common)."
    Write-Host 'receiver: the log receiver is part of the development kit; use the folder or the nar that has tools/.'
    exit 1
}
. $common

$tool = Get-DevkitTamacsw
if (-not $tool.Path) {
    Write-Host "receiver: $($tool.Error)"
    exit 1
}

$arguments = @()
$name = Get-DevkitDescriptValue (Join-Path $PSScriptRoot 'descript.txt') 'name'
if ($name) { $arguments = @('-t', ('"' + $name.Replace('"', '') + '"')) }
if ($arguments.Count -gt 0) {
    Start-Process -FilePath $tool.Path -ArgumentList $arguments -WorkingDirectory $PSScriptRoot
} else {
    Start-Process -FilePath $tool.Path -WorkingDirectory $PSScriptRoot
}
exit 0
