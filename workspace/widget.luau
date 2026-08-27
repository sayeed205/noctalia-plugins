--!nonstrict

local workspaces = {}

local function render()
  local children = {}
  for _, workspace in ipairs(workspaces) do
    local index = tostring(workspace.idx or "?")
    local name = workspace.name
    local label = (name ~= nil and name ~= "") and name or index
    local active = workspace.is_focused == true

    table.insert(children, ui.button({
      key = "workspace-" .. tostring(workspace.id or index),
      text = label,
      variant = active and "primary" or "ghost",
      tooltip = name ~= nil and (index .. ": " .. name) or ("Workspace " .. index),
      onClick = function()
        noctalia.runAsync("niri msg action focus-workspace --reference " .. index)
      end,
    }))
  end

  if #children == 0 then
    table.insert(children, ui.label({ text = "—", color = "on_surface_variant" }))
  end

  local container = barWidget.isVertical() and ui.column or ui.row
  barWidget.render(container({ gap = 2, align = "center" }, children))
end

local function updateWorkspaces(value)
  if type(value) ~= "table" then
    return
  end
  workspaces = value
  table.sort(workspaces, function(a, b)
    return (a.idx or 0) < (b.idx or 0)
  end)
  render()
end

local function snapshot()
  noctalia.runAsync("niri msg --json workspaces", function(result)
    if result.exitCode ~= 0 then
      return
    end
    local value = noctalia.json.decode(result.stdout)
    updateWorkspaces(value)
  end, 3000)
end

snapshot()

noctalia.runStream("niri msg --json event-stream", function(line)
  local event = noctalia.json.decode(line)
  if type(event) ~= "table" then
    return
  end
  if event.WorkspacesChanged ~= nil then
    updateWorkspaces(event.WorkspacesChanged.workspaces)
  elseif event.WorkspaceActivated ~= nil then
    local activated = event.WorkspaceActivated
    for _, workspace in ipairs(workspaces) do
      workspace.is_focused = workspace.id == activated.id
    end
    render()
  end
end)

function update()
  noctalia.setUpdateInterval(60000)
  snapshot()
end
