describe("theme-browser.ui.state_labels", function()
  local module_name = "theme-browser.ui.state_labels"

  before_each(function()
    package.loaded[module_name] = nil
  end)

  after_each(function()
    package.loaded[module_name] = nil
  end)

  it("formats readable state labels in expected order", function()
    local labels = require(module_name)
    local state = {
      get_entry_state = function(_, _)
        return {
          active = true,
          installed = true,
          cached = true,
          marked = true,
        }
      end,
    }

    local result = labels.format_readable_states(state, { name = "tokyonight" }, nil)
    assert.equals("Current, Installed, Downloaded, Marked", result)
  end)

  it("returns Available when no state is active", function()
    local labels = require(module_name)
    local state = {
      get_entry_state = function(_, _)
        return {
          active = false,
          installed = false,
          cached = false,
          marked = false,
        }
      end,
    }

    local result = labels.format_readable_states(state, { name = "tokyonight" }, nil)
    assert.equals("Available", result)
  end)
end)
