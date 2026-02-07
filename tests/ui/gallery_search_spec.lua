describe("theme-browser.ui.gallery search", function()
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

  local function press(keys)
    local termcodes = vim.api.nvim_replace_termcodes(keys, true, false, true)
    vim.api.nvim_feedkeys(termcodes, "xt", false)
  end

  before_each(function()
    snapshots = {}
    applied = nil
    vim.o.hlsearch = true

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
          { name = "moonlight", variant = "moonlight-night", repo = "author/moonlight.nvim" },
          { name = "kanagawa", variant = "wave", repo = "rebelot/kanagawa.nvim" },
          { name = "nightfox", variant = "carbon", repo = "EdenEast/nightfox.nvim" },
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
      load_theme = function(name, variant)
        applied = { name = name, variant = variant }
      end,
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

  it("keeps selection aligned with n/N search movement", function()
    local gallery = require(module_name)
    gallery.open()

    press("/-night<CR>")
    press("n")
    gallery.apply_current()

    assert.is_not_nil(applied)
    assert.equals("moonlight", applied.name)
    assert.equals("moonlight-night", applied.variant)

    press("N")
    gallery.apply_current()

    assert.is_not_nil(applied)
    assert.equals("tokyonight", applied.name)
    assert.equals("tokyonight-night", applied.variant)
  end)

  it("uses esc ladder: clear search first, close second", function()
    local gallery = require(module_name)
    gallery.open()

    press("/kanagawa<CR>")
    assert.is_truthy(vim.fn.getreg("/") ~= "")

    press("<Esc>")
    assert.is_true(gallery.is_open())
    assert.equals("", vim.fn.getreg("/"))

    press("<Esc>")
    assert.is_false(gallery.is_open())
  end)

end)
