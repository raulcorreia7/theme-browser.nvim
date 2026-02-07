describe("theme-browser.ui.gallery selection", function()
  local module_name = "theme-browser.ui.gallery"
  local snapshots = {}
  local applied = nil
  local marked = nil

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
    marked = nil
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
            mark = { "m" },
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
      mark_theme = function(name, variant)
        marked = { name = name, variant = variant }
      end,
    }

    package.loaded["theme-browser.application.theme_service"] = {
      apply = function(name, variant)
        applied = { name = name, variant = variant }
      end,
      preview = function(_, _) end,
      install = function(_, _) end,
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

  it("applies the row under cursor and renders right-side state column", function()
    local gallery = require(module_name)
    gallery.open()

    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_get_current_buf()

    local first = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    local fourth = vim.api.nvim_buf_get_lines(buf, 3, 4, false)[1]
    assert.is_truthy(first:find("Theme %- Variant", 1, false))
    assert.is_truthy(fourth:find("Available", 1, true))

    vim.api.nvim_win_set_cursor(win, { 5, 0 })
    gallery.apply_current()

    assert.is_not_nil(applied)
    assert.equals("kanagawa", applied.name)
    assert.equals("wave", applied.variant)
  end)

  it("marks the selected row with name and variant", function()
    local gallery = require(module_name)
    gallery.open()

    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_cursor(win, { 5, 0 })
    gallery.mark_current()

    assert.is_not_nil(marked)
    assert.equals("kanagawa", marked.name)
    assert.equals("wave", marked.variant)
  end)
end)
