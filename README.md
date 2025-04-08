# Installation

[Download/copy](https://github.com/parisni/dfzf/releases) the binaries into `/usr/local/bin/` or anywhere in your PATH.

Also be sure `fzf` is accessible from sway/i3, by moving it to `/usr/local/bin/` (instead of default `~/.cargo/bin` place)

Add to your config and reload sway/i3:
```bash
exec --no-startup-id dfzf-daemon
exec wl-paste --watch cliphist -max-items 5000 store
exec mako

set $dfzf_term "kitty -1 --app-id=dfzf-popup -e"
#set $dfzf_term "alacritty --class=dfzf-popup -e"
#set $dfzf_term "foot --app-id=dfzf-popup"
bindsym $mod+Tab    exec "$dfzf_term" dfzf-windows
bindsym $mod+Space  exec "$dfzf_term" dfzf-launcher
bindsym $mod+h      exec "$dfzf_term" dfzf-notifs
bindsym $mod+i      exec "$dfzf_term" dfzf-clipboard
for_window [app_id="^dfzf-popup$"] floating enable, sticky enable, resize set 60 ppt 70 ppt, border pixel 6
```

Kitty config needed:
```
confirm_os_window_close 0
allow_remote_control yes
shell_integration enabled
listen_on unix:/tmp/kitty
```


# Features

## Windows

- cycle previous window
- windows ordered by last access
- toggle window with enter
- kill window with ctrl-k
- preview window with ctrl-j
- terminal scrollback preview (kitty only)


## Clipboard

- image preview
- content preview with bat

## Notifications

## Launcher

# Inspiration

- `dfzf` is the combination of `d`menu and `fzf` 
- [dfzf-daemon shares 95% of its DNA with i3-back](https://github.com/Cretezy/i3-back)
- [dfzf-launcher shares 99% of its DNA with sway-launcher-desktop](https://github.com/Biont/sway-launcher-desktop/tree/master)
- [wofi-scripts has inspired dfzf-windows](https://github.com/tobiaspc/wofi-scripts)

# Related work

- [i3-tools: switch to previous window](https://github.com/dinAlt/i3-tools)
- [swayr: a window-switcher & more for sway](https://sr.ht/~tsdh/swayr/)
