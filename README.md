# dfzf — Instant Window Navigation for Sway and i3

**dfzf** redefines how you interact with windows in Sway and i3. Traditional tabs and workspaces rely on spatial memory. `dfzf-windows` brings a smarter model: name-based and time-based navigation — making window access constant time (O(1)), even with dozens of open apps.

No more mental gymnastics. Just type, fuzzy-match, and switch.

---
## 🚀 Why dfzf?

- ⏱️ **O(1) complexity** — instantly access any window, regardless of how many are open.
- 🔍 **Fuzzy search + recency sorting** — type part of a window’s title and see the most *recently used* matches first.
- 🧠 **Low cognitive load** — no need to remember where things are, only *what* and *when* you used them.

---

## 🧰 What's Included?

`dfzf` is more than a window switcher — it's a full toolkit for your desktop, built with speed, consistency, and minimalism in mind:

| Tool             | Description                                  | i3 | Sway |
|------------------|----------------------------------------------|:--:|:----:|
| `dfzf-windows`   | Navigate windows by title or time            | ✅ | ✅   |
| `dfzf-launcher`  | Launch desktop apps instantly                | ✅ | ✅   |
| `dfzf-clipboard` | Searchable clipboard with image/text preview | ❌ | ✅   |
| `dfzf-notify`    | Browse past notifications                    | ❌ | ✅   |
| `dfzf-mail`      | View and preview emails from the terminal    | ✅ |  ✅   |
| `dfzf-password`  | Copy and preview entries from pass           | ❌ | ✅   |
| `dfzf-exit`      | Logout, reboot, suspend, hibernate           | ❌ | ✅   |

---

## 📦 Installation

### Requirements

<details>
<summary>Click to expand</summary>

- `sway` or `i3`
- [`fzf`](https://github.com/junegunn/fzf)
- `jq` ≥ 1.7
- `gawk` (for `dfzf-launcher`)
- Terminal: `kitty` ≥ 0.41.1 **or** `alacritty` **or** `foot`
- `fd-find` (for `dfzf-password`)
- `himalaya` (for `dfzf-mail`)
- `batcat` (for preview in `dfzf-clipboard`)
- `mako` (for `dfzf-notify`)
- `wl-clipboard` & `cliphist` (for clipboard history)
- `rust` (to compile `dfzf-daemon` and `dfzf-mark`)

Ensure `fzf` is accessible from your window manager:
```bash
# ~/.config/sway/config (example)
set $PATH /usr/local/bin:/opt/bin:$PATH
````

</details>

### Option 1: Download Binaries

<details>
<summary>From Releases</summary>

* Download the latest binaries from the [Releases page](https://github.com/parisni/dfzf/releases)
* Copy them to `/usr/local/bin` or any directory in your `$PATH`.

> 📦 `.deb` package: coming soon.

</details>

### Option 2: Build from Source

<details>
<summary>Build dfzf-daemon & dfzf-mark</summary>

```bash
cd dfzf-utils
curl https://sh.rustup.rs -sSf | sh
rustup update nightly
cargo +nightly build --release
sudo cp target/release/dfzf-{daemon,mark} /usr/local/bin/
```

</details>

---

## ⚙️ Configuration

### Sway

<details>
<summary>Click to expand</summary>

```bash
exec --no-startup-id dfzf-daemon
exec wl-paste --watch cliphist -max-items 5000 store
exec mako

set $term kitty -1
set $dfzf_term kitty -1 --class=dfzf-popup -e

bindsym $mod+Tab exec $dfzf_term dfzf-windows
bindsym $mod+o   exec $dfzf_term dfzf-launcher
bindsym $mod+h   exec $dfzf_term dfzf-notifs
bindsym $mod+i   exec $dfzf_term dfzf-clipboard
bindsym $mod+m   exec $dfzf_term dfzf-mail
bindsym $mod+p   exec $dfzf_term dfzf-password
bindsym $mod+F1  exec $dfzf_term dfzf-exit

for_window [app_id="^dfzf-popup$"] floating enable, sticky enable, resize set 60 ppt 70 ppt, border pixel 6

# Optional: hide tabs entirely
font pango:monospace 0.001
default_border none
default_floating_border none
titlebar_padding 1
titlebar_border_thickness 0
```

</details>

### i3

<details>
<summary>Click to expand</summary>

Same as Sway, with minor differences in window matching and optional bar config.

```bash
exec --no-startup-id dfzf-daemon

set $term kitty -1
set $dfzf_term kitty -1 --class=dfzf-popup -e

bindsym $mod+Tab exec $dfzf_term dfzf-windows
bindsym $mod+o   exec $dfzf_term dfzf-launcher
...

for_window [class="^dfzf-popup$"] floating enable, sticky enable, resize set 60 ppt 70 ppt, border pixel 6

# Optional: hide tabs
font pango:monospace 0
default_border none
default_floating_border none

# Optional: if you use i3status
bar {
  font pango:monospace 10
  status_command i3status
}
```

</details>

---

## 🧩 Optional Enhancements

### User Configuration

<details>
<summary>Customize dfzf (e.g. exit menu, glyphs, window title matching)</summary>

Edit: `~/.config/dfzf/dfzf.conf`

```bash
exit_cmd_s='swaylock && systemctl suspend'
windows_title_rm_pattern=' —[^—]*?— Mozilla Firefox'
windows_glyph_rules_json='[ ... ]'
```

</details>

### Kitty Support

<details>
<summary>Enable previews and make terminal window IDs unique</summary>

* `~/.config/kitty/kitty.conf`:

```bash
allow_remote_control yes
shell_integration no-title
listen_on unix:/tmp/kitty
```

* `~/.oh-my-zsh/lib/termsupport.zsh`:

```bash
print -Pn "\e]2;${2:q} /$(< /dev/urandom tr -dc A-Za-z0-9 | head -c 2)\a"
```

</details>

---

## ✨ Features

### Windows

<details>
<summary>dfzf-windows</summary>

- Fuzzy search across all open windows
- **Sorted by last access time** — recent windows appear first
- `Enter`: focus window
- `Ctrl-J`: terminal preview (kitty only)
- `Ctrl-K`: kill window
- `Ctrl-U`: toggle urgent
- `Ctrl-I`: toggle important
- `Esc`: return to the current window
</details>

### Clipboard (Sway only)

<details>
<summary>dfzf-clipboard</summary>

* Preview text with `batcat`
* Preview images with `kitten`

</details>

### Mail

<details>
<summary>dfzf-mail</summary>

* Preview text or HTML emails
* Open HTML in browser

</details>

### Password Store

<details>
<summary>dfzf-password</summary>

* `Enter`: copy content
* `Ctrl-J`: preview secret

</details>

### Notifications (Sway only)

<details>
<summary>dfzf-notify</summary>

* Navigate recent notifications
* `Ctrl-K`: dismiss
* `Enter`: trigger action

</details>

### Application Launcher

<details>
<summary>dfzf-launcher</summary>

* Fuzzy search installed desktop apps

</details>

### Exit Menu

<details>
<summary>dfzf-exit</summary>

* Hibernate, reboot, shutdown, logout

</details>

---

## 🔗 Related Projects

* [i3-back (dfzf-daemon)](https://github.com/Cretezy/i3-back)
* [sway-launcher-desktop (dfzf-launcher)](https://github.com/Biont/sway-launcher-desktop)
* [wofi-scripts (inspired dfzf-windows)](https://github.com/tobiaspc/wofi-scripts)
* [swayr](https://sr.ht/~tsdh/swayr/)
* [i3-tools](https://github.com/dinAlt/i3-tools)

---

## 📝 License

This project is licensed under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html).

