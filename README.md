# dfzf — Effortless Window Navigation for Sway/i3

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
## A New Way to Navigate Your Desktop

Using `dfzf` invites you to rethink how you use your window manager:

- **No more tabs** — Use `dfzf-windows` to manage windows efficiently, without relying on tabbed layouts.
- **No more workspaces** — Replace static workspaces with a flexible color tagging system. Assign multiple tags to a single window for powerful cross-grouping and faster navigation.
- **No more bars** — Free up screen space and ditch the traditional bar. Invoke minimal, dedicated popups for clock, system monitor, system info, wifi, and more — only when needed.

These  make your desktop cleaner, more dynamic, and easier to manage — with more pixels dedicated to what actually matters —  always full-screen !


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
| `dfzf-scrollbacks`   | Fuzzy-search within all your terminals at once            | ✅ | ✅   |
| `dfzf-launcher`  | Launch desktop apps or cmds in terminal      | ✅ | ✅   |
| `dfzf-notify`    | Browse past notifications                    | ❌ | ✅   |
| `dfzf-tasks`     | Manage caldav tasks                        | ✅ |  ✅   |
| `dfzf-clipboard` | Searchable clipboard with image/text preview | ✅ | ✅   |
| `dfzf-password`  | Copy and preview entries from pass           | ✅ | ✅   |
| `dfzf-mail`      | View, preview and delete emails     | ✅ |  ✅   |
| `dfzf-exit`      | Logout, reboot, suspend, hibernate           | ❌ | ✅   |
| `dfzf-tools`      | Clock, calendar, top, wifi, bluetooth, fetch popup      | ✅ |  ✅   |
| `dfzf-hub`   | Invoke other dfzf commnands            | ✅ | ✅   |
| `dfzf-term`   | Terminal management (kill/new/toggle/scratchpad) | ✅ | ✅   |

---
## Terminal Support Matrix

| Feature / Terminal                   | Kitty     | Foot              | Alacritty        |
|-------------------------------------|-----------|-------------------|------------------|
| `dfzf-windows` Terminal Preview     | ✅ Full   | ❌ Not supported  | ❌ Not supported |
| `dfzf-scrollbacks` Support          | ✅ Full   | ❌ Not supported  | ❌ Not supported |
| `dfzf-clipboard` Image Preview      | ✅ Full   | ⚠️ Intermediate   | 🔻 Degraded      |
| Press `escape` to kill popup      | ✅ Full   | ⚠️ Intermediate   | ⚠️ Intermediate      |
| Everything else      | ✅ Full   | ✅ Full   | ✅ Full      |

---

## Installation

<details>
  <summary>
Prerequisite
  </summary>

In general, dfzf needs:
 
- sway or i3, with default layout `tabbed`
- fzf 
- kitty version >= 0.42.1 OR alacritty OR foot
- jq version >= 1.7
- nerdfonts to display the glyphs (see nerdfont section)

Moreover, each tool can have specific dependencies described in the `Features` section.



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



<details>
<summary>Nerdfont</summary>


Glyph are used in some dfzf modules (windows, tasks). If you don't wan't them you can override the config that way:
```bash
#~/.config/dfzf/dfzf.conf
windows_glyph_rules_json='[{"glyph": ""}]'
```

You can install nerdfont by running this script ([source](https://gist.github.com/matthewjberger/7dd7e079f282f8138a9dc3b045ebefa0?permalink_comment_id=3839120)). Also snap apps cannot access to `.local/share/fonts`, reason I personally install them into `~/.fonts` instead.
```bash
  #!/bin/bash

declare -a fonts=(
BitstreamVeraSansMono
CascadiaCode
CodeNewRoman
DroidSansMono
FiraCode
FiraMono
Go-Mono
Hack
Hermit
JetBrainsMono
Meslo
Noto
Overpass
ProggyClean
RobotoMono
SourceCodePro
SpaceMono
Ubuntu
UbuntuMono
)

version=$(curl -s 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest' | jq -r '.name')
fonts_dir="${HOME}/.fonts"

if [[ ! -d "$fonts_dir" ]]; then
mkdir -p "$fonts_dir"
fi

for font in "${fonts[@]}"; do
zip_file="${font}.zip"
download_url="https://github.com/ryanoasis/nerd-fonts/releases/download/${version}/${zip_file}"
echo "Downloading $download_url"
wget "$download_url"
unzip "$zip_file" -d "$fonts_dir"
rm "$zip_file"
done

find "$fonts_dir" -name 'Windows Compatible' -delete

fc-cache -fv
```
</details>

## Configuration

<details>

<summary>Sway configuration</summary>

```bash
exec --no-startup-id dfzf-daemon # reboot to make the daemon running
exec --no-startup-id copyq
exec mako # for the dfzf-notifs

exec swaymsg workspace 1, layout tabbed
workspace_auto_back_and_forth no

# FOR FOOT OR ALACRITTY
#set $term foot
#set $term alacritty
#set $dfzf_term foot --app-id=dfzf-popup -e
#bindsym $mod+Tab    exec --no-startup-id $dfzf_term dfzf-windows
#bindsym $mod+l      exec --no-startup-id $dfzf_term dfzf-hub

# FOR KITTY
set $term kitty -1
exec --no-startup-id kitty -1 --start-as hidden
exec --no-startup-id kitty -1 --instance-group dfzf --start-as hidden  -o 'map escape close_window' -o 'listen_on=unix:/tmp/kitty-dfzf' 
bindsym $mod+Tab    exec --no-startup-id kitty -1 --class=dfzf-popup -e dfzf-windows
bindsym $mod+l      exec --no-startup-id kitty -1 --instance-group dfzf --class=dfzf-popup -e dfzf-hub
bindsym $mod+n exec dfzf-term scratchpad $term
bindsym ctrl+slash exec dfzf-term toggle $term
bindsym shift+ctrl+slash exec dfzf-term kill $term

for_window [app_id="^dfzf-popup$"] floating enable, sticky enable, border pixel 6, exec dfzf-resize 65

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

# make sure the workspace is tabbed by default
exec i3-msg workspace 1, layout tabbed
exec --no-startup-id copyq
workspace_auto_back_and_forth no

# FOR FOOT OR ALACRITTY
#set $term foot
#set $term alacritty
#set $dfzf_term foot --app-id=dfzf-popup -e
#bindsym $mod+Tab    exec --no-startup-id $dfzf_term dfzf-windows
#bindsym $mod+l      exec --no-startup-id $dfzf_term dfzf-hub

# FOR KITTY
set $term kitty -1
exec --no-startup-id kitty -1 --start-as hidden
exec --no-startup-id kitty -1 --instance-group dfzf --start-as hidden  -o 'map escape close_window' -o 'listen_on=unix:/tmp/kitty-dfzf' 
bindsym $mod+Tab    exec --no-startup-id kitty -1 --class=dfzf-popup -e dfzf-windows
bindsym $mod+l      exec --no-startup-id kitty -1 --instance-group dfzf --class=dfzf-popup -e dfzf-hub
bindsym $mod+n exec dfzf-term scratchpad $term
bindsym ctrl+slash exec dfzf-term toggle $term
bindsym shift+ctrl+slash exec dfzf-term kill $term

for_window [class="^dfzf-popup$"] floating enable, sticky enable, border pixel 6, exec dfzf-resize 65

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

#kitty only: regexp to match the prompt
windows_prompt_pattern="^[>$%] "
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

tools_clock_cmd="tty-clock -c -C 4 -s"
tools_calendar_cmd="~/.venv/3.11.6/bin/khal interactive"
tools_top_cmd="gotop"

# hub user customization
hub_options=(
  "a: Audio"
  "b: Bluetooth"
  "c: Clipboard"
  "d: Date"
  "e: Exit"
  "f: Fetch"
  "g: Gotop"
  "k: Calendar"
  "l: Launcher"
  "m: Mail"
  "n: Notif"
  "p: Password"
  "s: Scrollback"
  "t: Task"
  "w: Wifi"
  "i: Iotop"
  "q: Pomatez"
)

# hub custom command mappings
hub_cmd_a='dfzf-exec exec pavucontrol'
hub_cmd_b='dfzf-tools bluetooth'
hub_cmd_c='dfzf-clipboard'
hub_cmd_d='dfzf-tools clock'
hub_cmd_e='dfzf-exit'
hub_cmd_f='dfzf-tools fetch'
hub_cmd_g='dfzf-tools top'
hub_cmd_k='dfzf-tools calendar'
hub_cmd_l='dfzf-launcher'
hub_cmd_m='dfzf-mail'
hub_cmd_n='dfzf-notifs'
hub_cmd_p='dfzf-password'
hub_cmd_s='dfzf-scrollbacks'
hub_cmd_t='dfzf-tasks'
hub_cmd_w='dfzf-tools wifi'
hub_cmd_i='TERM=xterm sudo /usr/sbin/iotop -o'
hub_cmd_q="pomatez || dfzf-windows-load|rg pomatez|sed -Ez 's/.*#([0-9]+).*/\1/'|xargs -I@ dfzf-exec '[con_id=@]' focus"
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
- terminal scrollback preview (kitty only)

keybindings:

- `Return`: focus window
- `ctrl-b`: toggle color blue
- `ctrl-g`: toggle color green
- `ctrl-o`: toggle color orange
- `ctrl-r`: toggle color red
- `B`: filter color blue
- `G`: filter color green
- `O`: filter color orange
- `R`: filter color red
- `ctrl-k`: kill window
- `ctrl-u`: toggle urgent  (yellow color)
- `ctrl-i`: toggle important (red color)
- `ctrl-j`: preview windows
- `escape`: return to current windows (works after previews)
- `ctrl-t`: will toggle tilling to the multi-selected windows

  ```bash
    sudo apt install jq ripgrep
  ```

  ![Image](https://github.com/user-attachments/assets/ab76602c-9e04-4a08-bb9d-dcee16413fce)
Tilling with multi-select (ctrl-t):
  ![Image](https://github.com/user-attachments/assets/fec7de04-550e-410c-9a81-351f09b63451)
![Image](https://github.com/user-attachments/assets/9fa6c549-79eb-4619-934b-487a50d83aeb)
</details>

<details>
  <summary>
 Scrollbacks
  </summary>

  Scrollbacks let you fuzzy-search across all your terminal histories (Kitty only) and focus the right one — great for digging up lost work from vague command memories.

  ```bash
    sudo apt install ripgrep
  ```

![Image](https://github.com/user-attachments/assets/51f9ca01-ed27-48bf-81f0-2433f301771c)

</details>

<details>
  <summary>
 Hub
  </summary>

  The hub lets you launch any dfzf command with a single keystroke — one keybinding to rule them all.

- `b`: Bluetooth
- `c`: Clipboard
- `d`: Date
- `e`: exit
- `g`: Gotop
- `k`: Calendar
- `l`: launcher
- `m`: Mail
- `n`: Notif
- `p`: Password
- `s`: Scrollback
- `t`: Task
- `w`: Wifi

  ![Image](https://github.com/user-attachments/assets/1aa98ea6-3b59-48fc-9eea-1673857ed019)
</details>



<details>
  <summary>
 Clipboard
  </summary>

- content preview with bat
- image preview with kitten

  ```bash
    sudo apt install jq copyq wl-clipboard batcat 
    # optional for non kitty term
    sudo apt install wafa

  ```



  ![Image](https://github.com/user-attachments/assets/e339b0d0-d010-43a9-9ce6-9b94f11c02a2)
</details>

<details>
  <summary>
Mail
  </summary>

  - list latest mails
  - preview text mails
  - `ctrl-j`: preview html mails in the browser
  
  ```bash
    sudo apt install jq himalaya
  ```
</details>

<details>
  <summary>
Password-store
  </summary>


  - `Return`: copy content
  - `ctrl-j`: preview content
 
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
  - `Return`: notification action
  - `ctrl-k`: kill notification
  - `ctrl-h`: toggle notif history
  
  ```bash
    sudo apt install jq mako-notifier
  ```
  ![Image](https://github.com/user-attachments/assets/645934df-c121-4f46-96d9-6b616f4b66cf)
</details>

<details>
  <summary>
 Tasks
  </summary>

  Manage caldav tasks:

  - `ctrl-t`: new task
  - `ctrl-e`: edit task
  - `ctrl-k`: delete task
  - `ctrl-d`: set status done for task
  - `ctrl-r`: sync tasks with remote caldav
  - `ctrl-l`: choose the collection
  
  ```bash
    pip install todoman vdirsyncer
  ```
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

<details>
  <summary>
    Tools
  </summary>

  Set of tools not related with fzf, but useful even to drop the sway bar.

  - resource usage: top, htop, gotop ...
  - calendar: khal, calcurse ...
  - clock: tty-clock ...
  - wifi
  - bluetooth
  - fetch: fastfetch

![Image](https://github.com/user-attachments/assets/7cefe766-54c1-4f91-9833-946c6f4e139f)
![Image](https://github.com/user-attachments/assets/dfb1ef58-38e0-44c1-b85b-5a8d0d99f0d4)
![Image](https://github.com/user-attachments/assets/ad0813b3-0090-4541-9077-f228508c9923)
![Image](https://github.com/user-attachments/assets/ba17b777-5136-4172-b065-39a1fc8b7ed5)
</details>

<details>
  <summary>
    Terminal Management
  </summary>

  `dfzf-term` provides two terminal integrations for different work contexts: project-specific tasks in companion terminals and general tasks in a shared global terminal.

  **Companion Terminals** (project-specific work):
  - One terminal per window, attached to any application (IDE, browser, etc.)
  - Auto-detects working directory: JetBrains `[/path/to/project]`, Neovim `- NVIM` suffix, Terminal path patterns, defaults to home
  - Toggles between split vertical and stacked layouts (stacked allows fullscreen switching between windows)
  - `Ctrl + /` - Toggle layout | `Shift + Ctrl + /` - Kill the companion
  - Automatically moves away any non-companion windows that might be added inadvertently during toggle operations

  **Global Terminal** (general tasks):
  - Single floating scratchpad terminal shared across workspaces
  - 90% screen size, centered and floating
  - `dfzf-term scratchpad [terminal_command]` - Toggle visibility
  - Works across sway/i3, independent of companion terminals

  ![Image](https://github.com/user-attachments/assets/ca5c3a4d-eff2-490c-871e-ae413acfba08)
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
