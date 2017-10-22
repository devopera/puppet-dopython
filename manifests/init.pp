class dopython (

  # class arguments
  # ---------------
  # setup defaults

  $user = 'web',
  
  # default version is 2.7.13, alternates 3.3.7, 3.4.7 (not yet 3.5.4, 3.6.2)
  $version_python_major = $dopython::params::version_python_major,
  $version_python_minor = $dopython::params::version_python_minor,
  
  # default version is 1.9.1, alternate 13.1.2
  $version_virtualenv = $dopython::params::version_virtualenv,

  # end of class arguments
  # ----------------------
  # begin class

) inherits dopython::params {

  # install python
  case $operatingsystem {
    centos, redhat: {
      if ($::operatingsystemmajrelease < 7) {
        # compile python from source
        $python_combined_version = "${version_python_major}.${version_python_minor}"
        exec { 'python-install-prereqs':
          command => '/usr/bin/yum install -y "@Development tools" zlib-devel bzip2-devel openssl-devel ncurses-devel python-devel sqlite-devel',
        }->
        # fetch, expand and compile, if alias doesn't exist
        exec { 'python-install-compile':
          path    => '/usr/bin:/bin',
          command => "bash -c 'wget http://www.python.org/ftp/python/${python_combined_version}/Python-${python_combined_version}.tgz -O /tmp/Python-${python_combined_version}.tgz && cd /tmp && tar -xf Python-${python_combined_version}.tgz && cd Python-${python_combined_version} && ./configure --prefix=/usr/local --enable-shared && make && make altinstall'",
          creates => "/tmp/Python-${python_combined_version}",
          timeout => 1800,
          onlyif  => "test ! -e /usr/local/bin/python${version_python_major}",
        }->
        # clean up (if we've created a directory/file in /tmp)
        exec { 'python-install-cleanup':
          path    => '/usr/bin:/bin',
          command => 'rm -rf /tmp/Python-*',
          onlyif  => "test -d /tmp/Python-${python_combined_version}",
        }->
        # setup python shared/dynamic library using ldconfig
        file { 'python-dynamic-lib-dir':
          name => '/etc/ld.so.conf.d/python-shared-lib.conf',
          source => 'puppet:///modules/dopython/python-shared-lib.conf',
          owner => 'root',
          group => 'root',
          mode => 0644,
        }->
        # make the Dynamic Linker Run Time Bindings reread /etc/ld.so.conf.d
        exec { 'python-ldconfig':
          path => '/sbin:/usr/bin:/bin',
          command => "bash -c 'ldconfig'",
          before => File['usr-local-python'],
        }
        # consistent resource for later puppet requires
        file { 'usr-local-python' :
          path => "/usr/local/bin/python${version_python_major}",
          ensure => present,
        }
      } else {
        $version_python_major_dotless = regsubst($version_python_major, '\.', '', 'G')
        package { 'python-install-prereqs' :
          name => 'python-devel',
          ensure => 'present',
        }->
        package { "python${version_python_major_dotless}" : }->
        # create local alias for consistency
        file { 'usr-local-python' :
          path => "/usr/local/bin/python${version_python_major}",
          target => "/usr/bin/python${version_python_major}",
          ensure => link,
        }
      }
    }
    fedora: {
      # install python
      package { 'python-install-prereqs' :
        name => 'python-devel',
        ensure => 'present',
      }->
      # create local alias for consistency
      file { 'usr-local-python' :
        path => "/usr/local/bin/python${version_python_major}",
        target => "/usr/bin/python${version_python_major}",
        ensure => link,
      }
    }
    ubuntu, debian: {
      # install python
      package { 'python-install-prereqs' :
        name => 'python-dev',
        ensure => 'present',
      }->
      package { "python${version_python_major}" : }->
      # create local alias for consistency
      file { 'usr-local-python' :
        path => "/usr/local/bin/python${version_python_major}",
        target => "/usr/bin/python${version_python_major}",
        ensure => link,
      }
    }
  }
  
  $venv_target_directory = '/usr/local/pythonenv/galaxy'
  $command_bash_include_virtualenv = "\n# activate python virtualenv if present\nif [ -f ${venv_target_directory}/bin/activate ]; then\n        source ${venv_target_directory}/bin/activate\nfi\n"
  
  # setup galaxy virtual environment in /usr/local/pythonenv
  file { 'python-venv-root' :
    path => '/usr/local/pythonenv',
    ensure => 'directory',
    mode => 0755,
    require => File['usr-local-python'],
  }->
  # download, expand and execute to install galaxy virtualenv (if alias doesn't exist), then install virtualenv in it
  exec { 'python-venv-install-galaxy':
    path    => '/usr/bin:/bin',
    command => "bash -c 'wget --no-check-certificate https://pypi.python.org/packages/source/v/virtualenv/virtualenv-${version_virtualenv}.tar.gz -O /tmp/virtualenv-${version_virtualenv}.tar.gz && cd /tmp && tar -xzf virtualenv-${version_virtualenv}.tar.gz && /usr/local/bin/python${version_python_major} virtualenv-${version_virtualenv}/virtualenv.py --no-site-packages --distribute ${venv_target_directory} && ${venv_target_directory}/bin/pip install virtualenv-${version_virtualenv}.tar.gz'",
    onlyif  => "test ! -d ${$venv_target_directory}",
  }->
  # clean up as root if we've created a directory/file in /tmp
  exec { 'python-venv-cleanup':
    path    => '/usr/bin:/bin',
    command => 'rm -rf /tmp/virtualenv-*',
    onlyif  => "test -d /tmp/virtualenv-${version_virtualenv}",
  }->
  anchor { 'python-venv' : }
  
  # include virtualenv in bashrc
  concat::fragment { 'dopython-bashrc-virtualenv':
    target  => "/home/${user}/.bashrc",
    content => $command_bash_include_virtualenv,
    # do just before colouring, because virtualenv messes with PS1
    order   => '19',
    require => [Exec['python-venv-install-galaxy']],
  }

  # if we're running SELinux
  if (str2bool($::selinux)) {
    # enable SELinux access to virtualenv directory
    exec { 'python-venv-selinux-http':
      path    => '/usr/sbin:/sbin:/bin',
      # testing a simpler version of this command
      # command => "bash -c 'semanage fcontext --add --ftype -- --type httpd_sys_content_t \"${venv_target_directory}/lib/python${version_python_major}/site-packages(/.*)?\" && semanage fcontext --add --ftype -d --type httpd_sys_content_t \"${venv_target_directory}/lib/python${version_python_major}/site-packages(/.*)?\" && restorecon -vR  ${venv_target_directory}/lib/python${version_python_major}/site-packages'",
      command => "bash -c 'semanage fcontext -a -t httpd_sys_content_t \"${venv_target_directory}/lib/python${version_python_major}/site-packages(/.*)?\" && semanage fcontext -a -t httpd_sys_content_t \"${venv_target_directory}/lib/python${version_python_major}/site-packages(/.*)?\" && restorecon -vR  ${venv_target_directory}/lib/python${version_python_major}/site-packages'",
      require => Exec['python-venv-install-galaxy'],
    }->
    # allow tmp exec to avoid memory error (https://bugzilla.redhat.com/show_bug.cgi?id=717404)
    # without having to hack /usr/local/lib/python2.7/ctypes/__init__.py (http://stackoverflow.com/questions/5914673/python-ctypes-memoryerror-in-fcgi-process-from-pil-library)
    # setsebool -P httpd_tmp_exec 1
    exec { 'python-memerr-selinux-http':
      path    => '/usr/sbin:/sbin:/bin',
      command => 'setsebool -P httpd_tmp_exec 1',
    }
  }

}
