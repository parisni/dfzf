# Installation


## Prerequisite

- sway or i3
- fzf 
- jq version >= 1.7
- gawk for dfzf-launcher
- kitty version >= 0.41.1 OR alacritty OR foot
- fd-find for dfzf-password
- himalaya for dfzf-mail
- batcat for dfzf-clipboard
- mako for dfzf-notif
- wl-clipboard, cliphist for dfzf-clipboard
- rust to compile the dfzf-daemon and dfzf-mark

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

<details>

<summary>Sway configuration</summary>

```bash
exec --no-startup-id dfzf-daemon
exec wl-paste --watch cliphist -max-items 5000 store
exec mako

set $term kitty -1
#set $term foot
#set $term alacritty

#set $dfzf_term foot --app-id=dfzf-popup -e
set $dfzf_term $term --class=dfzf-popup -e
bindsym $mod+Tab    exec $dfzf_term dfzf-windows
bindsym $mod+space  exec $dfzf_term dfzf-launcher
bindsym $mod+h      exec $dfzf_term dfzf-notifs
bindsym $mod+i      exec $dfzf_term dfzf-clipboard
bindsym $mod+m      exec $dfzf_term dfzf-mail
bindsym $mod+p      exec $dfzf_term dfzf-password
bindsym $mod+F1     exec $dfzf_term dfzf-exit
for_window [app_id="^dfzf-popup$"] floating enable, sticky enable, resize set 60 ppt 70 ppt, border pixel 6

# optional: hide the tabs
font pango:monospace 0.001
default_border none
default_floating_border none
titlebar_padding 1
titlebar_border_thickness 0
```
</details>
<details>

<summary>I3 configuration</summary>

```bash
exec --no-startup-id dfzf-daemon

set $term kitty -1
#set $term foot
#set $term alacritty

#set $dfzf_term foot --app-id=dfzf-popup -e
set $dfzf_term $term --class=dfzf-popup -e
bindsym $mod+Tab    exec $dfzf_term dfzf-windows
bindsym $mod+space  exec $dfzf_term dfzf-launcher
bindsym $mod+h      exec $dfzf_term dfzf-notifs
bindsym $mod+i      exec $dfzf_term dfzf-clipboard
bindsym $mod+m      exec $dfzf_term dfzf-mail
bindsym $mod+p      exec $dfzf_term dfzf-password
bindsym $mod+F1     exec $dfzf_term dfzf-exit
for_window [class="^dfzf-popup$"] floating enable, sticky enable, resize set 60 ppt 70 ppt, border pixel 6

# optional: hide the tabs
font pango:monospace 0
default_border none
default_floating_border none

# only if you rely on i3status
bar {
	font pango:monospace 10 # needed 
	status_command i3status
}
```
</details>


<details>
  <summary>Kitty configuration</summary>

```bash
#~/.config/kitty/kitty.conf
confirm_os_window_close 0
allow_remote_control yes
listen_on unix:/tmp/kitty
```

Windows terminal preview in kitty:

the terminal preview compares the i3/sway window title with the kitty title. In some case there is duplicates, and we cannot determinate the right terminal. So the current hack is to add 2 random characters to the title so that they get unique. For that, you will have to disable kitty title handling and tweak the shell title. Here for zsh:

```bash
#~/.config/kitty/kitty.conf
shell_integration no-title
```

tweak zsh:
```bash
# ~/.oh-my-zsh/lib/termsupport.zsh
  case "$TERM" in
    cygwin|xterm*|putty*|rxvt*|konsole*|ansi|mlterm*|alacritty*|st*|foot*|contour*)
      print -Pn "\e]2;${2:q} /$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 2)\a" # set window name
      print -Pn "\e]1;${1:q} /$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 2)\a" # set tab name
```

</details>


# Features

## Windows

- cycle previous window
- windows ordered by last access
- focus window with enter
- preview windows with ctrl-j
- focus current windows with excape (works after previews)
- kill window with ctrl-k
- terminal scrollback preview (kitty only)
- toggle urgent with ctrl-u (yellow color)
- toggle important with ctrl-i (red color)


### Browser tabs

#### Firefox
Install the below extensions:
- tabs are windows: no tabs anymore in FF, just regular windows
- hostname in windows title: adds the url in the title, useful to search

#### Chromium
Install the below extensions:
- TODO
- TODO


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
