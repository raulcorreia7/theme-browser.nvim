describe("theme-browser.ui.gallery selection", function()
  local module_name = "theme-browser.ui.gallery"
  local snapshots = {}
  local applied = nil

  local function snapshot(name)
    snapshots[name] = package.loaded[name]
  end

  local function restore(name)
    if snapshots[name] == nil then
      package.loaded[name] = nil
    else
      package.loaded[name] = snapshots[name]
    end
  end

  before_each(function()
    snapshots = {}
    applied = nil
    snapshot(module_name)
    snapshot("theme-browser")
    snapshot("theme-browser.adapters.registry")
    snapshot("theme-browser.persistence.state")
    snapshot("theme-browser.application.theme_service")

    package.loaded["theme-browser"] = {
      get_config = function()
        return {
          ui = {
            window_width = 0.6,
            window_height = 0.5,
            border = "rounded",
          },
          keymaps = {
            close = { "q", "<Esc>" },
            select = { "<CR>" },
            navigate_up = { "k" },
            navigate_down = { "j" },
            goto_top = { "gg" },
            goto_bottom = { "G" },
            preview = { "p" },
            install = { "i" },
          },
        }
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      is_initialized = function()
        return true
      end,
      list_entries = function()
        return {
          { name = "tokyonight", variant = "tokyonight-night", repo = "folke/tokyonight.nvim" },
          { name = "kanagawa", variant = "wave", repo = "rebelot/kanagawa.nvim" },
        }
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      get_current_theme = function()
        return nil
      end,
      format_entry_states = function()
        return "Available"
      end,
    }

    package.loaded["theme-browser.application.theme_service"] = {
      use = function(name, variant)
        applied = { name = name, variant = variant }
      end,
      preview = function(_, _) end,
    }

    package.loaded[module_name] = nil
  end)

  after_each(function()
    local ok, gallery = pcall(require, module_name)
    if ok and gallery.is_open() then
      gallery.close()
    end

    restore(module_name)
    restore("theme-browser")
    restore("theme-browser.adapters.registry")
    restore("theme-browser.persistence.state")
    restore("theme-browser.application.theme_service")
  end)

  it("applies the row under cursor and renders state badges", function()
    local gallery = require(module_name)
    gallery.open()

    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_get_current_buf()
    local winbar = vim.api.nvim_get_option_value("winbar", { win = win })
    assert.is_truthy(winbar:find("<CR> use", 1, true))

    local first = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    local fourth = vim.api.nvim_buf_get_lines(buf, 3, 4, false)[1]
    assert.is_truthy(first:find("Theme", 1, true))
    assert.is_truthy(fourth:find("%[AVAILABLE%]", 1, false))

    vim.api.nvim_win_set_cursor(win, { 4, 0 })
    gallery.apply_current()

    assert.is_not_nil(applied)
    assert.equals("kanagawa", applied.name)
    assert.equals("wave", applied.variant)
  end)

  it("uses install key as an alias for select", function()
    local gallery = require(module_name)
    gallery.open()

    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_cursor(win, { 4, 0 })
    gallery.install_current()

    assert.is_not_nil(applied)
    assert.equals("kanagawa", applied.name)
    assert.equals("wave", applied.variant)
  end)
end)
