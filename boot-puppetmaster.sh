#!/bin/bash
# Script to build a puppet master on an Ubuntu or Debian system.
# Requirements: An IP address, hostname, and valid network configuration.
# Takes one argument, the puppet repository to pull.
#
#. Setup git.
#. Checkout the puppet repository.
#. Install the puppetmaster package.
#. Install puppetmaster dependencies: librarian, hiera
#. [Install puppetmaster dependencies: postgresql, ngnix, etc.]
#. Let librarian pull modules
#. Start the puppetmaster service.
#
# Many parts of this scipt are borrowed from:
# https://github.com/seattle-biomed/bootstrap-linux/blob/master/bootstrap-linux
# https://github.com/pkhamre/puppetmaster-bootstrap/blob/master/puppetmaster-bootstrap
#
# ChangeLog
# 2013.05.06 - apowers: Initial write
# 2013.05.07 - apowers: bugfixes, mostly
# 2013.06.13 - apowers: repo as arg, error checking, git user
#
# TODO:
#. Install and configure Mcollective
#. Install and configure postgresql and puppetdb
#. Install and configure ngnix, unicorn, dashboard

PATH='/bin:/sbin:/usr/bin:/usr/sbin'

if [ "`/usr/bin/id -u`" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

if [ "$1" == "" ] ; then
  echo "Puppet repository required: user@git-host:repo" 1>&2
  exit 1
fi

REPOSITORY=$1
GIT_SERVER=`echo $1|sed -r 's/.+@([a-z.]+):.+/\1/'`

PUPPET_URL='http://apt.puppetlabs.com/'
DISTRIB_CODENAME=`awk -F= '/^DISTRIB_CODENAME/ { print $2 }' /etc/lsb-release`
PUPPET_REPO="puppetlabs-release-$DISTRIB_CODENAME.deb"
POSTGRESQL_VERSION='9.1'

# Make apt-get install really really quietly.
APT_OPTS='-qq -y'
export DEBIAN_FRONTEND=noninteractive
echo 'Dpkg::Options{"--force-confdef";"--force-confold";}' >> /etc/apt/apt.conf.d/local
GEM_OPTS='--no-rdoc --quiet --no-ri'

# Don't start services automatically
#echo no-triggers > /etc/dpkg/dpkg.cfg.d/custom

# Setup the puppetlabs apt repository
curl --silent ${PUPPET_URL}/pubkey.gpg | apt-key add - > /dev/null
/usr/bin/wget -O /tmp/$PUPPET_REPO $PUPPET_URL/$PUPPET_REPO
if [ "$?" != "0" ]
  echo "ERROR: unable to get $PUPPET_URL/$PUPPET_REPO"
  exit 1
fi
/usr/bin/dpkg -i /tmp/$PUPPET_REPO
/usr/bin/apt-get update

# Create local "git" user:
/usr/sbin/useradd -c "Git User" -U -m -s /bin/bash git
mkdir ~git/.ssh
ssh-keygen -t rsa -f ~git/.ssh/id_rsa -P ''

# Install and setup git.
/usr/bin/apt-get -y install git
/usr/bin/ssh-keyscan ${GIT_SERVER} > /etc/ssh/ssh_known_hosts
rm -rf /etc/puppet
su -l git -c "/usr/bin/git clone ${REPOSITORY} /etc/puppet"
chmod -r 644 /etc/puppet

# Install puppetmaster
/usr/bin/killall -9 puppetmaster
/usr/bin/apt-get ${APT_OPTS} install puppetmaster
/usr/bin/service puppetmaster start

#RubyGems
/usr/bin/apt-get ${APT_OPTS} install rubygems1.8
/usr/bin/gem install librarian-puppet ${GEM_OPTS}
/usr/bin/gem install hiera-gpg ${GEM_OPTS}
#/usr/bin/gem install activerecord --version 3.0.11 $GEM_OPTS
#/usr/bin/gem install pg $GEM_OPTS
#/usr/bin/gem install rack $GEM_OPTS

# Install dependencies.
# PostgreSQL
#/usr/bin/apt-get ${APT_OPTS} install postgresql-${POSTGRESQL_VERSION} libpq-dev
#cp files/puppetmaster/pg_hba.conf /etc/postgresql/${POSTGRESQL_VERSION}/main/pg_hba.conf
#sudo -u postgres -i createdb puppet
#sudo -u postgres -i createuser -D -R -S puppet
#sudo -u postgres -i psql template1 -c"ALTER USER puppet WITH PASSWORD 'puppet';" >/dev/null
#sudo -u postgres -i psql template1 -c'GRANT CREATE ON DATABASE puppet to puppet' >/dev/null

# Unicorn web server
#/usr/bin/gem install unicorn --no-rdoc --quiet --no-ri
#cp /usr/share/puppet/ext/rack/files/config.ru /etc/puppet/
# Unicorn (TODO, write upstart script)
#/usr/local/bin/unicorn --env production --daemonize --config-file /etc/puppet/unicorn.conf

# Ngnix web server
#/usr/bin/apt-get ${APT_OPTS} install nginx-light
#/usr/bin/service ngnix start

# Install modures via Librarian
cd /etc/puppet
rm /etc/puppet/Puppetfile.lock
/usr/local/bin/librarian-puppet update

/usr/sbin/ufw allow in 8140
