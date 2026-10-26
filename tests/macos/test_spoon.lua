-- Dfzf.spoon against a mocked `hs` API: runs anywhere Lua 5.4 is available,
-- Hammerspoon itself only exists on macOS.
local clock = 1000.0
local requests = {}
local windows, focusedId = {}, nil
local callbacks = {}
local lastTask
local timers, httpCalls, httpStatus = {}, {}, 200

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

local screen = {
  frame = function() return { x = 0, y = 25, w = 1000, h = 800 } end,
  name = function() return "Built-in" end,
}

local function newWindow(id, title, app, standard, pid)
  local w = {
    _id = id, _title = title, _app = app, _standard = standard ~= false, _pid = pid or 4242,
    frames = {}, maximized = 0, minimized = false, _frame = { x = 0, y = 0, w = 10, h = 10 },
  }
  function w:id() return self._id end
  function w:title() return self._title end
  function w:application()
    return { name = function() return self._app end, pid = function() return self._pid end }
  end
  function w:isStandard() return self._standard end
  function w:isMinimized() return self.minimized end
  function w:minimize() self.minimized = true end
  function w:unminimize() self.minimized = false end
  function w:focus() focusedId = self._id end
  function w:close() for i, x in ipairs(windows) do if x == self then table.remove(windows, i) end end end
  function w:screen() return screen end
  function w:frame() return { x = self._frame.x, y = self._frame.y, w = self._frame.w, h = self._frame.h } end
  function w:setFrame(rect)
    self._frame = rect
    table.insert(self.frames, rect)
  end
  function w:maximize() self.maximized = self.maximized + 1 end
  table.insert(windows, w)
  return w
end

hs = {
  timer = {
    secondsSinceEpoch = function() return clock end,
    doAfter = function(_, fn) fn() end,
    doEvery = function(_, fn)
      local timer = { fn = fn }
      function timer:stop() self.stopped = true end
      table.insert(timers, timer)
      return timer
    end,
  },
  host = { uuid = function() return "1111-2222" end },
  http = {
    asyncGet = function(url, headers, callback)
      table.insert(httpCalls, { method = "GET", url = url, headers = headers })
      callback(httpStatus, "{}")
    end,
    asyncPost = function(url, body, headers, callback)
      table.insert(httpCalls, { method = "POST", url = url, body = body, headers = headers })
      callback(httpStatus, "")
    end,
  },
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
      windowDestroyed = "destroyed",
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
  screen = { mainScreen = function() return screen end },
  spoons = { bindHotkeysToSpec = function() end },
  task = {
    new = function(path, callback, args)
      local task = { path = path, args = args, env = { PATH = "/usr/bin:/bin", NO_COLOR = "1", TERM = "xterm-kitty" } }
      function task:environment() return self.env end
      function task:setEnvironment(env) self.env = env end
      function task:start() lastTask = self end
      return task
    end,
  },
}
package.preload["hs.ipc"] = function() return {} end
-- The native module never exists here: make that explicit so a locally built
-- hs/_dfzf.so cannot change which backend these tests exercise.
package.preload["hs._dfzf"] = function() error("hs._dfzf absent in tests") end
local filterCount = 0
local newFilter = hs.window.filter.new
hs.window.filter.new = function(...)
  filterCount = filterCount + 1
  return newFilter(...)
end

local spoonPath = arg[1] or "../../macos/Dfzf.spoon/init.lua"
local spoon = dofile(spoonPath)
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
local function jq(filter)
  return io.popen("jq -c '" .. filter .. "' " .. treeFile):read("a")
end
check("tree lists standard windows only",
  jq('[.. | objects | select(.type == "con") | [.id, .app_id, .focused, .pid]]')
    == '[[1,"firefox",false,4242],[2,"kitty",true,4242]]\n')

ipc({ op = "hide", ids = { 1 } })
out = io.open(treeFile, "w")
out:write(ipc({ op = "tree" }))
out:close()
check("hidden window moves to the scratchpad workspace",
  jq('[.nodes[] | [.name, [.nodes[] | .id]]]') == '[["1",[2]],["__i3_scratch",[1]]]\n')
os.remove(treeFile)
ipc({ op = "show", id = 1 })
check("show unminimizes and focuses", not windows[1].minimized and focusedId == 1)

ipc({ op = "resize", id = 1, w = 900, h = 720 })
ipc({ op = "move", id = 1, x = 50, y = 40 })
local f = windows[1]._frame
check("resize then move relative to the screen origin", f.w == 900 and f.h == 720 and f.x == 50 and f.y == 65)
check("outputs report the screen frame", ipc({ op = "outputs" }):find('"width":1000', 1, true) ~= nil)

local popup = newWindow(4, "dfzf-popup", "kitty")
callbacks.created(popup)
local frame = popup.frames[1]
check("popup centered at 65%", frame and frame.w == 650 and frame.x == 175 and focusedId == 4)
local newer = newWindow(7, "dfzf-popup", "kitty")
callbacks.created(newer)
check("new popup closes the older one", hs.window.get(4) == nil and hs.window.get(7) ~= nil and focusedId == 7)
local late = newWindow(8, "dfzf-popup", "kitty")
local newest = newWindow(10, "dfzf-popup", "kitty")
callbacks.title(newest)
callbacks.created(late)
check("late event on an older popup keeps the newer one",
  hs.window.get(10) ~= nil and hs.window.get(7) == nil)
callbacks.created(newWindow(9, "hx notes.md", "kitty"))
check("regular window never closes popups", hs.window.get(10) ~= nil)
local term = newWindow(5, "dfzf-term", "kitty")
callbacks.created(term)
check("regular window maximized", term.maximized == 1 and #term.frames == 0)
local git = newWindow(6, "dfzf-git", "kitty")
callbacks.created(git)
check("floating title left unmaximized", git.maximized == 0)
callbacks.title(windows[2])
check("title change ignored for regular window", windows[2].maximized == 0)

ipc({ op = "close", ids = { 5, 42 } })
check("close existing, ignore unknown", hs.window.get(5) == nil)
ipc({ op = "tree" })
check("state of closed window pruned", spoon._state[5] == nil)

-- Closing the popup reactivates kitty, which focuses its other window back.
local function steal(win)
  focusedId = win:id()
  callbacks.focused(win)
end
local handoffPopup = hs.window.get(10)
ipc({ op = "focus", id = 1 })
handoffPopup:close()
callbacks.destroyed(handoffPopup)
steal(windows[2])
check("handoff: closed popup's app cannot steal the focus back", focusedId == 1)
clock = clock + 2
steal(windows[2])
check("handoff: expires after the grace period", focusedId == 2)
local browser = newWindow(15, "Docs", "Firefox", true, 4141)
clock = clock + 2
steal(browser)
clock = clock + 2
local idle = newWindow(11, "dfzf-popup", "kitty")
callbacks.created(idle)
steal(idle)
idle:close()
callbacks.destroyed({ id = function() return nil end })
steal(windows[2])
check("handoff: popup closed without a pick gives the focus back", focusedId == 15)
clock = clock + 2
local picked = newWindow(13, "dfzf-popup", "kitty")
callbacks.created(picked)
steal(picked)
local slack = newWindow(14, "general", "Slack", true, 4343)
steal(slack)
picked:close()
callbacks.destroyed(picked)
steal(windows[2])
check("handoff: popup whose pick focused another app forces nothing", focusedId == 2)
clock = clock + 2
steal(browser)
clock = clock + 2
local preview = newWindow(12, "dfzf-popup", "kitty")
callbacks.created(preview)
ipc({ op = "focus", id = 15 })
ipc({ op = "focus", id = 12 })
preview:close()
callbacks.destroyed({ id = function() return nil end })
steal(windows[2])
check("handoff: popup refocused after a focus request gives the focus back", focusedId == 15)
clock = clock + 2
steal(slack)
clock = clock + 5
steal(windows[2])
local opening = newWindow(16, "dfzf-popup", "kitty")
callbacks.created(opening)
opening:close()
callbacks.destroyed(opening)
steal(windows[2])
check("handoff: kitty focusing its own window while opening the popup is skipped", focusedId == 14)
clock = clock + 2
steal(browser)
spoon:_command("hub")
clock = clock + 1
steal(windows[2])
clock = clock + 2
local fromHotkey = newWindow(17, "dfzf-popup", "kitty")
callbacks.created(fromHotkey)
fromHotkey:close()
callbacks.destroyed(fromHotkey)
steal(windows[2])
check("handoff: popup opened by a hotkey goes back to the window it was opened from", focusedId == 15)
clock = clock + 2
steal(slack)
spoon:_command("hub")
clock = clock + 10
steal(browser)
local late = newWindow(18, "dfzf-popup", "kitty")
callbacks.created(late)
late:close()
callbacks.destroyed(late)
steal(windows[2])
check("handoff: a stale hotkey origin is not adopted", focusedId == 15)
local again = newWindow(19, "dfzf-popup", "kitty")
callbacks.created(again)
steal(again)
check("handoff: a new popup keeps the focus from the closed one's handoff", focusedId == 19)
again:close()
callbacks.destroyed(again)
steal(windows[2])
spoon:_command("hub")
local untitled = newWindow(20, "kitty", "kitty")
steal(untitled)
check("handoff: a popup hotkey drops the closed popup's handoff", focusedId == 20)
untitled:close()

check("unknown op errors", not pcall(ipc, { op = "nope" }))
check("focus on unknown id errors", not pcall(ipc, { op = "focus", id = 42 }))

spoon:_run("kitty -1 --title dfzf-term")
check("run detaches the command from Hammerspoon",
  lastTask.path == "/bin/bash" and lastTask.args[1] == "-c"
  and lastTask.args[2] == "(kitty -1 --title dfzf-term\n) </dev/null >/dev/null 2>&1 &"
  and lastTask.env.PATH == spoon.path .. ":/usr/bin:/bin")
check("run drops the NO_COLOR and TERM Hammerspoon may inherit from a shell",
  lastTask.env.NO_COLOR == nil and lastTask.env.TERM == nil)

lastTask = nil
spoon:focusToggle("it's", '[app_id="^slack$"]', "open -a Slack")
check("focusToggle without the native backend runs the script",
  lastTask.args[2] == [[(dfzf-focus-toggle 'it'\''s' '[app_id="^slack$"]' open -a Slack]] .. "\n) </dev/null >/dev/null 2>&1 &")

local function startWith(module)
  package.loaded["hs._dfzf"] = nil
  package.preload["hs._dfzf"] = module
  filterCount = 0
  return dofile(spoonPath):start()
end

local config, stopped
local toggleRequest, toggleReply
local native = startWith(function()
  return {
    start = function(c) config = c return true end,
    stop = function() stopped = true end,
    request = function(json, callback)
      toggleRequest = json
      callback(true, toggleReply)
      return true
    end,
  }
end)
check("native module: spoon delegates, no window filter",
  native._native ~= nil and filterCount == 0 and native._state == nil)
check("native module receives the spoon config",
  config.popupRatio == 0.65 and config.maximize == true and config.identityTitles["dfzf-term"]
    and config.popupTitles["dfzf-popup"] and config.floatingTitles["dfzf-git"])
check("native module: Lua ipc refuses requests", not pcall(native.ipc, native, "x"))

lastTask, toggleReply = nil, ""
native:_command("term")
check("term toggle goes through the native module",
  toggleRequest:find('"op":"focusToggle"', 1, true) and toggleRequest:find('"key":"term"', 1, true)
    and toggleRequest:find('"criteria":"[app_id=\\"^dfzf-term$\\"]"', 1, true)
    and toggleRequest:find('"fallback":true', 1, true) and lastTask == nil)
toggleReply = "missing"
native:_command("term")
check("missing toggle target runs the fallback",
  lastTask and lastTask.args[2]:find("--title dfzf-term", 1, true) ~= nil)
lastTask = nil
native:focusToggle("slack", '[app_id="^slack$"]')
check("missing toggle target without fallback runs nothing",
  toggleRequest:find('"fallback":false', 1, true) and lastTask == nil)

native:stop()
check("stop stops the native module", stopped == true and native._native == nil)

local fallback = startWith(function() error("module not found") end)
check("require failure falls back to Lua", fallback._native == nil and filterCount == 1)

fallback = startWith(function()
  return { start = function() return nil, "dfzf: no Accessibility permission" end, stop = function() end }
end)
check("start failure falls back to Lua", fallback._native == nil and filterCount == 1)

-- Windows switcher: a persistent dfzf-windows driven over fzf --listen.
local stateDir = os.tmpname() .. ".d"
os.execute("mkdir -p " .. stateDir)
local nativeRequests, focusOk = {}, true
local switcherTree = { type = "root", nodes = { { type = "con", id = 77, name = "dfzf-switcher", nodes = {} } } }
requests["<switcher tree>"] = switcherTree
package.loaded["hs._dfzf"] = nil
package.preload["hs._dfzf"] = function()
  return {
    start = function(c) config = c return true end,
    stop = function() end,
    request = function(json, callback)
      table.insert(nativeRequests, json)
      if json:find('"op":"tree"', 1, true) then
        callback(true, "<switcher tree>")
      else
        callback(focusOk, focusOk and "" or "dfzf: no window with id 77")
      end
      return true
    end,
  }
end
local switcher = dofile(spoonPath)
switcher.switcher = true
switcher.socketPath = stateDir .. "/hs.sock"
lastTask = nil
switcher:start()
check("native module receives the centered titles", config.centeredTitles["dfzf-switcher"] == true)
check("switcher: started with the spoon, key and port file through the environment",
  lastTask and lastTask.args[2]:find("--instance-group dfzf-switcher", 1, true)
    and lastTask.args[2]:find("dfzf-windows --persistent", 1, true)
    and lastTask.env.FZF_API_KEY == "11112222" .. "11112222"
    and lastTask.env.DFZF_SWITCHER_PORT_FILE == stateDir .. "/switcher.port"
    and not lastTask.args[2]:find("11112222", 1, true))

local portFile = io.open(stateDir .. "/switcher.port", "w")
portFile:write("6300")
portFile:close()
httpCalls = {}
timers[#timers].fn()
check("switcher: attached once its fzf answers", switcher._switcher and switcher._switcher.id == 77
  and timers[#timers].stopped and httpCalls[1].headers["x-api-key"] == "1111222211112222")

httpCalls, nativeRequests, lastTask = {}, {}, nil
switcher:_command("windows")
check("switcher: windows reloads the list and focuses it, without any process",
  #httpCalls == 1 and httpCalls[1].method == "POST" and httpCalls[1].url == "http://localhost:6300"
    and httpCalls[1].body == "change-query()+rebind(load)+reload(dfzf-windows-load)"
    and nativeRequests[1]:find('"op":"focus"', 1, true) and nativeRequests[1]:find('"id":77', 1, true)
    and lastTask == nil)

focusOk, httpStatus = false, 500
switcher:_command("windows")
check("switcher: a lost window starts a new switcher", switcher._switcher == nil and lastTask ~= nil
  and lastTask.args[2]:find("dfzf-windows --persistent", 1, true))
focusOk, httpStatus = true, 200

local popupOnly = dofile(spoonPath)
popupOnly._native = { request = function(request)
  if request ~= '{"op":"popupOrigin"}' then error("no switcher request expected") end
end }
lastTask = nil
popupOnly:_command("windows")
check("without Dfzf.switcher, windows opens the popup",
  lastTask and lastTask.args[2]:find("--title dfzf-popup -e dfzf-windows", 1, true) ~= nil)
os.execute("rm -r " .. stateDir)

os.exit(failures == 0 and 0 or 1)
