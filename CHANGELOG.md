<a name="unreleased"></a>
## [Unreleased]

### Doc
- more is less
- polish readme
- introduction

### License
- gplv3
- drop mit


<a name="v1.0.0"></a>
## v1.0.0 - 2025-05-03
### Chore
- improve windows code
- improve daemon code
- rename rust tool and allow multiple binaries
- clean code
- add makefile to build release archive
- move to bin
- rename to dfzf-launcher
- rename from i3-back to dfzf-daemon
- rm useless _back mark

### Ci
- introduce gha

### Doc
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

### Feat
- allow windows configs
- adapt for i3
- support debian fd-find
- password-store support
- preview window title in case kitten fails and wrap
- support multiple important marks
- implem dfzf-mark
- only rm dfzf marks
- make daemon code use node object
- introduce config file + use bind for exit
- email export html preview
- provide exit menu
- add email preview
- add gimp / vim glyph
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
- add dfzf-windows
- add clipboard
- make launcher style uniform w/ others
- copy last sway-launcher-desktop release
- track full windows visit history in marks

### Fix
- jump on first item after any query change
- exit to not stop the term otw swaylock daemon stuck
- vim glyph
- handle case when the window in created no focused
- rename marks
- better support for i3
- i3 missing app_id
- window title lpad
- support xwayland when windows list w/ null app_id
- term kitty preview exact match window title
- improve windows terminal preview
- add border to preview
- cycle logic between windows
- clipboard cat
- lpad w/ space to align titles
- better extract window id
- broken link
- binary names, typos


[Unreleased]: https://github.com/parisni/dfzf/compare/v1.0.0...HEAD
