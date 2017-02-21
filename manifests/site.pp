## site.pp ##

# Disable filebucket by default for all File resources:
# http://docs.puppetlabs.com/pe/latest/release_notes.html#filebucket-resource-no-longer-created-by-default
File { backup => false }


node 'bitbucket' {
  include profile::common
  include profile::bitbucket
}

node 'puppet-master'{
  include profile::common
  include profile::master
  include profile::code_manager
}

node default {
}

