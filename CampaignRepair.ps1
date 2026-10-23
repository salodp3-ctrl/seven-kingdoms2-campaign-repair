param(
    [ValidateSet('Status','Apply','Restore')][string]$Action = 'Status',
    [string]$GameExe,
    [switch]$NonInteractive,
    [switch]$Elevated
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

function Get-BytesHash([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Find-Game {
    $roots = @()
    try { $roots += (Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam').SteamPath } catch {}
    if (${env:ProgramFiles(x86)}) { $roots += Join-Path ${env:ProgramFiles(x86)} 'Steam' }
    $libraries = @($roots)
    foreach ($r in $roots) {
        $vdf = Join-Path $r 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            foreach ($m in [regex]::Matches([IO.File]::ReadAllText($vdf), '"path"\s+"([^"]+)"')) {
                $libraries += $m.Groups[1].Value.Replace('\\','\')
            }
        }
    }
    $candidates = @($libraries | ForEach-Object { Join-Path $_ 'steamapps\common\Seven Kingdoms 2 HD\7K2.exe' })
    $candidates += 'C:\GOG Games\Seven Kingdoms II HD\7K2.exe'
    return @($candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -Unique)
}

function Repair-Game([string]$Path, [string]$Operation) {
    $pathFull = (Resolve-Path -LiteralPath $Path).Path
    if ([IO.Path]::GetFileName($pathFull) -ine '7K2.exe') { throw 'Select the game file named 7K2.exe.' }
    $manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'patches.json') -Raw | ConvertFrom-Json
    if ($manifest.format -ne 1) { throw 'Unsupported patch manifest format.' }
    [byte[]]$current = [IO.File]::ReadAllBytes($pathFull)
    $currentHash = Get-BytesHash $current
    $matches = @($manifest.versions | Where-Object { $_.originalHash -eq $currentHash -or $_.patchedHash -eq $currentHash })
    if ($matches.Count -ne 1) {
        throw "Unrecognized game version. Nothing changed. SHA256: $currentHash. This kit supports only its verified Steam and GOG builds. A new game update or a different mod needs review; do not force this patch."
    }
    $version = $matches[0]
    $isPatched = $currentHash -eq $version.patchedHash
    Write-Host "Game: $pathFull"
    Write-Host "Version: $($version.name)"
    Write-Host "Campaign repair installed: $isPatched"
    if ($Operation -eq 'Status') { return }
    if ($Operation -eq 'Apply' -and $isPatched) { Write-Host 'Already repaired. No changes needed.'; return }
    if ($Operation -eq 'Restore' -and -not $isPatched) { Write-Host 'Already original. No changes needed.'; return }
    $running = @(Get-Process -Name 7K2 -ErrorAction SilentlyContinue)
    foreach ($process in $running) {
        try { $runningPath = $process.Path } catch { $runningPath = $null }
        if (-not $runningPath -or $runningPath -ieq $pathFull) {
            throw 'Close the Seven Kingdoms II game and its error boxes, then run this patch again.'
        }
    }
    $folder = Split-Path -Parent $pathFull
    $backupFolder = Join-Path $folder 'CampaignRepairBackups'
    $backup = Join-Path $backupFolder ("original-" + $version.originalHash + '.exe')
    if ($Operation -eq 'Apply') {
        if ($current.Length -ne $version.originalLength) { throw 'Unexpected original file length.' }
        [byte[]]$replacement = New-Object byte[] ([int]$version.patchedLength)
        [Array]::Copy($current, $replacement, $current.Length)
        foreach ($change in $version.changes) {
            $offset = [int]$change.offset
            [byte[]]$before = [Convert]::FromBase64String($change.before)
            [byte[]]$after = [Convert]::FromBase64String($change.after)
            if ($offset -lt 0 -or $offset + $before.Length -gt $current.Length -or $offset + $after.Length -gt $replacement.Length) { throw 'Invalid patch range.' }
            for ($i=0; $i -lt $before.Length; $i++) {
                if ($current[$offset+$i] -ne $before[$i]) { throw 'Original patch bytes do not match.' }
            }
            [Array]::Copy($after, 0, $replacement, $offset, $after.Length)
        }
        $expectedHash = $version.patchedHash
        if ((Get-BytesHash $replacement) -ne $expectedHash) { throw 'Patched file failed validation; nothing changed.' }
        if (-not (Test-Path -LiteralPath $backupFolder)) { New-Item -ItemType Directory -Path $backupFolder | Out-Null }
        if (Test-Path -LiteralPath $backup) {
            if ((Get-BytesHash ([IO.File]::ReadAllBytes($backup))) -ne $version.originalHash) { throw 'Existing backup failed validation. Nothing changed.' }
        } else { [IO.File]::WriteAllBytes($backup, $current) }
        if ((Get-BytesHash ([IO.File]::ReadAllBytes($backup))) -ne $version.originalHash) { throw 'Backup failed validation. Nothing changed.' }
    } else {
        if (-not (Test-Path -LiteralPath $backup)) { throw 'Original backup is missing. Use Steam Verify integrity to restore the original instead.' }
        [byte[]]$replacement = [IO.File]::ReadAllBytes($backup)
        $expectedHash = $version.originalHash
        if ((Get-BytesHash $replacement) -ne $expectedHash) { throw 'Original backup failed validation. Nothing changed.' }
    }
    $temp = Join-Path $folder ('7K2-campaign-repair-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllBytes($temp, $replacement)
        if ((Get-BytesHash ([IO.File]::ReadAllBytes($temp))) -ne $expectedHash) { throw 'Temporary file failed validation.' }
        if ((Get-BytesHash ([IO.File]::ReadAllBytes($pathFull))) -ne $currentHash) { throw 'Game changed during patching. Retry after Steam finishes.' }
        $rollback = Join-Path $backupFolder ('before-change-' + [Guid]::NewGuid().ToString('N') + '.exe')
        $folderPrefix = [IO.Path]::GetFullPath($folder).TrimEnd('\') + '\'
        foreach ($candidate in @($temp, $pathFull, $rollback)) {
            if (-not [IO.Path]::GetFullPath($candidate).StartsWith($folderPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw 'Replacement path falls outside the selected game folder.'
            }
        }
        [IO.File]::Move($pathFull, $rollback)
        try { [IO.File]::Move($temp, $pathFull) }
        catch {
            if (-not (Test-Path -LiteralPath $pathFull)) { [IO.File]::Move($rollback, $pathFull) }
            throw
        }
        if ((Get-BytesHash ([IO.File]::ReadAllBytes($pathFull))) -ne $expectedHash) { throw 'Final verification failed; use the verified backup to restore.' }
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp }
    }
    Write-Host "SUCCESS: $Operation completed and verified."
    Write-Host "Original backup: $backup"
    Write-Host 'Save files were not edited. You can launch the installed game normally.'
    if ($Operation -eq 'Apply') { Write-Host 'Use your campaign profile, then save into a new slot after the campaign transition succeeds.' }
}

try {
    if (-not $NonInteractive) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            if ($Elevated) { throw 'Administrator access was not granted.' }
            Write-Host 'Windows will ask for permission to update the installed game.'
            Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -Elevated') -Wait
            exit 0
        }
        Write-Host 'Seven Kingdoms II HD - Campaign Repair 1.0'
        Write-Host 'Fixes invalid monster species while preserving campaign animations.'
        Write-Host 'Invalid saved monster species are replaced with Minotauros when accessed.'
        Write-Host 'This is an unofficial fix for this specific bug, not a general crash fixer.'
        $found = @(Find-Game)
        for ($i=0; $i -lt $found.Count; $i++) { Write-Host "$($i+1). $($found[$i])" }
        Write-Host 'B. Browse for a different 7K2.exe'
        $choice = Read-Host 'Choose a game number, or B'
        [int]$number = 0
        if ([int]::TryParse($choice, [ref]$number) -and $number -ge 1 -and $number -le $found.Count) {
            $GameExe = $found[$number-1]
        } elseif ($choice -ieq 'B') {
            Add-Type -AssemblyName System.Windows.Forms
            $dialog = New-Object System.Windows.Forms.OpenFileDialog
            $dialog.Filter = 'Seven Kingdoms II executable (7K2.exe)|7K2.exe'
            if ($dialog.ShowDialog() -ne 'OK') { exit 0 }
            $GameExe = $dialog.FileName
            $dialog.Dispose()
        } else { throw 'No valid game selected.' }
        Write-Host '1. Apply repair (or confirm already repaired)'
        Write-Host '2. Check status only'
        Write-Host '3. Restore original executable'
        switch (Read-Host 'Choose 1, 2, or 3') {
            '1' { $Action = 'Apply' }
            '2' { $Action = 'Status' }
            '3' { $Action = 'Restore' }
            default { throw 'No valid action selected.' }
        }
    }
    if (-not $GameExe) { throw 'A game executable path is required.' }
    Repair-Game $GameExe $Action
    if (-not $NonInteractive) { [void](Read-Host 'Press Enter to close') }
    exit 0
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if (-not $NonInteractive) { [void](Read-Host 'Press Enter to close') }
    exit 1
}
