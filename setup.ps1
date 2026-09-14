#
# setup-git - the Windows entry point of "one line from a bare machine to a working checkout".
#
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Super-Banana-Studios/setup-git/main/setup.ps1))) -Repo <owner>/<repo>
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

$contact = 'Ask Ivan Murashka (@imurashka) or Nikolay (@nternovoy).'
$starterUrl = 'https://raw.githubusercontent.com/Super-Banana-Studios/setup-git/main/setup.sh'

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
    if (-not $Repo) {
        Write-Host 'This line needs to know which project to set up, and it was pasted without that part.'
        Write-Host ''
        Write-Host 'Usage:'
        Write-Host '  & ([scriptblock]::Create((irm <this url>))) -Repo <owner>/<repo> [-Branch <branch>] [-Path <directory>]'
        throw 'Ask the person who onboarded you for the full line - theirs already carries the project.'
    }
    if ($Repo -notmatch '^[^/\s]+/[^/\s]+$') {
        throw "`"$Repo`" is not a repository name. It looks like owner/repository, for example my-org/my-project."
    }

    $architecture = Get-MachineArchitecture
    $version = [Environment]::OSVersion.Version
    if ($architecture -ne 'AMD64' -or $version.Build -lt 22000) {
        throw "This line supports Windows 11 (x64) and Macs with Apple Silicon. Your machine is Windows $($version.Major).$($version.Minor) build $($version.Build) ($architecture)."
    }

    Write-Host "Setting up $Repo on Windows 11 ($architecture)."
    Write-Host 'You need administrator rights on this machine and a GitHub account in the organization.'

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

    & $bash $arguments
    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host "Setup stopped (exit code $LASTEXITCODE). The message above says what to do." -ForegroundColor Red
    }
}
catch {
    # No `exit` anywhere in this file: it runs inside the person's own PowerShell window,
    # and `exit` closes that window rather than this script (measured on 5.1.26100.9444).
    Write-Host ''
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $contact -ForegroundColor Red
}
