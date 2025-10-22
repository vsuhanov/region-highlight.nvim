local M = {}

-- Namespace for extmarks
M.ns_id = vim.api.nvim_create_namespace('region_highlight')

-- Default configuration
M.config = {
  colors_dark = {
    '#1a1f2e', -- very dark blue-gray
    '#1e1b2e', -- very dark purple
    '#1a2332', -- very dark blue
    '#1a2e2e', -- very dark teal
    '#1a2e1e', -- very dark green
    '#2e2419', -- very dark orange
    '#2e1a1a', -- very dark red
    '#2e2a1a', -- very dark yellow
    '#2a1e3d', -- very dark violet
    '#1a2a32', -- very dark cyan
  },
  colors_light = {
    '#e2e8f0', -- gray-200
    '#e9d8fd', -- purple-200
    '#bee3f8', -- blue-200
    '#b2f5ea', -- teal-200
    '#c6f6d5', -- green-200
    '#feebc8', -- orange-200
    '#fed7d7', -- red-200
    '#fefcbf', -- yellow-200
    '#ddd6fe', -- violet-200
    '#c4f1f9', -- cyan-200
  },
  highlights_file = vim.fn.stdpath('data') .. '/region-highlights.json',
}

-- Storage for active highlights by buffer
M.highlights = {}

-- Current mode (will be set on initialization)
M.current_mode = nil

-- Persistent highlights storage (loaded from JSON)
M.persistent_highlights = {}

-- Load highlights from JSON file
local function load_highlights()
  local file = io.open(M.config.highlights_file, 'r')
  if not file then
    return {}
  end

  local content = file:read('*a')
  file:close()

  if content == '' then
    return {}
  end

  local ok, data = pcall(vim.json.decode, content)
  if not ok then
    vim.notify('Failed to parse highlights file: ' .. M.config.highlights_file, vim.log.levels.ERROR)
    return {}
  end

  return data
end

-- Save highlights to JSON file
local function save_highlights()
  local file = io.open(M.config.highlights_file, 'w')
  if not file then
    vim.notify('Failed to open highlights file for writing: ' .. M.config.highlights_file, vim.log.levels.ERROR)
    return
  end

  local content = vim.json.encode(M.persistent_highlights)
  file:write(content)
  file:close()
end

-- Resolve overlaps: given a new range, update existing ranges to avoid overlaps
-- Returns the modified list of ranges for the file
local function resolve_overlaps(ranges, new_range)
  local result = {}

  for _, range in ipairs(ranges) do
    -- Check if there's any overlap
    if range.endLine < new_range.startLine or range.startLine > new_range.endLine then
      -- No overlap, keep the range as is
      table.insert(result, range)
    else
      -- There's an overlap, need to split/trim
      -- Keep part before new range if exists
      if range.startLine < new_range.startLine then
        table.insert(result, {
          startLine = range.startLine,
          endLine = new_range.startLine - 1,
          hlGroup = range.hlGroup,
        })
      end

      -- Keep part after new range if exists
      if range.endLine > new_range.endLine then
        table.insert(result, {
          startLine = new_range.endLine + 1,
          endLine = range.endLine,
          hlGroup = range.hlGroup,
        })
      end
    end
  end

  -- Add the new range
  table.insert(result, new_range)

  return result
end

-- Clear extmarks for a buffer
local function clear_buffer_extmarks(bufnr)
  if M.highlights[bufnr] then
    M.highlights[bufnr] = {}
  end
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns_id, 0, -1)
end

-- Apply a single highlight range to buffer
local function apply_highlight_to_buffer(bufnr, range)
  -- Initialize buffer highlights storage if needed
  if not M.highlights[bufnr] then
    M.highlights[bufnr] = {}
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  local start_line = range.startLine - 1  -- Convert to 0-indexed
  local end_line_range = range.endLine - 1  -- Convert to 0-indexed

  -- If start_line is out of bounds, ignore the entire range
  if start_line >= line_count then
    return
  end

  -- Apply highlight to each line in the range
  for line = start_line, end_line_range do
    -- Stop if we've gone past the end of the file
    if line >= line_count then
      break
    end

    -- Cap end_line to the maximum available value
    local end_line = math.min(line + 1, line_count)

    local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, M.ns_id, line, 0, {
      end_line = end_line,
      hl_group = range.hlGroup,
      hl_eol = true,
      priority = 1,
    })

    table.insert(M.highlights[bufnr], extmark_id)
  end
end

-- Apply all saved highlights for a specific file
local function apply_file_highlights(filepath)
  local bufnr = vim.fn.bufnr(filepath)
  if bufnr == -1 then
    return
  end

  local ranges = M.persistent_highlights[filepath]
  if not ranges then
    return
  end

  clear_buffer_extmarks(bufnr)

  for _, range in ipairs(ranges) do
    apply_highlight_to_buffer(bufnr, range)
  end
end

-- Simple hash function for filename + line range
local function hash_string(str)
  local hash = 0
  for i = 1, #str do
    hash = (hash * 31 + string.byte(str, i)) % 2147483647
  end
  return hash
end

-- Get color based on hash
local function get_color_for_range(filename, start_line, end_line)
  local key = string.format("%s:%d-%d", filename, start_line, end_line)
  local hash = hash_string(key)

  local colors = M.current_mode == 'dark' and M.config.colors_dark or M.config.colors_light
  local index = (hash % #colors) + 1

  return colors[index]
end

-- Create highlight groups based on current mode
local function create_highlight_groups()
  local colors = M.current_mode == 'dark' and M.config.colors_dark or M.config.colors_light

  for i, color in ipairs(colors) do
    vim.api.nvim_set_hl(0, 'RegionHighlight' .. i, {
      bg = color,
    })
  end
end

-- Apply highlight to a range of lines
function M.highlight_range(start_line, end_line)
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)

  if filename == '' then
    vim.notify('Cannot highlight unnamed buffer', vim.log.levels.WARN)
    return
  end

  -- Get the appropriate color
  local color = get_color_for_range(filename, start_line, end_line)

  -- Determine which highlight group to use
  local colors = M.current_mode == 'dark' and M.config.colors_dark or M.config.colors_light
  local color_index = nil
  for i, c in ipairs(colors) do
    if c == color then
      color_index = i
      break
    end
  end

  local hl_group = 'RegionHighlight' .. color_index

  -- Create new range
  local new_range = {
    startLine = start_line,
    endLine = end_line,
    hlGroup = hl_group,
  }

  -- Get existing ranges for this file
  local existing_ranges = M.persistent_highlights[filename] or {}

  -- Resolve overlaps
  local updated_ranges = resolve_overlaps(existing_ranges, new_range)

  -- Update persistent storage
  M.persistent_highlights[filename] = updated_ranges

  -- Save to file
  save_highlights()

  -- Clear and reapply all highlights for this buffer
  clear_buffer_extmarks(bufnr)
  for _, range in ipairs(updated_ranges) do
    apply_highlight_to_buffer(bufnr, range)
  end
end

-- Set light mode and recreate highlight groups
function M.setLightMode()
  M.current_mode = 'light'
  create_highlight_groups()
end

-- Set dark mode and recreate highlight groups
function M.setDarkMode()
  M.current_mode = 'dark'
  create_highlight_groups()
end

-- Clear entire region that covers the current line
function M.clear_highlight_at_line(line_num)
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)

  if filename == '' then
    vim.notify('Cannot clear highlight in unnamed buffer', vim.log.levels.WARN)
    return
  end

  local ranges = M.persistent_highlights[filename]
  if not ranges then
    vim.notify('No highlights found for this file', vim.log.levels.INFO)
    return
  end

  local updated_ranges = {}
  local found = false

  for _, range in ipairs(ranges) do
    -- Ensure range has the required fields
    if not range.startLine or not range.endLine then
      vim.notify('Invalid range found: missing startLine or endLine', vim.log.levels.ERROR)
      table.insert(updated_ranges, range)
    -- Check if this range covers the current line
    elseif range.startLine <= line_num and range.endLine >= line_num then
      found = true
      -- Remove entire region by not adding it to updated_ranges
    else
      -- Keep ranges that don't cover the current line
      table.insert(updated_ranges, range)
    end
  end

  if not found then
    vim.notify('No highlight found at line ' .. line_num, vim.log.levels.INFO)
    return
  end

  -- Update persistent storage
  if #updated_ranges == 0 then
    M.persistent_highlights[filename] = nil
  else
    M.persistent_highlights[filename] = updated_ranges
  end

  -- Save to file
  save_highlights()

  -- Clear and reapply highlights for this buffer
  clear_buffer_extmarks(bufnr)
  if updated_ranges and #updated_ranges > 0 then
    for _, range in ipairs(updated_ranges) do
      apply_highlight_to_buffer(bufnr, range)
    end
  end
end

-- Check if a line is within any highlight range
local function is_line_highlighted(filename, line_num)
  local ranges = M.persistent_highlights[filename]
  if not ranges then
    return false
  end

  for _, range in ipairs(ranges) do
    if range.startLine and range.endLine and range.startLine <= line_num and range.endLine >= line_num then
      return true
    end
  end

  return false
end

-- Command implementation
local function region_highlight_cmd(opts)
  local start_line = opts.line1
  local end_line = opts.line2

  -- Check if this is a single line (no visual selection)
  if start_line == end_line then
    local filename = vim.api.nvim_buf_get_name(0)
    if filename ~= '' and is_line_highlighted(filename, start_line) then
      -- Line is highlighted, clear it instead
      M.clear_highlight_at_line(start_line)
      return
    end
  end

  -- Otherwise, highlight the range
  M.highlight_range(start_line, end_line)
end

-- Clear all highlights in the current file
function M.clear_all_highlights()
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)

  if filename == '' then
    vim.notify('Cannot clear highlights in unnamed buffer', vim.log.levels.WARN)
    return
  end

  local ranges = M.persistent_highlights[filename]
  if not ranges or #ranges == 0 then
    vim.notify('No highlights found for this file', vim.log.levels.INFO)
    return
  end

  -- Remove all highlights for this file
  M.persistent_highlights[filename] = nil

  -- Save to file
  save_highlights()

  -- Clear all extmarks for this buffer
  clear_buffer_extmarks(bufnr)

  vim.notify('Cleared all highlights for this file', vim.log.levels.INFO)
end

-- Clear command implementation
local function region_highlight_clear_cmd(opts)
  -- Get current cursor position
  local line_num = vim.api.nvim_win_get_cursor(0)[1]

  M.clear_highlight_at_line(line_num)
end

-- Clear all command implementation
local function region_highlight_clear_all_cmd(opts)
  M.clear_all_highlights()
end

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend('force', M.config, opts)

  -- Initialize mode based on current background
  M.current_mode = vim.o.background or 'dark'

  -- Load persistent highlights
  M.persistent_highlights = load_highlights()

  -- Create highlight groups
  create_highlight_groups()

  -- Create the commands
  vim.api.nvim_create_user_command('RegionHighlight', region_highlight_cmd, {
    range = true,
    desc = 'Highlight the selected region with a background color',
  })

  vim.api.nvim_create_user_command('RegionHighlightClear', region_highlight_clear_cmd, {
    range = false,
    desc = 'Clear highlight at the current line',
  })

  vim.api.nvim_create_user_command('RegionHighlightClearAll', region_highlight_clear_all_cmd, {
    range = false,
    desc = 'Clear all highlights in the current file',
  })

  -- Apply highlights when entering a buffer
  vim.api.nvim_create_autocmd('BufEnter', {
    callback = function()
      local filename = vim.api.nvim_buf_get_name(0)
      if filename ~= '' then
        apply_file_highlights(filename)
      end
    end,
  })

  -- Recreate highlight groups when colorscheme changes
  vim.api.nvim_create_autocmd('ColorScheme', {
    callback = create_highlight_groups,
  })
end

M.setup()

return M
