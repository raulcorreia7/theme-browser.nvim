describe("theme-browser.persistence.lazy_spec", function()
  local module_name = "theme-browser.persistence.lazy_spec"
  local original_stdpath = vim.fn.stdpath
  local original_notify = vim.notify

  local temp_root = nil
  local state_calls = 0

  local function reset_module()
    package.loaded[module_name] = nil
    return require(module_name)
  end

  before_each(function()
    temp_root = vim.fn.tempname()
    vim.fn.mkdir(temp_root, "p")

    vim.notify = function(_, _, _) end

    vim.fn.stdpath = function(kind)
      if kind == "config" then
        return temp_root
      end
      return original_stdpath(kind)
    end

    package.loaded["theme-browser.adapters.registry"] = {
      resolve = function(_, variant)
        return {
          name = "tokyonight",
          variant = variant,
          repo = "folke/tokyonight.nvim",
          colorscheme = variant or "tokyonight",
        }
      end,
      list_themes = function()
        return {
          { name = "tokyonight", repo = "folke/tokyonight.nvim" },
        }
      end,
    }

    state_calls = 0
    package.loaded["theme-browser.persistence.state"] = {
      set_current_theme = function(_, _)
        state_calls = state_calls + 1
      end,
    }
  end)

  after_each(function()
    vim.fn.stdpath = original_stdpath
    vim.notify = original_notify

    package.loaded[module_name] = nil
    package.loaded["theme-browser.adapters.registry"] = nil
    package.loaded["theme-browser.persistence.state"] = nil

    if temp_root and vim.fn.isdirectory(temp_root) == 1 then
      vim.fn.delete(temp_root, "rf")
    end
  end)

  it("writes lazy spec and can skip state update", function()
    local lazy_spec = reset_module()
    local out = lazy_spec.generate_spec("tokyonight", "tokyonight-night", {
      notify = false,
      update_state = false,
    })

    assert.is_not_nil(out)
    assert.equals(0, state_calls)
    assert.equals(1, vim.fn.filereadable(out))

    local content = table.concat(vim.fn.readfile(out), "\n")
    assert.is_truthy(content:find('"folke/tokyonight.nvim"', 1, true))
    assert.is_truthy(content:find('"rktjmp/lush.nvim"', 1, true))
    assert.is_truthy(content:find("tokyonight%-night"))
    assert.is_truthy(content:find("config = function%(%)"))
    assert.is_truthy(content:find('vim.g.colors_name == "tokyonight%-night"'))
    assert.is_truthy(content:find("persist_startup%s*=%s*false"))
    assert.is_nil(content:find("init = function%(%)"))
  end)

  it("updates state when update_state is enabled", function()
    local lazy_spec = reset_module()
    lazy_spec.generate_spec("tokyonight", nil, {
      notify = false,
      update_state = true,
    })

    assert.equals(1, state_calls)
  end)
end)
