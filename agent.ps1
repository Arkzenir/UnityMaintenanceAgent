# Launch the Unity engineering harness against one or more project repos.
#   .\agent.ps1 C:\dev\UnityProject
#   .\agent.ps1 C:\dev\UnityProject -AdditionalPaths C:\dev\LegacyGame
#   .\agent.ps1 C:\dev\UnityProject -Agent codex
#
# Runs the agent from THIS directory so this harness's AGENTS.md and skills load.
# The first path is the working repo; additional paths are references for
# porting or re-importing between projects.
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProjectPath,

    [string[]]$AdditionalPaths = @(),

    # Agent command to launch: a name on PATH or a full path. Defaults to
    # $env:HARNESS_AGENT, then claude.
    [string]$Agent = $(if ($env:HARNESS_AGENT) { $env:HARNESS_AGENT } else { 'claude' }),

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = 'Stop'

$paths = @((Resolve-Path -LiteralPath $ProjectPath).Path)
foreach ($extra in $AdditionalPaths) {
    $paths += (Resolve-Path -LiteralPath $extra).Path
}

foreach ($p in $paths) {
    if (-not (Test-Path (Join-Path $p 'Assets')) -or
        -not (Test-Path (Join-Path $p 'ProjectSettings'))) {
        Write-Warning "$p does not look like a Unity project root (expected Assets\ and ProjectSettings\)"
    }
}

$command = Get-Command $Agent -ErrorAction SilentlyContinue
if (-not $command -or $command.CommandType -ne 'Application') {
    throw "Agent '$Agent' was not found on PATH. Install it, pass -Agent <path>, or set HARNESS_AGENT."
}

Set-Location -LiteralPath $PSScriptRoot

# Keep PROJECT_PATH.txt in sync: one path per line, first is the working repo.
$lines = @("# Written by agent.ps1 on $(Get-Date). Edit freely. One path per line; the first is the working repo.")
$lines += $paths
$lines | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'PROJECT_PATH.txt')

$env:UNITY_AGENT_PROJECT_PATHS = ($paths -join ';')
Remove-Item Env:UNITY_AGENT_PROJECT_PATH -ErrorAction SilentlyContinue

# Claude Code needs its extra directories passed explicitly; every other tool
# gets repo access from its own configuration.
$agentName = [IO.Path]::GetFileNameWithoutExtension($command.Name)
$agentArgs = @()
if ($agentName -eq 'claude') {
    foreach ($p in $paths) { $agentArgs += @('--add-dir', $p) }
}
$agentArgs += $ExtraArgs

& $command.Source @agentArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
