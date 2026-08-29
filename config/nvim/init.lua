vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.breakindent = true
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.splitright = true
vim.opt.splitbelow = true

local lazy_path = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazy_path) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazy_path })
end
vim.opt.rtp:prepend(lazy_path)

require("lazy").setup({
  { "folke/tokyonight.nvim", priority = 1000, config = function() vim.cmd.colorscheme("tokyonight-night") end },
  { "nvim-lua/plenary.nvim" },
  { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" }, keys = {
    { "<leader><leader>", "<cmd>Telescope find_files<cr>", desc = "Find files" },
    { "<leader>sg", "<cmd>Telescope live_grep<cr>", desc = "Search text" },
  } },
  { "nvim-tree/nvim-tree.lua", config = true, keys = { { "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "File tree" } } },
  { "lewis6991/gitsigns.nvim", config = true },
  { "nvim-lualine/lualine.nvim", config = true },
  { "akinsho/toggleterm.nvim", version = "*", config = true },
})

vim.keymap.set("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
vim.keymap.set("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })
