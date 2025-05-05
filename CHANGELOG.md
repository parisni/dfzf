<a name="unreleased"></a>
## [Unreleased]

### Maintenance
- improve changelog fmt
- bump2version


<a name="v1.0.1"></a>
## [v1.0.1] - 2025-05-05
### Bug Fixes
- **password:** copy pass to configured clipboard

### Documentation
- build rust
- more is less
- polish readme
- introduction

### Licensing
- gplv3
- drop mit


<a name="v1.0.0"></a>
## v1.0.0 - 2025-05-03
### Bug Fixes
- support xwayland when windows list w/ null app_id
- better extract window id
- i3 missing app_id
- exit to not stop the term otw swaylock daemon stuck
- vim glyph
- handle case when the window in created no focused
- rename marks
- jump on first item after any query change
- binary names, typos
- broken link
- better support for i3
- term kitty preview exact match window title
- improve windows terminal preview
- add border to preview
- cycle logic between windows
- clipboard cat
- lpad w/ space to align titles
- window title lpad
- **window:** i3 to focus on popup while preview
- **windows:** use blue of sway

### CI/CD
- introduce gha

### Documentation
- debian install
- fix term
- collapse all
- user config
- install/config/features
- kitty config
- collapse configuration for i3/sway
- add depts
- add windows tips/features
- exit, mail and password bindings
- kitty terminal content preview hack
- add notif and clipboard daemon
- add features
- add related work
- multi terminal support
- allow to use any terminal
- move forward

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

### Maintenance
- improve windows code
- improve daemon code
- rename rust tool and allow multiple binaries
- clean code
- add makefile to build release archive
- move to bin
- rename to dfzf-launcher
- rename from i3-back to dfzf-daemon
- rm useless _back mark


[Unreleased]: https://github.com/parisni/dfzf/compare/v1.0.1...HEAD
[v1.0.1]: https://github.com/parisni/dfzf/compare/v1.0.0...v1.0.1
