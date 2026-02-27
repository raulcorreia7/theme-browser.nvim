describe("theme-browser.registry.sync", function()
  local module_name = "theme-browser.registry.sync"
  local test_utils = require("tests.helpers.test_utils")
  local sync
  local original_vim_system

  local function reload_sync()
    package.loaded[module_name] = nil
    sync = require(module_name)
    return sync
  end

  local function with_temp_cache_dir(fn)
    test_utils.with_temp_registry(nil, fn)
  end

  local function wait_for_sync_result(timeout_ms)
    local result = nil
    timeout_ms = timeout_ms or 500
    local cb = function(success, message, count)
      result = { success = success, message = message, count = count }
    end
    return cb,
      function()
        vim.wait(timeout_ms, function()
          return result ~= nil
        end)
        return result
      end
  end

  before_each(function()
    original_vim_system = vim.system
  end)

  after_each(function()
    vim.system = original_vim_system
    if sync then
      sync.clear_synced_registry()
    end
  end)

  describe("manifest freshness", function()
    it("returns up_to_date when sha256 hashes match", function()
      with_temp_cache_dir(function(cache_dir)
        vim.fn.writefile(
          { vim.json.encode({ sha256 = "abc123", count = 10 }) },
          cache_dir .. "/registry-manifest.json"
        )

        vim.system = test_utils.mock_vim_system({
          { code = 0, stdout = vim.json.encode({ sha256 = "abc123", count = 10 }) },
        })

        local cb, get_result = wait_for_sync_result()
        reload_sync().sync({ notify = false }, cb)
        local result = get_result()

        assert.is_not_nil(result)
        assert.is_true(result.success)
        assert.equals("up_to_date", result.message)
      end)
    end)

    it("returns updated when sha256 hashes differ", function()
      with_temp_cache_dir(function(cache_dir)
        vim.fn.writefile(
          { vim.json.encode({ sha256 = "abc123", count = 10 }) },
          cache_dir .. "/registry-manifest.json"
        )

        vim.system = test_utils.mock_vim_system({
          { code = 0, stdout = vim.json.encode({ sha256 = "xyz789", count = 10 }) },
          { code = 0, stdout = vim.json.encode({ { name = "test" } }) },
        })

        local cb, get_result = wait_for_sync_result()
        reload_sync().sync({ notify = false }, cb)
        local result = get_result()

        assert.is_not_nil(result)
        assert.is_true(result.success)
        assert.equals("updated", result.message)
      end)
    end)

    it("returns updated when cached manifest is missing", function()
      with_temp_cache_dir(function()
        vim.system = test_utils.mock_vim_system({
          { code = 0, stdout = vim.json.encode({ sha256 = "abc123", count = 10 }) },
          { code = 0, stdout = vim.json.encode({ { name = "test" } }) },
        })

        local cb, get_result = wait_for_sync_result()
        reload_sync().sync({ notify = false }, cb)
        local result = get_result()

        assert.is_not_nil(result)
        assert.is_true(result.success)
        assert.equals("updated", result.message)
      end)
    end)

    it("compares by generated_at and count when sha256 missing", function()
      with_temp_cache_dir(function(cache_dir)
        vim.fn.writefile(
          { vim.json.encode({ generated_at = "2024-01-02", count = 10 }) },
          cache_dir .. "/registry-manifest.json"
        )
        vim.fn.writefile({ vim.json.encode({ { name = "existing" } }) }, cache_dir .. "/registry-full.json")

        vim.system = test_utils.mock_vim_system({
          { code = 0, stdout = vim.json.encode({ generated_at = "2024-01-01", count = 10 }) },
        })

        local cb, get_result = wait_for_sync_result()
        reload_sync().sync({ notify = false }, cb)
        local result = get_result()

        assert.is_not_nil(result)
        assert.is_true(result.success)
        assert.equals("up_to_date", result.message)
      end)
    end)
  end)

  describe("download and cache", function()
    it("downloads and caches registry when no manifest exists", function()
      with_temp_cache_dir(function(cache_dir)
        vim.system = test_utils.mock_vim_system({
          { code = 0, stdout = vim.json.encode({ sha256 = "abc123", count = 5 }) },
          { code = 0, stdout = vim.json.encode({ { name = "tokyonight", repo = "folke/tokyonight.nvim" } }) },
        })

        local cb, get_result = wait_for_sync_result()
        reload_sync().sync({ notify = false }, cb)
        local result = get_result()

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
        local manifest = { sha256 = "abc123", count = 5 }
        vim.fn.writefile({ vim.json.encode(manifest) }, cache_dir .. "/registry-manifest.json")
        vim.fn.writefile({ vim.json.encode({ { name = "existing" } }) }, cache_dir .. "/registry-full.json")

        vim.system = test_utils.mock_vim_system({
          { code = 0, stdout = vim.json.encode(manifest) },
        })

        local cb, get_result = wait_for_sync_result()
        reload_sync().sync({ notify = false }, cb)
        local result = get_result()

        assert.is_true(result.success)
        assert.equals("up_to_date", result.message)
      end)
    end)

    it("forces download when force option is true", function()
      with_temp_cache_dir(function(cache_dir)
        local manifest = { sha256 = "abc123", count = 5 }
        vim.fn.writefile({ vim.json.encode(manifest) }, cache_dir .. "/registry-manifest.json")

        vim.system = test_utils.mock_vim_system({
          { code = 0, stdout = vim.json.encode(manifest) },
          { code = 0, stdout = vim.json.encode({ { name = "forced" } }) },
        })

        local cb, get_result = wait_for_sync_result()
        reload_sync().sync({ notify = false, force = true }, cb)
        local result = get_result()

        assert.is_true(result.success)
        assert.equals("updated", result.message)
        assert.equals(1, result.count)
      end)
    end)

    it("uses custom registry and manifest URLs", function()
      with_temp_cache_dir(function()
        local urls_requested = {}
        local call_count = 0

        vim.system = function(cmd, _opts, callback)
          table.insert(urls_requested, cmd[#cmd])
          call_count = call_count + 1
          local response = call_count == 1
              and { code = 0, stdout = vim.json.encode({ sha256 = "abc", count = 1 }) }
            or { code = 0, stdout = vim.json.encode({ { name = "custom" } }) }
          if callback then
            vim.schedule(function()
              callback(response)
            end)
          end
        end

        local cb, get_result = wait_for_sync_result()
        reload_sync().sync({
          notify = false,
          registry_url = "https://example.com/custom-registry.json",
          manifest_url = "https://example.com/custom-manifest.json",
        }, cb)
        local result = get_result()

        assert.is_true(result.success)
        assert.equals("https://example.com/custom-manifest.json", urls_requested[1])
        assert.equals("https://example.com/custom-registry.json", urls_requested[2])
      end)
    end)

    it("resolves latest channel release URLs from releases API", function()
      with_temp_cache_dir(function()
        local urls_requested = {}
        local responses = {
          {
            code = 0,
            stdout = vim.json.encode({
              { tag_name = "v0.3.2" },
              { tag_name = "v0.3.2+20260226" },
            }),
          },
          { code = 0, stdout = vim.json.encode({ sha256 = "abc", count = 1 }) },
          { code = 0, stdout = vim.json.encode({ { name = "latest" } }) },
        }
        local call_count = 0

        vim.system = function(cmd, _opts, callback)
          call_count = call_count + 1
          urls_requested[call_count] = cmd[#cmd]
          local response = responses[call_count]
          vim.schedule(function()
            callback(response)
          end)
        end

        local cb, get_result = wait_for_sync_result()
        reload_sync().sync({ notify = false, channel = "latest" }, cb)
        local result = get_result()

        assert.is_true(result.success)
        assert.equals("https://api.github.com/repos/raulcorreia7/theme-browser-registry/releases?per_page=30", urls_requested[1])
        assert.equals(
          "https://github.com/raulcorreia7/theme-browser-registry/releases/download/v0.3.2+20260226/manifest.json",
          urls_requested[2]
        )
        assert.equals(
          "https://github.com/raulcorreia7/theme-browser-registry/releases/download/v0.3.2+20260226/themes.json",
          urls_requested[3]
        )
      end)
    end)
  end)

  describe("error handling", function()
    it("handles curl errors with stderr", function()
      with_temp_cache_dir(function()
        vim.system = test_utils.mock_vim_system({
          { code = 22, stdout = "", stderr = "Connection failed" },
        })

        local cb, get_result = wait_for_sync_result()
        reload_sync().sync({ notify = false }, cb)
        local result = get_result()

        assert.is_not_nil(result)
        assert.is_false(result.success)
        assert.equals("manifest fetch failed", result.message)
      end)
    end)

    it("handles curl errors without stderr", function()
      with_temp_cache_dir(function()
        vim.system = test_utils.mock_vim_system({
          { code = 22, stdout = "", stderr = nil },
        })

        local cb, get_result = wait_for_sync_result()
        reload_sync().sync({ notify = false }, cb)
        local result = get_result()

        assert.is_not_nil(result)
        assert.is_false(result.success)
        assert.equals("manifest fetch failed", result.message)
      end)
    end)

    it("handles invalid manifest JSON", function()
      with_temp_cache_dir(function()
        vim.system = test_utils.mock_vim_system({
          { code = 0, stdout = "not valid json" },
        })

        local cb, get_result = wait_for_sync_result()
        reload_sync().sync({ notify = false }, cb)
        local result = get_result()

        assert.is_not_nil(result)
        assert.is_false(result.success)
        assert.equals("invalid manifest", result.message)
      end)
    end)

    it("handles invalid registry JSON", function()
      with_temp_cache_dir(function()
        vim.system = test_utils.mock_vim_system({
          { code = 0, stdout = vim.json.encode({ sha256 = "abc", count = 1 }) },
          { code = 0, stdout = "not valid json" },
        })

        local cb, get_result = wait_for_sync_result()
        reload_sync().sync({ notify = false }, cb)
        local result = get_result()

        assert.is_not_nil(result)
        assert.is_false(result.success)
        assert.equals("invalid registry", result.message)
      end)
    end)

    it("handles registry download failure", function()
      with_temp_cache_dir(function()
        vim.system = test_utils.mock_vim_system({
          { code = 0, stdout = vim.json.encode({ sha256 = "abc", count = 1 }) },
          { code = 22, stderr = "download failed" },
        })

        local cb, get_result = wait_for_sync_result()
        reload_sync().sync({ notify = false }, cb)
        local result = get_result()

        assert.is_not_nil(result)
        assert.is_false(result.success)
        assert.equals("registry download failed", result.message)
      end)
    end)
  end)

  describe("path helpers", function()
    it("has_synced_registry returns false when no cached registry", function()
      with_temp_cache_dir(function()
        reload_sync()
        assert.is_false(sync.has_synced_registry())
      end)
    end)

    it("has_synced_registry returns true after successful sync", function()
      with_temp_cache_dir(function()
        vim.system = test_utils.mock_vim_system({
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
      with_temp_cache_dir(function()
        reload_sync()
        assert.is_nil(sync.get_synced_registry_path())
      end)
    end)

    it("get_synced_registry_path returns path after sync", function()
      with_temp_cache_dir(function()
        vim.system = test_utils.mock_vim_system({
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
        vim.system = test_utils.mock_vim_system({
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
      with_temp_cache_dir(function()
        vim.system = test_utils.mock_vim_system({
          { code = 0, stdout = vim.json.encode({ sha256 = "abc", count = 1, version = "0.1.0" }) },
          { code = 0, stdout = vim.json.encode({ { name = "test" } }) },
        })

        local cb, get_result = wait_for_sync_result()
        reload_sync().sync({ notify = false }, cb)
        local result = get_result()

        assert.is_not_nil(result)
        assert.is_true(result.success)
      end)
    end)
  end)
end)
