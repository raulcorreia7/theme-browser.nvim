describe("Integration: theme change persistence", function()
  local test_utils = require("tests.helpers.test_utils")
  local original_stdpath = vim.fn.stdpath
  local original_theme = vim.g.colors_name

  local temp_root
  local temp_rtp
  local registry_path

  local modules = {
    "theme-browser",
    "theme-browser.adapters.registry",
    "theme-browser.adapters.factory",
    "theme-browser.adapters.base",
    "theme-browser.persistence.state",
  }

  local function write_file(path, lines)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile(lines, path)
  end

  before_each(function()
    temp_root = vim.fn.tempname()
    temp_rtp = vim.fn.tempname()
    vim.fn.mkdir(temp_root, "p")
    vim.fn.mkdir(temp_rtp, "p")
    vim.fn.mkdir(temp_rtp .. "/colors", "p")

    write_file(temp_rtp .. "/colors/tb-theme-a.vim", {
      "hi clear",
      "let g:colors_name = 'tb-theme-a'",
    })
    write_file(temp_rtp .. "/colors/tb-theme-b.vim", {
      "hi clear",
      "let g:colors_name = 'tb-theme-b'",
    })

    registry_path = temp_root .. "/registry.json"
    write_file(registry_path, {
      vim.json.encode({
        {
          name = "theme-a",
          repo = "owner/theme-a",
          colorscheme = "tb-theme-a",
          meta = { strategy = "colorscheme_only" },
        },
        {
          name = "theme-b",
          repo = "owner/theme-b",
          colorscheme = "tb-theme-b",
          meta = { strategy = "colorscheme_only" },
        },
      }),
    })

    vim.fn.stdpath = function(kind)
      if kind == "data" then
        return temp_root .. "/data"
      elseif kind == "config" then
        return temp_root .. "/config"
      elseif kind == "cache" then
        return temp_root .. "/cache"
      end
      return original_stdpath(kind)
    end

    vim.opt.runtimepath:prepend(temp_rtp)
    test_utils.reset_all(modules)
  end)

  after_each(function()
    if original_theme and original_theme ~= "" then
      pcall(vim.cmd.colorscheme, original_theme)
    end

    if temp_rtp and vim.fn.isdirectory(temp_rtp) == 1 then
      pcall(function()
        vim.opt.runtimepath:remove(temp_rtp)
      end)
      vim.fn.delete(temp_rtp, "rf")
    end

    if temp_root and vim.fn.isdirectory(temp_root) == 1 then
      vim.fn.delete(temp_root, "rf")
    end

    vim.fn.stdpath = original_stdpath
    test_utils.restore_all(modules)
  end)

  it("persists selected theme across state reload", function()
    local state = require("theme-browser.persistence.state")
    state.initialize({
      package_manager = { enabled = false, mode = "installed_only" },
    })

    local registry = require("theme-browser.adapters.registry")
    registry.initialize(registry_path)

    local base = require("theme-browser.adapters.base")
    local first = base.load_theme("theme-a", nil, { notify = false })
    local second = base.load_theme("theme-b", nil, { notify = false })

    assert.is_true(first.ok)
    assert.is_true(second.ok)
    assert.equals("tb-theme-b", vim.g.colors_name)

    vim.wait(250)

    package.loaded["theme-browser.persistence.state"] = nil
    local reloaded = require("theme-browser.persistence.state")
    reloaded.load()
    local current = reloaded.get_current_theme()

    assert.is_not_nil(current)
    assert.equals("theme-b", current.name)
    assert.is_nil(current.variant)
  end)

  it("preview does not persist current selection", function()
    local state = require("theme-browser.persistence.state")
    state.initialize({
      package_manager = { enabled = false, mode = "installed_only" },
    })

    local registry = require("theme-browser.adapters.registry")
    registry.initialize(registry_path)

    state.set_current_theme("theme-a", nil)
    vim.wait(250)

    local preview = require("theme-browser.preview.manager")
    preview.create_preview("theme-b", nil)

    assert.equals("tb-theme-b", vim.g.colors_name)
    local current = state.get_current_theme()
    assert.equals("theme-a", current.name)
  end)
end)
