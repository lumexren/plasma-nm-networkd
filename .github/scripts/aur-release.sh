#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (c) 2026 lumexren
#
# AUR release automation script for GitHub Actions.

set -euo pipefail

pacman -Sy --noconfirm sudo git openssh pacman-contrib

mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "$AUR_SSH_KEY" > /root/.ssh/id_ed25519
chmod 600 /root/.ssh/id_ed25519
ssh-keyscan aur.archlinux.org >> /root/.ssh/known_hosts

git config --global user.name "lumexren"
git config --global user.email "$EMAIL"
git config --global --add safe.directory '*'

AUR_REPO="${AUR_REPO:-$(basename "$REPO_URL")}"

git clone "ssh://aur@aur.archlinux.org/${AUR_REPO}.git" aur-repo

if [[ -f aur-repo/PKGBUILD ]]; then
  old_ver="$(grep "^pkgver=" aur-repo/PKGBUILD 2>/dev/null | cut -d= -f2 | tr -d ' "' || printf "")"
  old_rel="$(grep "^pkgrel=" aur-repo/PKGBUILD 2>/dev/null | cut -d= -f2 | tr -d ' "' || printf "0")"
else
  old_ver=""
  old_rel="0"
fi

if [[ -n "$old_ver" && "$old_ver" == "$VERSION" ]]; then
  new_rel=$(( ${old_rel:-0} + 1 ))
else
  new_rel="1"
fi

cp PKGBUILD aur-repo/PKGBUILD
for f in *.install; do
  [ -f "$f" ] && cp "$f" aur-repo/
done
if [[ -f .gitignore ]]; then
  cp .gitignore aur-repo/.gitignore
fi

cd aur-repo

sed -i "s|^pkgver=.*|pkgver=${VERSION}|" PKGBUILD
sed -i "s|^pkgrel=.*|pkgrel=${new_rel}|" PKGBUILD

if ! id -u builder >/dev/null 2>&1; then
  useradd -m builder
  echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
fi

chown -R builder .

sudo -u builder bash -c "makepkg --printsrcinfo > .SRCINFO"

git add PKGBUILD .SRCINFO
for f in *.install; do
  [ -f "$f" ] && git add "$f"
done
if [[ -f .gitignore ]]; then
  git add .gitignore
fi

if git diff --cached --quiet; then
  echo "No changes detected, skipping AUR push."
  exit 0
fi

git commit -m "release: update to ${VERSION}-${new_rel}"
git push origin master
