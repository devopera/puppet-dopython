class dopython::params {

  case $operatingsystem {
    centos, redhat, fedora: {
      case $::operatingsystemmajrelease {
        '7', default: {
          $version_python_major = '3.6'
          $version_python_minor = '8'
          $version_virtualenv = '16.2.0'
        }
        '6': {
          $version_python_major = '2.7'
          $version_python_minor = '9'
          $version_virtualenv = '1.9.1'
        }
      }
    }
    ubuntu, debian: {
      case $::operatingsystemmajrelease {
        '13.04', '14.04', default: {
          $version_python_major = '3.5'
          $version_python_minor = '2'
          $version_virtualenv = '13.1.2'
        }
        '12.04': {
          $version_python_major = '3.3'
          $version_python_minor = '5'
          $version_virtualenv = '13.1.2'
        }
      }
    }
  }

}

