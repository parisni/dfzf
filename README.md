# Installation

[Download/copy](https://github.com/parisni/dfzf/releases) the binaries into `/usr/local/bin/` or anywhere in your PATH.

Add to your config and reload sway/i3:
```bash
exec --no-startup-id dfzf-daemon
set $dfzf_term "kitty -1 --class=dfzf-popup -e"
#set $dfzf_term "alacritty --class=dfzf-popup -e"
#set $dfzf_term "foot --app-id=dfzf-popup"
bindsym $mod+Tab    exec "$dfzf_term" dfzf-windows
bindsym $mod+Space  exec "$dfzf_term" dfzf-launcher
bindsym $mod+h      exec "$dfzf_term" dfzf-notifs
bindsym $mod+i      exec "$dfzf_term" dfzf-clipboard
for_window [app_id="^dfzf-popup$"] floating enable, sticky enable, resize set 60 ppt 70 ppt, border pixel 6
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

# Related work

- [i3-tools: switch to previous window](https://github.com/dinAlt/i3-tools)
- [swayr: a window-switcher & more for sway](https://sr.ht/~tsdh/swayr/)
