local M = {}

local breadcrumbs = { "Gallery" }

---Add breadcrumb to navigation
---@param name string Breadcrumb name
function M.add(name)
  table.insert(breadcrumbs, name)
end

---Remove last breadcrumb
function M.pop()
  table.remove(breadcrumbs)
end

---Clear all breadcrumbs
function M.clear()
  breadcrumbs = { "Gallery" }
end

---Get current breadcrumbs
---@return string[]
function M.get()
  return vim.deepcopy(breadcrumbs)
end

---Render breadcrumbs as string
---@param max_depth number Maximum breadcrumbs to show
---@return string Formatted breadcrumb string
function M.render(max_depth)
  local depth = math.min(max_depth or 5, #breadcrumbs)
  local result = {}

  for i = 1, depth do
    table.insert(result, breadcrumbs[i])
  end

  return table.concat(result, " > ")
end

---Check if at top level (Gallery)
---@return boolean
function M.at_top()
  return #breadcrumbs == 1
end

---Navigate to specific breadcrumb index
---@param index number Breadcrumb index
function M.navigate_to(index)
  while #breadcrumbs > index do
    M.pop()
  end
end

return M
