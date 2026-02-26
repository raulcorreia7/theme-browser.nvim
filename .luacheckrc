std = "max+busted"
globals = {
  "vim",
  "_",
}

files["tests/**/*.lua"] = {
  std = "max+busted",
  ignore = {
    "111", -- line too long
    "211", -- unused variable
    "212", -- unused argument
    "213", -- unused loop variable
    "631", -- line contains trailing whitespace
    "612", -- line contains only whitespace
  },
}

ignore = {
  "211", -- unused variable
  "212", -- unused argument
  "213", -- unused loop variable
  "612", -- line contains only whitespace
}
