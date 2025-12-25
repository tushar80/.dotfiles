-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

vim.keymap.set("n", "<leader>/", function()
  Snacks.picker.lines({
    layout = {
      preset = "dropdown",
      preview = false,
    },
  })
end, { desc = "Fuzzily search in current buffer" })

-- Find files (respects .gitignore)
vim.keymap.set("n", "<leader><space>", function()
  Snacks.picker.files({ hidden = true })
end, { desc = "Find Files" })

vim.keymap.set("n", "<leader>ff", function()
  Snacks.picker.files({ hidden = true })
end, { desc = "Find Files" })
