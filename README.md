# super-banana-studios.github.io

One command that takes a bare machine to a working checkout of a Super Banana project.

This starter is the part that has to run before the machine has any GitHub authentication, so it lives in a public repository, served at https://super-banana-studios.github.io. It installs `git`, `git-lfs` and `gh`, signs you in to GitHub as yourself, checks that you have access, and then fetches and runs the setup script of the project repository you pass to it. Everything project specific - the checkout, the Unity Editor, Claude Code and its plugins - lives in that project's own script, not here.

Nothing here is project specific: the project repository is an argument, so one starter serves every project.

## Usage

Ask the person who onboarded you for the line. It already carries the project repository, so you paste it and run it.

**macOS (Apple Silicon)** - Terminal:

```bash
/bin/bash -c "$(curl -fsSL https://super-banana-studios.github.io/setup.sh)" -- <owner>/<repo>
```

**Windows 11 (x64)** - PowerShell:

```powershell
& ([scriptblock]::Create((irm https://super-banana-studios.github.io/setup.ps1))) -Repo <owner>/<repo>
```

You need local administrator rights on the machine and a GitHub account that is already a member of the organization. If you have neither, ask Ivan or Nikolay before you run anything.

Supported machines: Windows 11 x64 and Apple Silicon macOS. Anything else stops with a message.

### Options

| What | macOS | Windows |
| --- | --- | --- |
| Project repository, required | first argument, after `--` | `-Repo <owner>/<repo>` |
| Branch to check out | `--branch proto/<name>` | `-Branch proto/<name>` |
| Where the checkout goes | `--path <directory>` | `-Path <directory>` |

Left out, the branch is the repository's default branch and the checkout lands in a directory named after the repository, under the directory you are in.

On macOS the `--` is what makes the words after it arguments of the script rather than of `bash` itself, so it is part of the line even when nothing follows the repository.

## The short form

A project that wants a line with nothing to fill in gets a file of its own here, naming that project and calling the generic half above. The Unity skeleton has one, `skel-win` and `skel-mac`:

**Windows 11 (x64)** - PowerShell:

```powershell
irm https://super-banana-studios.github.io/skel-win | iex
```

**macOS (Apple Silicon)** - Terminal:

```bash
/bin/bash -c "$(curl -fsSL https://super-banana-studios.github.io/skel-mac)"
```

`curl ... | bash` is not an option on macOS: the pipe becomes the script's standard input, and the three sign-ins read from it - gh and claude would see end of file instead of the keyboard. `skel-mac` writes the starter to a file and runs it from there.

A second project needs one more pair of files like these, and nothing else. Two forms of the line exist because `irm ... | iex` cannot pass arguments - the script arrives as text and nothing else. The generic half is still reachable with an argument, in the idiom Chocolatey and Scoop publish:

```powershell
iex "& { $(irm https://super-banana-studios.github.io/setup.ps1) } -Repo <owner>/<repo>"
```

## What it does

1. Refuses any machine that is not Windows 11 x64 or Apple Silicon macOS.
2. Installs `git`, `git-lfs` and `gh` when they are missing - winget on Windows, Homebrew on macOS. What is already there is left alone.
3. Signs you in with `gh auth login` in your browser, and points `git` at that sign-in with `gh auth setup-git`.
4. Checks that your account can read the project repository, and stops with a name to ask when it cannot.
5. Downloads `tools/setup.sh` from the **main** branch of that repository and hands over to it, passing on the same repository, branch and path.

Running it a second time changes nothing: every step checks before it acts.

## For the person who maintains a project

Put the rest of the setup in `tools/setup.sh` on your project's `main` branch. The starter runs it as:

```
bash tools/setup.sh <owner>/<repo> [--branch <branch>] [--path <directory>]
```

The repository always arrives as the first argument; `--branch` and `--path` arrive only when the person gave them. `main` is always the source of the file, so the script has to be identical on every branch of the project.

This starter stays almost frozen - it is published as a URL that must never be reissued, so anything that will keep changing belongs in your project's script instead.

## What it does not do

No token, key or password is stored here or passed to the script. You sign in to GitHub yourself through `gh auth login`, and the repository's own permissions decide what you can read.
