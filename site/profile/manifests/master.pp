class profile::master {

  service { 'puppet':
    ensure => running,
    enable => true,
  }

}

