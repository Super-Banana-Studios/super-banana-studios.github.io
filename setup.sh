#!/bin/bash
#
# setup-git - the first half of "one line from a bare machine to a working checkout".
#
#   setup.sh <owner>/<repo> [--branch <branch>] [--path <directory>]
#
# Installs git, git-lfs and gh, signs you in to GitHub as yourself, checks that you can
# see the project repository, then fetches tools/setup.sh from that repository's main
# branch and hands over to it with the same arguments.

set -u

CONTACT="Ask Ivan Murashka (@imurashka) or Nikolay (@nternovoy)."
POWERSHELL_LINE='& ([scriptblock]::Create((irm https://super-banana-studios.github.io/setup.ps1))) -Repo <owner>/<repo>'

repo=""
branch=""
checkout=""
admin_notice_shown=no

say() { printf '%s\n' "$*"; }

step() { printf '\n==> %s\n' "$*"; }

fail() {
	printf '\n%s\n%s\n' "$*" "$CONTACT" >&2
	exit 1
}

usage() {
	say "Usage: setup.sh <owner>/<repo> [--branch <branch>] [--path <directory>]"
	say ""
	say "  <owner>/<repo>   the project repository, for example my-org/my-project"
	say "  --branch         the branch to check out; the default branch when left out"
	say "  --path           where to put the checkout; the repository name here when left out"
}

admin_notice() {
	if [ "$admin_notice_shown" = no ]; then
		admin_notice_shown=yes
		say ""
		say "Some of this installs software, which needs administrator rights on this machine."
		say "You will be asked for your password or to approve a prompt. That is expected."
	fi
}

while [ $# -gt 0 ]; do
	case "$1" in
		--branch)
			[ $# -ge 2 ] || fail "--branch needs a branch name after it."
			branch=$2
			shift 2
			;;
		--path)
			[ $# -ge 2 ] || fail "--path needs a directory after it."
			checkout=$2
			shift 2
			;;
		-h | --help)
			usage
			exit 0
			;;
		-*)
			usage >&2
			fail "$1 is not an option this line knows."
			;;
		*)
			if [ -n "$repo" ]; then
				usage >&2
				fail "Only one repository can be given, and it already is $repo."
			fi
			repo=$1
			shift
			;;
	esac
done

if [ -z "$repo" ]; then
	say "This line needs to know which project to set up, and it was pasted without that part."
	say ""
	usage
	fail "Ask the person who onboarded you for the full line - theirs already carries the project."
fi

case "$repo" in
	*/*/* | */ | /* | *" "*) fail "\"$repo\" is not a repository name. It looks like owner/repository, for example my-org/my-project." ;;
	*/*) ;;
	*) fail "\"$repo\" is not a repository name. It looks like owner/repository, for example my-org/my-project." ;;
esac

kernel=$(uname -s)
machine=$(uname -m)

case "$kernel" in
	Darwin) os=macos ;;
	MINGW* | MSYS* | CYGWIN*) os=windows ;;
	*) os=$kernel ;;
esac

unsupported() {
	fail "This line supports Windows 11 (x64) and Macs with Apple Silicon. Your machine is $*."
}

case "$os" in
	macos)
		[ "$machine" = arm64 ] || unsupported "a Mac with an Intel processor ($machine)"
		[ "$(id -u)" != 0 ] || fail "Run this line as yourself, without sudo. It will ask for your password when it needs it."
		;;
	windows)
		[ "$machine" = x86_64 ] || unsupported "Windows on $machine"
		;;
	*)
		unsupported "$kernel $machine"
		;;
esac

say "Setting up $repo on $(if [ "$os" = macos ]; then echo "macOS ($machine)"; else echo "Windows ($machine)"; fi)."
say "You need administrator rights on this machine and a GitHub account in the organization."

if [ "$os" = macos ]; then
	if [ ! -x /opt/homebrew/bin/brew ]; then
		admin_notice
		step "Installing Homebrew, which also installs Apple's command line tools (they carry git)"
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" ||
			fail "Homebrew did not install, so git, git-lfs and gh cannot be installed either."
	fi
	[ -x /opt/homebrew/bin/brew ] || fail "Homebrew is not at /opt/homebrew/bin/brew after installing it."
	eval "$(/opt/homebrew/bin/brew shellenv)"

	if ! brew list --formula git-lfs >/dev/null 2>&1; then
		admin_notice
		step "Installing Git LFS"
		brew install git-lfs || fail "Git LFS did not install."
	fi
	if ! brew list --formula gh >/dev/null 2>&1; then
		admin_notice
		step "Installing the GitHub CLI"
		brew install gh || fail "The GitHub CLI did not install."
	fi
fi

command -v git >/dev/null 2>&1 || fail "git is still not there after the install step."
if ! command -v gh >/dev/null 2>&1; then
	if [ "$os" = windows ]; then
		fail "The GitHub CLI is missing. On Windows, run this line in PowerShell instead: $POWERSHELL_LINE"
	fi
	fail "The GitHub CLI is still not there after the install step."
fi

git lfs install >/dev/null || fail "git lfs install failed, so large files would not be downloaded."

step "GitHub sign-in"
if gh auth status --hostname github.com >/dev/null 2>&1; then
	say "Already signed in as $(gh api user --jq .login 2>/dev/null)."
else
	say "The GitHub tool asks two things first: whether git may use this sign-in too - answer Y - and"
	say "then shows a code and waits for Enter. Enter opens the browser: sign in with your GitHub"
	say "account there, type the code, then come back here."
	gh auth login --hostname github.com --web --git-protocol https ||
		fail "The GitHub sign-in did not finish, so nothing further can be downloaded."
fi
gh auth setup-git --hostname github.com || fail "git could not be pointed at your GitHub sign-in."

step "Checking your access to $repo"
gh repo view "$repo" --json name >/dev/null 2>&1
access=$?
if [ "$access" -ne 0 ]; then
	if [ "$access" -eq 4 ]; then
		fail "You are not signed in to GitHub, so your access to $repo cannot be checked. Run the line again."
	fi
	who=$(gh api user --jq .login 2>/dev/null)
	fail "Your GitHub account (${who:-unknown}) cannot see $repo, so it is either not there or not yours to read yet. You are probably not in the Super Banana dev team."
fi
say "You can read $repo."

script=$(mktemp) || fail "A temporary file could not be created."
if ! gh api "repos/$repo/contents/tools/setup.sh" -H "Accept: application/vnd.github.raw" >"$script" 2>/dev/null; then
	fail "$repo has no tools/setup.sh on its main branch, so there is nothing to run after this point."
fi
[ -s "$script" ] || fail "tools/setup.sh came back empty from $repo."

set -- "$repo"
[ -n "$branch" ] && set -- "$@" --branch "$branch"
[ -n "$checkout" ] && set -- "$@" --path "$checkout"

step "Handing over to the setup script of $repo"
exec bash "$script" "$@"
