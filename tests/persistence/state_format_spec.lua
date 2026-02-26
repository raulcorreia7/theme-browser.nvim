local test_utils = require("tests.helpers.test_utils")

describe("theme-browser.persistence.state formatting", function()
  local state_module = "theme-browser.persistence.state"
  local github_module = "theme-browser.downloader.github"
  local modules = { state_module, github_module }

  before_each(function()
    test_utils.reset_all(modules)
  end)

  after_each(function()
    test_utils.restore_all(modules)
  end)

  it("shows readable full state labels", function()
    package.loaded[github_module] = {
      is_cached = function(_, _)
        return true
      end,
    }

    local state = require(state_module)
    state.initialize({ auto_load = false })
    state.set_current_theme("demo-theme", "night")
    state.mark_theme("demo-theme", "night")

    local entry = {
      name = "demo-theme",
      variant = "night",
      repo = "owner/repo-not-installed",
    }

    local labels = state.format_entry_states(entry, { all = true, pretty = true })
    assert.is_truthy(labels:find("Current", 1, true))
    assert.is_truthy(labels:find("Installed", 1, true))
    assert.is_truthy(labels:find("Downloaded", 1, true))
    assert.is_truthy(labels:find("Marked", 1, true))
  end)

  it("shows Available when no state is active", function()
    package.loaded[github_module] = {
      is_cached = function(_, _)
        return false
      end,
    }

    local state = require(state_module)
    state.initialize({ auto_load = false })
    state.unmark_theme()
    state.set_current_theme("different-theme", nil)

    local entry = {
      name = "not-selected",
      variant = nil,
      repo = "owner/repo-not-installed",
    }

    local labels = state.format_entry_states(entry, { all = false, pretty = true })
    assert.equals("Available", labels)
  end)
end)
