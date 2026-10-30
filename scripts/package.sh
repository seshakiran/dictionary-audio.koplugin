#!/bin/sh
set -eu
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${1:-"$repo_root/dist"}
metadata_version=$(sed -n 's/.*version="\([^"]*\)".*/\1/p' "$repo_root/dictionary-audio.koplugin/_meta.lua")
test "$metadata_version" = "$(tr -d '\r\n' < "$repo_root/VERSION")"
staging_dir=$(mktemp -d)
trap 'rm -rf "$staging_dir"' EXIT INT TERM
mkdir -p "$output_dir" "$staging_dir/dictionary-audio.koplugin"
for file in _meta.lua main.lua audio_index.lua audio_player.lua pluginupdater.lua LICENSE; do
    cp "$repo_root/dictionary-audio.koplugin/$file" "$staging_dir/dictionary-audio.koplugin/$file"
done
(cd "$staging_dir" && zip -qr dictionary-audio.koplugin.zip dictionary-audio.koplugin)
mv "$staging_dir/dictionary-audio.koplugin.zip" "$output_dir/dictionary-audio.koplugin.zip"
echo "Created $output_dir/dictionary-audio.koplugin.zip"
