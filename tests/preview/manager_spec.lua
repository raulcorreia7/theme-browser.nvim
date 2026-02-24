describe("theme-browser.preview.manager", function()
  local module_name = "theme-browser.preview.manager"
  local original_rtp

  before_each(function()
    original_rtp = vim.o.runtimepath
    package.loaded[module_name] = nil
    package.loaded["theme-browser.downloader.github"] = {
      get_cache_path = function(_, _)
        return "/tmp/theme-browser-preview-cache"
      end,
      is_cached = function(_, _)
        return true
      end,
    }
    package.loaded["theme-browser"] = {
      get_config = function()
        return { cache_dir = "/tmp" }
      end,
    }
    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(_, _, _)
        return { ok = true, name = "tokyonight", colorscheme = "tokyonight-night" }
      end,
    }
    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function(_, _)
        return { name = "tokyonight", repo = "folke/tokyonight.nvim", variant = "tokyonight-night" }
      end,
    }
    package.loaded["theme-browser.package_manager.manager"] = {
      load_entry = function(_)
        return false
      end,
    }
  end)

  after_each(function()
    vim.o.runtimepath = original_rtp
    package.loaded[module_name] = nil
    package.loaded["theme-browser.downloader.github"] = nil
    package.loaded["theme-browser"] = nil
    package.loaded["theme-browser.adapters.base"] = nil
    package.loaded["theme-browser.adapters.registry"] = nil
    package.loaded["theme-browser.package_manager.manager"] = nil
  end)

  it("tracks and clears preview records", function()
    local preview = require(module_name)
    preview.create_preview("tokyonight", "tokyonight-night")
    local active = preview.list_previews()
    assert.equals(1, #active)
    assert.equals("tokyonight", active[1].name)

    preview.cleanup()
    assert.equals(0, #preview.list_previews())
  end)
end)
