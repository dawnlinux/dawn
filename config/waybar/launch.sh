#!/bin/bash

pkill waybar
pkill swaync 
hyprctl reload

waybar &
swaync &
