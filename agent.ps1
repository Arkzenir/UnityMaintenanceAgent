# Launch the Unity engineering harness against a project repo.
#   .\agent.ps1 C:\dev\UnityProject
#
# Runs Claude Code from THIS directory (so this harness's CLAUDE.md and skills
# load) with read/write access granted to the project repo.
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProjectPath,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = 'Stop'

$resolved = (Resolve-Path -LiteralPath $ProjectPath).Path

if (-not (Test-Path (Join-Path $resolved 'Assets')) -or
    -not (Test-Path (Join-Path $resolved 'ProjectSettings'))) {
    Write-Warning "$resolved does not look like a Unity project root (expected Assets\ and ProjectSettings\)"
}

Set-Location -LiteralPath $PSScriptRoot

# Keep PROJECT_PATH.txt in sync so the hooks and the agent see the same path.
@(
    "# Written by agent.ps1 on $(Get-Date). Edit freely."
    $resolved
) | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'PROJECT_PATH.txt')

$env:UNITY_AGENT_PROJECT_PATH = $resolved

& claude --add-dir $resolved @ExtraArgs
