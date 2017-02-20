class profile::code_manager {

  class { 'pe_code_manager_webhook::code_manager':
    git_management_system => 'stash',
    manage_git_webhook    => false,
  }

  # The creation of a deploy key associated with a project can be automated
  # with this resource; however, in the Vagrant environment, the BitBucket server would need
  # to be up and configured with a Project and r10k username/password before this will work.
  git_deploy_key { $facts['fqdn']:
    ensure       => present,
    username     => 'r10k',
    password     => 'puppet',
    project_name => 'PUP',
    path         => '/etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa.pub',
    server_url   => 'http://bitbucket:7990',
    provider     => 'stash',
  }

  # Copy the RBAC token to the Vagrant dir for easy troubleshooting.
  $rbac_token_json = file('/etc/puppetlabs/puppetserver/.puppetlabs/code_manager_service_user_token', '/dev/null')

  if !empty($rbac_token_json) {

    $rbac_token = parsejson($rbac_token_json)['token']

    file { '/vagrant/code_manager_rbac_token.txt':
      ensure  => file,
      owner   => 'vagrant',
      group   => 'vagrant',
      mode    => '0644',
      content => "${rbac_token}\n",
    }
  }

}
