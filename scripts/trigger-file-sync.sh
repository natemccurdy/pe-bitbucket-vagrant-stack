#!/bin/bash
# This script synchorizes code from code-staging to code.
echo "==> Delete the code dir so file-sync can do its thing"
sudo rm -rf /etc/puppetlabs/code/*

# Determine paths to certs.
certname="$(puppet agent --configprint certname)"
certdir="$(puppet agent --configprint certdir)"

# Set variables for the curl.
cert="${certdir}/${certname}.pem"
key="$(puppet agent --configprint privatekeydir)/${certname}.pem"
cacert="${certdir}/ca.pem"

echo "==> Hitting the file-sync commit endpoint at https://$(hostname -f):8140/file-sync/v1/commit"
/opt/puppetlabs/puppet/bin/curl -s --request POST --header "Content-Type: application/json" --data '{"commit-all": true}' \
                                --cert "$cert" \
                                --key "$key" \
                                --cacert "$cacert" \
                                "https://$(hostname -f):8140/file-sync/v1/commit" && echo

