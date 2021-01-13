local t = ...

t:install{
  -- Copy all example scripts.
  ['tool.lua']                  = '${install_base}/',

  -- Copy the report file.
  ['${report_path}']            = '${install_base}/.jonchki/'
}

-- Create the package file.
t:createPackageFile()

-- Create a hash file.
t:createHashFile()

-- Build the artifact.
t:createArchive('${install_base}/../../../../${default_archive_name}', 'native')

return true

