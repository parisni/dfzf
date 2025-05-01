# Installation



<details>
  <summary>
Prerequisite
  </summary>

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
-
Also be sure `fzf` is accessible from sway/i3, by moving it to `/usr/local/bin/` (instead of default `~/.cargo/bin` place)
  or  setup sway/i3 path correctly
  ```
#~/.config/sway/config
set $PATH /usr/local/bin:/opt/bin:$PATH

  ```




</details>

<details>
  <summary>
    Download the releases
  </summary>

- [Download/copy](https://github.com/parisni/dfzf/releases) the binaries into `/usr/local/bin/` or anywhere in your PATH.
- TODO: deb package 
</details>

<details>
<summary>Build/install dfzf-daemon</summary>

```bash
cd dfzf-utils
curl https://sh.rustup.rs -sSf | sh
rustup update nightly
cargo +nightly build --release
sudo cp target/release/dfzf-{daemon,mark} /usr/local/bin/
```
</details>

# Configuration

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
  <summary>user configuration [optional]</summary>

  you can override default configurations:
  ```bash
# ~/.config/dfzf/dfzf.conf

exit_options=(
"l: Lock (swaylock)"
"e: Restart GDM"
"s: Lock and Suspend"
"r: Reboot"
"S: Shutdown"
"h: Hibernate"
)

exit_cmd_l='swaylock -e -F -f -k -c 000000'
exit_cmd_e='sudo /usr/bin/systemctl restart gdm'
exit_cmd_s='swaylock -e -F -f -k -c 000000 && systemctl suspend'
exit_cmd_r='sudo reboot'
exit_cmd_S='shutdown now'
exit_cmd_h='sudo /bin/systemctl hibernate'


#remove pattern from the window's title
windows_title_rm_pattern=' —[^—]*?— Mozilla Firefox'
windows_app_id_map_json='{"evolution": "mail", "kitty": "terminal", "jetbrains-idea-ce": "jetbrains"}'
windows_glyph_rules_json='[
{ "field": "name", "regex": "vim\\b", "glyph": " " },
{ "field": "app_id", "regex": "terminal", "glyph": " " },
{ "field": "app_id", "regex": "firefox", "glyph": " " },
{ "field": "app_id", "regex": "jetbrains", "glyph": " " },
{ "field": "app_id", "regex": "gimp", "glyph": " " },
{ "field": "app_id", "regex": "thunar|nautilus", "glyph": " " },
{ "field": "app_id", "regex": "thunderbird|evolution|geary|mailspring|k9mail|mail", "glyph": " " },
{ "glyph": " " }
]'

```

</details>

<details>
  <summary>Kitty configuration [optional]</summary>

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




<details>
  <summary>
 Firefox [optional]
  </summary>

Install the below extensions:
- tabs are windows: no tabs anymore in FF, just regular windows
- hostname in windows title: adds the url in the title, useful to search

</details>

<details>
  <summary>
 Chromium [optional]
  </summary>

Install the below extensions:
- TODO
- TODO

</details>


# Features

<details>
  <summary>
    Windows
  </summary>

- windows ordered by last access
- cycle previous window
- Return: focus window
- focus window with enter
- ctrl-k: kill window
- terminal scrollback preview (kitty only)
- ctrl-u: toggle urgent  (yellow color)
- ctrl-i: toggle important (red color)
- ctrl-j: preview windows
- escape: return to current windows (works after previews)

</details>






<details>
  <summary>
 Clipboard: Sway only
  </summary>

- content preview with bat
- image preview with kitten
</details>


<details>
  <summary>
Mail
  </summary>

  - list latest mails
  - preview text mails
  - ctrl-j: preview html mails in the browser
</details>


<details>
  <summary>
    Exit
  </summary>

  - hibernate
  - reboot
  - shutdown
  - logout
</details>


<details>
  <summary>
Password-store
  </summary>

  - Return: copy content
  - ctrl-j: preview content
</details>


<details>
  <summary>
 Notifications: Sway only
  </summary>

  - list notification ordered
  - Return: notification action
  - ctrl-k: kill notification
</details>

<details>
  <summary>
 Launcher
  </summary>

  - list desktop applications
  - fire application
</details>

# Related work

- `dfzf` is the combination of `d`menu and `fzf` 
- [dfzf-daemon comes from i3-back](https://github.com/Cretezy/i3-back)
- [dfzf-launcher comes from sway-launcher-desktop](https://github.com/Biont/sway-launcher-desktop/tree/master)
- [wofi-scripts has inspired dfzf-windows](https://github.com/tobiaspc/wofi-scripts)
- [swayr: a window-switcher & more for sway](https://sr.ht/~tsdh/swayr/)
- [i3-tools: switch to previous window](https://github.com/dinAlt/i3-tools)
