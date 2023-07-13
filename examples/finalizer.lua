local t = ...

t:install{
  -- Copy all example scripts.
  ['mini.lua']                  = '${install_base}/',
  ['tool.lua']                  = '${install_base}/',

  -- Copy the report file.
  ['${report_path}']            = '${install_base}/.jonchki/'
}

return true
