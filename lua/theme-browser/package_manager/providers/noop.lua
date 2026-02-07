local M = {}

function M.id()
  return "noop"
end

function M.is_available()
  return false
end

function M.is_ready()
  return true
end

function M.when_ready(callback)
  if type(callback) ~= "function" then
    return
  end
  vim.schedule(callback)
end

function M.load_entry(_)
  return false
end

function M.install_entry(_, _)
  return false
end

return M
