#/bin/bash

## Add Official Kali Linux Repositories
echo "## Regular repositories
deb http://http.kali.org/kali kali main non-free contrib
## Source repositories
deb-src http://http.kali.org/kali main non-free contrib
deb-src http://security.kali.org/kali-security kali/updates main contrib non-free" >> /etc/apt/sources.list

## Update and Upgrate Kali Linux
apt-get clean
apt-get update -y --force-yes
apt-get upgrade -y --force-yes
apt-get dist-upgrade -y --force-yes

## Install prerequisite dependencies
apt-get -y --force-yes install \
flex \
bison \
build-essential \
checkinstall \
libpcap-dev \
libnet1-dev \
libpcre3-dev \
libmysqlclient15-dev \
libnetfilter-queue-dev \
iptables-dev

## Install libdnet from source. The "-fPIC" C flag is neccessary for
## compiling on a 64-bit platform
wget https://libdnet.googlecode.com/files/libdnet-1.12.tgz
tar xvfvz libdnet*.tgz
./libdnet*/configure "CLFAGS=-fPIC"
make
checkinstall -y

## Create symbolic link where Snort looks for libdnet
#dpkg -i libdnet*.deb
#ln -s /usr/local/lib/libdnet.1.0.1 /usr/local/lib/libdnet.1

## Download and install DAQ (Data Acquisition) Library
wget http://www.snort.org/dl/snort-current/daq-2.0.2.tar.gz
tar xvfvz daq*.tar.gz
./daq*/configure
make
checkinstall -y
dpkg -i daq*.deb
