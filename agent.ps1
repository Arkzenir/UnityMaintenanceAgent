# Launch the Unity engineering harness against a project repo with any agent CLI.
#   .\agent.ps1 C:\dev\UnityProject
#   .\agent.ps1 C:\dev\UnityProject -Agent codex
#
# Runs the agent from THIS directory so this harness's AGENTS.md and skills load,
# with the project repo exported for the checks.
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProjectPath,

    # Agent command to launch: a name on PATH or a full path. Defaults to
    # $env:HARNESS_AGENT, then claude.
    [string]$Agent = $(if ($env:HARNESS_AGENT) { $env:HARNESS_AGENT } else { 'claude' }),

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = 'Stop'

$resolved = (Resolve-Path -LiteralPath $ProjectPath).Path

if (-not (Test-Path (Join-Path $resolved 'Assets')) -or
    -not (Test-Path (Join-Path $resolved 'ProjectSettings'))) {
    Write-Warning "$resolved does not look like a Unity project root (expected Assets\ and ProjectSettings\)"
}

$command = Get-Command $Agent -ErrorAction SilentlyContinue
if (-not $command -or $command.CommandType -ne 'Application') {
    throw "Agent '$Agent' was not found on PATH. Install it, pass -Agent <path>, or set HARNESS_AGENT."
}

Set-Location -LiteralPath $PSScriptRoot

# Keep PROJECT_PATH.txt in sync so the guards and the agent see the same path.
@(
    "# Written by agent.ps1 on $(Get-Date). Edit freely."
    $resolved
) | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'PROJECT_PATH.txt')

$env:UNITY_AGENT_PROJECT_PATH = $resolved

# Only Claude Code needs the extra directory flag; other agents get repo access
# from their own configuration.
$agentName = [IO.Path]::GetFileNameWithoutExtension($command.Name)
$agentArgs = @()
if ($agentName -eq 'claude') { $agentArgs += @('--add-dir', $resolved) }
$agentArgs += $ExtraArgs

& $command.Source @agentArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
