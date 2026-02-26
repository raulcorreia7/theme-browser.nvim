describe("theme-browser.registry.sync", function()
  local module_name = "theme-browser.registry.sync"
  local sync
  local original_vim_system
  local _schedule_queue = {}
  local schedule_depth = 0
  local max_depth = 100

  local function reload_sync()
    package.loaded[module_name] = nil
    sync = require(module_name)
    return sync
  end

  local function mock_vim_system(responses)
    local call_count = 0
    return function(_cmd, _opts, callback)
      call_count = call_count + 1
      local response = responses[call_count] or responses[#responses]
      if callback then
        vim.schedule(function()
          callback(response)
        end)
      end
    end
  end

  local function with_temp_cache_dir(fn)
    local temp_dir = vim.fn.tempname()
    vim.fn.mkdir(temp_dir, "p")

    local tb_module = "theme-browser"
    local original_tb = package.loaded[tb_module]
    package.loaded[tb_module] = {
      get_config = function()
        return { cache_dir = temp_dir }
      end,
    }

    local ok, err = pcall(fn, temp_dir)

    package.loaded[tb_module] = original_tb
    vim.fn.delete(temp_dir, "rf")

    if not ok then
      error(err)
    end
  end

  local function wait_for_result(timeout_ms)
    timeout_ms = timeout_ms or 2000
    local start = vim.loop.hrtime()
    local result = nil

    while not result do
      local elapsed = (vim.loop.hrtime() - start) / 1e6
      if elapsed > timeout_ms then
        return nil, "timeout"
      end
      vim.wait(10)
    end

    return result
  end

  before_each(function()
    original_vim_system = vim.system
    _schedule_queue = {}
  end)

  after_each(function()
    vim.system = original_vim_system
    if sync then
      sync.clear_synced_registry()
    end
  end)

  describe("is_fresh_manifest", function()
    it("returns true when sha256 hashes match", function()
      local cached_manifest = { sha256 = "abc123", count = 10 }
      local remote_manifest = { sha256 = "abc123", count = 10 }

      with_temp_cache_dir(function(cache_dir)
        vim.fn.writefile(
          { vim.json.encode(cached_manifest) },
          cache_dir .. "/registry-manifest.json"
        )

        vim.system = mock_vim_system({
          { code = 0, stdout = vim.json.encode(remote_manifest) },
        })

        local result = nil
        reload_sync().sync({ notify = false }, function(success, message)
          result = { success = success, message = message }
        end)

        vim.wait(500, function()
          return result ~= nil
        end)

        assert.is_not_nil(result)
        assert.is_true(result.success)
        assert.equals("up_to_date", result.message)
      end)
    end)

    it("returns false when sha256 hashes differ", function()
      local cached_manifest = { sha256 = "abc123", count = 10 }
      local remote_manifest = { sha256 = "xyz789", count = 10 }

      with_temp_cache_dir(function(cache_dir)
        vim.fn.writefile(
          { vim.json.encode(cached_manifest) },
          cache_dir .. "/registry-manifest.json"
        )

        vim.system = mock_vim_system({
          { code = 0, stdout = vim.json.encode(remote_manifest) },
          { code = 0, stdout = vim.json.encode({ { name = "test" } }) },
        })

        local result = nil
        reload_sync().sync({ notify = false }, function(success, message)
          result = { success = success, message = message }
        end)

        vim.wait(500, function()
          return result ~= nil
        end)

        assert.is_not_nil(result)
        assert.is_true(result.success)
        assert.equals("updated", result.message)
      end)
    end)

    it("returns false when cached manifest is missing", function()
      local remote_manifest = { sha256 = "abc123", count = 10 }

      with_temp_cache_dir(function(_cache_dir)
        vim.system = mock_vim_system({
          { code = 0, stdout = vim.json.encode(remote_manifest) },
          { code = 0, stdout = vim.json.encode({ { name = "test" } }) },
        })

        local result = nil
        reload_sync().sync({ notify = false }, function(success, message)
          result = { success = success, message = message }
        end)

        vim.wait(500, function()
          return result ~= nil
        end)

        assert.is_not_nil(result)
        assert.is_true(result.success)
        assert.equals("updated", result.message)
      end)
    end)

    it("compares by generated_at and count when sha256 missing", function()
      local cached_manifest = { generated_at = "2024-01-02", count = 10 }
      local remote_manifest = { generated_at = "2024-01-01", count = 10 }

      with_temp_cache_dir(function(cache_dir)
        vim.fn.writefile(
          { vim.json.encode(cached_manifest) },
          cache_dir .. "/registry-manifest.json"
        )
        vim.fn.writefile(
          { vim.json.encode({ { name = "existing" } }) },
          cache_dir .. "/registry-full.json"
        )

        vim.system = mock_vim_system({
          { code = 0, stdout = vim.json.encode(remote_manifest) },
        })

        local result = nil
        reload_sync().sync({ notify = false }, function(success, message)
          result = { success = success, message = message }
        end)

        vim.wait(500, function()
          return result ~= nil
        end)

        assert.is_not_nil(result)
        assert.is_true(result.success)
        assert.equals("up_to_date", result.message)
      end)
    end)
  end)

  describe("fetch_url_async", function()
    it("returns data when curl succeeds (vim.system path)", function()
      with_temp_cache_dir(function(_cache_dir)
        vim.system = mock_vim_system({
          { code = 0, stdout = vim.json.encode({ sha256 = "abc", count = 1 }) },
          { code = 0, stdout = vim.json.encode({ { name = "tokyonight" } }) },
        })

        local result = nil
        reload_sync().sync({ notify = false }, function(success, message, count)
          result = { success = success, message = message, count = count }
        end)

        vim.wait(500, function()
          return result ~= nil
        end)

        assert.is_not_nil(result)
        assert.is_true(result.success)
        assert.equals("updated", result.message)
        assert.equals(1, result.count)
      end)
    end)

    it("handles curl errors with stderr (vim.system path)", function()
      with_temp_cache_dir(function(_cache_dir)
        vim.system = mock_vim_system({
          { code = 22, stdout = "", stderr = "Connection failed" },
        })

        local result = nil
        reload_sync().sync({ notify = false }, function(success, message)
          result = { success = success, message = message }
        end)

        vim.wait(500, function()
          return result ~= nil
        end)

        assert.is_not_nil(result)
        assert.is_false(result.success)
        assert.equals("manifest fetch failed", result.message)
      end)
    end)

    it("handles curl errors without stderr (vim.system path)", function()
      with_temp_cache_dir(function(_cache_dir)
        vim.system = mock_vim_system({
          { code = 22, stdout = "", stderr = nil },
        })

        local result = nil
        reload_sync().sync({ notify = false }, function(success, message)
          result = { success = success, message = message }
        end)

        vim.wait(500, function()
          return result ~= nil
        end)

        assert.is_not_nil(result)
        assert.is_false(result.success)
        assert.equals("manifest fetch failed", result.message)
      end)
    end)
  end)

  describe("sync function", function()
    it("downloads and caches registry when no cached manifest exists", function()
      with_temp_cache_dir(function(cache_dir)
        vim.system = mock_vim_system({
          { code = 0, stdout = vim.json.encode({ sha256 = "abc123", count = 5 }) },
          {
            code = 0,
            stdout = vim.json.encode({
              { name = "tokyonight", repo = "folke/tokyonight.nvim", colorscheme = "tokyonight" },
            }),
          },
        })

        local result = nil
        reload_sync().sync({ notify = false }, function(success, message, count)
          result = { success = success, message = message, count = count }
        end)

        vim.wait(500, function()
          return result ~= nil
        end)

        assert.is_not_nil(result)
        assert.is_true(result.success)
        assert.equals("updated", result.message)
        assert.equals(1, result.count)

        assert.equals(1, vim.fn.filereadable(cache_dir .. "/registry-full.json"))
        assert.equals(1, vim.fn.filereadable(cache_dir .. "/registry-manifest.json"))
      end)
    end)

    it("skips download when cached manifest matches remote", function()
      with_temp_cache_dir(function(cache_dir)
        local cached_manifest = { sha256 = "abc123", count = 5 }
        local remote_manifest = { sha256 = "abc123", count = 5 }

        vim.fn.writefile(
          { vim.json.encode(cached_manifest) },
          cache_dir .. "/registry-manifest.json"
        )
        vim.fn.writefile(
          { vim.json.encode({ { name = "existing" } }) },
          cache_dir .. "/registry-full.json"
        )

        vim.system = mock_vim_system({
          { code = 0, stdout = vim.json.encode(remote_manifest) },
        })

        local result = nil
        reload_sync().sync({ notify = false }, function(success, message)
          result = { success = success, message = message }
        end)

        vim.wait(500, function()
          return result ~= nil
        end)

        assert.is_not_nil(result)
        assert.is_true(result.success)
        assert.equals("up_to_date", result.message)
      end)
    end)

    it("forces download when force option is true", function()
      with_temp_cache_dir(function(cache_dir)
        local cached_manifest = { sha256 = "abc123", count = 5 }
        local remote_manifest = { sha256 = "abc123", count = 5 }

        vim.fn.writefile(
          { vim.json.encode(cached_manifest) },
          cache_dir .. "/registry-manifest.json"
        )

        vim.system = mock_vim_system({
          { code = 0, stdout = vim.json.encode(remote_manifest) },
          { code = 0, stdout = vim.json.encode({ { name = "forced" } }) },
        })

        local result = nil
        reload_sync().sync({ notify = false, force = true }, function(success, message, count)
          result = { success = success, message = message, count = count }
        end)

        vim.wait(500, function()
          return result ~= nil
        end)

        assert.is_not_nil(result)
        assert.is_true(result.success)
        assert.equals("updated", result.message)
        assert.equals(1, result.count)
      end)
    end)

    it("handles invalid manifest JSON", function()
      with_temp_cache_dir(function(_cache_dir)
        vim.system = mock_vim_system({
          { code = 0, stdout = "not valid json" },
        })

        local result = nil
        reload_sync().sync({ notify = false }, function(success, message)
          result = { success = success, message = message }
        end)

        vim.wait(500, function()
          return result ~= nil
        end)

        assert.is_not_nil(result)
        assert.is_false(result.success)
        assert.equals("invalid manifest", result.message)
      end)
    end)

    it("handles invalid registry JSON", function()
      with_temp_cache_dir(function(_cache_dir)
        vim.system = mock_vim_system({
          { code = 0, stdout = vim.json.encode({ sha256 = "abc", count = 1 }) },
          { code = 0, stdout = "not valid json" },
        })

        local result = nil
        reload_sync().sync({ notify = false }, function(success, message)
          result = { success = success, message = message }
        end)

        vim.wait(500, function()
          return result ~= nil
        end)

        assert.is_not_nil(result)
        assert.is_false(result.success)
        assert.equals("invalid registry", result.message)
      end)
    end)

    it("handles registry download failure", function()
      with_temp_cache_dir(function(_cache_dir)
        vim.system = mock_vim_system({
          { code = 0, stdout = vim.json.encode({ sha256 = "abc", count = 1 }) },
          { code = 22, stderr = "download failed" },
        })

        local result = nil
        reload_sync().sync({ notify = false }, function(success, message)
          result = { success = success, message = message }
        end)

        vim.wait(500, function()
          return result ~= nil
        end)

        assert.is_not_nil(result)
        assert.is_false(result.success)
        assert.equals("registry download failed", result.message)
      end)
    end)

    it("uses custom registry and manifest URLs", function()
      with_temp_cache_dir(function(_cache_dir)
        local urls_requested = {}
        local call_count = 0

        vim.system = function(cmd, _opts, callback)
          table.insert(urls_requested, cmd[#cmd])
          call_count = call_count + 1
          local response
          if call_count == 1 then
            response = { code = 0, stdout = vim.json.encode({ sha256 = "abc", count = 1 }) }
          else
            response = { code = 0, stdout = vim.json.encode({ { name = "custom" } }) }
          end
          if callback then
            vim.schedule(function()
              callback(response)
            end)
          end
        end

        local result = nil
        reload_sync().sync({
          notify = false,
          registry_url = "https://example.com/custom-registry.json",
          manifest_url = "https://example.com/custom-manifest.json",
        }, function(success, message)
          result = { success = success, message = message }
        end)

        vim.wait(500, function()
          return result ~= nil
        end)

        assert.is_not_nil(result)
        assert.is_true(result.success)
        assert.equals("https://example.com/custom-manifest.json", urls_requested[1])
        assert.equals("https://example.com/custom-registry.json", urls_requested[2])
      end)
    end)
  end)

  describe("registry path helpers", function()
    it("has_synced_registry returns false when no cached registry", function()
      with_temp_cache_dir(function(_cache_dir)
        reload_sync()
        assert.is_false(sync.has_synced_registry())
      end)
    end)

    it("has_synced_registry returns true after successful sync", function()
      with_temp_cache_dir(function(_cache_dir)
        vim.system = mock_vim_system({
          { code = 0, stdout = vim.json.encode({ sha256 = "abc", count = 1 }) },
          { code = 0, stdout = vim.json.encode({ { name = "test" } }) },
        })

        local done = false
        reload_sync().sync({ notify = false }, function()
          done = true
        end)

        vim.wait(500, function()
          return done
        end)

        assert.is_true(sync.has_synced_registry())
      end)
    end)

    it("get_synced_registry_path returns nil when no cache", function()
      with_temp_cache_dir(function(_cache_dir)
        reload_sync()
        assert.is_nil(sync.get_synced_registry_path())
      end)
    end)

    it("get_synced_registry_path returns path after sync", function()
      with_temp_cache_dir(function(cache_dir)
        vim.system = mock_vim_system({
          { code = 0, stdout = vim.json.encode({ sha256 = "abc", count = 1 }) },
          { code = 0, stdout = vim.json.encode({ { name = "test" } }) },
        })

        local done = false
        reload_sync().sync({ notify = false }, function()
          done = true
        end)

        vim.wait(500, function()
          return done
        end)

        local path = sync.get_synced_registry_path()
        assert.is_not_nil(path)
        assert.is_truthy(path:find("registry%-full%.json"))
      end)
    end)

    it("clear_synced_registry removes cached files", function()
      with_temp_cache_dir(function(cache_dir)
        vim.system = mock_vim_system({
          { code = 0, stdout = vim.json.encode({ sha256 = "abc", count = 1 }) },
          { code = 0, stdout = vim.json.encode({ { name = "test" } }) },
        })

        local done = false
        reload_sync().sync({ notify = false }, function()
          done = true
        end)

        vim.wait(500, function()
          return done
        end)

        assert.is_true(sync.has_synced_registry())

        sync.clear_synced_registry()

        assert.is_false(sync.has_synced_registry())
        assert.is_nil(sync.get_synced_registry_path())
        assert.equals(0, vim.fn.filereadable(cache_dir .. "/registry-full.json"))
        assert.equals(0, vim.fn.filereadable(cache_dir .. "/registry-manifest.json"))
      end)
    end)
  end)

  describe("version compatibility", function()
    it("accepts matching version", function()
      with_temp_cache_dir(function(_cache_dir)
        vim.system = mock_vim_system({
          { code = 0, stdout = vim.json.encode({ sha256 = "abc", count = 1, version = "0.1.0" }) },
          { code = 0, stdout = vim.json.encode({ { name = "test" } }) },
        })

        local result = nil
        reload_sync().sync({ notify = false }, function(success, message)
          result = { success = success, message = message }
        end)

        vim.wait(500, function()
          return result ~= nil
        end)

        assert.is_not_nil(result)
        assert.is_true(result.success)
      end)
    end)
  end)
end)
