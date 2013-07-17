#!/bin/bash
# Takes one argument, the name of the puppetmaster.
[ $1 ] && puppet="-p $1"
cd /root
rm /root/bootstrap-linux
rm /root/bootstrap-linux.log
rm -rf /var/lib/puppet/ssl
echo "Fetching bootstrap setup script."
wget https://raw.github.com/seattle-biomed/bootstrap-linux/master/bootstrap-linux -O /root/bootstrap-linux
echo "Executing bootstrap setup script."
chmod +x /root/bootstrap-linux
/root/bootstrap-linux -k $puppet
status=$?
echo "START=yes" > /etc/default/puppet
if [ $status ] ; then
  echo "Errors during bootstrap configuration."
  exit $status
else
  echo -n "Press Enter to reboot, CTRL-C to break." ; read X
  reboot
fi

