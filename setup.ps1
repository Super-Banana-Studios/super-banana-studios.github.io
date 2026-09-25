#
# setup-git - the Windows entry point of "one line from a bare machine to a working checkout".
#
#   & ([scriptblock]::Create((irm https://super-banana-studios.github.io/setup.ps1))) -Repo <owner>/<repo>
#
# This file installs only what bash needs - Git for Windows (which brings bash, git-lfs and
# curl) and the GitHub CLI - and then hands over to setup.sh, which is the one implementation
# of the starter on every system.
#
param(
    [Parameter(Position = 0)] [string] $Repo,
    [Parameter(Position = 1)] [string] $Branch,
    [Parameter(Position = 2)] [string] $Path
)

$contact = 'Ask Ivan Murashka (@imurashka).'
$starterUrl = 'https://super-banana-studios.github.io/setup.sh'

function Write-Step([string] $text) {
    Write-Host ''
    Write-Host "==> $text" -ForegroundColor Cyan
}

function Get-MachineArchitecture {
    if ($env:PROCESSOR_ARCHITEW6432) { return $env:PROCESSOR_ARCHITEW6432 }
    return $env:PROCESSOR_ARCHITECTURE
}

function Update-PathFromRegistry {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ';'
}

# The window this runs in is Windows PowerShell 5.1's, and three of its defaults hurt a person
# watching an install, all measured on a clean Windows 11 machine on 2026-09-14:
#  - QuickEdit: one click in the window selects text and freezes every program writing to the
#    console until Esc, which looks exactly like a hang. Off for the run, restored at the end.
#  - No virtual terminal processing: the colours and progress bars gh, git and Unity draw arrive
#    as literal text such as "[2m". On, and left on - it only helps.
#  - OEM output encoding: a tick mark prints as "?". UTF-8, and left as well.
$consoleSignature = @'
using System;
using System.Runtime.InteropServices;
public static class StarterConsole {
    [DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int handle);
    [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr handle, out uint mode);
    [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr handle, uint mode);
}
'@
$originalInputMode = $null

function Set-ConsoleForTheRun {
    try {
        Add-Type -TypeDefinition $consoleSignature -ErrorAction Stop
        $mode = 0
        $stdin = [StarterConsole]::GetStdHandle(-10)
        if ([StarterConsole]::GetConsoleMode($stdin, [ref] $mode)) {
            $script:originalInputMode = $mode
            [void] [StarterConsole]::SetConsoleMode($stdin, ($mode -bor 0x80) -band (-bnot 0x40))
        }
        $stdout = [StarterConsole]::GetStdHandle(-11)
        if ([StarterConsole]::GetConsoleMode($stdout, [ref] $mode)) {
            [void] [StarterConsole]::SetConsoleMode($stdout, $mode -bor 0x4)
        }
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    } catch { }
}

function Restore-Console {
    if ($null -ne $script:originalInputMode) {
        try { [void] [StarterConsole]::SetConsoleMode([StarterConsole]::GetStdHandle(-10), $script:originalInputMode) } catch { }
    }
}

function Install-WingetPackage([string] $id, [string] $label) {
    Write-Step "Installing $label"
    winget install --id $id -e --source winget --scope machine --silent --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        throw "$label did not install (winget exit code $LASTEXITCODE). Approve the Windows prompt if one is waiting, then run the line again."
    }
}

function Find-GitBash {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Git\bin\bash.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe')
    )
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe')
    }
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        $root = Split-Path (Split-Path $git.Source -Parent) -Parent
        $candidates += (Join-Path $root 'bin\bash.exe')
    }
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

try {
    Set-ConsoleForTheRun

    if (-not $Repo) {
        Write-Host 'This line needs to know which project to set up, and it was pasted without that part.'
        Write-Host ''
        Write-Host 'Usage:'
        Write-Host '  & ([scriptblock]::Create((irm <this url>))) -Repo <owner>/<repo> [-Branch <branch>] [-Path <directory>]'
        throw 'The full line names the project, so ask for that one.'
    }
    if ($Repo -notmatch '^[^/\s]+/[^/\s]+$') {
        throw "`"$Repo`" is not a repository name. It looks like owner/repository, for example my-org/my-project."
    }

    $architecture = Get-MachineArchitecture
    $version = [Environment]::OSVersion.Version
    if ($architecture -ne 'AMD64' -or $version.Build -lt 22000) {
        throw "This line supports Windows 11 (x64) and Macs with Apple Silicon. Your machine is Windows $($version.Major).$($version.Minor) build $($version.Build) ($architecture)."
    }

    $needsGit = -not (Find-GitBash)
    $needsGh = -not (Get-Command gh -ErrorAction SilentlyContinue)

    if ($needsGit -or $needsGh) {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            throw @'
Windows cannot find winget, the installer this line uses. On a machine that has just been set up it can take a few minutes to appear after the first sign-in - wait, open a new PowerShell window and run the line again. If it is still missing, run this once and then run the line again:
  Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
'@
        }
        Write-Host ''
        Write-Host 'Some of this installs software, which needs administrator rights on this machine.'
        Write-Host 'Windows will ask you to approve a prompt. That is expected.'
        if ($needsGit) { Install-WingetPackage 'Git.Git' 'Git for Windows' }
        if ($needsGh) { Install-WingetPackage 'GitHub.cli' 'the GitHub CLI' }
        Update-PathFromRegistry
    }

    # Git for Windows ships two bash.exe and only bin\bash.exe sets up a PATH where the
    # starter's coreutils exist; usr\bin\bash.exe fails on the first one it calls.
    $bash = Find-GitBash
    if (-not $bash) {
        throw 'Git for Windows is installed but bash.exe is not where it is expected. Open a new PowerShell window and run the line again.'
    }
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw 'The GitHub CLI is installed but Windows does not see it yet. Open a new PowerShell window and run the line again.'
    }

    $starterPath = Join-Path $env:TEMP 'setup-git.sh'
    Invoke-RestMethod -Uri $starterUrl -OutFile $starterPath -ErrorAction Stop
    if (-not (Test-Path $starterPath) -or (Get-Item $starterPath).Length -eq 0) {
        throw "The starter script could not be downloaded from $starterUrl."
    }

    $arguments = @($starterPath, $Repo)
    if ($Branch) { $arguments += @('--branch', $Branch) }
    if ($Path) { $arguments += @('--path', $Path) }

    # The project's setup script writes the folder of the checkout here when it finishes. This
    # window is the person's own, and people new to a terminal type `claude` in it right after the
    # run - so it moves to that folder and picks up the PATH the run wrote, and `claude` starts
    # in the project rather than wherever the window was (Ivan, 2026-09-25).
    $checkoutFile = Join-Path $env:TEMP 'superb-setup.checkout'
    Remove-Item $checkoutFile -ErrorAction SilentlyContinue

    & $bash $arguments
    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host "Setup stopped (exit code $LASTEXITCODE). The message above says what to do." -ForegroundColor Red
    }
    elseif (Test-Path $checkoutFile) {
        $checkout = (Get-Content $checkoutFile -TotalCount 1).Trim()
        if ($checkout -and (Test-Path $checkout)) {
            $paths = (@([Environment]::GetEnvironmentVariable('Path', 'User'), [Environment]::GetEnvironmentVariable('Path', 'Machine'), $env:Path) -join ';').Split(';')
            $env:Path = ($paths | Where-Object { $_ } | Select-Object -Unique) -join ';'
            Set-Location $checkout
            Write-Host "This window is now in $checkout - type claude to start." -ForegroundColor Green
        }
    }
}
catch {
    # No `exit` anywhere in this file: it runs inside the person's own PowerShell window,
    # and `exit` closes that window rather than this script (measured on 5.1.26100.9444).
    Write-Host ''
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $contact -ForegroundColor Red
}
finally {
    Restore-Console
}
