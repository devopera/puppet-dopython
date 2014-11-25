class dopython::wsgi (

  # class arguments
  # ---------------
  # setup defaults

  $user = 'web',
  
  $version_mod_wsgi = '3.5',
  $version_python_major = '2.7',

  # end of class arguments
  # ----------------------
  # begin class

) {

  # fetch apache params
  include apache::params

  # install python and mod_wsgi
  case $operatingsystem {
    centos, redhat, fedora: {
      if ($operatingsystemrelease < 7.0) {
        # mod_wsgi build pre-requisites: httpd-devel for Apache extension tool (apxs)
        if ! defined( Package['httpd-devel'] ) {
          package { 'httpd-devel' :
            ensure => installed,
          }
        }
        # compile mod_wsgi from source
        exec { 'modwsgi-install-compile':
          path    => '/usr/bin:/bin',
          command => "bash -c 'wget https://github.com/GrahamDumpleton/mod_wsgi/archive/${version_mod_wsgi}.tar.gz -O /tmp/mod_wsgi-${version_mod_wsgi}.tar.gz && cd /tmp && tar -xf mod_wsgi-${version_mod_wsgi}.tar.gz && cd mod_wsgi-${version_mod_wsgi} && ./configure --with-python=/usr/local/bin/python${version_python_major} && make && make install'",
          creates => "/tmp/mod_wsgi-${version_mod_wsgi}",
          require => [Package['httpd-devel'], File['usr-local-python']],
          onlyif  => "test ! -e /usr/lib64/httpd/modules/mod_wsgi.so",
        }->
        # clean up (if we've created a directory/file in /tmp)
        exec { 'modwsgi-install-cleanup':
          path    => '/usr/bin:/bin',
          command => 'rm -rf /tmp/mod_wsgi-*',
          onlyif  => "test -d /tmp/mod_wsgi-${version_mod_wsgi}",
          before  => File['mod_wsgi-vhost'],
        }
      }
    }
    ubuntu, debian: {
      # could check for ubuntu 12.04 or later
      if (versioncmp($lsbdistrelease, '12.04') >= 0) {
      }
      
      # install wsgi for production python serving (without 'include apache' which wipes vhosts)
      package { 'mod_wsgi_package':
        ensure  => 'present',
        name    => $apache::params::mod_packages['wsgi'],
        require => Anchor['doapache-package'],
        before  => File['mod_wsgi-vhost'],
      }
    }
  }

  # create vhost that loads mod_wsgi, before anything that might require it
  file { 'mod_wsgi-vhost' :
    name => "${apache::params::confd_dir}/00_wsgi.conf",
    content => template('dopython/wsgi.conf.erb'),
    ensure => 'present',
    owner => 'root',
    group => 'root',
    mode => 0644,
  }
  
  # restart (not graceful) apache to avoid seg fault
  exec { 'mod_wsgi-refresh-apache' :
    path => '/bin:/usr/bin:/sbin:/usr/sbin',
    command => "service ${apache::params::apache_name} restart",
    tag => ['service-sensitive'],
    require => [File['mod_wsgi-vhost']],
  }

}
