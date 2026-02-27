local M = {}

local log = require("theme-browser.util.notify")

local DEFAULT_REGISTRY_URL =
  "https://github.com/raulcorreia7/theme-browser-registry/releases/latest/download/themes.json"
local DEFAULT_MANIFEST_URL =
  "https://github.com/raulcorreia7/theme-browser-registry/releases/latest/download/manifest.json"
local RELEASES_API_URL = "https://api.github.com/repos/raulcorreia7/theme-browser-registry/releases?per_page=30"
local CACHE_FILENAME = "registry-full.json"
local MANIFEST_FILENAME = "registry-manifest.json"
local COMPATIBLE_VERSION = "0.1"

local function get_cache_dir()
  local ok_tb, tb = pcall(require, "theme-browser")
  if ok_tb and type(tb.get_config) == "function" then
    local config = tb.get_config()
    if type(config) == "table" and type(config.cache_dir) == "string" and config.cache_dir ~= "" then
      return config.cache_dir
    end
  end
  return vim.fn.stdpath("cache") .. "/theme-browser"
end

local function get_plugin_config()
  local ok_tb, tb = pcall(require, "theme-browser")
  if not ok_tb or type(tb.get_config) ~= "function" then
    return nil
  end
  local config = tb.get_config()
  if type(config) ~= "table" then
    return nil
  end
  return config
end

local function get_registry_channel()
  local config = get_plugin_config()
  local registry = config and config.registry or nil
  if type(registry) == "table" and registry.channel == "latest" then
    return "latest"
  end
  return "stable"
end

local function get_cached_registry_path()
  return get_cache_dir() .. "/" .. CACHE_FILENAME
end

local function get_cached_manifest_path()
  return get_cache_dir() .. "/" .. MANIFEST_FILENAME
end

local function ensure_cache_dir()
  local dir = get_cache_dir()
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end
end

local function fetch_url_async(url, callback)
  if vim.system then
    vim.system({ "curl", "-sL", "-f", url }, { text = true }, function(result)
      vim.schedule(function()
        if result.code == 0 then
          callback(true, result.stdout)
        else
          callback(false, result.stderr or "curl failed")
        end
      end)
    end)
  else
    vim.schedule(function()
      local output = vim.fn.system({ "curl", "-sL", "-f", url })
      if vim.v.shell_error == 0 then
        callback(true, output)
      else
        callback(false, "curl failed")
      end
    end)
  end
end

local function write_file(path, content)
  ensure_cache_dir()
  local file = io.open(path, "w")
  if not file then
    return false, "failed to open file for writing"
  end
  file:write(content)
  file:close()
  return true, nil
end

local function read_file(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local content = file:read("*a")
  file:close()
  return content
end

local function parse_json_safe(content)
  if type(content) ~= "string" or content == "" then
    return nil
  end
  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    return nil
  end
  return data
end

local function build_release_asset_url(tag_name, file_name)
  return string.format(
    "https://github.com/raulcorreia7/theme-browser-registry/releases/download/%s/%s",
    tag_name,
    file_name
  )
end

local function release_matches_channel(tag_name, channel)
  if type(tag_name) ~= "string" then
    return false
  end
  if channel == "latest" then
    if tag_name:match("^v%d+%.%d+%.%d+%+%d%d%d%d%d%d%d%d$") then
      return true
    end
    return tag_name:match("^v%d+%.%d+%.%d+%+%d%d%d%d%d%d%d%d[%.%-_]%d+$") ~= nil
  end
  return tag_name:match("^v%d+%.%d+%.%d+$") ~= nil
end

local function resolve_release_urls_async(channel, callback)
  fetch_url_async(RELEASES_API_URL, function(ok, body)
    if not ok then
      callback(false, nil, nil, "release list fetch failed")
      return
    end

    local releases = parse_json_safe(body)
    if type(releases) ~= "table" then
      callback(false, nil, nil, "invalid release list")
      return
    end

    for _, release in ipairs(releases) do
      local tag_name = type(release) == "table" and release.tag_name or nil
      if release_matches_channel(tag_name, channel) then
        callback(
          true,
          build_release_asset_url(tag_name, "themes.json"),
          build_release_asset_url(tag_name, "manifest.json"),
          tag_name
        )
        return
      end
    end

    callback(false, nil, nil, "no matching release found")
  end)
end

local function resolve_urls_async(opts, callback)
  local explicit_registry_url = opts.registry_url
  local explicit_manifest_url = opts.manifest_url
  if type(explicit_registry_url) == "string" and explicit_registry_url ~= "" then
    local manifest_url = explicit_manifest_url
    if type(manifest_url) ~= "string" or manifest_url == "" then
      manifest_url = DEFAULT_MANIFEST_URL
    end
    callback(true, explicit_registry_url, manifest_url, "custom")
    return
  end

  local channel = opts.channel
  if channel ~= "stable" and channel ~= "latest" then
    channel = get_registry_channel()
  end

  if channel == "stable" then
    callback(true, DEFAULT_REGISTRY_URL, DEFAULT_MANIFEST_URL, "stable")
    return
  end

  resolve_release_urls_async(channel, function(ok, registry_url, manifest_url, extra)
    if ok then
      callback(true, registry_url, manifest_url, extra)
      return
    end

    callback(false, nil, nil, extra)
  end)
end

local function is_fresh_manifest(cached_manifest, remote_manifest)
  if type(cached_manifest) ~= "table" or type(remote_manifest) ~= "table" then
    return false
  end

  local cached_hash = cached_manifest.sha256
  local remote_hash = remote_manifest.sha256
  if type(cached_hash) == "string" and type(remote_hash) == "string" then
    return cached_hash == remote_hash
  end

  local cached_count = cached_manifest.count
  local remote_count = remote_manifest.count
  local cached_time = cached_manifest.generated_at
  local remote_time = remote_manifest.generated_at

  if type(remote_time) == "string" and type(cached_time) == "string" then
    return cached_time >= remote_time and cached_count == remote_count
  end

  return false
end

local function is_compatible_version(version)
  if type(version) ~= "string" then
    return true
  end
  local major_minor = version:match("^(%d+%.%d+)")
  if not major_minor then
    return true
  end
  return major_minor == COMPATIBLE_VERSION
end

function M.get_synced_registry_path()
  local cached = get_cached_registry_path()
  if vim.fn.filereadable(cached) == 1 then
    return cached
  end
  return nil
end

function M.has_synced_registry()
  return vim.fn.filereadable(get_cached_registry_path()) == 1
end

function M.clear_synced_registry()
  local registry_path = get_cached_registry_path()
  local manifest_path = get_cached_manifest_path()

  if vim.fn.filereadable(registry_path) == 1 then
    vim.fn.delete(registry_path)
  end
  if vim.fn.filereadable(manifest_path) == 1 then
    vim.fn.delete(manifest_path)
  end
end

function M.sync(opts, callback)
  opts = opts or {}

  local force = opts.force == true
  local notify = opts.notify ~= false

  if notify then
    log.info("Checking for registry updates...")
  end

  local cached_manifest_content = read_file(get_cached_manifest_path())
  local cached_manifest = parse_json_safe(cached_manifest_content)

  resolve_urls_async(opts, function(urls_ok, registry_url, manifest_url, source)
    if not urls_ok then
      if notify then
        log.warn("Failed to resolve release channel, using cached version if available")
      end
      if type(callback) == "function" then
        callback(false, source or "release url resolution failed")
      end
      return
    end

    if notify and source and source ~= "custom" then
      log.info(string.format("Using registry source: %s", source))
    end

    fetch_url_async(manifest_url, function(manifest_ok, manifest_data)
      if not manifest_ok then
        if notify then
          log.warn("Failed to fetch registry manifest, using cached version if available")
        end
        if type(callback) == "function" then
          callback(false, "manifest fetch failed")
        end
        return
      end

      local remote_manifest = parse_json_safe(manifest_data)
      if not remote_manifest then
        if type(callback) == "function" then
          callback(false, "invalid manifest")
        end
        return
      end

      if remote_manifest.version and not is_compatible_version(remote_manifest.version) then
        if notify then
          log.warn(
            string.format(
              "Registry version %s may be incompatible (expected %s.x)",
              remote_manifest.version,
              COMPATIBLE_VERSION
            )
          )
        end
      end

      if not force and is_fresh_manifest(cached_manifest, remote_manifest) then
        if notify then
          log.info("Registry is up to date")
        end
        if type(callback) == "function" then
          callback(true, "up_to_date")
        end
        return
      end

      if notify then
        log.info("Downloading updated registry...")
      end

      fetch_url_async(registry_url, function(registry_ok, registry_data)
        if not registry_ok then
          if notify then
            log.error("Failed to download registry")
          end
          if type(callback) == "function" then
            callback(false, "registry download failed")
          end
          return
        end

        local registry = parse_json_safe(registry_data)
        if not registry or type(registry) ~= "table" then
          if notify then
            log.error("Invalid registry data")
          end
          if type(callback) == "function" then
            callback(false, "invalid registry")
          end
          return
        end

        local ok1, err1 = write_file(get_cached_registry_path(), registry_data)
        if not ok1 then
          if notify then
            log.error(string.format("Failed to cache registry: %s", err1))
          end
          if type(callback) == "function" then
            callback(false, err1)
          end
          return
        end

        local ok2, err2 = write_file(get_cached_manifest_path(), manifest_data)
        if not ok2 then
          if notify then
            log.warn(string.format("Failed to cache manifest: %s", err2))
          end
        end

        local count = type(registry) == "table" and #registry or 0
        if notify then
          log.info(string.format("Registry updated: %d themes", count))
        end
        if type(callback) == "function" then
          callback(true, "updated", count)
        end
      end)
    end)
  end)
end

function M.sync_blocking(opts)
  opts = opts or {}
  local done = false
  local result = { success = false, message = "unknown" }

  M.sync(vim.tbl_extend("force", opts, { notify = false }), function(success, message, count)
    done = true
    result.success = success
    result.message = message
    result.count = count
  end)

  vim.wait(30000, function()
    return done
  end)

  return result
end

return M
