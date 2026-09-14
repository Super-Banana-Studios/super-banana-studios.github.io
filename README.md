# setup-git

> **Not ready yet.** The scripts are still being written, so the lines below do not work. This repository is the public placeholder they will land in.

One command that takes a bare machine to a working checkout of a Super Banana project.

This starter is the part that has to run before the machine has any GitHub authentication, so it lives in a public repository. It installs `git`, `git-lfs` and `gh`, signs you in to GitHub as yourself, checks that you have access, and then fetches and runs the setup script of the project repository you pass to it. Everything project specific - the checkout, the Unity Editor, Claude Code and its plugins - lives in that project's own script, not here.

Nothing here is project specific: the project repository is an argument, so one starter serves every project.

## Usage

Ask the person who onboarded you for the line. It already carries the project repository, so you paste it and run it.

**macOS (Apple Silicon)** - Terminal:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Super-Banana-Studios/setup-git/main/setup.sh)" -- <owner>/<repo>
```

**Windows 11 (x64)** - PowerShell:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Super-Banana-Studios/setup-git/main/setup.ps1))) -Repo <owner>/<repo>
```

You need local administrator rights on the machine and a GitHub account that is already a member of the organization. If you have neither, ask Ivan or Nikolay before you run anything.

Supported machines: Windows 11 x64 and Apple Silicon macOS. Anything else stops with a message.

## What it does not do

No token, key or password is stored here or passed to the script. You sign in to GitHub yourself through `gh auth login`, and the repository's own permissions decide what you can read.
