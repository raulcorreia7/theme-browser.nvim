describe("theme-browser.downloader.github", function()
  local module_name = "theme-browser.downloader.github"
  local github

  before_each(function()
    package.loaded[module_name] = nil
    github = require(module_name)
  end)

  it("uses owner-aware cache paths to avoid collisions", function()
    local cache_dir = "/tmp/theme-browser-cache"
    local a = github.get_cache_path("ownerA/theme.nvim", cache_dir)
    local b = github.get_cache_path("ownerB/theme.nvim", cache_dir)
    assert.not_equals(a, b)
    assert.is_truthy(a:find("ownerA__theme.nvim", 1, true))
    assert.is_truthy(b:find("ownerB__theme.nvim", 1, true))
  end)

  it("resolves to existing slug path when present", function()
    local cache_dir = vim.fn.tempname()
    local slug_path = github.get_cache_path("owner/theme.nvim", cache_dir)
    vim.fn.mkdir(slug_path, "p")

    local resolved = github.resolve_cache_path("owner/theme.nvim", cache_dir)
    assert.equals(slug_path, resolved)

    vim.fn.delete(cache_dir, "rf")
  end)

  it("resolves to existing legacy ownerless path when slug path is missing", function()
    local cache_dir = vim.fn.tempname()
    local legacy_path = cache_dir .. "/theme.nvim"
    vim.fn.mkdir(legacy_path, "p")

    local resolved = github.resolve_cache_path("owner/theme.nvim", cache_dir)
    assert.equals(legacy_path, resolved)

    vim.fn.delete(cache_dir, "rf")
  end)
end)
