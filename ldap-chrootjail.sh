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
domain=$1
if [ -z "$domain" ]; then
  echo "Please specify a domain. \n\t Usage: $0 <domain>" >&2
  exit 1
fi
#Edit this if these users are in a different group
group="domain users@$domain"

# Edit this path, if you would like the jail to be situated in a 
# different location.
#
path='/jail'
mkdir -p $path

# Edit these paths, if you would like jailed users to have access to
# different commands.
#
BIN=`which bash which cat which cp which whoami which vi which grep which ls which touch which mkdir which more which mv which cp which less which pwd which id which head which tail | tr '\n' '\t'`

##TODO: this doesnt work lol
if ! grep -q "Match group \"$group\"" /etc/ssh/sshd_config
then
  echo "Configuring Jail Group in SSH"
  echo "
Match group \"$group\"
  ChrootDirectory $path
  AllowTCPForwarding no
  X11Forwarding no
" >> /etc/ssh/sshd_config
  systemctl restart sshd    
fi

echo "Creating Jail Path"

homeDir="$path/home"
mkdir -p ${homeDir}
chown root:root ${homeDir}
chmod 755 ${homeDir}

cd $path 
mkdir -p dev
mkdir -p bin
mkdir -p lib64
mkdir -p etc
mkdir -p usr/bin
mkdir -p usr/lib64

#Pick an OS
if [ -e "/lib64/libnss_files.so.2" ]
then
 cp -p /lib64/libnss_files.so.2 ${path}/lib64/libnss_files.so.2
fi

if [ -e "/lib/x86_64-linux-gnu/libnss_files.so.2" ]
then
  mkdir -p ${path}/lib/x86_64-linux-gnu
  cp -p /lib/x86_64-linux-gnu/libnss_files.so.2 ${path}/lib/x86_64-linux-gnu/libnss_files.so.2
fi


# Creating additional paths so the system doesnt break
[ -r $path/dev/urandom ] || mknod $path/dev/urandom c 1 9
[ -r $path/dev/null ]    || mknod -m 666 $path/dev/null    c 1 3
[ -r $path/dev/zero ]    || mknod -m 666 $path/dev/zero    c 1 5
[ -r $path/dev/tty ]     || mknod -m 666 $path/dev/tty     c 5 0

 
binPath=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

for bin in $BIN
do
  cp $bin ${binPath}${bin} > /dev/null 2>&1
  if ldd $bin > /dev/null
  then
    libs=`ldd $bin | grep '/lib' | sed 's/\t/ /g' | sed 's/ /\n/g' | grep "/lib"`
    for l in $libs
    do
      mkdir -p ./`dirname $l` > /dev/null 2>&1
      cp $l ./$l  > /dev/null 2>&1
    done
  fi
done

# FOR EACH USER IN DOMAIN USERS GROUP:::
echo "Jailing All Users in Domain Users Group"

##TO MANUALLY GRAB USERS RUN THESE & CLEAN UP THE FILE:
  #getent group $group | tr -s ',' '\n' > user_list
  #AND THEN UNCOMMENT THESE:
    #file_path="user_list" 
    #for user in $(cat $file_path)
    
##TO AUTOMATICALLY GRAB USERS: {will have 3 messed up lines if using Microsoft AD}
for user in $(getent group $group | tr -s ',' '\n')   
do
	userDir="${homeDir}/$user"
	mkdir -p ${userDir}
	chmod 0700 ${userDir}
	chown $user:$group ${userDir}
	
	if [ ! -h "/home/${user}" -a -d "/home/${user}" ]
		then
  		echo ":: Backing Up Old Directory to /home/${user}.orig"
  		mv /home/${user} /home/${user}.orig
	fi

	if [ ! -e "/home/${user}" ]
	then
  		echo ":: Linking Jailed Home to Old /home"
  		ln -s ${userDir} /home/${user}
	fi
	
done


 
echo "Chroot Jail Complete, You May Rest Easy"
