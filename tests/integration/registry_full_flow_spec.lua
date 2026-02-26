describe("Integration: full registry flow", function()
  local module_name = "theme-browser"
  local snapshots = {}
  local test_results = {}

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

  local function record_result(theme_name, variant, status, error_msg)
    table.insert(test_results, {
      theme = theme_name,
      variant = variant,
      status = status,
      error = error_msg,
      timestamp = os.date("%Y-%m-%d %H:%M:%S"),
    })
  end

  local function generate_report()
    local passed = 0
    local failed = 0
    local lines = {
      "============================================",
      "  THEME REGISTRY FULL FLOW TEST REPORT",
      "============================================",
      "",
      string.format("Generated: %s", os.date("%Y-%m-%d %H:%M:%S")),
      "",
      "SUMMARY:",
      "--------",
    }

    for _, result in ipairs(test_results) do
      if result.status == "PASS" then
        passed = passed + 1
      else
        failed = failed + 1
      end
    end

    table.insert(lines, string.format("Total Tests:  %d", #test_results))
    table.insert(lines, string.format("Passed:       %d", passed))
    table.insert(lines, string.format("Failed:       %d", failed))
    table.insert(lines, "")
    table.insert(lines, "DETAILED RESULTS:")
    table.insert(lines, "-----------------")
    table.insert(lines, "")

    for _, result in ipairs(test_results) do
      local status_icon = result.status == "PASS" and "✓" or "✗"
      local variant_str = result.variant and string.format(" (%s)", result.variant) or ""
      table.insert(lines, string.format("%s %s%s", status_icon, result.theme, variant_str))
      if result.error then
        table.insert(lines, string.format("    Error: %s", result.error))
      end
    end

    table.insert(lines, "")
    table.insert(lines, "============================================")
    table.insert(
      lines,
      string.format("FINAL STATUS: %s", failed == 0 and "ALL TESTS PASSED" or "SOME TESTS FAILED")
    )
    table.insert(lines, "============================================")

    return table.concat(lines, "\n"), passed, failed
  end

  local function get_registry_path()
    local plugin_root = vim.fn.fnamemodify(vim.fn.getcwd(), ":p")

    local full_registry = vim.fn.fnamemodify(plugin_root .. "../registry/artifacts/themes.json", ":p")
    if vim.fn.filereadable(full_registry) == 1 then
      return full_registry
    end

    local bundled = vim.fn.fnamemodify(plugin_root .. "lua/theme-browser/data/registry.json", ":p")
    if vim.fn.filereadable(bundled) == 1 then
      return bundled
    end

    return nil
  end

  before_each(function()
    snapshots = {}
    snapshot(module_name)
    snapshot("theme-browser.adapters.registry")
    snapshot("theme-browser.application.theme_service")
    package.loaded[module_name] = nil
  end)

  after_each(function()
    restore(module_name)
    restore("theme-browser.adapters.registry")
    restore("theme-browser.application.theme_service")
  end)

  it("iterates preview/use across full local registry without lua errors", function()
    local registry_path = get_registry_path()
    assert.is_not_nil(registry_path, "Registry file not found")

    local tb = require(module_name)
    tb.setup({
      registry_path = registry_path,
      auto_load = false,
      startup = {
        enabled = false,
        write_spec = false,
        skip_if_already_active = true,
      },
      package_manager = {
        enabled = true,
        mode = "manual",
        provider = "auto",
      },
    })

    local notify_calls = 0
    local orig_notify = vim.notify
    vim.notify = function(msg, level, opts)
      opts = opts or {}
      if opts.title == "Theme Browser" then
        notify_calls = notify_calls + 1
      end
      return orig_notify(msg, level, opts)
    end

    local registry = require("theme-browser.adapters.registry")
    local service = require("theme-browser.application.theme_service")
    local entries = registry.list_entries()

    assert.is_true(#entries >= 40, "Expected at least 40 registry entries")

    local preview_errors = 0
    local use_errors = 0

    for _, entry in ipairs(entries) do
      local ok_preview = pcall(service.preview, entry.name, entry.variant, {
        notify = false,
        install_missing = false,
        wait_install = false,
      })
      if not ok_preview then
        preview_errors = preview_errors + 1
      end

      local ok_use = pcall(service.use, entry.name, entry.variant, {
        notify = false,
        install_missing = false,
        wait_install = false,
      })
      if not ok_use then
        use_errors = use_errors + 1
      end
    end

    vim.notify = orig_notify

    assert.equals(0, preview_errors)
    assert.equals(0, use_errors)
    assert.equals(0, notify_calls)
  end)

  describe("Top 5 Themes Validation", function()
    local top_themes = {
      {
        name = "tokyonight",
        repo = "folke/tokyonight.nvim",
        variants = {
          { name = "tokyonight-night", colorscheme = "tokyonight-night" },
          { name = "tokyonight-storm", colorscheme = "tokyonight-storm" },
          { name = "tokyonight-moon", colorscheme = "tokyonight-moon" },
          { name = "tokyonight-day", colorscheme = "tokyonight-day" },
        },
      },
      {
        name = "catppuccin",
        repo = "catppuccin/nvim",
        variants = {
          { name = "catppuccin-latte", colorscheme = "catppuccin-latte" },
          { name = "catppuccin-frappe", colorscheme = "catppuccin-frappe" },
          { name = "catppuccin-macchiato", colorscheme = "catppuccin-macchiato" },
          { name = "catppuccin-mocha", colorscheme = "catppuccin-mocha" },
        },
      },
      {
        name = "kanagawa",
        repo = "rebelot/kanagawa.nvim",
        variants = {
          { name = "kanagawa-wave", colorscheme = "kanagawa-wave" },
          { name = "kanagawa-dragon", colorscheme = "kanagawa-dragon" },
          { name = "kanagawa-lotus", colorscheme = "kanagawa-lotus" },
        },
      },
      {
        name = "gruvbox",
        repo = "morhetz/gruvbox",
        variants = {
          { name = "gruvbox", colorscheme = "gruvbox" },
        },
      },
      {
        name = "onedark",
        repo = "navarasu/onedark.nvim",
        variants = {},
      },
    }

    before_each(function()
      test_results = {}
    end)

    it("validates all tokyonight variants exist in registry", function()
      local registry_path = get_registry_path()
      assert.is_not_nil(registry_path, "Registry file not found")

      local tb = require(module_name)
      tb.setup({
        registry_path = registry_path,
        auto_load = false,
        startup = { enabled = false },
      })

      local registry = require("theme-browser.adapters.registry")
      local theme = registry.get_theme("tokyonight")

      assert.is_not_nil(theme)
      assert.equals("folke/tokyonight.nvim", theme.repo)
      assert.is_not_nil(theme.variants)
      assert.equals(4, #theme.variants)

      local variant_names = {}
      for _, v in ipairs(theme.variants) do
        variant_names[v.name or v] = true
      end

      assert.is_true(variant_names["tokyonight-night"] or variant_names["tokyonight-night"])
      assert.is_true(variant_names["tokyonight-storm"] or variant_names["tokyonight-storm"])
      assert.is_true(variant_names["tokyonight-moon"] or variant_names["tokyonight-moon"])
      assert.is_true(variant_names["tokyonight-day"] or variant_names["tokyonight-day"])

      for _, variant in ipairs(top_themes[1].variants) do
        local entry = registry.resolve("tokyonight", variant.name)
        if entry then
          record_result("tokyonight", variant.name, "PASS")
        else
          record_result("tokyonight", variant.name, "FAIL", "Entry not found in registry")
        end
      end
    end)

    it("validates all catppuccin variants exist in registry", function()
      local registry_path = get_registry_path()
      assert.is_not_nil(registry_path, "Registry file not found")

      local tb = require(module_name)
      tb.setup({
        registry_path = registry_path,
        auto_load = false,
        startup = { enabled = false },
      })

      local registry = require("theme-browser.adapters.registry")
      local theme = registry.get_theme("catppuccin")

      assert.is_not_nil(theme)
      assert.equals("catppuccin/nvim", theme.repo)
      assert.is_not_nil(theme.variants)
      assert.equals(4, #theme.variants)

      for _, variant in ipairs(top_themes[2].variants) do
        local entry = registry.resolve("catppuccin", variant.name)
        if entry then
          record_result("catppuccin", variant.name, "PASS")
        else
          record_result("catppuccin", variant.name, "FAIL", "Entry not found in registry")
        end
      end
    end)

    it("validates all kanagawa variants exist in registry", function()
      local registry_path = get_registry_path()
      assert.is_not_nil(registry_path, "Registry file not found")

      local tb = require(module_name)
      tb.setup({
        registry_path = registry_path,
        auto_load = false,
        startup = { enabled = false },
      })

      local registry = require("theme-browser.adapters.registry")
      local theme = registry.get_theme("kanagawa")

      assert.is_not_nil(theme)
      assert.equals("rebelot/kanagawa.nvim", theme.repo)
      assert.is_not_nil(theme.variants)
      assert.is_true(#theme.variants >= 1, "Expected at least 1 kanagawa variant")

      for _, variant in ipairs(top_themes[3].variants) do
        local entry = registry.resolve("kanagawa", variant.name)
        if entry then
          record_result("kanagawa", variant.name, "PASS")
        else
          record_result("kanagawa", variant.name, "FAIL", "Entry not found in registry")
        end
      end
    end)

    it("validates gruvbox theme exists in registry", function()
      local registry_path = get_registry_path()
      assert.is_not_nil(registry_path, "Registry file not found")

      local tb = require(module_name)
      tb.setup({
        registry_path = registry_path,
        auto_load = false,
        startup = { enabled = false },
      })

      local registry = require("theme-browser.adapters.registry")
      local theme = registry.get_theme("gruvbox")

      assert.is_not_nil(theme, "gruvbox should exist in registry")
      assert.is_not_nil(theme.repo)

      local entry = registry.resolve("gruvbox", nil)
      if entry then
        record_result("gruvbox", nil, "PASS")
      else
        record_result("gruvbox", nil, "FAIL", "Entry not found in registry")
      end
    end)

    it("validates onedark theme exists in registry", function()
      local registry_path = get_registry_path()
      assert.is_not_nil(registry_path, "Registry file not found")

      local tb = require(module_name)
      tb.setup({
        registry_path = registry_path,
        auto_load = false,
        startup = { enabled = false },
      })

      local registry = require("theme-browser.adapters.registry")
      local theme = registry.get_theme("onedark")

      assert.is_not_nil(theme, "onedark should exist in registry")
      assert.is_not_nil(theme.repo)
      assert.is_not_nil(theme.colorscheme)

      if theme.variants and #theme.variants > 0 then
        for _, variant in ipairs(theme.variants) do
          local entry = registry.resolve("onedark", variant.name)
          if entry then
            record_result("onedark", variant.name, "PASS")
          else
            record_result("onedark", variant.name, "FAIL", "Entry not found in registry")
          end
        end
      else
        local entry = registry.resolve("onedark", nil)
        if entry then
          record_result("onedark", nil, "PASS")
        else
          record_result("onedark", nil, "FAIL", "Entry not found in registry")
        end
      end
    end)

    it("generates test report for all top 5 themes", function()
      local registry_path = get_registry_path()
      assert.is_not_nil(registry_path, "Registry file not found")

      local tb = require(module_name)
      tb.setup({
        registry_path = registry_path,
        auto_load = false,
        startup = { enabled = false },
      })

      local registry = require("theme-browser.adapters.registry")

      for _, theme_def in ipairs(top_themes) do
        local theme = registry.get_theme(theme_def.name)
        if theme then
          if #theme_def.variants > 0 then
            for _, variant in ipairs(theme_def.variants) do
              local entry = registry.resolve(theme_def.name, variant.name)
              if entry then
                record_result(theme_def.name, variant.name, "PASS")
              else
                record_result(theme_def.name, variant.name, "FAIL", "Failed to resolve variant")
              end
            end
          else
            local entry = registry.resolve(theme_def.name, nil)
            if entry then
              record_result(theme_def.name, nil, "PASS")
            else
              record_result(theme_def.name, nil, "FAIL", "Failed to resolve theme")
            end
          end
        else
          record_result(theme_def.name, nil, "FAIL", "Theme not found in registry")
        end
      end

      local report, passed, failed = generate_report()
      assert.is_not_nil(report)
      assert.is_true(passed > 0)

      assert.equals(0, failed, "Some top 5 theme tests failed. Report:\n" .. report)
    end)
  end)

  describe("Theme Entry Resolution", function()
    it("correctly resolves theme entries by various identifiers", function()
      local registry_path = get_registry_path()
      assert.is_not_nil(registry_path, "Registry file not found")

      local tb = require(module_name)
      tb.setup({
        registry_path = registry_path,
        auto_load = false,
        startup = { enabled = false },
      })

      local registry = require("theme-browser.adapters.registry")

      local by_name = registry.get_theme("tokyonight")
      assert.is_not_nil(by_name)

      local by_entry_id = registry.get_entry("tokyonight:tokyonight-night")
      assert.is_not_nil(by_entry_id)

      local resolved = registry.resolve("tokyonight", "tokyonight-night")
      assert.is_not_nil(resolved)
      assert.equals("tokyonight", resolved.name)
      assert.equals("tokyonight-night", resolved.variant)
    end)

    it("lists all entries for top 5 themes correctly", function()
      local registry_path = get_registry_path()
      assert.is_not_nil(registry_path, "Registry file not found")

      local tb = require(module_name)
      tb.setup({
        registry_path = registry_path,
        auto_load = false,
        startup = { enabled = false },
      })

      local registry = require("theme-browser.adapters.registry")
      local all_entries = registry.list_entries()

      local top5_names =
        { tokyonight = true, catppuccin = true, kanagawa = true, gruvbox = true, onedark = true }
      local found_counts = {}

      for _, entry in ipairs(all_entries) do
        if top5_names[entry.name] then
          found_counts[entry.name] = (found_counts[entry.name] or 0) + 1
        end
      end

      assert.is_true((found_counts.tokyonight or 0) >= 4, "tokyonight should have at least 4 entries")
      assert.is_true((found_counts.catppuccin or 0) >= 4, "catppuccin should have at least 4 entries")
      assert.is_true((found_counts.kanagawa or 0) >= 1, "kanagawa should have at least 1 entry")
      assert.is_true((found_counts.gruvbox or 0) >= 1, "gruvbox should have at least 1 entry")
      assert.is_true((found_counts.onedark or 0) >= 1, "onedark should have at least 1 entry")
    end)
  end)
end)
