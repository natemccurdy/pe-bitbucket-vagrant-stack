class profile::master {

  service { 'puppet':
    ensure => running,
    enable => true,
  }

  include firewalld

  $puppet_master_ports = [
    '443',
    '8140',
    '8170',
  ]

  $puppet_master_ports.each | $port | {

    firewalld_port { "Open port ${port}":
      ensure   => present,
      zone     => 'public',
      port     => $port,
      protocol => 'tcp',
    }

  }

}

