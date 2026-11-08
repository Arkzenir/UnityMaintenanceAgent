#Requires -Version 5.1
<#
.SYNOPSIS
    Portable checks for the Unity engineering harness.

.DESCRIPTION
    Windows implementation. The macOS/Linux counterpart is scripts/harness.sh;
    keep the two in step. No Node or Python needed.

        harness.ps1 check-path            validate every configured Unity project
        harness.ps1 check-write <path>    test one write target against every project
        harness.ps1 check-repo            scan every project for stray artifacts

    PROJECT_PATH.txt holds one project path per line. The first is the working
    repo; additional paths are reference/source repos for cross-project work
    such as porting or re-importing. UNITY_AGENT_PROJECT_PATHS (semicolon-
    separated) or UNITY_AGENT_PROJECT_PATH overrides the file.

    check-write and check-repo exit 0 when clean and 2 on a violation. They fail
    open when no project path is configured.
#>
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('check-path', 'check-write', 'check-repo')]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'

$HarnessDir = Split-Path -Parent $PSScriptRoot
$ConfigFile = Join-Path $HarnessDir 'PROJECT_PATH.txt'

# Names that must never appear inside a game repo.
$BannedNamePatterns = @(
    '^claude\.md$',
    '^agents?\.md$',
    '^gemini\.md$',
    '^\.claude$',
    '^\.cursor(rules)?$',
    '^\.codex$',
    '^\.gemini$',
    '^\.aider.*',
    '^\.windsurfrules$',
    '^copilot-instructions\.md$',
    '^current_?status\.md$',
    '^curren_?status\.md$',
    '^handoff\.md$',
    '^analysis\.md$',
    '^audit(_report)?\.md$',
    '^plan\.md$',
    '^notes\.md$',
    '^scratch\..*',
    '^todo\.md$'
)

# Patterns that signal agent scratch, backups, or shadow copies.
$BannedPathPatterns = @(
    '\.agent\.md$',
    '\.plan\.md$',
    '_notes\.md$',
    '_ai\.(cs|md)$',
    '\.bak$',
    '\.orig$',
    '\.old$',
    '\.cs\.(txt|new|old|bak)$',
    '[\\/][^\\/]*_v\d+\.cs$',
    '[\\/][^\\/]*_new\.cs$',
    '[\\/][^\\/]*_copy\.cs$',
    '[\\/][^\\/]*\.copy\.cs$'
)

# Path segments inside a repo that are never ours to write.
$BannedDirPatterns = @(
    '(^|[\\/])(Library|Temp|obj|Logs|UserSettings|\.claude|\.cursor|\.codex|\.gemini|\.aider[^\\/]*)([\\/]|$)'
)

# Filename patterns the end-of-turn scan looks for.
$SuspectPatterns = @(
    '^claude\.md$',
    '^agents?\.md$',
    '^gemini\.md$',
    '^\.cursorrules$',
    '^\.windsurfrules$',
    '^copilot-instructions\.md$',
    '^current_?status\.md$',
    '^curren_?status\.md$',
    '^handoff\.md$',
    '^analysis\.md$',
    '^audit(_report)?\.md$',
    '\.agent\.md$',
    '\.plan\.md$',
    '_notes\.md$',
    '\.bak$',
    '\.orig$',
    '\.old$',
    '^scratch\.'
)

$SkipDirs = @(
    'Library', 'Temp', 'obj', 'bin', 'Logs', 'UserSettings',
    '.git', '.vs', '.idea', 'node_modules', 'Build', 'Builds'
)

$SuspectDirs = @('.claude', '.cursor', '.codex', '.gemini', '.aider')

function ConvertTo-ProjectPath {
    param([string]$Raw)

    if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }

    $value = $Raw.Trim()
    if ($value.Length -ge 2) {
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2).Trim()
        }
    }

    if ($value.Length -eq 0 -or $value -like '*PASTE_YOUR_UNITY_PROJECT_PATH_HERE*') {
        return $null
    }

    if ($value -eq '~') {
        $value = $HOME
    } elseif ($value.StartsWith('~/') -or $value.StartsWith('~\')) {
        $value = Join-Path $HOME $value.Substring(2)
    }

    $value = $value.TrimEnd('\', '/')
    if ($value -match '^[A-Za-z]:$') { $value = $value + '\' }

    try { return [IO.Path]::GetFullPath($value) } catch { return $null }
}

function Get-ConfiguredProjectPaths {
    $entries = @()

    if (-not [string]::IsNullOrWhiteSpace($env:UNITY_AGENT_PROJECT_PATHS)) {
        $entries = $env:UNITY_AGENT_PROJECT_PATHS -split ';'
    } elseif (-not [string]::IsNullOrWhiteSpace($env:UNITY_AGENT_PROJECT_PATH)) {
        $entries = @($env:UNITY_AGENT_PROJECT_PATH)
    } elseif (Test-Path -LiteralPath $ConfigFile) {
        try {
            $lines = Get-Content -LiteralPath $ConfigFile -ErrorAction Stop
        } catch {
            $lines = @()
        }
        foreach ($line in $lines) {
            $text = $line.Trim()
            if ($text.Length -eq 0 -or $text.StartsWith('#')) { continue }
            $entries += $text
        }
    }

    $paths = New-Object System.Collections.Generic.List[string]
    foreach ($entry in $entries) {
        $path = ConvertTo-ProjectPath -Raw $entry
        if ($path) { $paths.Add($path) }
    }

    return $paths.ToArray()
}

function Get-RelativeRepoPath {
    param([string]$Repo, [string]$File)

    $root = $Repo.TrimEnd('\', '/')
    if ($File.Equals($root, [StringComparison]::OrdinalIgnoreCase)) { return '' }

    $prefix = $root + [IO.Path]::DirectorySeparatorChar
    if ($File.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        return $File.Substring($prefix.Length)
    }

    return $null
}

function Write-Blocked {
    param([string]$RelativePath)

    [Console]::Error.WriteLine(
        "BLOCKED by repo-guard: `"$RelativePath`" is not permitted inside the game repo."
    )
    [Console]::Error.WriteLine(
        'AGENTS.md Rule 1 - the repo must contain no harness, planning, backup, or ' +
        'AI-related files, and Library/Temp/obj/Logs/UserSettings are off limits.'
    )
    [Console]::Error.WriteLine(
        'Write documentation and analysis to projects/<slug>/ in the harness, and ' +
        'scratch work to scratch/. If you were creating a backup copy, do not - ' +
        'git and the user''s own VCS handle that.'
    )
    exit 2
}

function Get-RepoFindings {
    param([string]$Repo)

    $found = New-Object System.Collections.Generic.List[string]
    $stack = New-Object System.Collections.Stack
    $stack.Push($Repo)

    while ($stack.Count -gt 0 -and $found.Count -lt 40) {
        $dir = $stack.Pop()
        try {
            foreach ($sub in [IO.Directory]::GetDirectories($dir)) {
                $leaf = [IO.Path]::GetFileName($sub)
                if ($SkipDirs -contains $leaf) { continue }
                if ($SuspectDirs -contains $leaf) {
                    $found.Add((Get-RelativeRepoPath -Repo $Repo -File $sub) + '/')
                    continue
                }
                $stack.Push($sub)
            }
            foreach ($item in [IO.Directory]::GetFiles($dir)) {
                $leaf = [IO.Path]::GetFileName($item)
                foreach ($pattern in $SuspectPatterns) {
                    if ($leaf -match $pattern) {
                        $found.Add((Get-RelativeRepoPath -Repo $Repo -File $item))
                        break
                    }
                }
                if ($found.Count -ge 40) { break }
            }
        } catch {
            # Unreadable directory: skip it, same as the POSIX scan.
        }
    }

    return $found.ToArray()
}

function Invoke-CheckPath {
    $paths = @(Get-ConfiguredProjectPaths)
    if ($paths.Count -eq 0) {
        [Console]::Error.WriteLine('ERROR: No project path configured.')
        [Console]::Error.WriteLine('  Copy PROJECT_PATH.example.txt to PROJECT_PATH.txt and paste your Unity project path.')
        exit 1
    }

    $failed = $false
    foreach ($repo in $paths) {
        Write-Output "Configured path: $repo"

        if (-not (Test-Path -LiteralPath $repo -PathType Container)) {
            [Console]::Error.WriteLine('ERROR: That folder does not exist. Check for typos or a stray character.')
            $failed = $true
            continue
        }

        $missing = @()
        if (-not (Test-Path -LiteralPath (Join-Path $repo 'Assets') -PathType Container)) {
            $missing += 'Assets'
        }
        if (-not (Test-Path -LiteralPath (Join-Path $repo 'ProjectSettings') -PathType Container)) {
            $missing += 'ProjectSettings'
        }
        if ($missing.Count -gt 0) {
            [Console]::Error.WriteLine(
                "ERROR: Missing $($missing -join ' and ') - this is not a Unity project root."
            )
            [Console]::Error.WriteLine('  You may have pointed at the Assets folder or a parent folder.')
            $failed = $true
            continue
        }

        $version = 'unknown'
        $versionFile = Join-Path $repo 'ProjectSettings\ProjectVersion.txt'
        if (Test-Path -LiteralPath $versionFile) {
            $match = Select-String -LiteralPath $versionFile -Pattern 'm_EditorVersion:\s*(\S+)' |
                Select-Object -First 1
            if ($match) { $version = $match.Matches[0].Groups[1].Value }
        }

        Write-Output "OK: valid Unity project root (Unity $version)."
    }

    if ($failed) { exit 1 }
    Write-Output '  Ready - start the agent.'
}

function Invoke-CheckWrite {
    $paths = @(Get-ConfiguredProjectPaths)
    if ($paths.Count -eq 0) { exit 0 }
    if ([string]::IsNullOrWhiteSpace($Path)) { exit 0 }

    try { $file = [IO.Path]::GetFullPath($Path) } catch { exit 0 }

    $base = [IO.Path]::GetFileName($file)

    foreach ($repo in $paths) {
        $relative = Get-RelativeRepoPath -Repo $repo -File $file
        if ($null -eq $relative) { continue }

        $hit = $false
        foreach ($pattern in $BannedNamePatterns) {
            if ($base -match $pattern) { $hit = $true; break }
        }
        if (-not $hit) {
            foreach ($pattern in $BannedPathPatterns) {
                if ($relative -match $pattern) { $hit = $true; break }
            }
        }
        if (-not $hit) {
            foreach ($pattern in $BannedDirPatterns) {
                if ($relative -match $pattern) { $hit = $true; break }
            }
        }

        if ($hit) { Write-Blocked -RelativePath $relative }
    }

    exit 0
}

function Invoke-CheckRepo {
    $paths = @(Get-ConfiguredProjectPaths)
    if ($paths.Count -eq 0) { exit 0 }

    $any = $false
    foreach ($repo in $paths) {
        if (-not (Test-Path -LiteralPath $repo -PathType Container)) { continue }

        $found = @(Get-RepoFindings -Repo $repo)
        if ($found.Count -eq 0) { continue }

        $any = $true
        $sorted = $found | Sort-Object
        [Console]::Error.WriteLine("repo-hygiene found $($sorted.Count) stray artifact(s) in ${repo}:")
        foreach ($entry in $sorted) {
            [Console]::Error.WriteLine("  - $entry")
        }
    }

    if (-not $any) { exit 0 }

    [Console]::Error.WriteLine('')
    [Console]::Error.WriteLine(
        'AGENTS.md Rule 1: the repo must be clean. If you created these, remove them ' +
        'and move the content into projects/<slug>/ in the harness. If they predate ' +
        'you and belong to the user, say so explicitly in your report and leave them ' +
        'alone - do not delete the user''s files.'
    )
    exit 2
}

switch ($Command) {
    'check-path'  { Invoke-CheckPath }
    'check-write' { Invoke-CheckWrite }
    'check-repo'  { Invoke-CheckRepo }
}
