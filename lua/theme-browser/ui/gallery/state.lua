local M = {}

function M.new(namespace)
  return {
    popup = nil,
    winid = nil,
    bufnr = nil,
    is_open = false,
    ns = namespace,
    all_entries = {},
    filtered_entries = {},
    selected_idx = 1,
    current_query = "",
    is_rendering = false,
    row_offset = 0,
    search_context_active = false,
    last_cursor_preview_id = nil,
  }
end

function M.index_to_row(session, index)
  return index + session.row_offset
end

function M.row_to_index(session, row)
  return row - session.row_offset
end

function M.reset(session)
  session.popup = nil
  session.winid = nil
  session.bufnr = nil
  session.all_entries = {}
  session.filtered_entries = {}
  session.selected_idx = 1
  session.current_query = ""
  session.is_rendering = false
  session.row_offset = 0
  session.search_context_active = false
  session.last_cursor_preview_id = nil
  session.is_open = false
end

return M
