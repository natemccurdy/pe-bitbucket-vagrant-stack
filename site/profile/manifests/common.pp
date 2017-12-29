# This class is for common resources between all nodes and
# resources and things that don't really fit into their own profile.
class profile::common {

  include firewalld
  include epel

  service { 'puppet':
    ensure => running,
    enable => true,
  }

  # New versions of bitbucket require a modern git (2.2.0+).
  # The WANDisco repo keeps an up to date rpm for centos7.
  package { 'wandisco git repo':
    ensure   => present,
    name     => 'wandisco-git-release-7-1.noarch',
    source   => 'http://opensource.wandisco.com/centos/7/git/x86_64/wandisco-git-release-7-1.noarch.rpm',
    provider => 'rpm',
  }

  # Some useful packages
  $pkgs = [ 'telnet', 'vim', 'tree', 'git' ]

  package { $pkgs:
    ensure  => present,
    require => [
      Class['epel'],
      Package['wandisco git repo'],
    ],
  }

}
