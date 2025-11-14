vim.api.nvim_create_user_command("Markket", function() 
  require("markket").markket()
end, {})
