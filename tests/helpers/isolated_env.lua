local M = {}

local test_root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
local is_windows = vim.fn.has("win32") == 1

local function joinpath(...)
  return vim.fn.resolve(table.concat({ ... }, "/"))
end

local function mkdirp(path)
  if vim.fn.isdirectory(path) == 0 then
    vim.fn.mkdir(path, "p")
  end
end

local function rmrf(path)
  if vim.fn.isdirectory(path) == 1 then
    vim.fn.delete(path, "rf")
  elseif vim.fn.filereadable(path) == 1 then
    vim.fn.delete(path)
  end
end

local function get_temp_dir()
  local tmp = os.getenv("TMPDIR") or os.getenv("TEMP") or "/tmp"
  return joinpath(tmp, "theme-browser-tests." .. tostring(vim.uv.hrtime()))
end

function M.setup()
  local temp_dir = get_temp_dir()
  local config_home = joinpath(temp_dir, "config")
  local data_home = joinpath(temp_dir, "data")
  local cache_home = joinpath(temp_dir, "cache")
  local state_home = joinpath(temp_dir, "state")

  mkdirp(config_home)
  mkdirp(data_home)
  mkdirp(cache_home)
  mkdirp(state_home)

  vim.env.XDG_CONFIG_HOME = config_home
  vim.env.XDG_DATA_HOME = data_home
  vim.env.XDG_CACHE_HOME = cache_home
  vim.env.XDG_STATE_HOME = state_home

  local nvim_path = joinpath(config_home, "nvim")
  mkdirp(joinpath(nvim_path, "lua"))
  mkdirp(joinpath(data_home, "nvim", "lazy"))

  return {
    temp_dir = temp_dir,
    config_home = config_home,
    data_home = data_home,
    cache_home = cache_home,
    state_home = state_home,
    nvim_config = nvim_path,
    lazy_root = joinpath(data_home, "nvim", "lazy"),
  }
end

function M.teardown(env)
  if env and env.temp_dir then
    rmrf(env.temp_dir)
  end
end

function M.write_file(path, content)
  local dir = vim.fn.fnamemodify(path, ":h")
  mkdirp(dir)
  local file = io.open(path, "w")
  if not file then
    error("Failed to write: " .. path)
  end
  file:write(content)
  file:close()
end

function M.write_lazy_spec(env, spec)
  local spec_content = "return " .. vim.inspect(spec)
  M.write_file(joinpath(env.nvim_config, "lua", "plugins", "test-init.lua"), spec_content)
end

function M.write_init_lua(env, content)
  M.write_file(joinpath(env.nvim_config, "init.lua"), content)
end

function M.bootstrap_lazy(env)
  local lazy_path = joinpath(env.lazy_root, "lazy.nvim")
  if vim.fn.isdirectory(lazy_path) == 0 then
    local repo = "https://github.com/folke/lazy.nvim.git"
    local cmd = string.format("git clone --depth=1 --branch=stable %s %s", repo, lazy_path)
    os.execute(cmd)
  end
  return lazy_path
end

function M.create_minimal_init(env, plugin_path)
  local lazy_path = M.bootstrap_lazy(env)
  local init = string.format(
    [[
vim.opt.rtp:prepend("%s")
vim.opt.rtp:prepend("%s")

vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("lazy").setup({
  { "nvim-lua/plenary.nvim", lazy = false },
}, {
  root = "%s",
  lockfile = "%s/lazy-lock.json",
  defaults = { lazy = false },
})

vim.opt.rtp:prepend("%s")
]],
    lazy_path,
    lazy_path,
    env.lazy_root,
    env.nvim_config,
    plugin_path
  )
  M.write_init_lua(env, init)
  return env
end

function M.create_test_config(opts)
  opts = opts or {}
  local temp_dir = vim.fn.tempname()
  mkdirp(temp_dir)

  return vim.tbl_extend("force", {
    registry_path = opts.registry_path,
    cache_dir = joinpath(temp_dir, "cache"),
    auto_load = opts.auto_load or false,
    package_manager = opts.package_manager or {
      enabled = false,
      mode = "manual",
      provider = "noop",
    },
  }, opts)
end

function M.with_isolated_env(fn)
  local env = M.setup()
  local ok, err = pcall(fn, env)
  M.teardown(env)
  if not ok then
    error(err, 0)
  end
end

return M
