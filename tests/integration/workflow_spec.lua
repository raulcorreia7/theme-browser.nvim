describe("Integration: workflow", function()
  local original_stdpath = vim.fn.stdpath
  local temp_root

  local function reset_modules()
    package.loaded["theme-browser"] = nil
    package.loaded["theme-browser.adapters.registry"] = nil
    package.loaded["theme-browser.adapters.factory"] = nil
    package.loaded["theme-browser.adapters.base"] = nil
    package.loaded["theme-browser.persistence.state"] = nil
    package.loaded["theme-browser.persistence.lazy_spec"] = nil
    package.loaded["theme-browser.preview.manager"] = nil
    package.loaded["theme-browser.application.theme_service"] = nil
    package.loaded["theme-browser.runtime.loader"] = nil
  end

  local function write_file(path, lines)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile(lines, path)
  end

  local function make_registry(path)
    write_file(path, {
      vim.json.encode({
        {
          name = "tokyonight",
          repo = "folke/tokyonight.nvim",
          colorscheme = "tokyonight",
          variants = { "tokyonight-night" },
          meta = { strategy = "colorscheme_only" },
        },
      }),
    })
  end

  before_each(function()
    temp_root = vim.fn.tempname()
    vim.fn.mkdir(temp_root, "p")
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
    reset_modules()
  end)

  after_each(function()
    vim.fn.stdpath = original_stdpath
    reset_modules()
    if temp_root and vim.fn.isdirectory(temp_root) == 1 then
      vim.fn.delete(temp_root, "rf")
    end
  end)

  it("supports mark -> preview -> install flow", function()
    local registry_path = temp_root .. "/registry.json"
    make_registry(registry_path)

    local state = require("theme-browser.persistence.state")
    state.initialize({ package_manager = { enabled = false, mode = "plugin_only" } })

    local registry = require("theme-browser.adapters.registry")
    registry.initialize(registry_path)

    local preview_calls = {}
    package.loaded["theme-browser.adapters.base"] = {
      load_theme = function(name, variant, opts)
        opts = opts or {}
        if opts.preview then
          table.insert(preview_calls, { name = name, variant = variant })
        else
          state.set_current_theme(name, variant)
        end
        return {
          ok = true,
          name = name,
          variant = variant,
          colorscheme = variant or name,
        }
      end,
    }

    package.loaded["theme-browser.runtime.loader"] = {
      ensure_available = function(_, _, _, callback)
        callback(true, nil, nil)
      end,
    }

    state.mark_theme("tokyonight")
    local marked = state.get_marked_theme()
    assert.is_not_nil(marked)
    assert.equals("tokyonight", marked.name)
    assert.is_nil(marked.variant)

    package.loaded["theme-browser.downloader.github"] = {
      is_cached = function(_, _)
        return false
      end,
      get_cache_path = function(_, cache_dir)
        return cache_dir .. "/tokyonight.nvim"
      end,
      download = function(_, _, callback, _)
        callback(true, nil)
      end,
    }

    local service = require("theme-browser.application.theme_service")
    service.preview("tokyonight", "tokyonight-night", { notify = false })

    assert.equals(1, #preview_calls)
    assert.is_nil(state.get_current_theme())

    local spec_file = service.install("tokyonight", "tokyonight-night", { notify = false })
    assert.equals(1, vim.fn.filereadable(spec_file))
    assert.is_nil(state.get_current_theme())

    service.apply("tokyonight", "tokyonight-night", { notify = false })
    local current = state.get_current_theme()
    assert.equals("tokyonight", current.name)
    assert.equals("tokyonight-night", current.variant)

    local content = table.concat(vim.fn.readfile(spec_file), "\n")
    assert.is_truthy(content:find("folke/tokyonight.nvim", 1, true))
  end)

  it("registry search returns all themes on empty query", function()
    local registry_path = temp_root .. "/registry.json"
    make_registry(registry_path)

    local registry = require("theme-browser.adapters.registry")
    registry.initialize(registry_path)

    local all_themes = registry.list_themes()
    local search_results = registry.search_themes("")
    assert.equals(#all_themes, #search_results)
  end)
end)
