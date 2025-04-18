# Installation


## Prerequisite

- sway or i3
- jq version >= 1.7
- gawk (for the launcher)
- fzf version 
- rust to compile the daemon
- kitty version >= 0.41.1 OR alacritty OR foot

[Download/copy](https://github.com/parisni/dfzf/releases) the binaries into `/usr/local/bin/` or anywhere in your PATH.

Also be sure `fzf` is accessible from sway/i3, by moving it to `/usr/local/bin/` (instead of default `~/.cargo/bin` place)


Build/install dfzf-daemon:
```shell
cd dfzf-daemon
curl https://sh.rustup.rs -sSf | sh
rustup update nightly
cargo +nightly build --release
sudo cp target/release/dfzf-daemon /usr/local/bin/
```

Add to your config and reload sway/i3:
```bash
exec --no-startup-id dfzf-daemon
exec wl-paste --watch cliphist -max-items 5000 store
exec mako

set $term = "kitty -1 --app-id=terminal"
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
listen_on unix:/tmp/kitty
```

Windows terminal preview in kitty:

the terminal preview compares the i3/sway window title with the kitty title. In some case there is duplicates, and we cannot determinate the right terminal. So the current hack is to add 2 random characters to the title so that they get unique. For that, you will have to disable kitty title handling and tweak the shell title. Here for zsh:

```
shell_integration no-title
```

tweak the `~/.oh-my-zsh/lib/termsupport.zsh`:
```
  case "$TERM" in
    cygwin|xterm*|putty*|rxvt*|konsole*|ansi|mlterm*|alacritty*|st*|foot*|contour*)
      print -Pn "\e]2;${2:q} /$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 2)\a" # set window name
      print -Pn "\e]1;${1:q} /$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 2)\a" # set tab name
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
