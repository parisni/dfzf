<a name="unreleased"></a>
## [Unreleased]

### Features
- **scrollbacks:** fzf all terminal content + focus window/scroll to it


<a name="v0.5.0"></a>
## [v0.5.0] - 2025-05-22
### Bug Fixes
- **tasks:** avoid empty collection

### Features
- **clipboard:** add support for both batcat and bat ([#1](https://github.com/parisni/dfzf/issues/1))
- **tasks:** let choose the task collection
- **tools:** add clock, top and calendar popup

### Maintenance
- **all:** force uniform FZF_DEFAULT_OPTS


<a name="v0.4.0"></a>
## [v0.4.0] - 2025-05-19
### Documentation
- **all:** improve
- **tasks:** init tasks commands

### Features
- **tasks:** add color to priority
- **tasks:** dfzf-tasks to manage tasks with todoman
- **windows:** colorize only glyph and class


<a name="v0.3.1"></a>
## [v0.3.1] - 2025-05-15
### Bug Fixes
- **windows:** kitty terminal preview regression due to color
- **windows:** mark urgent regression


<a name="v0.3.0"></a>
## [v0.3.0] - 2025-05-15
### Bug Fixes
- **all:** silent killing other popups output
- **windows:** k to not kill the windows

### Documentation
- **windows:** add color to windows, and filter based on color
- **windows:** disable floating windows in sway/i3 config

### Features
- **windows:** group and filter windows by color: red, blue, green, orange
- **windows:** also list floating windows


<a name="v0.2.3"></a>
## [v0.2.3] - 2025-05-14
### Bug Fixes
- **windows:** regression on windows-load


<a name="v0.2.2"></a>
## [v0.2.2] - 2025-05-14
### Bug Fixes
- **all:** make fzf bind call execution silent
- **windows:** make first invocation call tree once


<a name="v0.2.1"></a>
## [v0.2.1] - 2025-05-13
### Bug Fixes
- **all:** unset FZF_DEFAULT_OPTS not to break dfzf
- **all:** keep one dfzf-popup open more efficiently


<a name="v0.2.0"></a>
## [v0.2.0] - 2025-05-12
### Bug Fixes
- **windows:** drop arbitrary sleep time in favor of sync calls

### Features
- **notifs:** toggle history
- **windows:** reload windows


<a name="v0.1.0"></a>
## v0.1.0 - 2025-05-08
### Bug Fixes
- window title lpad
- exit to not stop the term otw swaylock daemon stuck
- binary names, typos
- term kitty preview exact match window title
- support xwayland when windows list w/ null app_id
- vim glyph
- handle case when the window in created no focused
- rename marks
- better support for i3
- i3 missing app_id
- broken link
- jump on first item after any query change
- better extract window id
- improve windows terminal preview
- add border to preview
- cycle logic between windows
- clipboard cat
- lpad w/ space to align titles
- **password:** copy pass to configured clipboard
- **window:** i3 to focus on popup while preview
- **windows:** use blue of sway

### CI/CD
- introduce gha

### Documentation
- add depts
- add windows tips/features
- debian install
- fix term
- allow to use any terminal
- multi terminal support
- add related work
- add features
- add notif and clipboard daemon
- kitty terminal content preview hack
- build rust
- more is less
- polish readme
- introduction
- add firefox extensions and instructions
- move forward
- exit, mail and password bindings
- user config
- install/config/features
- kitty config
- collapse configuration for i3/sway
- reword and reorg
- collapse all
- **clipboard:** screenshot
- **exit:** screenshot
- **launcher:** screenshot
- **notifs:** screenshot
- **password:** screenshot
- **windows:** screenshot
- **windows:** share chromium extensions
- **windows:** add gif

### Features
- add gimp / vim glyph
- allow windows configs
- provide exit menu
- add email preview
- adapt for i3
- support debian fd-find
- password-store support
- preview window title in case kitten fails and wrap
- track full windows visit history in marks
- support multiple important marks
- copy last sway-launcher-desktop release
- implem dfzf-mark
- only rm dfzf marks
- make daemon code use node object
- introduce config file + use bind for exit
- email export html preview
- make launcher style uniform w/ others
- add clipboard
- add dfzf-windows
- improve notifs separating preview/items
- add more glyph for applications
- ansi color for urgent windows
- add a urgent hint, allow to toggle urgent
- add glyph based on window class
- make launcher by default only consider desktop
- fzf exact match by default
- make sure unique dfzf popup is alive
- support chafa preview for foot/alacritty
- support both sway and i3
- init readme
- add dfzf-notifs
- **windows:** make the current entry selectable
- **windows:** current focus blue
- **windows:** make glyph configurable
- **windows:** c-i add important mark
- **windows:** make preview keep the sort order

### Licensing
- gplv3
- drop mit

### Maintenance
- improve changelog fmt
- bump2version
- improve windows code
- improve daemon code
- rename rust tool and allow multiple binaries
- clean code
- add makefile to build release archive
- move to bin
- rename to dfzf-launcher
- rename from i3-back to dfzf-daemon
- rm useless _back mark


[Unreleased]: https://github.com/parisni/dfzf/compare/v0.5.0...HEAD
[v0.5.0]: https://github.com/parisni/dfzf/compare/v0.4.0...v0.5.0
[v0.4.0]: https://github.com/parisni/dfzf/compare/v0.3.1...v0.4.0
[v0.3.1]: https://github.com/parisni/dfzf/compare/v0.3.0...v0.3.1
[v0.3.0]: https://github.com/parisni/dfzf/compare/v0.2.3...v0.3.0
[v0.2.3]: https://github.com/parisni/dfzf/compare/v0.2.2...v0.2.3
[v0.2.2]: https://github.com/parisni/dfzf/compare/v0.2.1...v0.2.2
[v0.2.1]: https://github.com/parisni/dfzf/compare/v0.2.0...v0.2.1
[v0.2.0]: https://github.com/parisni/dfzf/compare/v0.1.0...v0.2.0
