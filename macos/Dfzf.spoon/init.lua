-- Hammerspoon backend for dfzf on macOS: window list, focus, marks and recency,
-- served to the dfzf scripts through `hs -c` (see macos/bin/dfzf-hs-msg).

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
}
obj.popupTitles = { ["dfzf-popup"] = true }
obj.popupRatio = 0.65
obj.maximize = true
-- Hammerspoon inherits launchd's minimal PATH: prepend where dfzf, kitty and
-- their dependencies usually live.
obj.path = "/opt/homebrew/bin:/usr/local/bin:" .. os.getenv("HOME") .. "/.local/bin"
obj.commands = {
  windows = "kitty -1 --title dfzf-popup -e dfzf-windows",
  hub = "kitty -1 --title dfzf-popup -e dfzf-hub",
  term = [[dfzf-focus-toggle term '[app_id="^dfzf-term$"]' kitty -1 --title dfzf-term]],
}

local PREVIEW_MARK = "_dfzf-preview"
local SORT_PREFIX = "_dfzf-sort"
-- Focus events are delivered asynchronously and can land after a preview has
-- already cleared its mark: ignore them for this long after the clear.
local PREVIEW_GRACE_SECONDS = 0.5

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

function obj:_tree()
  local focused = hs.window.focusedWindow()
  local focusedId = focused and focused:id()
  local nodes, alive = {}, {}
  for _, win in ipairs(self._filter:getWindows()) do
    local id = win:id()
    if id then
      alive[id] = true
      if win:isStandard() then
        local entry = self._state[id] or { marks = {}, urgent = false }
        table.insert(nodes, {
          id = id,
          type = "con",
          name = win:title() or "",
          app_id = self:_appId(win),
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
  return hs.json.encode({
    id = 0,
    type = "root",
    name = "root",
    layout = "tabbed",
    focused = false,
    marks = {},
    nodes = nodes,
    floating_nodes = {},
  })
end

function obj:_onFocused(win)
  local id = win and win:id()
  if not id then
    return
  end
  local entry = self:_entry(id)
  -- A preview only peeks at a window: it must not reorder the recency list.
  if contains(entry.marks, PREVIEW_MARK) or (self._previewGraceUntil[id] or 0) > now() then
    return
  end
  self:_touch(id, math.floor(now() * 1000))
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
  elseif self.maximize then
    win:maximize(0)
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
end

function handlers.close(self, req)
  for _, id in ipairs(req.ids) do
    local ok, win = pcall(self._window, self, id)
    if ok then
      win:close()
    end
  end
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
  local req = hs.json.decode(request)
  local handler = req and handlers[req.op]
  if not handler then
    error("dfzf: unknown request " .. request)
  end
  return handler(self, req) or ""
end

function obj:_run(command)
  local task = hs.task.new("/bin/sh", nil, { "-c", command })
  local env = task:environment()
  env.PATH = self.path .. ":" .. (env.PATH or "/usr/bin:/bin")
  task:setEnvironment(env)
  task:start()
end

-- Binds hotkeys to the entries of `Dfzf.commands` (windows, hub, term).
function obj:bindHotkeys(mapping)
  local spec = {}
  for name in pairs(self.commands) do
    spec[name] = function()
      self:_run(self.commands[name])
    end
  end
  hs.spoons.bindHotkeysToSpec(spec, mapping)
  return self
end

function obj:start()
  -- dfzf talks to the spoon through the `hs` CLI, which needs hs.ipc loaded.
  require("hs.ipc")
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
  self._filter:subscribe(wf.windowCreated, function(win) self:_place(win) end)
  self._filter:subscribe(wf.windowTitleChanged, function(win)
    if self.popupTitles[win:title() or ""] then
      self:_place(win)
    end
  end)
  return self
end

function obj:stop()
  if self._filter then
    self._filter:unsubscribeAll()
    self._filter = nil
  end
  return self
end

return obj
