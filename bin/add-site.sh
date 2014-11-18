#!/bin/bash
# Add a site to a VIP Quickstart install, in Vagrant or EC2
# by Weston Ruter (@westonruter), XWP <https://xwp.co/>
#
# This script facilitates adding new sites to the multisite install. It turns on
# the SUBDOMAIN_INSTALL option so that when new sites are created it doesn't reoute
# them via subdirectory paths. Then after the site is created as a subdomain it
# rewrites the subdomain to use a top-level domain or whatever site domain is provided.
# This is important for Quickstart in Vagrant since *.vip.local subdomains are not
# currently recognized by Zeroconf.
#
# LICENSE: GPLv2+
# 
# INSTALLATION:
# Place script in the bin/ root directory of VIP Quickstart.
#
# USAGE:
# bin/add-site.sh SITE_SLUG [SITE_DOMAIN]
#
# EXAMPLES:
# bin/add-site.sh foo  # site added at http://foo.local
# bin/add-site.sh bar passthe.bar.local # site @ http://passthe.bar.local
# bin/add-site.sh stage staging.example.com  # site @ http://staging.example.com

set -e
shopt -s expand_aliases

while [ "$( pwd )" != "/" ]; do
	if [ -e Vagrantfile ]; then
		break
	else
		cd ..
	fi
done
if [ ! -e Vagrantfile ]; then
	echo 'Error: Please run from root of VIP Quickstart repo' 1>&2
	exit 1
fi

site_slug="$1"
if [ -z "$site_slug" ]; then
	echo 'Error: Missing first site_slug argument' 1>&2
	exit 1
fi

site_domain="$2"
vagrant_ip='10.86.73.80'

if command -v vagrant >/dev/null 2>&1 && [ ! -e /vagrant ]; then
	function wp {
		# Note: This wp wrapper will not accept any args that require quotes
		args="$@"
		vagrant ssh -c "cd /vagrant/www/wp; /usr/bin/wp $args" -- -q -T
	}
else
	alias wp="wp --allow-root"
fi

root_domain=$( wp option get home | sed 's:.*//::' )
if [ -z "$site_domain" ]; then
	site_domain="$site_slug.local"
fi

echo "root_domain: $root_domain"
echo "site_domain: $site_domain"

if ! grep -sq 'SUBDOMAIN_INSTALL' www/local-config.php; then
	echo "Enable SUBDOMAIN_INSTALL (non-subdirectory install)" 1>&2
	echo "define( 'SUBDOMAIN_INSTALL', true );" >> www/local-config.php
fi

blog_id=$( wp site list --format=csv --fields=blog_id,url | { grep -F ",$site_domain/" || true; } )
if [ ! -z "$blog_id" ]; then
	echo "Site has alread been added (blog_id=$blog_id)."
else
	temp_domain="$site_slug.$root_domain"
	echo "Check if temp domain $temp_domain has been created..."
	blog_id=$( wp site list --format=csv --fields=blog_id,url | { grep -F ",$temp_domain/" || true; } | sed 's/,.*//' )
	if [ -z "$blog_id" ]; then
		echo "Nope. Creating site..."
		blog_id=$( wp site create --porcelain --slug="$site_slug" )
		echo "Created site (blog_id=$blog_id)"
	else
		echo "Site already exists (blog_id=$blog_id) so proceeding to make sure configured."
	fi

	temp_domain=$( wp site url $blog_id | sed 's:.*//::' )
	if [ "$temp_domain" != "$site_domain" ]; then
		echo "Replace $temp_domain with $site_domain..."
		wp search-replace --network "$temp_domain" "$site_domain"
	fi
fi

host_updater_cmd='if ! grep -sq %s /etc/hosts; then echo "%s %s" | sudo tee -a /etc/hosts; else echo "%s already added"; fi'

if command -v vagrant >/dev/null 2>&1 && [ ! -e /vagrant ]; then
	if [ -e /etc/hosts ]; then
		echo "Add hosts file entry to Host..."
		eval "$( printf "$host_updater_cmd" "$site_domain" "$vagrant_ip" "$site_domain" "$site_domain" )"
	else
		echo "It looks like you are on Windows. You'll need to manually add to your hosts file:"
		echo "$vagrant_ip $site_domain"
	fi

	echo "Add hosts file entry to Vagrant..."
	vagrant ssh -c "$( printf "$host_updater_cmd" "$site_domain" "127.0.0.1" "$site_domain" "$site_domain" )" -- -q

	vagrant ssh -c 'sudo service memcached restart' -- -q # since `wp cache flush` is disabled for Multisite
else
	echo "Add hosts file entry to Host..."
	eval "$( printf "$host_updater_cmd" "$site_domain" "127.0.0.1" "$site_domain" "$site_domain" )"

	sudo service memcached restart
fi

exit 0
