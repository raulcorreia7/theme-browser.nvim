describe("theme-browser.ui.gallery focus", function()
  local module_name = "theme-browser.ui.gallery"
  local snapshots = {}

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
    snapshot(module_name)
    snapshot("theme-browser")
    snapshot("theme-browser.adapters.registry")
    snapshot("theme-browser.persistence.state")
    snapshot("theme-browser.preview.manager")
    snapshot("theme-browser.adapters.base")
    snapshot("theme-browser.persistence.lazy_spec")

    package.loaded["theme-browser"] = {
      get_config = function()
        return {
          ui = {
            window_width = 0.6,
            window_height = 0.5,
            border = "rounded",
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
      get_entry_state = function(_)
        return {
          active = false,
          installed = false,
          cached = false,
          marked = false,
        }
      end,
      format_entry_states = function()
        return "Available"
      end,
      mark_theme = function(_) end,
    }

    package.loaded["theme-browser.preview.manager"] = {
      create_preview = function(_, _) end,
      cleanup = function() end,
    }

    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(_, _) end,
    }

    package.loaded["theme-browser.persistence.lazy_spec"] = {
      generate_spec = function(_, _) end,
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
    restore("theme-browser.preview.manager")
    restore("theme-browser.adapters.base")
    restore("theme-browser.persistence.lazy_spec")
  end)

  it("re-focuses existing gallery when opened again", function()
    local gallery = require(module_name)
    gallery.open()
    assert.is_true(gallery.is_open())

    local focused = gallery.focus()
    assert.is_true(focused)

    gallery.open()
    assert.is_true(gallery.is_open())
  end)

  it("recovers when gallery is marked open but window is gone", function()
    local gallery = require(module_name)
    gallery.open()
    assert.is_true(gallery.is_open())

    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_close(win, true)

    assert.is_false(gallery.focus())

    gallery.open()
    assert.is_true(gallery.is_open())
    assert.is_true(gallery.focus())
  end)
end)
