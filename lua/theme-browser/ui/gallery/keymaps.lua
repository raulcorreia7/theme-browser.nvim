local M = {}

function M.setup(session, get_config, callbacks)
  local opts = { buffer = session.bufnr, nowait = true, silent = true }
  local keymaps = get_config().keymaps or {}

  local function map_keys(keys, fn)
    if type(keys) ~= "table" then
      return
    end
    for _, lhs in ipairs(keys) do
      vim.keymap.set("n", lhs, fn, opts)
    end
  end

  map_keys(keymaps.navigate_down or { "j" }, function()
    callbacks.navigate_to(session.selected_idx + 1)
  end)

  vim.keymap.set("n", "<C-j>", function()
    callbacks.navigate_to(session.selected_idx + 1)
  end, opts)

  vim.keymap.set("n", "<Down>", function()
    callbacks.navigate_to(session.selected_idx + 1)
  end, opts)

  vim.keymap.set("n", "<C-n>", function()
    callbacks.navigate_to(session.selected_idx + 1)
  end, opts)

  map_keys(keymaps.navigate_up or { "k" }, function()
    callbacks.navigate_to(session.selected_idx - 1)
  end)

  vim.keymap.set("n", "<C-k>", function()
    callbacks.navigate_to(session.selected_idx - 1)
  end, opts)

  vim.keymap.set("n", "<Up>", function()
    callbacks.navigate_to(session.selected_idx - 1)
  end, opts)

  vim.keymap.set("n", "<C-p>", function()
    callbacks.navigate_to(session.selected_idx - 1)
  end, opts)

  map_keys(keymaps.goto_top or { "gg" }, function()
    callbacks.navigate_to(1)
  end)

  map_keys(keymaps.goto_bottom or { "G" }, function()
    callbacks.navigate_to(#session.filtered_entries)
  end)

  map_keys(keymaps.select or { "<CR>" }, callbacks.apply_selected)
  map_keys(keymaps.preview or { "p" }, callbacks.preview_selected)
  map_keys(keymaps.install or { "i" }, callbacks.install_selected)
  map_keys(keymaps.copy_repo or { "Y" }, callbacks.copy_repo)

  vim.keymap.set("n", "n", function()
    if vim.fn.getreg("/") ~= "" then
      session.search_context_active = true
    end
    local ok = pcall(vim.cmd, "normal! n")
    if not ok then
      return
    end
    local changed = callbacks.sync_selection_to_cursor({ clamp = true })
    if changed then
      callbacks.preview_selected_on_move()
    end
  end, opts)

  vim.keymap.set("n", "N", function()
    if vim.fn.getreg("/") ~= "" then
      session.search_context_active = true
    end
    local ok = pcall(vim.cmd, "normal! N")
    if not ok then
      return
    end
    local changed = callbacks.sync_selection_to_cursor({ clamp = true })
    if changed then
      callbacks.preview_selected_on_move()
    end
  end, opts)

  map_keys(keymaps.close or { "<Esc>" }, function()
    if session.search_context_active or vim.v.hlsearch == 1 or vim.fn.getreg("/") ~= "" then
      callbacks.clear_search_context()
      return
    end
    callbacks.close()
  end)

  vim.keymap.set("n", "<C-h>", callbacks.focus_gallery_window, opts)
  vim.keymap.set("n", "<C-l>", callbacks.focus_gallery_window, opts)

  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = session.bufnr,
    callback = function()
      if session.is_rendering then
        return
      end
      if not session.winid or not vim.api.nvim_win_is_valid(session.winid) then
        return
      end
      local changed = callbacks.sync_selection_to_cursor({ clamp = false })
      if changed then
        callbacks.preview_selected_on_move()
      end
    end,
  })
end

return M
