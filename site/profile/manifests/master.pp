class profile::master {

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

