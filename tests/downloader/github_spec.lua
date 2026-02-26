local test_utils = require("tests.helpers.test_utils")

describe("theme-browser.downloader.github", function()
  local module_name = "theme-browser.downloader.github"
  local modules = { module_name }
  local github

  before_each(function()
    test_utils.reset_all(modules)
    github = require(module_name)
  end)

  after_each(function()
    test_utils.restore_all(modules)
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

  describe("sanitize_error_message", function()
    it("sanitizes personal access tokens (ghp_)", function()
      local input = "Authentication failed for ghp_1234567890abcdef"
      local result = github._sanitize_error_message(input)
      assert.is_falsy(result:match("ghp_1234567890abcdef"))
      assert.is_truthy(result:match("ghp_%*%*%*"))
    end)

    it("sanitizes OAuth tokens (gho_)", function()
      local input = "Error with gho_abcdefghijklmnop"
      local result = github._sanitize_error_message(input)
      assert.is_falsy(result:match("gho_abcdefghijklmnop"))
      assert.is_truthy(result:match("gho_%*%*%*"))
    end)

    it("sanitizes user tokens (ghu_)", function()
      local input = "Failed using ghu_user123token"
      local result = github._sanitize_error_message(input)
      assert.is_falsy(result:match("ghu_user123token"))
      assert.is_truthy(result:match("ghu_%*%*%*"))
    end)

    it("sanitizes server tokens (ghs_)", function()
      local input = "Server error ghs_server456secret"
      local result = github._sanitize_error_message(input)
      assert.is_falsy(result:match("ghs_server456secret"))
      assert.is_truthy(result:match("ghs_%*%*%*"))
    end)

    it("sanitizes refresh tokens (ghr_)", function()
      local input = "Refresh failed ghr_refresh789token"
      local result = github._sanitize_error_message(input)
      assert.is_falsy(result:match("ghr_refresh789token"))
      assert.is_truthy(result:match("ghr_%*%*%*"))
    end)

    it("sanitizes fine-grained PATs (github_pat_)", function()
      local input = "Auth error github_pat_11ABCDEFG3_secret123"
      local result = github._sanitize_error_message(input)
      assert.is_falsy(result:match("github_pat_11ABCDEFG3_secret123"))
      assert.is_truthy(result:match("github_pat_%*%*%*"))
    end)

    it("sanitizes token query params", function()
      local input = "URL: https://api.github.com?token=my-secret-token-123"
      local result = github._sanitize_error_message(input)
      assert.is_falsy(result:match("token=my%-secret%-token%-123"))
      assert.is_truthy(result:match("token=%*%*%*"))
    end)

    it("sanitizes access_token query params", function()
      local input = "Request: access_token=abc123xyz789"
      local result = github._sanitize_error_message(input)
      assert.is_falsy(result:match("access_token=abc123xyz789"))
      assert.is_truthy(result:match("access_token=%*%*%*"))
    end)

    it("sanitizes Authorization headers", function()
      local input = "Header: Authorization: token ghp_supersecret123"
      local result = github._sanitize_error_message(input)
      assert.is_falsy(result:match("ghp_supersecret123"))
      assert.is_truthy(result:match("Authorization: token %*%*%*"))
    end)

    it("handles non-string input", function()
      assert.equals("unknown error", github._sanitize_error_message(nil))
      assert.equals("unknown error", github._sanitize_error_message(123))
      assert.equals("unknown error", github._sanitize_error_message({}))
    end)

    it("preserves non-sensitive error messages", function()
      local input = "Repository not found: owner/repo"
      local result = github._sanitize_error_message(input)
      assert.equals(input, result)
    end)

    it("sanitizes multiple tokens in one message", function()
      local input = "Both ghp_first123 and gho_second456 failed"
      local result = github._sanitize_error_message(input)
      assert.is_falsy(result:match("ghp_first123"))
      assert.is_falsy(result:match("gho_second456"))
      assert.is_truthy(result:match("ghp_%*%*%*"))
      assert.is_truthy(result:match("gho_%*%*%*"))
    end)
  end)
end)
