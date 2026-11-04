-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("n", "<leader>ac", function()
  Snacks.terminal("claude --dangerously-skip-permissions", { win = { position = "right" } })
end, { desc = "Claude (bypass perms)" })
