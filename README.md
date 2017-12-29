# PE Bitbuket Server Vagrant Stack

This Vagrant stack includes 2 virtual machines:

| VM Name       | Description |
|---------------|-------------|
| puppet-master | A Monolithic install of PE 2017.3.2 on CentOS 7 |
| bitbucket     | BitBucket Server 5.6.2 on CentOS 7              |

The `bitbucket` VM is setup to install BitBucket Server using the all-in-one `.bin` installer from Atlassian. BitBucket Server is setup using a developer-mode which means it will only allow `git push`'s to it for about 8 hours. You can create an account on https://my.atlassian.com and create a free evaluation license that will be good for 30 days. The licenses are very easy to make.

The goal of the stack is to facilitate testing and understanding of how to use code-manager with BitBucket Server.

http://blogs.atlassian.com/2014/11/automating-stash-deployments/

## BitBucket Access

You can reach the BitBucket Server UI on port **7990**

Username is: **admin**

Password is: **admin**

## What this stack does for you

The stack sets up a PE 2017.3.2 puppet master and a BitBucket Server 5.6.2 instance.

### What's being automated?

If you are attempting to replicate this setup, here are the steps that you would need to complete manually (but that this stack takes care of for you).

1. Create an RBAC user on the Puppet master and generate an auth token to be used by the webhook.
  * https://docs.puppetlabs.com/pe/latest/code_mgr_webhook.html#generate-an-authentication-token
  * I've done this automatically with the puppet code in:
    `site/profile/manifests/code_manager.pp`
1. Add the Puppet Master's CA cert to the Java keystore on the BitBucket server:
  * Determine the $JAVA_HOME value used for BitBucket by looking in: `/opt/atlassian/bitbucket/<version>/bin/setenv.sh`
    * You can also look at the `System Information` page of the Web GUI. In my case, it's `/opt/atlassian/bitbucket/5.6.2/jre`
  * Run the following command and replace `$JAVA_HOME` with the path just determined:

    ```
    $JAVA_HOME/bin/keytool -import -alias puppet-server -file /etc/puppetlabs/puppet/ssl/certs/ca.pem -keystore $JAVA_HOME/lib/security/cacerts
    ```

    * When asked for a password, use `changeit`.
  * There's Puppet code to automate the Java KS cert at: [site/profile/manifests/bitbucket.pp:48-56](site/profile/manifests/bitbucket.pp#L48-56)

## Manual Setup of BitBucket

After running vagrant up, there's a few things that need to be setup manually...

1. Install the following BitBucket Server plugin by logging into the web GUI of the BitBucket server and going to `Find new add-ons`.
    * https://marketplace.atlassian.com/plugins/com.atlassian.stash.plugin.stash-web-post-receive-hooks-plugin/server/overview

1. Make a `Project` and a new `repository`:
    * Project name: __puppet__ (with a short name of __PUP__)
    * Repository name: __control-repo__

1. Create a user account that Code Manager will use to deploy code.
    * Create a user called `puppet` with a password of `puppet`.
    * Make the r10k user an admin of the `PUP` project.
        * This is needed to allow the automatic creation of deploy keys with abrader/gms.

1. Either use the admin user to test pushing code, or create a user for yourself and add your SSH key to that user.
    * If making a user for yourself, give your user account read/write or admin privilege to the `PUP` project.

1. Configure the hook on your control repo.
    * Click the `Hooks` tab under the repo's settings.
    * Click the pencil icon next to `Post-Receive WebHooks`
    * The URL to drop in should be in the format of:

      ```
      https://puppet-master:8170/code-manager/v1/webhook?type=stash&token=<TOKEN>
      ```

    * Replace \<TOKEN\> with the RBAC Token that was generated automatically for you.
        * The token value can be found on the puppet master in a file at: `/vagrant/code_manager_rbac_token.txt`
        * or in the Vagrant directory as: `code_manager_rbac_token.txt`


## Troubleshooting

### BitBucket

The main BitBucket log that you'll want to monitor to troubleshoot the webhook is:

  ```
  /var/atlassian/application-data/bitbucket/log/atlassian-bitbucket.log
  ```

Most likely, the problem you have will be with SSL validation of code-manager. There's a `java_ks` resource in `site/profile/manifests/bitbucket.pp` that attempts to manage this. This guide shows how to manually add the Master's CA to the Java keystore that BitBucket uses.
  * https://confluence.atlassian.com/display/KB/Connecting+to+SSL+services

### Puppetserver

Monitor the puppetserver log to ensure that file-sync hasn't crashed puppetserver: `/var/log/puppetlabs/puppetserver/puppetserver.log`

### TODO

Automate the initial setup of BitBucket Server (users, project, and repo creation). Probably with a combination of installer properties and API curls:
* https://confluence.atlassian.com/bitbucketserver/automated-setup-for-bitbucket-server-776640098.html
* https://developer.atlassian.com/static/rest/bitbucket-server/4.3.1/bitbucket-rest.html

## Other Notes

This is based on the puppet-debugging-kit.

https://github.com/Sharpie/puppet-debugging-kit
