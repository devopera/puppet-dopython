
# apply permission to a file/directory sensitively
define dopython::pipinstall(
  $packagename = $title,
) {
    exec { "dopython-pipinstall-${title}" :
      path => '/bin:/usr/bin:/sbin:/usr/sbin',
      command => "bash -c \"source /usr/local/pythonenv/galaxy/bin/activate && pip install --quiet ${packagename}\"",
      require => [Anchor['python-venv']],
    }
}

