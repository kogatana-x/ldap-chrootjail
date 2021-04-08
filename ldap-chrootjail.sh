#!/bin/bash

# ----------------------------------------------------------------------
# ldap-jailuser.sh <DOMAIN>
#
# This script creates a jail for all users tied to Windows AD 
# whenever they login to the server after running this script. 
# All domain users will be restricted to the commands listed in $BIN.

# Should work on all RHEL and Debian-based OS versions
# Not tested on POSIX-like versions.
#
# The new home directory will be under /jail/home/<user>
# Dont worry! The old home directory has been preserved and saved to /home/<user>.orig
#
# Additionally, all required binaries for each command in $BIN are copied to the jail, and
# please note, the ssh server config will be edited: please restart ssh server after execution
# for changes to take effect.
# ----------------------------------------------------------------------
DOMAIN=$1
if [ -z "$DOMAIN" ]; then
  echo "Please specify a domain. \n\t Usage: $0 <domain>" >&2
  exit 1
fi
# Edit this path, if you would like the jail to be situatied in a 
# different location.
#
PATH='/jail'
mkdir -p $PATH

if ! grep -q "Match group domain?users@$DOMAIN" /etc/ssh/sshd_config
then
  echo "Configuring Jail Group in SSH"
  echo "
Match group domain?users@$DOMAIN
  ChrootDirectory $PATH
  AllowTCPForwarding no
  X11Forwarding no
" >> /etc/ssh/sshd_config
  systemctl restart sshd    #ELSE PROMPT TO RESTART
fi

echo "Creating Jail Path"

home_dir="$PATH/home"
mkdir -p ${home_dir}
chown root:root ${home_dir}
chmod 755 ${home_dir}

cd $PATH 
mkdir -p dev
mkdir -p bin
mkdir -p lib64
mkdir -p etc
mkdir -p usr/bin
mkdir -p usr/lib64

#Pick an OS
if [ -e "/lib64/libnss_files.so.2" ]
then
 cp -p /lib64/libnss_files.so.2 ${PATH}/lib64/libnss_files.so.2
fi

if [ -e "/lib/x86_64-linux-gnu/libnss_files.so.2" ]
then
  mkdir -p ${PATH}/lib/x86_64-linux-gnu
  cp -p /lib/x86_64-linux-gnu/libnss_files.so.2 ${PATH}/lib/x86_64-linux-gnu/libnss_files.so.2
fi


# Creating additional paths so the system doesnt break
[ -r $PATH/dev/urandom ] || mknod $PATH/dev/urandom c 1 9
[ -r $PATH/dev/null ]    || mknod -m 666 $PATH/dev/null    c 1 3
[ -r $PATH/dev/zero ]    || mknod -m 666 $PATH/dev/zero    c 1 5
[ -r $PATH/dev/tty ]     || mknod -m 666 $PATH/dev/tty     c 5 0

 
BIN_PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
BIN="`which bash` `which cat` `which cp` `which whoami` `which vi` `which grep` `which ls` `which touch` `which mkdir` `which more` `which mv` `which cp` `which less` `which pwd` `which id` `which head` `which tail`"

for bin in $BIN
do
  cp $bin ${BIN_PATH}${bin} > /dev/null 2>&1
  if ldd $bin > /dev/null
  then
    LIBS=`ldd $bin | grep '/lib' | sed 's/\t/ /g' | sed 's/ /\n/g' | grep "/lib"`
    for l in $LIBS
    do
      mkdir -p ./`dirname $l` > /dev/null 2>&1
      cp $l ./$l  > /dev/null 2>&1
    done
  fi
done

# FOR EACH USER IN DOMAIN USERS GROUP:::
echo "Jailing All Users in Domain Users Group"
#T1: for user in $(getent group domain?users)     

##IF THE DOMAIN IS ON THE USERNAME, THE DOMAIN WILL STAY ON THE USER
for user in $(getent group "domain users@$DOMAIN" | tr -s ',' '\n')   
do
	user_dir="${home_dir}/$user"
	mkdir -p ${user_dir}
	chmod 0700 ${user_dir}
	chown $user:$group_name ${user_dir}
	
	if [ ! -h "/home/${user}" -a -d "/home/${user}" ]
		then
  		echo ":: Backing Up Old Directory to /home/${user}.orig"
  		mv /home/${user} /home/${user}.orig
	fi

	if [ ! -e "/home/${user}" ]
	then
  		echo ":: Linking Jailed Home to Old /home"
  		ln -s ${user_dir} /home/${user}
	fi
	
done


 
echo "Chroot Jail Complete, You May Rest Easy"
