class profile::code_manager {

  $code_manager_service_user = 'code_manager_service_user'
  $code_manager_service_user_password = fqdn_rand_string(40, '', "${code_manager_service_user}_password")

  #puppet_master_classifier_settings is a custom function
  $classifier_settings   = puppet_master_classifer_settings()
  $classifier_hostname   = $classifier_settings['server']
  $classifier_port       = $classifier_settings['port']

  $token_directory       = '/etc/puppetlabs/puppetserver/.puppetlabs'
  $token_filename        = "${token_directory}/${code_manager_service_user}_token"

  $code_manager_ssh_key_file = '/etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa'

  file { '/etc/puppetlabs/puppetserver/ssh':
    ensure => directory,
    owner  => 'pe-puppet',
    group  => 'pe-puppet',
    mode   => '0755',
  }

  exec { 'create code manager ssh key' :
    command => "/usr/bin/ssh-keygen -t rsa -b 4096 -C 'code_manager' -f ${code_manager_ssh_key_file} -q -N ''",
    creates => $code_manager_ssh_key_file,
    require => File['/etc/puppetlabs/puppetserver/ssh'],
  }

  file { $code_manager_ssh_key_file :
    ensure  => file,
    owner   => 'pe-puppet',
    group   => 'pe-puppet',
    require => Exec['create code manager ssh key'],
  }

  #If files exist in the codedir code manager can't manage them unless pe-puppet can read them
  exec { 'chown all environments to pe-puppet' :
    command => "/bin/chown -R pe-puppet:pe-puppet ${::settings::codedir}",
    unless  => "/usr/bin/test \$(stat -c %U ${::settings::codedir}/environments/production) = 'pe-puppet'",
  }

  $code_manager_role_name = 'Deploy Environments'
  $create_role_creates_file = '/etc/puppetlabs/puppetserver/.puppetlabs/deploy_environments_created'
  $create_role_curl = @(EOT)
    /opt/puppetlabs/puppet/bin/curl -s -k -X POST -H 'Content-Type: application/json' \
    https://<%= $classifier_hostname %>:4433/rbac-api/v1/roles \
    -d '{"permissions": [{"object_type": "environment", "action": "deploy_code", "instance": "*"},
    {"object_type": "tokens", "action": "override_lifetime", "instance": "*"}],"user_ids": [], "group_ids": [], "display_name": "<%= $code_manager_role_name  %>", "description": ""}' \
    --cert <%= $::settings::certdir %>/<%= $::trusted['certname'] %>.pem  \
    --key <%= $::settings::privatekeydir %>/<%= $::trusted['certname'] %>.pem  \
    --cacert <%= $::settings::certdir %>/ca.pem;
    touch <%= $create_role_creates_file %>
    | EOT

  exec { 'create deploy environments role' :
    command   => inline_epp( $create_role_curl ),
    creates   => $create_role_creates_file,
    logoutput => true,
    path      => $::path,
    require   => File[$token_directory],
  }

  rbac_user { $code_manager_service_user :
    ensure       => 'present',
    name         => $code_manager_service_user,
    email        => "${code_manager_service_user}@example.com",
    display_name => 'Code Manager Service Account',
    password     => $code_manager_service_user_password,
    roles        => [ $code_manager_role_name ],
    require      => Exec['create deploy environments role'],
  }

  file { $token_directory :
    ensure => directory,
    owner  => 'pe-puppet',
    group  => 'pe-puppet',
  }

  exec { "Generate Token for ${code_manager_service_user}" :
    command => epp('profile/create_rbac_token.epp',
                  { 'code_manager_service_user'          => $code_manager_service_user,
                    'code_manager_service_user_password' => $code_manager_service_user_password,
                    'classifier_hostname'                => $classifier_hostname,
                    'classifier_port'                    => $classifier_port,
                    'token_filename'                     => $token_filename
                  }),
    creates => $token_filename,
    require => [ Rbac_user[$code_manager_service_user], File[$token_directory] ],
  }

  #this file cannont be read until the next run after the above exec
  #because the file function runs on the master not on the agent
  #so the file doesn't exist at the time the function is run
  $rbac_token_file_contents = file($token_filename, '/dev/null')

  #Only mv code if this is at least the 2nd run of puppet
  #Code manager needs to be enabled and puppet server restarted
  #before this exec can complete.  Gating on the token file
  #ensures at least one run has completed
  if $::code_manager_mv_old_code and !empty($rbac_token_file_contents) {

    $timestamp = chomp(generate('/bin/date', '+%Y%d%m_%H:%M:%S'))

    exec { 'mv files out of $environmentpath' :
      command   => "mkdir /etc/puppetlabs/env_back_${timestamp};
                    mv ${::settings::codedir}/environments/* /etc/puppetlabs/env_back_${timestamp}/;
                    rm /opt/puppetlabs/facter/facts.d/code_manager_mv_old_code.txt;
                    TOKEN=`/opt/puppetlabs/puppet/bin/ruby -e \"require 'json'; puts JSON.parse(File.read('${token_filename}'))['token']\"`;
                    /opt/puppetlabs/puppet/bin/curl -s -k -X POST -H 'Content-Type: application/json' \"https://${::trusted['certname']}:8170/code-manager/v1/deploys?token=\$TOKEN\" -d '{\"environments\": [\"${::environment}\"], \"wait\": true}';
                    /opt/puppetlabs/puppet/bin/curl -s -k -X POST -H 'Content-Type: application/json' \"https://${::trusted['certname']}:8170/code-manager/v1/deploys?token=\$TOKEN\" -d '{\"deploy-all\": true, \"wait\": true}';
                    sleep 15",
      path      => $::path,
      logoutput => true,
      require   => Exec["Generate Token for ${code_manager_service_user}"],
    }
  }

  # The creation of a deploy key associated with a project can be automated
  # with this resource; however, in the Vagrant environment, the BitBucket server would need
  # to be up and configured with a Project and r10k username/password before this will work.
  git_deploy_key { "add_deploy_key_to_PUP-${::fqdn}":
    ensure       => present,
    name         => $::fqdn,
    username     => 'r10k',
    password     => 'puppet',
    project_name => 'PUP',
    path         => "${code_manager_ssh_key_file}.pub",
    server_url   => 'http://bitbucket:7990',
    provider     => 'stash',
  }

  # Create a file on the puppet master with the contents of the RBAC token.
  # THIS SHOULD NOT BE DONE IN PRODUCTION, AND IS ONLY HERE TO MAKE THE VAGRANT
  # ENVIRONMENT EASY TO USE.
  if !empty($rbac_token_file_contents) {
    $rbac_token = parsejson($rbac_token_file_contents)['token']

    file { '/vagrant/code_manager_rbac_token.txt':
      ensure  => file,
      owner   => 'vagrant',
      group   => 'vagrant',
      content => "${rbac_token}\n",
    }

  }
}
