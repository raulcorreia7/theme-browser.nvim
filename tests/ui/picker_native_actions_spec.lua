local test_utils = require("tests.helpers.test_utils")

describe("theme-browser.picker.native repo actions", function()
  local module_name = "theme-browser.picker.native"
  local modules = {
    module_name,
    "nui.popup",
    "theme-browser",
    "theme-browser.adapters.registry",
    "theme-browser.persistence.state",
    "theme-browser.application.theme_service",
    "theme-browser.picker.highlights",
    "theme-browser.config.defaults",
    "theme-browser.ui.entry",
    "theme-browser.util.icons",
  }

  local last_popup
  local mapped_callbacks
  local mark_calls
  local setreg_calls
  local opened_urls

  local original_keymap_set
  local original_ui_open
  local original_setreg

  local function open_popup_window(popup, layout)
    local config = {
      relative = "editor",
      style = "minimal",
      row = layout.position.row,
      col = layout.position.col,
      width = layout.size.width,
      height = layout.size.height,
      border = "rounded",
      focusable = true,
    }

    if popup.winid and vim.api.nvim_win_is_valid(popup.winid) then
      vim.api.nvim_win_set_config(popup.winid, config)
      return
    end

    popup.winid = vim.api.nvim_open_win(popup.bufnr, true, config)
  end

  before_each(function()
    test_utils.reset_all(modules)

    last_popup = nil
    mapped_callbacks = {}
    mark_calls = {}
    setreg_calls = {}
    opened_urls = {}

    package.loaded["nui.popup"] = setmetatable({}, {
      __call = function(_, opts)
        local popup = {
          bufnr = vim.api.nvim_create_buf(false, true),
          winid = nil,
          mount = function(self)
            open_popup_window(self, {
              position = opts.position,
              size = opts.size,
            })
          end,
          unmount = function(self)
            if self.winid and vim.api.nvim_win_is_valid(self.winid) then
              pcall(vim.api.nvim_win_close, self.winid, true)
            end
            if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
              pcall(vim.api.nvim_buf_delete, self.bufnr, { force = true })
            end
            self.winid = nil
          end,
          update_layout = function(self, layout)
            open_popup_window(self, layout)
          end,
        }

        last_popup = popup
        return popup
      end,
    })

    package.loaded["theme-browser"] = {
      get_config = function()
        return {
          ui = { show_hints = false },
          keymaps = {},
        }
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      list_entries = function()
        return {
          {
            name = "tokyonight",
            variant = "night",
            colorscheme = "tokyonight-night",
            repo = "folke/tokyonight.nvim",
          },
        }
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      build_state_snapshot = function()
        return {}
      end,
      mark_theme = function(name, variant)
        table.insert(mark_calls, { name = name, variant = variant })
      end,
    }

    package.loaded["theme-browser.application.theme_service"] = {
      use = function(_, _, _, callback)
        if callback then
          callback(true)
        end
      end,
      install = function(_, _, _, callback)
        if callback then
          callback(true)
        end
      end,
      preview = function()
        return 0
      end,
    }

    package.loaded["theme-browser.picker.highlights"] = {
      setup = function() end,
    }

    package.loaded["theme-browser.config.defaults"] = {
      keymaps = {
        close = { "q" },
        select = { "<CR>" },
        set_main = { "m" },
        preview = { "p" },
        install = { "i" },
        copy_repo = { "Y" },
        open_repo = { "O" },
        navigate_up = { "k" },
        navigate_down = { "j" },
        goto_top = { "gg" },
        goto_bottom = { "G" },
        scroll_up = { "<C-u>" },
        scroll_down = { "<C-d>" },
        search = { "/" },
        clear_search = { "c" },
      },
    }

    package.loaded["theme-browser.ui.entry"] = {
      entry_status = function()
        return "available"
      end,
      entry_background = function()
        return "dark"
      end,
    }

    package.loaded["theme-browser.util.icons"] = {
      STATE_ICONS = {
        available = "o",
        current = "c",
        previewing = "p",
        previewed = "r",
        installed = "i",
        downloaded = "d",
        light = "l",
        dark = "k",
      },
    }

    original_keymap_set = vim.keymap.set
    vim.keymap.set = function(_, lhs, callback, _)
      mapped_callbacks[lhs] = callback
    end

    original_ui_open = vim.ui.open
    vim.ui.open = function(url)
      table.insert(opened_urls, url)
      return true
    end

    original_setreg = vim.fn.setreg
    vim.fn.setreg = function(register, value)
      setreg_calls[register] = value
    end
  end)

  after_each(function()
    vim.keymap.set = original_keymap_set
    vim.ui.open = original_ui_open
    vim.fn.setreg = original_setreg

    if last_popup then
      last_popup:unmount()
    end

    test_utils.restore_all(modules)
  end)

  it("copies and opens the selected repository URL", function()
    local picker = require(module_name)
    picker.pick()

    assert.is_not_nil(mapped_callbacks["Y"])
    assert.is_not_nil(mapped_callbacks["O"])

    mapped_callbacks["Y"]()
    assert.equals("https://github.com/folke/tokyonight.nvim", setreg_calls["+"])
    assert.equals("https://github.com/folke/tokyonight.nvim", setreg_calls['"'])

    mapped_callbacks["O"]()
    assert.equals(1, #opened_urls)
    assert.equals("https://github.com/folke/tokyonight.nvim", opened_urls[1])
  end)

  it("marks theme after install key succeeds", function()
    local picker = require(module_name)
    picker.pick()

    assert.is_not_nil(mapped_callbacks["i"])
    mapped_callbacks["i"]()

    vim.wait(100)

    assert.equals(1, #mark_calls)
    assert.equals("tokyonight", mark_calls[1].name)
    assert.equals("night", mark_calls[1].variant)
  end)
end)
