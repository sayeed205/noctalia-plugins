--!nonstrict

-- Compact, compositor-neutral workspace strip. The data source is adapted per
-- compositor; each dot focuses its matching workspace when clicked.

local backend = nil
local workspaces = {}
local render
local pendingWorkspaceId = nil
local hoveredWorkspaceId = nil

local SLOT_SIZE = 26
local ACTIVE_INSET = 2
local DOT_SIZE = 5

local function focusWorkspace(workspace)
  pendingWorkspaceId = workspace.id
  for _, candidate in ipairs(workspaces) do
    candidate.active = candidate.id == workspace.id
  end
  render()

  if backend == "niri" then
    noctalia.runAsync("niri msg action focus-workspace " .. tostring(workspace.index))
  elseif backend == "hyprland" then
    local id = tostring(workspace.id)
    noctalia.runAsync("hyprctl dispatch 'hl.dsp.focus({ workspace = \"" .. id .. "\" })'", function(result)
      if result.exitCode ~= 0 then
        noctalia.runAsync("hyprctl dispatch workspace " .. id)
      end
    end, 3000)
  elseif backend == "sway" then
    noctalia.runAsync("swaymsg workspace number " .. tostring(workspace.index))
  end
end

render = function()
  local function fixedSpace(width, height)
    return ui.box({ width = width, height = height, fill = "surface/0" })
  end

  local function workspaceSlot(workspace)
    local active = workspace.active
    local hovered = hoveredWorkspaceId == workspace.id
    local pillInset = ACTIVE_INSET
    local dotFill = active and "on_primary"
      or (hovered and "on_primary/0.7" or "on_surface_variant/0.4")
    local dot = ui.box({
      width = DOT_SIZE,
      height = DOT_SIZE,
      fill = dotFill,
      radius = DOT_SIZE / 2,
    })

    local slotChildren
    if active or hovered then
      slotChildren = {
        fixedSpace(pillInset, DOT_SIZE),
        ui.row({
          width = SLOT_SIZE - pillInset * 2,
          height = SLOT_SIZE - pillInset * 2,
          fill = active and "primary" or "primary/0.45",
          radius = (SLOT_SIZE - pillInset * 2) / 2,
          gap = 0,
          align = "center",
        }, {
          fixedSpace((SLOT_SIZE - pillInset * 2 - DOT_SIZE) / 2, DOT_SIZE),
          dot,
          fixedSpace((SLOT_SIZE - pillInset * 2 - DOT_SIZE) / 2, DOT_SIZE),
        }),
      }
    else
      slotChildren = {
        fixedSpace((SLOT_SIZE - DOT_SIZE) / 2, DOT_SIZE),
        dot,
        fixedSpace((SLOT_SIZE - DOT_SIZE) / 2, DOT_SIZE),
      }
    end

    return ui.row({
      key = "workspace-" .. tostring(workspace.id),
      width = SLOT_SIZE,
      height = SLOT_SIZE,
      gap = 0,
      align = "center",
      onClick = function()
        focusWorkspace(workspace)
      end,
      onHover = function(state)
        local nextId = state == "true" and workspace.id or nil
        if hoveredWorkspaceId ~= nextId then
          hoveredWorkspaceId = nextId
          render()
        end
      end,
    }, slotChildren)
  end

  local children = {}
  local occupiedRun = {}

  local function flushOccupiedRun()
    if #occupiedRun == 0 then
      return
    end
    table.insert(children, ui.row({
      key = "occupied-run-" .. tostring(#children + 1),
      width = SLOT_SIZE * #occupiedRun,
      height = SLOT_SIZE,
      fill = "secondary/0.6",
      radius = SLOT_SIZE / 2,
      gap = 0,
      align = "center",
    }, occupiedRun))
    occupiedRun = {}
  end

  for _, workspace in ipairs(workspaces) do
    local slot = workspaceSlot(workspace)
    if workspace.occupied then
      table.insert(occupiedRun, slot)
    else
      flushOccupiedRun()
      table.insert(children, slot)
    end
  end
  flushOccupiedRun()

  if #children == 0 then
    table.insert(children, ui.label({ text = "—", color = "on_surface_variant" }))
  end

  local container = barWidget.isVertical() and ui.column or ui.row
  barWidget.render(container({
    gap = 0,
    align = "center",
  }, children))
end

local function normalizeNiri(value)
  local result = {}
  for _, workspace in ipairs(value) do
    local index = tonumber(workspace.idx) or 0
    table.insert(result, {
      id = workspace.id or index,
      index = index,
      active = workspace.is_focused == true,
      occupied = workspace.active_window_id ~= nil,
    })
  end
  return result
end

local function normalizeHyprland(value, activeId)
  local result = {}
  local highestId = 0
  local highestOccupied = false
  for _, workspace in ipairs(value) do
    local id = tonumber(workspace.id)
    if id ~= nil and id > 0 then
      local occupied = (tonumber(workspace.windows) or 0) > 0
      if id > highestId then
        highestId = id
        highestOccupied = occupied
      end
      table.insert(result, {
        id = id,
        index = id,
        active = id == activeId,
        occupied = occupied,
      })
    end
  end

  if highestId > 0 and highestOccupied then
    table.insert(result, {
      id = highestId + 1,
      index = highestId + 1,
      active = false,
      occupied = false,
    })
  end
  return result
end

local function normalizeSway(value)
  local result = {}
  for _, workspace in ipairs(value) do
    local index = tonumber(workspace.num)
    if index ~= nil and index >= 0 then
      table.insert(result, {
        id = workspace.id or index,
        index = index,
        active = workspace.focused == true,
        occupied = workspace.urgent == true,
      })
    end
  end
  return result
end

local function apply(value)
  if type(value) ~= "table" then
    return
  end

  if pendingWorkspaceId ~= nil then
    local confirmed = false
    for _, workspace in ipairs(value) do
      if workspace.id == pendingWorkspaceId and workspace.active then
        confirmed = true
        break
      end
    end
    if not confirmed then
      return
    end
    pendingWorkspaceId = nil
  end

  workspaces = value
  table.sort(workspaces, function(a, b)
    return a.index < b.index
  end)
  render()
end

local function snapshot()
  if backend == "niri" then
    noctalia.runAsync("niri msg --json workspaces", function(result)
      if result.exitCode == 0 then
        apply(normalizeNiri(noctalia.json.decode(result.stdout)))
      end
    end, 3000)
  elseif backend == "hyprland" then
    noctalia.runAsync("hyprctl workspaces -j", function(workspaceResult)
      if workspaceResult.exitCode ~= 0 then
        return
      end
      noctalia.runAsync("hyprctl activeworkspace -j", function(activeResult)
        if activeResult.exitCode ~= 0 then
          return
        end
        local active = noctalia.json.decode(activeResult.stdout)
        apply(normalizeHyprland(noctalia.json.decode(workspaceResult.stdout), tonumber(active.id)))
      end, 3000)
    end, 3000)
  elseif backend == "sway" then
    noctalia.runAsync("swaymsg -t get_workspaces -r", function(result)
      if result.exitCode == 0 then
        apply(normalizeSway(noctalia.json.decode(result.stdout)))
      end
    end, 3000)
  end
end

local function environment(name)
  local value = noctalia.getenv(name)
  return type(value) == "string" and value or ""
end

local desktop = (environment("XDG_CURRENT_DESKTOP") .. ":"
  .. environment("XDG_SESSION_DESKTOP")):lower()

if environment("NIRI_SOCKET") ~= "" or desktop:find("niri", 1, true) ~= nil then
  backend = "niri"
elseif environment("HYPRLAND_INSTANCE_SIGNATURE") ~= ""
  or desktop:find("hyprland", 1, true) ~= nil then
  backend = "hyprland"
elseif environment("SWAYSOCK") ~= "" or desktop:find("sway", 1, true) ~= nil then
  backend = "sway"
elseif noctalia.commandExists("niri") then
  backend = "niri"
elseif noctalia.commandExists("hyprctl") then
  backend = "hyprland"
elseif noctalia.commandExists("swaymsg") then
  backend = "sway"
end

if backend == nil then
  noctalia.log("Workspace: no supported compositor IPC found")
end

noctalia.setUpdateInterval(100)
snapshot()

function update()
  snapshot()
end
