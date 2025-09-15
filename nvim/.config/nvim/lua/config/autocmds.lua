-- Restore last cursor position when reopening a file
local last_cursor_group = vim.api.nvim_create_augroup("LastCursorGroup", {})
vim.api.nvim_create_autocmd("BufReadPost", {
  group = last_cursor_group,
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- python formatting
vim.api.nvim_create_autocmd({"BufNewFile", "BufRead"}, {
  pattern = "*.py",
  callback = function()
    vim.opt.textwidth = 79
    vim.opt.colorcolumn = "79"
  end
})

-- javascript formatting
vim.api.nvim_create_autocmd({"BufNewFile", "BufRead"}, {
  pattern = {"*.js", "*.html", "*.css", "*.lua"},
  callback = function()
    vim.opt.tabstop = 2
    vim.opt.softtabstop = 2
    vim.opt.shiftwidth = 2
  end
})

-- Highlight yanked text (works across 0.8 → 0.10+)
local highlight_yank_group = vim.api.nvim_create_augroup("HighlightYank", { clear = true })

-- Prefer the long-standing API, fall back to the newer table if present.
local on_yank = (vim.highlight and vim.highlight.on_yank) or (vim.hl and vim.hl.on_yank)

vim.api.nvim_create_autocmd("TextYankPost", {
  group = highlight_yank_group,
  desc = "Briefly highlight on yank",
  callback = function()
    if on_yank then
      -- Wrap in pcall so a random edge case never breaks yank again.
      pcall(on_yank, {
        higroup = "IncSearch",  -- not 'hl'
        timeout = 200,
        on_visual = true,
      })
    end
  end,
})

