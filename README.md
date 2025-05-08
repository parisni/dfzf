# dfzf — Effortless Window Navigation for Sway and i3

**dfzf** redefines how you interact with windows in sway and i3, letting you switch windows with `fzf`, sorted by recency — no more cycling or losing your mind. Unlike traditional workspaces or tabbing, it frees you from relying on mental cartography, using name- and time-based navigation to keep access effortless, even with dozens of windows.

No more mental gymnastics. Just type to fuzzy-match and access recent windows first — eventually, you’ll rely solely on **dfzf-windows** for seamless navigation.

![Demo](https://github.com/user-attachments/assets/ab181f25-622b-4aaf-931a-ee5d07371853)
<details>
  <summary>Click to expand description of the GIF</summary>

This GIF shows dfzf-windows in action:
 - List the current windows, recent ones come first
 - Inspect the windows previews, including terminal
 - Mark the windows either as "urgent" or "important"
 - Kills windows one by one until none are left  
 - Bonus: Notice a bit of "inception" in the `dfzf-windows` preview...

  
</details>


---
## Why dfzf?

* ⏱️ **Instant access** — switch to any window instantly, regardless of how many are open.
* 🔍 **Recent-first navigation** — fuzzy-search windows by name, with recent ones prioritized.
* 🧠 **Low cognitive load** — remember *what* and *when*, not *where*.

---
## How It Works

**dfzf** relies on `dfzf-daemon` to track window focus changes via IPC, storing the order of recently used windows in their marks. It uses `dfzf-mark` to add or remove marks, such as "important" marks (shown in red). And don't worry if you're already using marks — **dfzf** won't interfere with your existing setup.

Just make sure the daemon is running when you try **dfzf** for the first time!


---
## What's Included?

`dfzf` is more than a window switcher — it's a full toolkit for your desktop, built with speed, consistency, and minimalism in mind:

| Tool             | Description                                  | i3 | Sway |
|------------------|----------------------------------------------|:--:|:----:|
| `dfzf-windows`   | Navigate windows by title or time            | ✅ | ✅   |
| `dfzf-launcher`  | Launch desktop apps instantly                | ✅ | ✅   |
| `dfzf-clipboard` | Searchable clipboard with image/text preview | ❌ | ✅   |
| `dfzf-notify`    | Browse past notifications                    | ❌ | ✅   |
| `dfzf-mail`      | View and preview emails from the terminal    | ✅ |  ✅   |
| `dfzf-password`  | Copy and preview entries from pass           | ✅ | ✅   |
| `dfzf-exit`      | Logout, reboot, suspend, hibernate           | ❌ | ✅   |

---


## Installation

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
- [Download the deb package](https://github.com/parisni/dfzf/releases), and `sudo dpkg -i` it on debian/ubuntu.
</details>

<details>
<summary>Build/install dfzf-daemon</summary>

```bash
cd dfzf-utils
curl https://sh.rustup.rs -sSf | sh
rustup update nightly
cargo +nightly build --release
find  dfzf-utils  -type f  -executable -name "dfzf-*" |xargs -I@ sudo cp @ /usr/local/bin/
```
</details>

## Configuration

<details>

<summary>Sway configuration</summary>

```bash
exec --no-startup-id dfzf-daemon # reboot to make the daemon running
exec wl-paste --watch cliphist -max-items 1000 store # for dfzf-clipboard  
exec mako # for the dfzf-notifs

set $term kitty -1
#set $term foot
#set $term alacritty

#set $dfzf_term foot --app-id=dfzf-popup -e
set $dfzf_term kitty -1 --class=dfzf-popup -e
bindsym $mod+Tab    exec $dfzf_term dfzf-windows
bindsym $mod+o      exec $dfzf_term dfzf-launcher
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
exec --no-startup-id dfzf-daemon # reboot to make the daemon running

set $term kitty -1
#set $term foot
#set $term alacritty

#set $dfzf_term foot --app-id=dfzf-popup -e
set $dfzf_term kitty -1 --class=dfzf-popup -e
bindsym $mod+Tab    exec $dfzf_term dfzf-windows
bindsym $mod+o      exec $dfzf_term dfzf-launcher
bindsym $mod+m      exec $dfzf_term dfzf-mail
bindsym $mod+p      exec $dfzf_term dfzf-password
bindsym $mod+F1     exec $dfzf_term dfzf-exit
for_window [class="^dfzf-popup$"] floating enable, sticky enable, resize set 60 ppt 70 ppt, border pixel 6

# optional: hide the tabs
font pango:monospace 0
default_border none
default_floating_border none

# reset font for the bar
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

#remove pattern from the window's title
windows_title_rm_pattern=' —[^—]*?— Mozilla Firefox'
# rename the application classes
windows_app_id_map_json='{"evolution": "mail", "kitty": "terminal", "jetbrains-idea-ce": "jetbrains"}'
# assign glyphs to application classes
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

# override the exit list and respective commands
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
- [tabs are windows](https://addons.mozilla.org/en-US/firefox/addon/tabs-are-windows/reviews/?utm_source=firefox-browser&utm_medium=firefox-browser&utm_content=addons-manager-reviews-link)
- [hostname in windows title](https://addons.mozilla.org/en-US/firefox/addon/hostname-in-window-title/reviews/?utm_source=firefox-browser&utm_medium=firefox-browser&utm_content=addons-manager-reviews-link)
I use this template `{title} - {href} —`, together with this variable in dfzf config to bring perfect ff titles.

```bash
  # remove pattern from the window's title
windows_title_rm_pattern=' —[^—]*?— Mozilla Firefox'
```


</details>

<details>
  <summary>
 Chromium [optional]
  </summary>

Install the below extensions:
- [new-tab-new-window](https://chromewebstore.google.com/detail/new-tab-new-window/dndlcbaomdoggooaficldplkcmkfpgff)
- either [URL in title](https://chromewebstore.google.com/detail/url-in-title/ignpacbgnbnkaiooknalneoeladjnfgb?hl=en) or [Title morph](https://chromewebstore.google.com/detail/title-morph/ajlggpkmjdilpiamlofcmjckeabiecea)

</details>


## Features

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

  ```bash
    sudo apt install jq
  ```

  ![Image](https://github.com/user-attachments/assets/ab76602c-9e04-4a08-bb9d-dcee16413fce)
</details>






<details>
  <summary>
 Clipboard
  </summary>

- content preview with bat
- image preview with kitten

  ```bash
    sudo apt install jq cliphist wl-clipboard batcat
  ```

  ![Image](https://github.com/user-attachments/assets/e339b0d0-d010-43a9-9ce6-9b94f11c02a2)
</details>

<details>
  <summary>
Mail
  </summary>

  - list latest mails
  - preview text mails
  - ctrl-j: preview html mails in the browser
  
  ```bash
    sudo apt install jq himalaya
  ```
</details>

<details>
  <summary>
Password-store
  </summary>


  - Return: copy content
  - ctrl-j: preview content
 
  ```bash
    sudo apt install pass wl-clipboard
  ```
  ![Image](https://github.com/user-attachments/assets/2ebeec63-3ee8-4a47-9b8c-988c8cb5ffeb)
</details>

<details>
  <summary>
 Notifications
  </summary>


  - list notification ordered
  - Return: notification action
  - ctrl-k: kill notification
  
  ```bash
    sudo apt install jq mako-notifier
  ```
  ![Image](https://github.com/user-attachments/assets/645934df-c121-4f46-96d9-6b616f4b66cf)
</details>

<details>
  <summary>
 Launcher
  </summary>


  - list desktop applications
  - fire application
  
  ```bash
    sudo apt install jq gawk
  ```
  ![Image](https://github.com/user-attachments/assets/257e278d-e537-4c17-a1c9-7f5b876cb30b)
</details>

<details>
  <summary>
    Exit
  </summary>


  - hibernate
  - reboot
  - shutdown
  - logout

  ![Image](https://github.com/user-attachments/assets/2e60004a-f3a4-4336-a42e-576292f77e47)
</details>

## Related work

- `dfzf` is the combination of `d`menu and `fzf` 
- [dfzf-daemon comes from i3-back](https://github.com/Cretezy/i3-back)
- [dfzf-launcher comes from sway-launcher-desktop](https://github.com/Biont/sway-launcher-desktop/tree/master)
- [wofi-scripts has inspired dfzf-windows](https://github.com/tobiaspc/wofi-scripts)
- [swayr: a window-switcher & more for sway](https://sr.ht/~tsdh/swayr/)
- [i3-tools: switch to previous window](https://github.com/dinAlt/i3-tools)


## License

This project is licensed under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html).
