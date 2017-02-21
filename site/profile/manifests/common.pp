# This class is for common resources between all nodes and
# resources and things that don't really fit into their own profile.
class profile::common {

  include firewalld
  include epel

  service { 'puppet':
    ensure => running,
    enable => true,
  }

  # Some useful packages
  $pkgs = [ 'telnet', 'vim', 'tree', 'git' ]

  package { $pkgs:
    ensure  => present,
    require => Class['epel'],
  }

}
