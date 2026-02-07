describe("theme-browser.config.registry", function()
  local module_name = "theme-browser.config.registry"

  before_each(function()
    package.loaded[module_name] = nil
  end)

  after_each(function()
    package.loaded[module_name] = nil
  end)

  it("resolves a readable fallback registry path", function()
    local registry = require(module_name)
    local resolved = registry.resolve(nil)

    assert.is_true(type(resolved.path) == "string")
    assert.is_true(resolved.path ~= "")
    assert.is_true(vim.fn.filereadable(resolved.path) == 1)
    assert.are.equal("bundled", resolved.source)
  end)

  it("prefers a readable user registry path", function()
    local registry = require(module_name)
    local path = vim.fn.tempname() .. ".json"
    vim.fn.writefile({ "[]" }, path)

    local resolved = registry.resolve(path)

    assert.are.equal(path, resolved.path)
    assert.are.equal("user", resolved.source)
    vim.fn.delete(path)
  end)
end)
