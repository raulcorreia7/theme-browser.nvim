describe("theme-browser.startup.config", function()
  local module_name = "theme-browser.startup.config"
  local snapshots = {}

  local function snapshot(name)
    snapshots[name] = package.loaded[name]
  end

  local function restore(name)
    local previous = snapshots[name]
    if previous == nil then
      package.loaded[name] = nil
    else
      package.loaded[name] = previous
    end
  end

  before_each(function()
    snapshots = {}
    snapshot(module_name)
    snapshot("theme-browser")
    package.loaded[module_name] = nil
    package.loaded["theme-browser"] = nil
  end)

  after_each(function()
    restore(module_name)
    restore("theme-browser")
  end)

  it("resolves startup defaults when config is missing", function()
    local startup_config = require(module_name)
    local resolved = startup_config.resolve(nil)

    assert.is_true(resolved.enabled)
    assert.is_true(resolved.write_spec)
    assert.is_true(resolved.skip_if_already_active)
  end)

  it("resolves partial startup table with defaults", function()
    local startup_config = require(module_name)
    local resolved = startup_config.resolve({
      startup = {
        enabled = false,
      },
    })

    assert.is_false(resolved.enabled)
    assert.is_true(resolved.write_spec)
    assert.is_true(resolved.skip_if_already_active)
  end)

  it("reads startup config from runtime theme-browser module", function()
    package.loaded["theme-browser"] = {
      get_config = function()
        return {
          startup = {
            enabled = true,
            write_spec = false,
            skip_if_already_active = false,
          },
        }
      end,
    }

    local startup_config = require(module_name)
    local resolved = startup_config.from_runtime()

    assert.is_true(resolved.enabled)
    assert.is_false(resolved.write_spec)
    assert.is_false(resolved.skip_if_already_active)
  end)

  it("falls back to defaults when runtime module is unavailable", function()
    package.loaded["theme-browser"] = nil

    local startup_config = require(module_name)
    local resolved = startup_config.from_runtime()

    assert.is_true(resolved.enabled)
    assert.is_true(resolved.write_spec)
    assert.is_true(resolved.skip_if_already_active)
  end)
end)
