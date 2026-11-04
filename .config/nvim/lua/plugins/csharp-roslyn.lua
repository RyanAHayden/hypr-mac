-- C#: Microsoft's Roslyn LSP (what VS Code C# Dev Kit uses) instead of OmniSharp.
-- Server installed via: dotnet tool install -g roslyn-language-server --prerelease \
--   --source https://pkgs.dev.azure.com/azure-public/vside/_packaging/vs-impl/nuget/v3/index.json
-- Update: same command with `update` instead of `install`.
vim.env.PATH = vim.env.HOME .. "/.dotnet/tools:" .. vim.env.PATH

return {
  { "neovim/nvim-lspconfig", opts = { servers = { omnisharp = { enabled = false } } } },
  { "seblyng/roslyn.nvim", ft = { "cs", "razor" }, opts = {} },
}
