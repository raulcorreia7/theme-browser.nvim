describe("theme-browser.persistence.state", function()
  local original_stdpath = vim.fn.stdpath
  local temp_root

  local function reset_state_module()
    package.loaded["theme-browser.persistence.state"] = nil
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
    reset_state_module()
  end)

  after_each(function()
    vim.fn.stdpath = original_stdpath
    reset_state_module()
    if temp_root and vim.fn.isdirectory(temp_root) == 1 then
      vim.fn.delete(temp_root, "rf")
    end
  end)

  it("loads default state on initialize", function()
    local state = require("theme-browser.persistence.state")
    state.initialize({ auto_load = false })

    assert.is_nil(state.get_current_theme())
    local pm = state.get_package_manager()
    assert.is_false(pm.enabled)
    assert.equals("installed_only", pm.mode)
  end)

  it("saves and reloads selected theme", function()
    local state = require("theme-browser.persistence.state")
    state.initialize({})

    state.set_current_theme("test-theme", "variant1")
    vim.wait(250)

    state.load()
    local current = state.get_current_theme()
    assert.equals("test-theme", current.name)
    assert.equals("variant1", current.variant)
  end)

  it("saves and reloads startup theme metadata", function()
    local state = require("theme-browser.persistence.state")
    state.initialize({})

    state.set_startup_theme({
      name = "tokyonight",
      variant = "tokyonight-night",
      colorscheme = "tokyonight-night",
      repo = "folke/tokyonight.nvim",
    })
    vim.wait(250)

    state.load()
    local startup = state.get_startup_theme()
    assert.is_not_nil(startup)
    assert.equals("tokyonight", startup.name)
    assert.equals("tokyonight-night", startup.variant)
    assert.equals("tokyonight-night", startup.colorscheme)
    assert.equals("folke/tokyonight.nvim", startup.repo)
  end)

  it("loads legacy state file when startup_theme is missing", function()
    local state_file = temp_root .. "/data/theme-browser/state.json"
    vim.fn.mkdir(vim.fn.fnamemodify(state_file, ":h"), "p")
    vim.fn.writefile({
      vim.json.encode({
        current_theme = { name = "legacy-theme", variant = "" },
        marked_theme = "legacy-theme",
        theme_history = { "older-theme" },
        cache_stats = { hits = 3, misses = 1 },
        package_manager = { enabled = true, mode = "auto" },
      }),
    }, state_file)

    local state = require("theme-browser.persistence.state")
    state.load()

    local current = state.get_current_theme()
    assert.is_not_nil(current)
    assert.equals("legacy-theme", current.name)
    assert.is_nil(current.variant)
    assert.is_nil(state.get_startup_theme())

    local marked = state.get_marked_theme()
    assert.is_not_nil(marked)
    assert.equals("legacy-theme", marked.name)
    assert.is_nil(marked.variant)
  end)

  it("tracks mark and unmark", function()
    local state = require("theme-browser.persistence.state")
    state.initialize({})

    state.mark_theme("marked-theme", "night")
    local marked = state.get_marked_theme()
    assert.is_not_nil(marked)
    assert.equals("marked-theme", marked.name)
    assert.equals("night", marked.variant)

    state.unmark_theme()
    assert.is_nil(state.get_marked_theme())
  end)

  it("tracks recent history", function()
    local state = require("theme-browser.persistence.state")
    state.initialize({})

    state.set_current_theme("theme1", nil)
    state.set_current_theme("theme2", nil)
    state.set_current_theme("theme3", nil)

    local history = state.get_history()
    assert.equals(2, #history)
    assert.equals("theme2", history[1])
    assert.equals("theme1", history[2])
  end)

  it("increments cache hit/miss counters", function()
    local state = require("theme-browser.persistence.state")
    state.initialize({})

    state.increment_cache_hit()
    state.increment_cache_hit()
    state.increment_cache_miss()

    local stats = state.get_cache_stats()
    assert.equals(2, stats.hits)
    assert.equals(1, stats.misses)
  end)

  it("resets state to defaults", function()
    local state = require("theme-browser.persistence.state")
    state.initialize({})

    state.set_current_theme("tokyonight", "night")
    state.mark_theme("tokyonight")
    state.increment_cache_hit()
    state.increment_cache_miss()
    vim.wait(250)

    state.reset()

    assert.is_nil(state.get_current_theme())
    assert.is_nil(state.get_marked_theme())
    local stats = state.get_cache_stats()
    assert.equals(0, stats.hits)
    assert.equals(0, stats.misses)
  end)

  it("matches marked state by variant when marked variant exists", function()
    local state = require("theme-browser.persistence.state")
    state.initialize({})
    state.mark_theme("tokyonight", "night")

    local matching_entry = {
      name = "tokyonight",
      variant = "night",
      repo = "folke/tokyonight.nvim",
    }
    local different_variant = {
      name = "tokyonight",
      variant = "storm",
      repo = "folke/tokyonight.nvim",
    }

    local matching_state = state.get_entry_state(matching_entry)
    local different_state = state.get_entry_state(different_variant)
    assert.is_true(matching_state.marked)
    assert.is_false(different_state.marked)
  end)
end)
