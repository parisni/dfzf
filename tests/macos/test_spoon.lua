-- Dfzf.spoon against a mocked `hs` API: runs anywhere Lua 5.4 is available,
-- Hammerspoon itself only exists on macOS.
local clock = 1000.0
local requests = {}
local windows, focusedId = {}, nil
local callbacks = {}

local function encode(value)
  local kind = type(value)
  if kind == "table" then
    if next(value) == nil then
      return "{}" -- hs.json may encode an empty table as an object
    end
    if #value > 0 then
      local parts = {}
      for _, item in ipairs(value) do parts[#parts + 1] = encode(item) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local parts = {}
    for key, item in pairs(value) do parts[#parts + 1] = encode(tostring(key)) .. ":" .. encode(item) end
    return "{" .. table.concat(parts, ",") .. "}"
  elseif kind == "string" then
    return '"' .. value:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
  else
    return tostring(value)
  end
end

local function newWindow(id, title, app, standard)
  local w = { _id = id, _title = title, _app = app, _standard = standard ~= false, frames = {}, maximized = 0 }
  function w:id() return self._id end
  function w:title() return self._title end
  function w:application() return { name = function() return self._app end } end
  function w:isStandard() return self._standard end
  function w:isMinimized() return false end
  function w:unminimize() end
  function w:focus() focusedId = self._id end
  function w:close() for i, x in ipairs(windows) do if x == self then table.remove(windows, i) end end end
  function w:screen() return { frame = function() return { x = 0, y = 0, w = 1000, h = 800 } end } end
  function w:setFrame(rect) table.insert(self.frames, rect) end
  function w:maximize() self.maximized = self.maximized + 1 end
  table.insert(windows, w)
  return w
end

hs = {
  timer = { secondsSinceEpoch = function() return clock end },
  json = {
    encode = encode,
    decode = function(s) return requests[s] end,
  },
  window = {
    focusedWindow = function()
      for _, w in ipairs(windows) do if w._id == focusedId then return w end end
    end,
    get = function(id) for _, w in ipairs(windows) do if w._id == id then return w end end end,
    orderedWindows = function() return { windows[2], windows[1] } end,
    filter = {
      windowFocused = "focused", windowCreated = "created", windowTitleChanged = "title",
      new = function()
        local f = {}
        function f:setCurrentSpace() return self end
        function f:getWindows() return windows end
        function f:subscribe(event, fn) callbacks[event] = fn return self end
        function f:unsubscribeAll() end
        return f
      end,
    },
  },
  screen = { mainScreen = function() end },
  spoons = { bindHotkeysToSpec = function() end },
}
package.preload["hs.ipc"] = function() return {} end

local spoon = dofile(arg[1] or "../../macos/Dfzf.spoon/init.lua")
local function ipc(req)
  local key = "req" .. tostring(#requests + 1)
  requests[key] = req
  return spoon:ipc(key)
end
local function marks(id) return table.concat(((spoon._state[id] or {}).marks or {}), ",") end
local failures = 0
local function check(name, cond)
  print((cond and "ok   " or "FAIL ") .. name)
  if not cond then failures = failures + 1 end
end

newWindow(1, "Inbox - mail.google.com", "Firefox")
newWindow(2, "hx main.go", "kitty")
newWindow(3, "Sheet", "Firefox", false)
spoon:start()
check("seed: front window most recent", marks(2) == "_dfzf-sort-999999" and marks(1) == "_dfzf-sort-999998")

clock = 2000.0
callbacks.focused(windows[1])
check("focus event refreshes recency", marks(1) == "_dfzf-sort-2000000")

ipc({ op = "markToggle", id = 1, prefix = "_dfzf-red", appendTs = true })
check("markToggle adds timestamped mark", marks(1):match("_dfzf%-red%-%d+") ~= nil)
ipc({ op = "markToggle", id = 1, prefix = "_dfzf-red", appendTs = true })
check("markToggle removes it", marks(1) == "_dfzf-sort-2000000")

ipc({ op = "markToggle", id = 2, prefix = "_dfzf-preview", appendTs = false })
clock = 3000.0
callbacks.focused(windows[2])
check("preview mark freezes recency", marks(2) == "_dfzf-sort-999999,_dfzf-preview")
ipc({ op = "markToggle", id = 2, prefix = "_dfzf-preview", appendTs = false })
callbacks.focused(windows[2])
check("grace period after preview clear", marks(2) == "_dfzf-sort-999999")
clock = 3001.0
callbacks.focused(windows[2])
check("recency resumes after grace", marks(2) == "_dfzf-sort-3001000")

ipc({ op = "mark", id = 1, mark = "_dfzf-origin-term", add = true })
ipc({ op = "mark", id = 2, mark = "_dfzf-origin-term", add = true })
check("mark is unique (moved)", not marks(1):find("origin") and marks(2):find("origin") ~= nil)
ipc({ op = "unmark", mark = "_dfzf-origin-term", ids = { 2 } })
check("unmark by ids", not marks(2):find("origin"))
ipc({ op = "mark", id = 1, mark = "_x", add = false })
check("mark without add replaces", marks(1) == "_x")
ipc({ op = "unmark", mark = "" })
check("bare unmark clears all", marks(1) == "" and marks(2) == "")

ipc({ op = "urgent", ids = { 1 }, mode = "toggle" })
check("urgent toggle", spoon._state[1].urgent == true)
ipc({ op = "urgent", ids = { 1 }, mode = "disable" })
check("urgent disable", spoon._state[1].urgent == false)

ipc({ op = "focus", id = 2 })
check("focus handler", focusedId == 2)
local treeFile = os.tmpname()
local out = io.open(treeFile, "w")
out:write(ipc({ op = "tree" }))
out:close()
local summary = io.popen("jq -c '[.nodes[] | [.id, .app_id, .focused]]' " .. treeFile):read("a")
os.remove(treeFile)
check("tree lists standard windows only", summary == '[[1,"firefox",false],[2,"kitty",true]]\n')

local popup = newWindow(4, "dfzf-popup", "kitty")
callbacks.created(popup)
local frame = popup.frames[1]
check("popup centered at 65%", frame and frame.w == 650 and frame.x == 175 and focusedId == 4)
local term = newWindow(5, "dfzf-term", "kitty")
callbacks.created(term)
check("regular window maximized", term.maximized == 1 and #term.frames == 0)
callbacks.title(windows[2])
check("title change ignored for regular window", windows[2].maximized == 0)

ipc({ op = "close", ids = { 5, 42 } })
check("close existing, ignore unknown", hs.window.get(5) == nil)
ipc({ op = "tree" })
check("state of closed window pruned", spoon._state[5] == nil)

check("unknown op errors", not pcall(ipc, { op = "nope" }))
check("focus on unknown id errors", not pcall(ipc, { op = "focus", id = 42 }))

os.exit(failures == 0 and 0 or 1)
