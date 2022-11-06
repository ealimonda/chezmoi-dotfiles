# chezmoi-dotfiles
My dotfiles, powered by chezmoi

## Installation on a new machine:

### Install chezmoi

#### Generic OS

```bash
$ curl -fsLS chezmoi.io/get | sudo sh -s -- -b /usr/local/bin/
```

#### macOS (homebrew)

```bash
$ brew update && brew install chezmoi
```

### Init configuration

```bash
$ chezmoi init https://github.com/ealimonda/chezmoi-dotfiles
$ chezmoi apply
```
