# Installation

[Download/copy](https://github.com/parisni/dfzf/releases) the binaries into `/usr/local/bin/` or anywhere in your PATH.

Add to your config and reload sway/i3:
```
exec --no-startup-id dfzf-daemon
bindsym $mod+Tab    exec kitty -1 --class "dfzf-popup"           -e dfzf-windows
bindsym $mod+Space  exec kitty -1 --class "dfzf-popup"           -e dfzf-launcher
bindsym $mod+h      exec kitty -1 --class "dfzf-popup"           -e dfzf-notifs
bindsym $mod+i      exec kitty -1 --class "dfzf-popup-clipboard" -e dfzf-clipboard
for_window [app_id="^dfzf-popup$"] floating enable, sticky enable, resize set 60 ppt 70 ppt, border pixel 6
for_window [app_id="^dfzf-popup-clipboard$"] floating enable, sticky enable, resize set 60 ppt 70 ppt, border pixel 6
```

# Features

## Windows

## Notifications

## Clipboard

## Launcher

# Inspiration

- `dfzf` is the combination of `d`menu and `fzf` 
- [dfzf-daemon shares 95% of its DNA with i3-back](https://github.com/Cretezy/i3-back)
- [dfzf-launcher shares 99% of its DNA with sway-launcher-desktop](https://github.com/Biont/sway-launcher-desktop/tree/master)
- [wofi-scripts has inspired dfzf-windows](https://github.com/tobiaspc/wofi-scripts)
