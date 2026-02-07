describe("theme-browser.ui.gallery preview on move", function()
  local module_name = "theme-browser.ui.gallery"
  local snapshots = {}
  local previews = {}

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
    previews = {}
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
            preview_on_move = true,
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
      build_state_snapshot = function()
        return {}
      end,
      get_entry_state = function(entry, _)
        if entry.name == "tokyonight" then
          return {
            active = false,
            installed = true,
            cached = false,
            marked = false,
          }
        end

        return {
          active = false,
          installed = false,
          cached = false,
          marked = false,
        }
      end,
    }

    package.loaded["theme-browser.application.theme_service"] = {
      preview = function(name, variant, opts)
        table.insert(previews, { name = name, variant = variant, opts = opts or {} })
      end,
      apply = function(_, _, _) end,
      install = function(_, _, _) end,
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

  it("previews only installed or cached entries while moving", function()
    local gallery = require(module_name)
    gallery.open()

    press("j")
    vim.wait(80)
    assert.equals(0, #previews)

    press("k")
    vim.wait(80)

    assert.equals(1, #previews)
    assert.equals("tokyonight", previews[1].name)
    assert.equals("tokyonight-night", previews[1].variant)
    assert.is_false(previews[1].opts.notify)
  end)
end)
