std = "max+busted"
globals = {
  "vim",
}

files["tests/**/*.lua"] = {
  std = "max+busted",
}

ignore = {
  "212", -- unused argument
  "213", -- unused loop variable
}
