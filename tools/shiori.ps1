<#
.SYNOPSIS
    Sends one SHIORI request to the ghost's satori.dll with tamac.exe, without SSP.
.DESCRIPTION
    tamac.exe loads the dictionaries, sends the request, prints the response and unloads SATORI (tamac -r).
    SSP does not need to be running, and nothing appears on the desktop.

    Every call runs in a temporary copy of ghost/master that is deleted afterwards, so the real folder is not
    touched (SATORI writes satori_savedata.txt and satori_savebackup.txt when it unloads). The copy has the
    variables that the real satori_savedata.txt holds. Each call loads the ghost from scratch: no OnBoot or other
    event is sent before the request. The code runs in the real dictionaries, though: code that calls SAORI
    (fill_desktop and so on) or runs programs really does so.

    -Eval expands SATORI text with ShioriEcho, SATORI's own debug ID. Each line of the text is one line of a
    sentence body (Reference0, Reference1, ...), handled like a line in a dictionary: an expression in full-width
    brackets such as the calc function, the name of a word group / sentence / variable in full-width brackets, a
    variable assignment line, a jump line, and so on. A sentence with a plain name is called by writing its name
    in the brackets; arguments go through the call function. Random talks (sentences without a name) are run by
    -Event OnTalk. The result is the sakura script that SATORI makes from the lines (dangerous tags such as
    \![raise are neutralized). ShioriEcho works only when the debug mode is on and SecurityLevel is local: this
    script adds the debug mode line to the initialization sentence of satori_conf.txt in the temporary copy only
    (the text is in tools/satori.json). -Plain also turns off the automatic waits and line breaks so that the script
    is easy to read. Examples: docs/agents/commands.md.

    -Event sends "GET SHIORI/3.0" (NOTIFY with -Notify) with ID and References, as SSP does for an event or a
    resource. Sender is SSP, SecurityLevel is local and Charset is UTF-8 (SATORI answers in the charset of the
    request). An ID that does not start with On is expanded as a name: a sentence, word group, variable or built-in
    name. -Header adds or replaces headers.

    -Request sends the given text as it is. tamac.exe turns the line breaks into CRLF and adds the blank line.

    The SATORI messages that this request caused are shown after the response: [error] such as a call with
    arguments to a name that does not exist, a calculation that failed or a wrong number of arguments, [warning]
    such as a name that was not found, and [note] such as a jump to a missing sentence. Messages from loading are
    shown too (see tools/check-dic.ps1). They come from tools/satori.json and the SATORI log; -ShowLog prints the
    whole log.
    Exit codes: 0 = OK, 1 = failed (satori.dll could not be loaded, the dictionaries have load errors, no or an
    error response), 2 = SATORI logged an error or a warning while handling the request (the response may be
    incomplete), 3 = tamac.exe is not installed or has no -r option.
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools/shiori.ps1 -Event OnBoot
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools/shiori.ps1 -Event OnMouseDoubleClick -Reference '0,0,0,0,Head'
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools/shiori.ps1 -Event version
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tools/shiori.ps1 -Eval (calc expression in full-width brackets) -Plain
#>
[CmdletBinding(DefaultParameterSetName = 'Eval')]
param(
    # SATORI text to expand with ShioriEcho. Each line becomes Reference0, Reference1, ...
    [Parameter(ParameterSetName = 'Eval', Mandatory = $true, Position = 0)]
    [string]$Eval,

    # -Eval only: turn off the automatic waits and line breaks in the temporary copy.
    [Parameter(ParameterSetName = 'Eval')]
    [switch]$Plain,

    # SHIORI event or resource ID.
    [Parameter(ParameterSetName = 'Event', Mandatory = $true)]
    [Alias('Event')]
    [string]$EventName,

    # Event references. Commas separate Reference0, Reference1, ...
    [Parameter(ParameterSetName = 'Event')]
    [string[]]$Reference,

    # Send NOTIFY instead of GET.
    [Parameter(ParameterSetName = 'Event')]
    [switch]$Notify,

    # Headers to add or replace, as 'Name: value'.
    [Parameter(ParameterSetName = 'Event')]
    [string[]]$Header,

    # Raw SHIORI request: the request line and the headers.
    [Parameter(ParameterSetName = 'Request', Mandatory = $true)]
    [string]$Request,

    # Folder that contains satori.dll (default: ghost/master).
    [string]$GhostDir,
    # Also print the whole SATORI log (load, request and unload).
    [switch]$ShowLog,
    [int]$TimeoutSeconds = 60
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/common.ps1')
. (Join-Path $PSScriptRoot 'lib/satori.ps1')
Initialize-DevkitConsole

if (-not $GhostDir) { $GhostDir = Join-Path $DevkitRoot 'ghost/master' }
$GhostDir = (Resolve-DevkitFullPath $GhostDir).TrimEnd('\', '/')
if (-not (Test-Path -LiteralPath (Join-Path $GhostDir 'satori.dll'))) {
    Write-Host "shiori: FAILED - satori.dll was not found in $GhostDir"
    exit 1
}

$tamac = Get-DevkitToolPath 'tamac'
if (-not (Test-Path -LiteralPath $tamac)) {
    Write-Host 'shiori: SKIPPED - tamac.exe is not installed. Run: powershell -NoProfile -ExecutionPolicy Bypass -File tools/setup.ps1'
    exit 3
}
# An older tamac.exe than minimumVersion in tools/tools.json may not have -r (added in v1.0.3.25); it would ignore it.
if ((Test-DevkitToolCurrent 'tamac') -eq $false) {
    Write-Host 'shiori: SKIPPED - this tamac.exe is too old. Run: powershell -NoProfile -ExecutionPolicy Bypass -File tools/setup.ps1 -Tool tamac'
    exit 3
}

$mode = $PSCmdlet.ParameterSetName
switch ($mode) {
    'Eval' {
        $lines = @($Eval -split "\r\n|\r|\n" | Where-Object { $_.Trim() -ne '' })
        if ($lines.Count -eq 0) {
            Write-Host 'shiori: -Eval is empty'
            exit 1
        }
        $headers = New-Object System.Collections.Generic.List[string]
        $headers.Add('GET SHIORI/3.0')
        $headers.Add('Charset: UTF-8')
        $headers.Add('Sender: SSP')
        $headers.Add('SecurityLevel: local')
        $headers.Add('ID: ShioriEcho')
        for ($i = 0; $i -lt $lines.Count; $i++) { $headers.Add("Reference${i}: " + $lines[$i]) }
        $requestText = $headers -join "`n"
    }
    'Event' {
        $headers = New-Object System.Collections.Generic.List[string]
        if ($Notify) { $headers.Add('NOTIFY SHIORI/3.0') } else { $headers.Add('GET SHIORI/3.0') }
        $headers.Add('Charset: UTF-8')
        $headers.Add('Sender: SSP')
        $headers.Add('SecurityLevel: local')
        $headers.Add('ID: ' + $EventName)
        $references = @($Reference | Where-Object { $null -ne $_ } | ForEach-Object { $_ -split ',' })
        for ($i = 0; $i -lt $references.Count; $i++) { $headers.Add("Reference${i}: " + $references[$i]) }
        foreach ($extra in @($Header | Where-Object { $_ })) {
            if ($extra -notmatch '^([^:\s]+):') {
                Write-Host "shiori: -Header must be 'Name: value': $extra"
                exit 1
            }
            $prefix = $matches[1] + ':'
            $index = -1
            for ($i = 1; $i -lt $headers.Count; $i++) {
                if ($headers[$i].StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { $index = $i; break }
            }
            if ($index -ge 0) { $headers[$index] = $extra } else { $headers.Add($extra) }
        }
        foreach ($line in $headers) {
            if ($line -match "[\r\n]") {
                Write-Host 'shiori: values must be a single line'
                exit 1
            }
        }
        $requestText = $headers -join "`n"
    }
    'Request' {
        $requestText = $Request
        if ($requestText.Trim() -eq '') {
            Write-Host 'shiori: -Request is empty'
            exit 1
        }
    }
}

$tamacArgs = @('-r')
$result = Invoke-DevkitTamac -GhostDir $GhostDir -Arguments $tamacArgs -InputText $requestText -EnableDebug:($mode -eq 'Eval') -Plain:$Plain -TimeoutSeconds $TimeoutSeconds

# Paths in the output are shown relative to the ghost root (the folder with ghost/ and shell/).
$base = Split-Path (Split-Path $GhostDir -Parent) -Parent

$diagnostics = @(Get-DevkitSatoriDiagnostics -Log $result.Log -Sandbox $result.Sandbox -GhostDir $GhostDir -Base $base -IncludeNotes)
$loadMessages = @($diagnostics | Where-Object { $_.Phase -eq 'load' })
$requestMessages = @($diagnostics | Where-Object { $_.Phase -ne 'load' })
$loadErrors = @($loadMessages | Where-Object { $_.Level -eq 'error' }).Count

$response = $result.Response
$exitCode = 0
$failure = $null
if ($response.Trim() -ne '') {
    if ($mode -eq 'Eval') {
        if ($response -match '^SHIORI/\d\.\d\s+200' -and $response -match '(?m)^Value: ?(.*)$') {
            $value = $matches[1]
            Write-Host $value
            if ($value.Contains(([string][char]0x30C7 + [char]0x30D0 + [char]0x30C3 + [char]0x30B0 + [char]0x30E2 + [char]0x30FC + [char]0x30C9))) {
                $failure = 'ShioriEcho answered that the debug mode is off; a dictionary may switch it off after satori_conf.txt'
            }
        } elseif ($response -match '^SHIORI/\d\.\d\s+204') {
            Write-Host '(no output: 204 No Content)'
        } else {
            Write-Host $response.TrimEnd()
            $failure = "-Eval was not answered with a Value ($(($response -split "`n")[0].Trim()))"
        }
    } else {
        Write-Host $response.TrimEnd()
        if ($response -match '^SHIORI/\d\.\d\s+(\d{3})' -and [int]$matches[1] -ge 400) {
            $failure = "error response ($($response.Split("`n")[0].Trim()))"
        }
    }
}

if ($ShowLog) {
    Write-Host '---- SATORI log ----'
    foreach ($line in ($result.Log -split "`n")) { Write-Host (ConvertTo-DevkitGhostText $line $result.Sandbox $GhostDir $base) }
    Write-Host '--------------------'
}
if ($loadMessages.Count -gt 0) {
    Write-Host 'shiori: messages while loading the dictionaries:'
    [void](Write-DevkitSatoriDiagnostics $loadMessages 'SATORI' -Indent '  ')
}
if ($requestMessages.Count -gt 0) {
    Write-Host 'shiori: messages while handling the request:'
    [void](Write-DevkitSatoriDiagnostics $requestMessages 'SATORI' -Indent '  ')
}

if ($result.TimedOut) {
    Write-Host "shiori: FAILED - tamac.exe did not finish within $TimeoutSeconds seconds"
    exit 1
}
if ($response.Trim() -eq '') {
    Write-Host "shiori: FAILED - tamac.exe printed no response (exit code $($result.ExitCode)); is satori.dll loadable? Use -ShowLog."
    exit 1
}
if ($loadErrors -gt 0) {
    Write-Host 'shiori: FAILED - the dictionaries have load errors. Fix them first (tools/check-dic.ps1).'
    exit 1
}
if ($result.ExitCode -ne 0 -and $result.ExitCode -ne 2) {
    Write-Host "shiori: FAILED (tamac.exe exit code $($result.ExitCode))"
    exit 1
}
if ($failure) {
    Write-Host "shiori: FAILED - $failure"
    exit 1
}
# A NOTIFY about something that has no sentence is normal, so its "not found" warnings do not count.
$counted = @($requestMessages | Where-Object { $_.Level -eq 'error' -or ($_.Level -eq 'warning' -and -not $Notify) })
if ($counted.Count -gt 0) {
    Write-Host 'shiori: SATORI logged errors or warnings while handling the request (see above).'
    $exitCode = 2
}
exit $exitCode
