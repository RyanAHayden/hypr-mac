-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local transparent_group = vim.api.nvim_create_augroup("ryha_transparent_background", { clear = true })

local function clear_backgrounds()
  local highlights = {
    "Normal",
    "NormalNC",
    "NormalFloat",
    "FloatBorder",
    "FloatTitle",
    "EndOfBuffer",
    "SignColumn",
    "LineNr",
    "CursorLineNr",
    "CursorLine",
    "CursorColumn",
    "ColorColumn",
    "Folded",
    "FoldColumn",
    "StatusLine",
    "StatusLineNC",
    "WinSeparator",
    "VertSplit",
  }

  for _, group in ipairs(highlights) do
    vim.api.nvim_set_hl(0, group, { bg = "none" })
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  group = transparent_group,
  callback = clear_backgrounds,
})

clear_backgrounds()

local dashboard_group = vim.api.nvim_create_augroup("ryha_dashboard", { clear = true })

local dashboard_filetypes = {
  alpha = true,
  dashboard = true,
  ministarter = true,
  snacks_dashboard = true,
}

local function clean_dashboard_window()
  if not dashboard_filetypes[vim.bo.filetype] then
    return
  end

  vim.schedule(function()
    vim.wo.cursorline = false
    vim.wo.foldcolumn = "0"
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.scrolloff = 0
    vim.wo.sidescrolloff = 0
    vim.wo.signcolumn = "no"
    vim.wo.statuscolumn = ""
    vim.wo.winbar = ""
  end)
end

vim.api.nvim_create_autocmd("FileType", {
  group = dashboard_group,
  pattern = vim.tbl_keys(dashboard_filetypes),
  callback = clean_dashboard_window,
})

clean_dashboard_window()

-- ponytail: drop shada oldfiles entries like "~./bashrc" (tilde-user syntax).
-- fnamemodify(":p") on these spawns a shell from the projects picker's async
-- callback, which nvim can't wait() on there and aborts (SIGABRT). Filter, don't shell out.
vim.v.oldfiles = vim.tbl_filter(function(f)
  return not f:match("^~[^/]")
end, vim.v.oldfiles)
