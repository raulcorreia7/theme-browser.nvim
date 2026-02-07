describe("theme-browser.startup.persistence", function()
  local module_name = "theme-browser.startup.persistence"
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
    snapshot("theme-browser.startup.config")
    snapshot("theme-browser.persistence.state")
    snapshot("theme-browser.persistence.lazy_spec")
    snapshot("theme-browser.adapters.registry")

    package.loaded[module_name] = nil
  end)

  after_each(function()
    restore(module_name)
    restore("theme-browser.startup.config")
    restore("theme-browser.persistence.state")
    restore("theme-browser.persistence.lazy_spec")
    restore("theme-browser.adapters.registry")
  end)

  it("does not write managed startup spec when write_spec is disabled", function()
    local startup_state_calls = 0
    local spec_calls = 0

    package.loaded["theme-browser.startup.config"] = {
      from_runtime = function()
        return {
          enabled = true,
          write_spec = false,
          skip_if_already_active = true,
        }
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      set_startup_theme = function(_)
        startup_state_calls = startup_state_calls + 1
      end,
    }

    package.loaded["theme-browser.persistence.lazy_spec"] = {
      generate_spec = function(_, _, _)
        spec_calls = spec_calls + 1
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function(_, _)
        return { name = "tokyonight", variant = "night", colorscheme = "tokyonight-night" }
      end,
    }

    local persistence = require(module_name)
    persistence.persist_applied_theme("tokyonight", "night", "tokyonight-night", {})

    assert.equals(1, startup_state_calls)
    assert.equals(0, spec_calls)
  end)

  it("writes managed startup spec when write_spec is enabled", function()
    local startup_state_calls = 0
    local spec_calls = 0

    package.loaded["theme-browser.startup.config"] = {
      from_runtime = function()
        return {
          enabled = true,
          write_spec = true,
          skip_if_already_active = true,
        }
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      set_startup_theme = function(_)
        startup_state_calls = startup_state_calls + 1
      end,
    }

    package.loaded["theme-browser.persistence.lazy_spec"] = {
      generate_spec = function(_, _, _)
        spec_calls = spec_calls + 1
      end,
    }

    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function(_, _)
        return { name = "tokyonight", variant = "night", colorscheme = "tokyonight-night" }
      end,
    }

    local persistence = require(module_name)
    persistence.persist_applied_theme("tokyonight", "night", "tokyonight-night", {})

    assert.equals(1, startup_state_calls)
    assert.equals(1, spec_calls)
  end)

end)
