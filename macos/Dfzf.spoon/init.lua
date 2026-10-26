-- Hammerspoon backend for dfzf on macOS, served by the native hs._dfzf module
-- on a Unix socket, else by this file through `hs -c` (see macos/bin/dfzf-hs).

local obj = {}
obj.__index = obj

obj.name = "Dfzf"
obj.version = "0.1"
obj.author = "Nicolas Paris <contact@parisni.com>"
obj.homepage = "https://github.com/parisni/dfzf"
obj.license = "GPL-3.0 - https://www.gnu.org/licenses/gpl-3.0.html"

-- macOS has no per-window app_id/class: dfzf helper windows are tagged by a
-- fixed title (kitty --title) and reported to dfzf with that title as app_id.
obj.identityTitles = {
  ["dfzf-popup"] = true,
  ["dfzf-term"] = true,
  ["dfzf-hidden"] = true,
  ["dfzf-git"] = true,
  ["dfzf-scratchpad"] = true,
  ["dfzf-switcher"] = true,
}
obj.popupTitles = { ["dfzf-popup"] = true }
-- Scratchpad-like windows sized by their own scripts (dfzf-resize): never maximized.
obj.floatingTitles = { ["dfzf-git"] = true, ["dfzf-scratchpad"] = true }
-- Centered like popups, but neither closed by a newer popup nor focused when
-- created: the windows switcher, hidden between uses.
obj.centeredTitles = { ["dfzf-switcher"] = true }
obj.popupRatio = 0.65
obj.maximize = true
-- nil: $DFZF_HS_SOCKET, else ~/.local/state/dfzf/hs.sock (same default as dfzf-hs).
obj.socketPath = nil
-- Hammerspoon inherits launchd's minimal PATH: prepend where dfzf, kitty and
-- their dependencies usually live.
obj.path = "/opt/homebrew/bin:/usr/local/bin:" .. os.getenv("HOME") .. "/.local/bin"
-- Homebrew's `kitty` is a bash script re-executing the app binary: call the
-- binary itself when present, one process less on every popup.
local KITTY_APP = "/Applications/kitty.app/Contents/MacOS/kitty"
local kittyApp = io.open(KITTY_APP, "r")
local kitty = kittyApp and KITTY_APP or "kitty"
if kittyApp then
  kittyApp:close()
end
-- A string runs as a shell command; a table is a focus toggle (see
-- Dfzf:focusToggle), which the native backend serves without any process.
obj.commands = {
  windows = kitty .. " -1 --title dfzf-popup -e dfzf-windows",
  hub = kitty .. " -1 --title dfzf-popup -e dfzf-hub",
  term = { toggle = "term", criteria = '[app_id="^dfzf-term$"]', fallback = kitty .. " -1 --title dfzf-term" },
  git = "dfzf-git",
}
-- Native backend only: the `windows` hotkey shows a dfzf-windows kept alive in
-- its own hidden kitty instance (`--instance-group`: hiding it leaves the other
-- kitty windows alone) instead of opening a popup: no window nor process to
-- start, only the list to reload.
obj.switcher = false
obj.switcherCommand = kitty .. " -1 --instance-group dfzf-switcher -o macos_quit_when_last_window_closed=yes"
  .. " --title dfzf-switcher -e dfzf-windows --persistent"
local SWITCHER_TITLE = "dfzf-switcher"
-- The reload rebinds `load` so the list opens on the previous window, as the
-- popup's start:up did.
local SWITCHER_SHOW = "change-query()+rebind(load)+reload(dfzf-windows-load)"
local SWITCHER_START_SECONDS = 10

local PREVIEW_MARK = "_dfzf-preview"

local spoonDir = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local SORT_PREFIX = "_dfzf-sort"
-- Focus events are delivered asynchronously and can land after a preview has
-- already cleared its mark: ignore them for this long after the clear.
local PREVIEW_GRACE_SECONDS = 0.5
-- Closing a popup lets its app (kitty, which also hosts dfzf-term) activate
-- itself again: for this long, its windows cannot take the focus back from
-- the window the popup handed it to.
local HANDOFF_SECONDS = 1.0

local function now()
  return hs.timer.secondsSinceEpoch()
end

local function startsWith(text, prefix)
  return text:sub(1, #prefix) == prefix
end

local function contains(list, value)
  for _, item in ipairs(list) do
    if item == value then
      return true
    end
  end
  return false
end

function obj:_entry(id)
  local entry = self._state[id]
  if not entry then
    entry = { marks = {}, urgent = false }
    self._state[id] = entry
  end
  return entry
end

local function removeMarks(entry, predicate)
  local kept = {}
  for _, mark in ipairs(entry.marks) do
    if not predicate(mark) then
      table.insert(kept, mark)
    end
  end
  entry.marks = kept
end

-- Same semantics as sway: a mark lives on at most one window, so setting it
-- moves it; without `add`, it replaces the window's marks.
function obj:_setMark(id, mark, add)
  for _, entry in pairs(self._state) do
    removeMarks(entry, function(m) return m == mark end)
  end
  local entry = self:_entry(id)
  if add then
    table.insert(entry.marks, mark)
  else
    entry.marks = { mark }
  end
end

function obj:_touch(id, timestampMs)
  local entry = self:_entry(id)
  removeMarks(entry, function(m) return startsWith(m, SORT_PREFIX) end)
  table.insert(entry.marks, string.format("%s-%d", SORT_PREFIX, timestampMs))
end

function obj:_appId(win)
  local title = win:title() or ""
  if self.identityTitles[title] then
    return title
  end
  local app = win:application()
  return app and app:name():lower() or ""
end

-- Look in the window filter first: it tracks every Space, while plain
-- hs.window lookups may only see the current one.
function obj:_window(id)
  for _, candidate in ipairs(self._filter:getWindows()) do
    if candidate:id() == id then
      return candidate
    end
  end
  local win = hs.window.get(id)
  if not win then
    error("dfzf: no window with id " .. tostring(id))
  end
  return win
end

-- Mirrors sway: visible windows live in workspace "1", minimized ones play
-- the scratchpad ("__i3_scratch"), which dfzf scripts detect by name.
function obj:_tree()
  local focused = hs.window.focusedWindow()
  local focusedId = focused and focused:id()
  local visible, hidden, alive = {}, {}, {}
  for _, win in ipairs(self._filter:getWindows()) do
    local id = win:id()
    if id then
      alive[id] = true
      if win:isStandard() then
        local entry = self._state[id] or { marks = {}, urgent = false }
        local app = win:application()
        table.insert(win:isMinimized() and hidden or visible, {
          id = id,
          type = "con",
          name = win:title() or "",
          app_id = self:_appId(win),
          pid = app and app:pid() or nil,
          marks = entry.marks,
          urgent = entry.urgent,
          focused = id == focusedId,
          layout = "none",
          nodes = {},
          floating_nodes = {},
        })
      end
    end
  end
  -- windowDestroyed may hand over a window whose id is no longer readable:
  -- prune state of vanished windows here instead.
  for id in pairs(self._state) do
    if not alive[id] then
      self._state[id] = nil
    end
  end
  local function workspace(id, name, nodes)
    return {
      id = id,
      type = "workspace",
      name = name,
      layout = "tabbed",
      focused = false,
      marks = {},
      nodes = nodes,
      floating_nodes = {},
    }
  end
  -- Negative ids cannot collide with macOS window ids.
  return hs.json.encode({
    id = 0,
    type = "root",
    name = "root",
    layout = "tabbed",
    focused = false,
    marks = {},
    nodes = { workspace(-1, "1", visible), workspace(-2, "__i3_scratch", hidden) },
    floating_nodes = {},
  })
end

function obj:_onFocused(win)
  local id = win and win:id()
  if not id then
    return
  end
  self:_guardHandoff(win, id)
  local entry = self:_entry(id)
  -- A preview only peeks at a window: it must not reorder the recency list.
  if contains(entry.marks, PREVIEW_MARK) or (self._previewGraceUntil[id] or 0) > now() then
    return
  end
  self:_touch(id, math.floor(now() * 1000))
end

local function pidOf(win)
  local app = win:application()
  return app and app:pid()
end

-- A focus request from a popup: remember where it sent the focus, for when it closes.
function obj:_noteFocusRequest(id)
  self._handoff = nil
  local target = hs.window.get(id)
  if not target or self.popupTitles[target:title() or ""] then
    return
  end
  local popup
  for _, win in ipairs(self._filter:getWindows()) do
    local winId = win:id()
    if winId and self.popupTitles[win:title() or ""] and (not popup or winId > popup:id()) then
      popup = win
    end
  end
  if popup then
    self._handoff = { popupId = popup:id(), pid = pidOf(popup), target = target }
  end
end

-- The destroyed window may no longer tell its id: then trust the popup being gone.
function obj:_onDestroyed(win)
  local handoff = self._handoff
  if not handoff or handoff.untilTime then
    self:_restoreFromPopup(win)
    return
  end
  local id = win and win:id()
  if id ~= handoff.popupId and (id or hs.window.get(handoff.popupId)) then
    return
  end
  self._popup = nil
  handoff.untilTime = now() + HANDOFF_SECONDS
  local focused = hs.window.focusedWindow()
  if not focused or focused:id() ~= handoff.target:id() then
    handoff.target:focus()
  end
end

function obj:_recency(id)
  local recency = 0
  for _, mark in ipairs((self._state[id] or { marks = {} }).marks) do
    if startsWith(mark, SORT_PREFIX .. "-") then
      recency = math.max(recency, tonumber(mark:sub(#SORT_PREFIX + 2)) or 0)
    end
  end
  return recency
end

-- A popup closed without focusing anything (esc): hand the focus back to the
-- window used before it, unless it is already elsewhere (a clicked
-- notification's app). A newer popup replaces `_popup`, so closing an older
-- one never takes the focus from it.
function obj:_restoreFromPopup(win)
  local popup = self._popup
  if not popup then
    return
  end
  local id = win and win:id()
  if id ~= popup.id and (id or hs.window.get(popup.id)) then
    return
  end
  self._popup = nil
  local focused = hs.window.focusedWindow()
  if focused and focused:id() ~= popup.id and pidOf(focused) ~= popup.pid then
    return
  end
  local previous, previousRecency = nil, 0
  for _, other in ipairs(self._filter:getWindows()) do
    local otherId = other:id()
    if otherId and otherId ~= popup.id and other:isStandard() and not other:isMinimized()
      and not self.popupTitles[other:title() or ""] then
      local recency = self:_recency(otherId)
      if recency > previousRecency then
        previous, previousRecency = other, recency
      end
    end
  end
  if not previous then
    return
  end
  self._handoff = { popupId = popup.id, pid = popup.pid, target = previous, untilTime = now() + HANDOFF_SECONDS }
  if not focused or focused:id() ~= previous:id() then
    previous:focus()
  end
end

function obj:_guardHandoff(win, id)
  local handoff = self._handoff
  if not handoff or not handoff.untilTime or id == handoff.target:id() then
    return
  end
  if now() > handoff.untilTime then
    self._handoff = nil
  elseif pidOf(win) == handoff.pid then
    handoff.target:focus()
  end
end

function obj:_place(win)
  if not win:isStandard() then
    return
  end
  if self.popupTitles[win:title() or ""] then
    local screen = win:screen() or hs.screen.mainScreen()
    local frame = screen:frame()
    local ratio = self.popupRatio
    win:setFrame({
      x = frame.x + frame.w * (1 - ratio) / 2,
      y = frame.y + frame.h * (1 - ratio) / 2,
      w = frame.w * ratio,
      h = frame.h * ratio,
    }, 0)
    win:focus()
    local id = win:id()
    if id and (not self._popup or id >= self._popup.id) then
      self._popup = { id = id, pid = pidOf(win) }
    end
    self:_closePopupsOlderThan(win:id())
  elseif self.maximize then
    if not self.floatingTitles[win:title() or ""] then
      win:maximize(0)
    end
  end
end

-- One dfzf popup at a time, the newest wins: macOS window ids only grow, so this
-- needs no focus (unlike sway's dfzf-kill-bro) and a replayed event on an older
-- popup never closes a newer one.
function obj:_closePopupsOlderThan(id)
  if not id then
    return
  end
  local older = {}
  for _, other in ipairs(self._filter:getWindows()) do
    local otherId = other:id()
    if otherId and otherId < id and self.popupTitles[other:title() or ""] then
      table.insert(older, other)
    end
  end
  for _, other in ipairs(older) do
    other:close()
  end
end

local handlers = {}

function handlers.tree(self)
  return self:_tree()
end

function handlers.focus(self, req)
  local win = self:_window(req.id)
  if win:isMinimized() then
    win:unminimize()
  end
  win:focus()
  self:_noteFocusRequest(req.id)
end

function handlers.close(self, req)
  for _, id in ipairs(req.ids) do
    local ok, win = pcall(self._window, self, id)
    if ok then
      win:close()
    end
  end
end

function handlers.hide(self, req)
  for _, id in ipairs(req.ids) do
    self:_window(id):minimize()
  end
end

function handlers.show(self, req)
  handlers.focus(self, req)
end

function handlers.outputs()
  local focused = hs.window.focusedWindow()
  local screen = focused and focused:screen() or hs.screen.mainScreen()
  local frame = screen:frame()
  return hs.json.encode({ {
    name = screen:name() or "screen",
    focused = true,
    rect = { x = frame.x, y = frame.y, width = frame.w, height = frame.h },
  } })
end

function handlers.resize(self, req)
  local win = self:_window(req.id)
  local frame = win:frame()
  frame.w, frame.h = req.w, req.h
  win:setFrame(frame, 0)
end

-- sway positions are relative to the output: offset by the screen origin.
function handlers.move(self, req)
  local win = self:_window(req.id)
  local screen = win:screen() or hs.screen.mainScreen()
  local origin = screen:frame()
  local frame = win:frame()
  frame.x, frame.y = origin.x + req.x, origin.y + req.y
  win:setFrame(frame, 0)
end

-- macOS exposes no window urgency to read: urgency is a dfzf-only flag here.
function handlers.urgent(self, req)
  for _, id in ipairs(req.ids) do
    local entry = self:_entry(id)
    if req.mode == "toggle" then
      entry.urgent = not entry.urgent
    else
      entry.urgent = req.mode == "enable"
    end
  end
end

function handlers.mark(self, req)
  self:_setMark(req.id, req.mark, req.add)
end

function handlers.unmark(self, req)
  for id, entry in pairs(self._state) do
    if req.ids == nil or contains(req.ids, id) then
      removeMarks(entry, function(m) return req.mark == "" or m == req.mark end)
    end
  end
end

function handlers.markToggle(self, req)
  local entry = self:_entry(req.id)
  local present = false
  for _, mark in ipairs(entry.marks) do
    if startsWith(mark, req.prefix) then
      present = true
    end
  end
  if present then
    removeMarks(entry, function(m) return startsWith(m, req.prefix) end)
    if req.prefix == PREVIEW_MARK then
      self._previewGraceUntil[req.id] = now() + PREVIEW_GRACE_SECONDS
    end
  else
    local mark = req.prefix
    if req.appendTs then
      mark = string.format("%s-%d", mark, os.time())
    end
    self:_setMark(req.id, mark, true)
  end
end

-- Entry point of `dfzf-hs`: runs one JSON request and returns its reply.
function obj:ipc(request)
  if self._native then
    error("dfzf: the native backend is active, requests go through its socket")
  end
  local req = hs.json.decode(request)
  local handler = req and handlers[req.op]
  if not handler then
    error("dfzf: unknown request " .. request)
  end
  return handler(self, req) or ""
end

-- extraEnv: variables for the command only, kept off its command line (and ps).
function obj:_run(command, extraEnv)
  -- Detached: the kitty instance a command may start must outlive a reload or
  -- quit of Hammerspoon, and must not hold the task's pipes (hs.task would block).
  -- /bin/bash, not /bin/sh: macOS's sh re-executes bash, one process more.
  local task = hs.task.new("/bin/bash", nil, { "-c", "(" .. command .. "\n) </dev/null >/dev/null 2>&1 &" })
  local env = task:environment()
  env.PATH = self.path .. ":" .. (env.PATH or "/usr/bin:/bin")
  env.NO_COLOR = nil
  env.TERM = nil
  for name, value in pairs(extraEnv or {}) do
    env[name] = value
  end
  task:setEnvironment(env)
  task:start()
end

local function shellQuote(text)
  return "'" .. text:gsub("'", [['\'']]) .. "'"
end

-- dfzf-focus-toggle <key> <criteria> [fallback]: jumps to the windows matching
-- the sway-like criteria, and back on the next call. The native backend decides
-- in one in-process request; the fallback (a shell command creating the target)
-- only starts when no window matches. The Lua backend runs the script itself.
function obj:focusToggle(key, criteria, fallback)
  if not self._native then
    self:_run("dfzf-focus-toggle " .. shellQuote(key) .. " " .. shellQuote(criteria)
      .. (fallback and " " .. fallback or ""))
    return
  end
  local request = hs.json.encode({ op = "focusToggle", key = key, criteria = criteria, fallback = fallback ~= nil })
  local sent, err = self._native.request(request, function(ok, reply)
    if not ok then
      print("Dfzf: focusToggle " .. key .. ": " .. tostring(reply))
    elseif reply == "missing" and fallback then
      self:_run(fallback)
    end
  end)
  if not sent then
    print("Dfzf: focusToggle " .. key .. ": " .. tostring(err))
  end
end

function obj:_command(name)
  if name == "windows" and self.switcher and self._native then
    self:showSwitcher()
    return
  end
  local command = self.commands[name]
  if type(command) == "table" then
    self:focusToggle(command.toggle, command.criteria, command.fallback)
  else
    self:_run(command)
  end
end

local function readFile(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("a")
  file:close()
  return (content:gsub("%s+$", ""))
end

-- The key and port files sit next to the dfzf socket, in a private directory.
function obj:_switcherFiles()
  local socket = self.socketPath or os.getenv("DFZF_HS_SOCKET") or (os.getenv("HOME") .. "/.local/state/dfzf/hs.sock")
  local dir = socket:match("^(.*)/[^/]*$") or "."
  return dir .. "/switcher.key", dir .. "/switcher.port"
end

-- fzf's FZF_API_KEY: kept across reloads, as the switcher outlives them.
function obj:_switcherKey()
  local keyFile = self:_switcherFiles()
  local key = readFile(keyFile)
  if not key or key == "" then
    key = hs.host.uuid():gsub("-", "") .. hs.host.uuid():gsub("-", "")
    local file = assert(io.open(keyFile, "w"))
    file:write(key)
    file:close()
  end
  return key
end

-- Calls back with the switcher's {port, key} when its fzf answers, else nil.
function obj:_switcherProbe(callback)
  local _, portFile = self:_switcherFiles()
  local port = readFile(portFile)
  if not port or not port:match("^%d+$") then
    callback(nil)
    return
  end
  local key = self:_switcherKey()
  hs.http.asyncGet("http://localhost:" .. port .. "?limit=1", { ["x-api-key"] = key }, function(status)
    callback(status == 200 and { port = port, key = key } or nil)
  end)
end

-- Newest switcher window of the tree: a stale one may linger while it closes.
function obj:_switcherWindow(callback)
  self._native.request('{"op":"tree"}', function(ok, reply)
    local found
    local function walk(node)
      if node.type == "con" and node.name == SWITCHER_TITLE and (not found or node.id > found) then
        found = node.id
      end
      for _, child in ipairs(node.nodes or {}) do
        walk(child)
      end
    end
    if ok then
      walk(hs.json.decode(reply) or {})
    end
    callback(found)
  end)
end

function obj:_switcherAttach(switcher, attempts)
  self:_switcherWindow(function(id)
    if not id and attempts > 0 then
      hs.timer.doAfter(0.1, function() self:_switcherAttach(switcher, attempts - 1) end)
      return
    end
    self._switcherStarting = false
    if not id then
      print("Dfzf: the windows switcher has no window")
      return
    end
    switcher.id = id
    self._switcher = switcher
    if self._switcherShowWhenReady then
      self._switcherShowWhenReady = false
      self:showSwitcher()
    end
  end)
end

-- Attaches to a running switcher (it survives Hammerspoon reloads), else starts
-- one; `show` shows it once ready. Falls back to the popup if it never answers.
function obj:_switcherStart(show)
  self._switcherShowWhenReady = self._switcherShowWhenReady or show
  if self._switcherStarting then
    return
  end
  self._switcherStarting = true
  self:_switcherProbe(function(running)
    if running then
      self:_switcherAttach(running, 10)
      return
    end
    local _, portFile = self:_switcherFiles()
    os.remove(portFile)
    self:_run(self.switcherCommand, { FZF_API_KEY = self:_switcherKey(), DFZF_SWITCHER_PORT_FILE = portFile })
    local deadline = now() + SWITCHER_START_SECONDS
    local probing = false
    local poll
    poll = hs.timer.doEvery(0.05, function()
      if probing then
        return
      end
      probing = true
      self:_switcherProbe(function(started)
        probing = false
        if started then
          poll:stop()
          self:_switcherAttach(started, 10)
        elseif now() > deadline then
          poll:stop()
          self._switcherStarting = false
          print("Dfzf: the windows switcher did not start, using the popup")
          if self._switcherShowWhenReady then
            self._switcherShowWhenReady = false
            self:_run(self.commands.windows)
          end
        end
      end)
    end)
  end)
end

-- The `windows` hotkey with Dfzf.switcher: reloads the hidden list and brings
-- its window back, both in-process; a dead switcher is started again.
function obj:showSwitcher()
  local switcher = self._switcher
  if not switcher then
    self:_switcherStart(true)
    return
  end
  local function lost()
    if self._switcher == switcher then
      self._switcher = nil
      self:_switcherStart(true)
    end
  end
  hs.http.asyncPost("http://localhost:" .. switcher.port, SWITCHER_SHOW, { ["x-api-key"] = switcher.key },
    function(status)
      if status ~= 200 then
        lost()
      end
    end)
  self._native.request(hs.json.encode({ op = "focus", id = switcher.id }), function(ok)
    if not ok then
      lost()
    end
  end)
end

-- Binds hotkeys to the entries of `Dfzf.commands` (windows, hub, term, git).
function obj:bindHotkeys(mapping)
  local spec = {}
  for name in pairs(self.commands) do
    spec[name] = function()
      self:_command(name)
    end
  end
  hs.spoons.bindHotkeysToSpec(spec, mapping)
  return self
end

-- Returns the started native module, or nil and the reason it is unavailable.
function obj:_startNative()
  if not package.cpath:find(spoonDir, 1, true) then
    package.cpath = spoonDir .. "?.so;" .. package.cpath
  end
  local loaded, native = pcall(require, "hs._dfzf")
  if not loaded then
    return nil, native
  end
  local started, err = native.start({
    socketPath = self.socketPath,
    identityTitles = self.identityTitles,
    popupTitles = self.popupTitles,
    floatingTitles = self.floatingTitles,
    centeredTitles = self.centeredTitles,
    popupRatio = self.popupRatio,
    maximize = self.maximize,
  })
  if not started then
    return nil, err
  end
  return native
end

function obj:start()
  -- `dfzf-hs` falls back to the `hs` CLI, which needs hs.ipc loaded.
  require("hs.ipc")
  local native, reason = self:_startNative()
  if native then
    self._native = native
    if self.switcher then
      self:_switcherStart(false)
    end
    return self
  end
  print("Dfzf: native backend unavailable (" .. tostring(reason) .. "), using the Lua backend")
  self._state = {}
  self._previewGraceUntil = {}
  self._filter = hs.window.filter.new(true):setCurrentSpace(nil)

  -- Seed recency from the current z-order (front to back) so the very first
  -- switch already offers the previous window.
  local seed = math.floor(now() * 1000)
  for index, win in ipairs(hs.window.orderedWindows()) do
    local id = win:id()
    if id then
      self:_touch(id, seed - index)
    end
  end

  local wf = hs.window.filter
  self._filter:subscribe(wf.windowFocused, function(win) self:_onFocused(win) end)
  self._filter:subscribe(wf.windowDestroyed, function(win) self:_onDestroyed(win) end)
  self._filter:subscribe(wf.windowCreated, function(win) self:_place(win) end)
  self._filter:subscribe(wf.windowTitleChanged, function(win)
    if self.popupTitles[win:title() or ""] then
      self:_place(win)
    end
  end)
  return self
end

function obj:stop()
  if self._native then
    self._native.stop()
    self._native = nil
  end
  if self._filter then
    self._filter:unsubscribeAll()
    self._filter = nil
  end
  return self
end

return obj
