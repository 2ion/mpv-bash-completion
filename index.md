A script for generating a Bash completion script for the popular [mpv
video player](https://github.com/mpv-player/mpv).
It features...

* Completion for all --options,
* Type-based completion for --option arguments for choices, flags,
  integers and floats,
* Completion for upper/lower bounds for integer- and float-type argument
  ranges where applicable,
* Completion of filter lists as arguments to --vf and --af style
  options as well as completion of filter parameters while composing filter
  lists,
* Similarly, parameter completion for video and audio outputs (--vo, --ao),
* Regular file name completion.

## Supported OSs

* [Arch Linux](#arch-linux)
* [Debian Jessie/Testing/Unstable + Ubuntu 16.04 Xenial](#debian)
* Gentoo Linux, Funtoo Linux: [app-shells/mpv-bash-completion](https://packages.gentoo.org/packages/app-shells/mpv-bash-completion)
* [OS X Homebrew](#osx-homebrew)
* [Generic Linux/OSX/Unix systems](#platform-agnostic-method)

## Source code

The main repository is on [Github](https://github.com/2ion/mpv-bash-completion).

```
git clone https://github.com/2ion/mpv-bash-completion.git
```

Tarballs of tagged releases can be downloaded [here](https://github.com/2ion/mpv-bash-completion/releases).

## Dependencies

* Bash 4
* Lua 5.1 or 5.2 or 5.3 or LuaJIT
* mpv >= 0.14

### Optional dependencies

* xrandr: for dynamic resolution detection and completion under X11
  and xwayland

### Supporting inputrc configuration

We recommend the following setting for a snappier completion experience:
To the file `~/.inputrc`, add the line
```
set show-all-if-ambiguous on
```
Launch a new shell to use the setting.

## Installation

You can just generate the completion script or build a package for one
of the supported platforms.

### Platform-agnostic method

```sh
# You may set the following environment variables beforehand:
# export MPV_BASHCOMPGEN_VERBOSE=1 # verbose debug/progress output
# export MPV_BASHCOMPGEN_MPV_CMD=mpv # path or command to execute mpv, defaults to 'mpv'

./gen.lua > mpv.sh
source ./mpv.sh
```

### Arch Linux

Install [mpv-bash-completion-git](https://aur.archlinux.org/packages/mpv-bash-completion-git/)
from the AUR. It will install all necessary dependencies and also ships
a pacman hook which automatically rebuilds the completion file whenever
you update mpv so it's **not** necessary to install the package every time.

### Debian

.deb packages can be downloaded directly [here](https://pkg.bunsenlabs.org/debian/pool/main/m/mpv-bash-completion/).

#### Stable (Jessie)

Install via BunsenLabs. Set up the `bunsenlabs-hydrogen` repository as
described [here](https://pkg.bunsenlabs.org/index.html#bunsen-hydrogen),
then execute:

```sh
sudo apt-get update && sudo apt-get install mpv-bash-completion
```

#### Testing & Sid; Ubuntu Xenial

These currently contain mpv 0.14 for which the below package is built.

Install via the BunsenLabs unstable repository. Set up the `unstable`
repository as explained [here](https://pkg.bunsenlabs.org/#unstable),
then execute:

```sh
sudo apt-get update && sudo apt-get install mpv-bash-completion
```

#### mpv git builds / custom package build

You can build a package on Debian testing or unstable, or if your mpv's
version is greater than approximately 0.14. Jessie's version of mpv is
too old.

```sh
sudo apt-get install debhelper mpv lua5.3 dpkg-dev git
git clone https://github.com/2ion/mpv-bash-completion.git
cd mpv-bash-completion && git checkout debian
dpkg-buildpackage -us -uc -b # Install the resulting package: dpkg -i $package
```

### OSX Homebrew

You can simply install using the provided formula. You need to reinstall
every time you upgrade mpv in order to update the completion function to
match the current mpv build.

```sh
brew tap 2ion/mpv-bash-completion https://github.com/2ion/mpv-bash-completion.git
brew install --HEAD mpv-bash-completion
```