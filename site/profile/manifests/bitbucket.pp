class profile::bitbucket {

  $bitbucket_version   = '5.6.2'
  $bitbucket_installer = "atlassian-bitbucket-${bitbucket_version}-x64.bin"
  $bitbucket_home      = '/var/atlassian/application-data/bitbucket'

  firewalld_port { 'Open port 7990':
    ensure   => present,
    zone     => 'public',
    port     => '7990',
    protocol => 'tcp',
  }

  firewalld_port { 'Open port 7999':
    ensure   => present,
    zone     => 'public',
    port     => '7999',
    protocol => 'tcp',
  }

  include archive

  # Get BitBucket
  archive { "/vagrant/${bitbucket_installer}":
    ensure  => present,
    source  => "https://www.atlassian.com/software/stash/downloads/binary/${bitbucket_installer}",
    creates => "/vagrant/${bitbucket_installer}",
    extract => false,
    cleanup => false,
  }

  # Make sure the installer is executable
  file { "/vagrant/${bitbucket_installer}":
    mode    => '0755',
    require => Archive["/vagrant/${bitbucket_installer}"],
  }

  # Run BitBucket Installer
  exec { 'Run Bitbucket Server Installer':
    command   => "/vagrant/${bitbucket_installer} -q",
    creates   => "/opt/atlassian/bitbucket/${bitbucket_version}/bin/_start-webapp.sh",
    logoutput => true,
    require   => [
      File["/vagrant/${bitbucket_installer}"],
      Package['git'],
    ],
  }

  file { '/usr/bin/keytool':
    ensure => link,
    target => "/opt/atlassian/bitbucket/${bitbucket_version}/jre/bin/keytool",
  }

  file { 'bitbucket.service':
    ensure  => file,
    path    => '/etc/systemd/system/bitbucket.service',
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => epp('profile/bitbucket.service.epp', { bitbucket_version => $bitbucket_version }),
    notify  => Exec['reload systemctl'],
  }

  exec { 'reload systemctl':
    command     => 'systemctl daemon-reload',
    path        => $facts['path'],
    refreshonly => true,
  }

  service { 'bitbucket':
    ensure  => running,
    enable  => true,
    require => [
      Exec['Run Bitbucket Server Installer'],
      File['bitbucket.service'],
      Exec['reload systemctl'],
    ]
  }

  # Add the Puppet CA as a trusted certificate authority because
  # the webhook add-on must use a trusted connection.
  java_ks { $::settings::server :
    ensure       => latest,
    certificate  => "${::settings::certdir}/ca.pem",
    target       => "/opt/atlassian/bitbucket/${bitbucket_version}/jre/lib/security/cacerts",
    password     => 'changeit',
    trustcacerts => true,
    require      => [ Exec['Run Bitbucket Server Installer'], File['/usr/bin/keytool'] ],
    notify       => Service['bitbucket'],
  }

  file_line { 'bitbucket dev mode':
    ensure  => present,
    path    => "/opt/atlassian/bitbucket/${bitbucket_version}/bin/_start-webapp.sh",
    line    => 'JVM_SUPPORT_RECOMMENDED_ARGS="-Datlassian.dev.mode=true"',
    match   => '#JVM_SUPPORT_RECOMMENDED_ARG',
    notify  => Service['bitbucket'],
    require => Exec['Run Bitbucket Server Installer'],
  }

  # Add ruby and the puppet-lint gem for the pre-receive hooks.
  package { 'ruby':
    ensure => present,
  }

  package { 'puppet-lint':
    ensure   => present,
    provider => 'gem',
    require  => Package['ruby'],
  }

}
