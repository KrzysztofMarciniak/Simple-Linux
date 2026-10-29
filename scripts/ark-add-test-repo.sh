#!/bin/sh
set -e

R="$HOME/.ark/recipes"
mkdir -p "$R"
cd "$R"

tmp=$(mktemp -d)
wget -O "$tmp/repo.tar.gz" \
  https://github.com/KrzysztofMarciniak/ark-test-repository/archive/refs/heads/master.tar.gz
tar -xzf "$tmp/repo.tar.gz" -C "$tmp"

rm -rf ark-test-repository
mv "$tmp"/ark-test-repository-master ark-test-repository
rm -rf "$tmp"

echo "ark-test-repository installed in $R"
