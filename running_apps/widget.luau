--!nonstrict

-- Compact running-window switcher for the active Hyprland workspace.

local windows = {}
local activeWorkspaceId = nil
local activeWindowAddress = nil
local pendingWindowAddress = nil
local hoveredWindowAddress = nil
local render

local SLOT_SIZE = 26
local ACTIVE_INSET = 2
local ICON_SIZE = 18
local MAX_VISIBLE = 5

local function focusWindow(window)
  local address = tostring(window.address)
  pendingWindowAddress = address
  activeWindowAddress = address
  render()

  local modern = "hyprctl dispatch 'hl.dsp.focus({ window = \"address:" .. address .. "\" })'"
  noctalia.runAsync(modern, function(result)
    if result.exitCode ~= 0 then
      noctalia.runAsync("hyprctl dispatch focuswindow address:" .. address)
    end
  end, 3000)
end

local function iconFor(window, highlighted)
  local appId = window.class or window.initialClass or ""
  local path = appId ~= "" and noctalia.appIconPath(appId, ICON_SIZE) or nil
  if path ~= nil then
    return ui.image({ path = path, width = ICON_SIZE, height = ICON_SIZE, fit = "contain" })
  end

  local fallback = appId:sub(1, 1):upper()
  if fallback == "" then
    fallback = "?"
  end
  return ui.label({
    text = fallback,
    color = highlighted and "on_primary" or "on_secondary_container",
    fontSize = 12,
  })
end

render = function()
  local function fixedSpace(width, height)
    return ui.box({ width = width, height = height, fill = "surface/0" })
  end

  local slots = {}
  local count = math.min(#windows, MAX_VISIBLE)

  for index = 1, count do
    local window = windows[index]
    local active = tostring(window.address) == activeWindowAddress
    local hovered = tostring(window.address) == hoveredWindowAddress
    local inset = ACTIVE_INSET
    local iconPadding = (SLOT_SIZE - inset * 2 - ICON_SIZE) / 2
    local slotChildren

    if active or hovered then
      slotChildren = {
        fixedSpace(inset, ICON_SIZE),
        ui.row({
          width = SLOT_SIZE - inset * 2,
          height = SLOT_SIZE - inset * 2,
          fill = active and "primary" or "primary/0.45",
          radius = (SLOT_SIZE - inset * 2) / 2,
          gap = 0,
          align = "center",
        }, {
          fixedSpace(iconPadding, ICON_SIZE),
          iconFor(window, true),
          fixedSpace(iconPadding, ICON_SIZE),
        }),
      }
    else
      local inactivePadding = (SLOT_SIZE - ICON_SIZE) / 2
      slotChildren = {
        fixedSpace(inactivePadding, ICON_SIZE),
        iconFor(window, false),
        fixedSpace(inactivePadding, ICON_SIZE),
      }
    end

    table.insert(slots, ui.row({
      key = "running-app-" .. tostring(window.address),
      width = SLOT_SIZE,
      height = SLOT_SIZE,
      gap = 0,
      align = "center",
      onClick = function()
        focusWindow(window)
      end,
      onHover = function(state)
        local nextAddress = state == "true" and tostring(window.address) or nil
        if hoveredWindowAddress ~= nextAddress then
          hoveredWindowAddress = nextAddress
          render()
        end
      end,
    }, slotChildren))
  end

  if #slots == 0 then
    barWidget.render(ui.row({ gap = 0, align = "center" }, {}))
    return
  end

  barWidget.render(ui.row({ gap = 0, align = "center" }, {
    ui.row({
      key = "running-apps-group",
      width = SLOT_SIZE * #slots,
      height = SLOT_SIZE,
      fill = "secondary/0.6",
      radius = SLOT_SIZE / 2,
      gap = 0,
      align = "center",
    }, slots),
  }))
end

local function apply(clients, workspace, activeWindow)
  if type(clients) ~= "table" or type(workspace) ~= "table" then
    return
  end

  activeWorkspaceId = tonumber(workspace.id)
  local reportedWindowAddress = type(activeWindow) == "table" and tostring(activeWindow.address) or nil
  if pendingWindowAddress ~= nil then
    if reportedWindowAddress == pendingWindowAddress then
      pendingWindowAddress = nil
    else
      return
    end
  end
  activeWindowAddress = reportedWindowAddress
  windows = {}

  for _, client in ipairs(clients) do
    local clientWorkspace = type(client.workspace) == "table" and tonumber(client.workspace.id) or nil
    if clientWorkspace == activeWorkspaceId then
      table.insert(windows, client)
    end
  end

  table.sort(windows, function(a, b)
    local aAt = type(a.at) == "table" and tonumber(a.at[1]) or nil
    local bAt = type(b.at) == "table" and tonumber(b.at[1]) or nil
    if aAt ~= nil and bAt ~= nil and aAt ~= bAt then
      return aAt < bAt
    end

    local aY = type(a.at) == "table" and tonumber(a.at[2]) or nil
    local bY = type(b.at) == "table" and tonumber(b.at[2]) or nil
    if aY ~= nil and bY ~= nil and aY ~= bY then
      return aY < bY
    end

    return tostring(a.address) < tostring(b.address)
  end)
  render()
end

local function snapshot()
  if not noctalia.commandExists("hyprctl") then
    return
  end

  noctalia.runAsync("hyprctl clients -j", function(clientsResult)
    if clientsResult.exitCode ~= 0 then
      return
    end
    noctalia.runAsync("hyprctl activeworkspace -j", function(workspaceResult)
      if workspaceResult.exitCode ~= 0 then
        return
      end
      noctalia.runAsync("hyprctl activewindow -j", function(activeResult)
        if activeResult.exitCode ~= 0 then
          return
        end
        apply(
          noctalia.json.decode(clientsResult.stdout),
          noctalia.json.decode(workspaceResult.stdout),
          noctalia.json.decode(activeResult.stdout)
        )
      end, 3000)
    end, 3000)
  end, 3000)
end

noctalia.setUpdateInterval(100)
snapshot()

function update()
  snapshot()
end
