vim.pack.add({
  {
    src = "https://github.com/nvim-treesitter/nvim-treesitter",
  },
})

require("nvim-treesitter").setup()

require("nvim-treesitter").install({
  -- Neovim
  "lua",
  "vim",
  "vimdoc",
  "query",

  -- Programming Languages
  "python",
  "cpp",
  "java",
  "javascript",
  "html",
  "css",
  "rust",
  "go",

  -- Shell
  "bash",

  -- Config Files
  "json",
  "json5",
  "yaml",
  "toml",
  "xml",
  "ini",

  -- Markdown
  "markdown",
  "markdown_inline",

  -- Git
  "git_config",
  "git_rebase",
  "gitattributes",
  "gitcommit",
  "gitignore",

  -- DevOps / Infrastructure
  "dockerfile",
  "ssh_config",

  -- Build Systems
  "cmake",
  "make",

  -- Data Formats
  "csv",

  -- Regex
  "regex",

  -- Documentation
  "comment",
})

vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    pcall(vim.treesitter.start)
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
  end,
})


