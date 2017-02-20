class profile::bitbucket {

  $bitbucket_version   = '4.13.0'
  $bitbucket_installer = "atlassian-bitbucket-${bitbucket_version}-x64.bin"
  $bitbucket_home      = '/var/atlassian/application-data/bitbucket'

  service { 'puppet':
    ensure => running,
    enable => true,
  }

  require epel

  include firewalld

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
    creates   => "/opt/atlassian/bitbucket/${bitbucket_version}/bin/setenv.sh",
    logoutput => true,
    require   => File["/vagrant/${bitbucket_installer}"],
  }

  file { '/usr/bin/keytool':
    ensure => link,
    target => "/opt/atlassian/bitbucket/${bitbucket_version}/jre/bin/keytool",
  }

  service { 'atlbitbucket':
    ensure     => running,
    hasstatus  => true,
    hasrestart => true,
    require    => Exec['Run Bitbucket Server Installer'],
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
    notify       => Service['atlbitbucket'],
  }

  file_line { 'bitbucket dev mode':
    ensure => present,
    path   => "/opt/atlassian/bitbucket/${bitbucket_version}/bin/setenv.sh",
    line   => 'export JAVA_OPTS="-Xms${JVM_MINIMUM_MEMORY} -Xmx${JVM_MAXIMUM_MEMORY} ${JAVA_OPTS} ${JVM_REQUIRED_ARGS} ${JVM_SUPPORT_RECOMMENDED_ARGS} ${BITBUCKET_HOME_MINUSD} -Datlassian.dev.mode=true"', #lint:ignore:single_quote_string_with_variables
    match  => '^export JAVA_OPTS=',
    notify => Service['atlbitbucket'],
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
