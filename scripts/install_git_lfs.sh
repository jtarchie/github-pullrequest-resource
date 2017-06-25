#!/bin/sh

set -eu

_main() {
  local tmpdir
  tmpdir="$(mktemp -d git_lfs_install.XXXXXX)"

  cd "$tmpdir"
  curl -Lo git.tar.gz https://github.com/github/git-lfs/releases/download/v2.1.1/git-lfs-linux-amd64-2.1.1.tar.gz
  gunzip git.tar.gz
  tar xf git.tar
  mv git-lfs-2.1.1/git-lfs /usr/bin
  cd ..
  rm -rf "$tmpdir"
  git lfs install --skip-smudge
}

_main "$@"
