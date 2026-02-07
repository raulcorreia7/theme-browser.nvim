describe("theme-browser.downloader.cache", function()
  local original_stdpath = vim.fn.stdpath
  local previous_theme_browser
  local previous_state
  local previous_delete
  local temp_root
  local config

  before_each(function()
    temp_root = vim.fn.tempname()
    vim.fn.mkdir(temp_root, "p")
    vim.fn.stdpath = function(kind)
      if kind == "cache" then
        return temp_root .. "/cache"
      elseif kind == "data" then
        return temp_root .. "/data"
      elseif kind == "config" then
        return temp_root .. "/config"
      end
      return original_stdpath(kind)
    end

    previous_theme_browser = package.loaded["theme-browser"]
    previous_state = package.loaded["theme-browser.persistence.state"]

    config = {
      cache_dir = temp_root .. "/cache/theme-browser",
      cache = {
        auto_cleanup = true,
        cleanup_interval_days = 7,
      },
    }

    package.loaded["theme-browser"] = {
      get_config = function()
        return config
      end,
    }

    package.loaded["theme-browser.persistence.state"] = {
      get_cache_stats = function()
        return { hits = 0, misses = 0 }
      end,
      increment_cache_hit = function() end,
      increment_cache_miss = function() end,
    }

    package.loaded["theme-browser.downloader.cache"] = nil
    previous_delete = vim.fn.delete
  end)

  after_each(function()
    vim.fn.stdpath = original_stdpath
    package.loaded["theme-browser"] = previous_theme_browser
    package.loaded["theme-browser.persistence.state"] = previous_state
    package.loaded["theme-browser.downloader.cache"] = nil
    vim.fn.delete = previous_delete
    if temp_root and vim.fn.isdirectory(temp_root) == 1 then
      vim.fn.delete(temp_root, "rf")
    end
  end)

  it("clear_all returns success when delete returns zero", function()
    local cache = require("theme-browser.downloader.cache")
    vim.fn.delete = function(_, _)
      return 0
    end

    local ok, err = cache.clear_all({ notify = false })
    assert.is_true(ok)
    assert.is_nil(err)
  end)

  it("clear_all returns failure when delete returns non-zero", function()
    local cache = require("theme-browser.downloader.cache")
    vim.fn.delete = function(_, _)
      return 1
    end

    local ok, err = cache.clear_all({ notify = false })
    assert.is_false(ok)
    assert.is_truthy(type(err) == "string" and err:find("delete returned", 1, true) ~= nil)
  end)

  it("maybe_cleanup runs once and skips until interval elapses", function()
    local cache = require("theme-browser.downloader.cache")
    local delete_calls = 0
    vim.fn.delete = function(_, _)
      delete_calls = delete_calls + 1
      return 0
    end

    local cleaned, err = cache.maybe_cleanup({ notify = false })
    assert.is_true(cleaned)
    assert.is_nil(err)

    local cleaned_again, reason = cache.maybe_cleanup({ notify = false })
    assert.is_false(cleaned_again)
    assert.equals("not_due", reason)
    assert.equals(1, delete_calls)
  end)

  it("maybe_cleanup can be disabled", function()
    config.cache.auto_cleanup = false
    local cache = require("theme-browser.downloader.cache")
    local delete_calls = 0
    vim.fn.delete = function(_, _)
      delete_calls = delete_calls + 1
      return 0
    end

    local cleaned, reason = cache.maybe_cleanup({ notify = false })
    assert.is_false(cleaned)
    assert.equals("disabled", reason)
    assert.equals(0, delete_calls)
  end)
end)
