describe("theme-browser.adapters.setup_adapter", function()
  it("should call setup with opts", function()
    local adapter = require("theme-browser.adapters.setup_adapter")
    local opts = { theme = "test" }
    local result = adapter.setup(opts)

    assert.equals(result.theme, "test")
    assert.is_nil(result.test)
  end)

  it("should have adapter_type field", function()
    local adapter = require("theme-browser.adapters.setup_adapter")
    assert.equals(adapter.adapter_type, "setup")
  end)
end)
