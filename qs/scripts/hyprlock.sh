#!/bin/sh

WALLPAPER=$(cat "$HOME/.cache/current-wallpaper")

[ -z "$WALLPAPER" ] && exit 1

ln -sfn "$WALLPAPER" "$HOME/.cache/hyprlock-wallpaper"
