local M = {}

M.config = {
  -- Default configuration options
}

function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend('force', M.config, opts)
end

return M
