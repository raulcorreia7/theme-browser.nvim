describe("theme-browser.persistence.state formatting", function()
  local state_module = "theme-browser.persistence.state"
  local github_module = "theme-browser.downloader.github"

  local previous_state
  local previous_github

  before_each(function()
    previous_state = package.loaded[state_module]
    previous_github = package.loaded[github_module]
    package.loaded[state_module] = nil
  end)

  after_each(function()
    package.loaded[state_module] = previous_state
    package.loaded[github_module] = previous_github
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
