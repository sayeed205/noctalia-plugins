--!nonstrict

-- Compositor adapters normalize native workspace IPC into one bar widget.

local backend = nil
local workspaces = {}

local function render()
  local children = {}
  for _, workspace in ipairs(workspaces) do
    table.insert(children, ui.button({
      key = "workspace-" .. tostring(workspace.id),
      text = workspace.label,
      variant = workspace.active and "primary" or "ghost",
      tooltip = workspace.name ~= "" and workspace.name or ("Workspace " .. workspace.label),
      onClick = function()
        if backend == "niri" then
          noctalia.runAsync("niri msg action focus-workspace --reference " .. tostring(workspace.index))
        elseif backend == "hyprland" then
          noctalia.runAsync("hyprctl dispatch workspace " .. tostring(workspace.id))
        elseif backend == "sway" then
          noctalia.runAsync("swaymsg workspace number " .. tostring(workspace.index))
        end
      end,
    }))
  end

  if #children == 0 then
    table.insert(children, ui.label({
      text = backend == nil and "No workspace backend" or "—",
      color = "on_surface_variant",
    }))
  end

  local container = barWidget.isVertical() and ui.column or ui.row
  barWidget.render(container({ gap = 2, align = "center" }, children))
end

local function normalizeNiri(value)
  local result = {}
  for _, workspace in ipairs(value) do
    local index = tonumber(workspace.idx) or 0
    table.insert(result, {
      id = workspace.id,
      index = index,
      label = workspace.name ~= nil and workspace.name ~= "" and workspace.name or tostring(index),
      name = workspace.name or "",
      active = workspace.is_focused == true,
    })
  end
  return result
end

local function normalizeHyprland(value, activeId)
  local result = {}
  for _, workspace in ipairs(value) do
    local id = tonumber(workspace.id)
    if id ~= nil and id > 0 then
      local name = type(workspace.name) == "string" and workspace.name or ""
      table.insert(result, {
        id = id,
        index = id,
        label = name ~= "" and name or tostring(id),
        name = name,
        active = id == activeId,
      })
    end
  end
  return result
end

local function normalizeSway(value)
  local result = {}
  for _, workspace in ipairs(value) do
    local index = tonumber(workspace.num)
    if index ~= nil and index >= 0 then
      local name = type(workspace.name) == "string" and workspace.name or ""
      table.insert(result, {
        id = workspace.id or index,
        index = index,
        label = name ~= "" and name or tostring(index),
        name = name,
        active = workspace.focused == true,
      })
    end
  end
  return result
end

local function apply(value)
  if type(value) ~= "table" then
    return
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

backend = noctalia.commandExists("niri") and "niri"
  or noctalia.commandExists("hyprctl") and "hyprland"
  or noctalia.commandExists("swaymsg") and "sway"

if backend == nil then
  noctalia.log("Workspace: no supported compositor IPC found (tried niri, hyprctl, swaymsg)")
end

noctalia.setUpdateInterval(1000)
snapshot()

function update()
  snapshot()
end
