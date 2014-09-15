#!/bin/bash

url_moki_base="https://raw.githubusercontent.com/moki-ics/moki/master"
url_background="$url_moki_base/images/moki.jpg"
url_quickdraw="https://www.digitalbond.com/wp-content/uploads/2011/02/quickdraw_4_3_1.zip"
url_quickdraw_pcap="http://digitalbond.com/wp-content/uploads/2011/02/Quickdraw_PCAPS_4_0.zip"
url_modscan="http://modscan.googlecode.com/svn/trunk/modscan.py"
url_plcscan_base="http://plcscan.googlecode.com/svn/trunk"
url_codesys_base="$url_moki_base/mirror/digital-bond-codesys"
git_s7metasploit="https://github.com/moki-ics/s7-metasploit-modules.git"

moki_bin_directory="/root/Desktop"
moki_data_dir="/usr/local/share/moki"
meta_module_dir="/usr/share/metasploit-framework/modules/exploits"
kali_directory_path="/usr/share/desktop-directories/Kali.directory"
moki_directory_path="/usr/share/desktop-directories/Moki.directory"
bin_directory="/usr/bin"
desktop_apps="/usr/share/applications"
nmap_scripts="/usr/share/nmap/scripts"

wget="wget --no-check-certificate"

##################################################
# Parse Inputs
##################################################
VERBOSE=false
do_update=false
codesys_install=false
modscan_install=false
plcscan_install=false
s7metasploit_install=false
snort_install=false
snort_test=false  # TODO: remove option, turn into shortcut

### Check Inputs ###
while true; do
case "$1" in
    -h | --help )
        cat << "EOF"

Usage: setup.sh [options]

    Installs extra SCADA/ICS tools under Kali
    Options:
        -h | --help     This message
        -v | --verbose  Script works in verbose mode
        --all           Installs all the below
        --quickdraw     Installs snort and Digital Bond's ICS snort Rules
        --plcsan        Installs PLCscan script
        --codesys       Installs CoDeSys Runtime exploit script
        --modscan       Installs ModScan script
EOF
        exit 0
        shift
        ;;
    -v | --verbose )
        VERBOSE=true;
        shift
        ;;
    --all )
        do_update=true
        codesys_install=true
        modscan_install=true
        plcscan_install=true
        s7metasploit_install=true
        snort_install=true
        shift
        ;;
    --codesys | --CoDeSyS )
        codesys_install=true
        shift
        ;;
    --modscan | --ModScan )
        modscan_install=true
        shift
        ;;
    --plcscan | --PLCscan | --PLCScan )
        plcscan_install=true
        shift
        ;;
    --quickdraw )
        do_update=true
        snort_install=true
        shift
        ;;
    --s7-metasploit )
        s7metasploit_install=true
        shift
        ;;
    --snort-test )
        snort_test=true
        shift
        ;;
    * ) break
        ;;
   esac
done


#### test folder in ~/ ####
dir="$HOME/.moki_tmp"
rm -rf "$dir"
mkdir "$dir"
if ! cd "$dir" ; then
    echo "-> Error: could not cd to \"$dir\"" >&2
    exit 1
fi

########## Run this to get sudo access ###########
echo "# Checking for sudo access... "
sudo ls >/dev/null

########## Make data dir ###########
if [ ! -d "$moki_data_dir" ]; then
    echo "# Making $moki_data_dir ... "
    mkdir "$moki_data_dir"
fi

########## Make Moki Desktop Directory File #######
cat >> $moki_directory_path << "EOF"
[Desktop Entry]
Name=Moki ICS Tools
Type=Directory
Icon=k.png
EOF

########## Update software repositories ###########
if $do_update ; then
    echo "# Adding Official Kali Linux Repositories... " 

    if ! grep "Moki" /etc/apt/sources.list; then
        cat >> /etc/apt/sources.list << "EOF"

## [Moki start]
deb http://http.kali.org/kali kali main non-free contrib
deb-src http://http.kali.org/kali main non-free contrib
deb-src http://security.kali.org/kali-security kali/updates main contrib non-free
## [Moki end]
EOF
    fi

    echo "# Updating apt-get & Upgrading all packages... "
    apt-get clean
    apt-get update -y --force-yes
    apt-get upgrade -y --force-yes
    apt-get dist-upgrade -y --force-yes
fi


##################################################
# Snort & Quickdraw SCADA Snort Rules
##################################################

if $snort_install && [ ! `which snort` ]; then
    echo "# Installing snort..."
    apt-get install -y snort \
    snort-common \
    snort-common-libraries
fi

if $snort_install ; then
    snort_rules_dir="/etc/snort/rules"

    echo "# Downloading rules..."
    $wget $url_quickdraw -O quickdraw.zip
    unzip quickdraw.zip

    echo "# Copying Quickdraw SCADA rules to the rules directory..."
    cp dnp3*.rules $snort_rules_dir/dnp3.rules
    cp modbus*.rules $snort_rules_dir/modbus.rules
    cp enip_cip*.rules $snort_rules_dir/enip_cip.rules
    cp vulnerability*.rules $snort_rules_dir/vulnerability.rules

    snort_rules_file="/etc/snort/snort.conf"
    if ! grep "Moki" $snort_rules_file; then
        echo "# Editing the snort rules file..."
        cat >> $snort_rules_file << "EOF"

## [Moki start]
#-----------------------------
# Moki SCADA Variables
#-----------------------------
ipvar MODBUS_CLIENT $HOME_NET
ipvar MODBUS_SERVER $HOME_NET
ipvar ENIP_CLIENT $HOME_NET
ipvar ENIP_SERVER $HOME_NET
ipvar DNP3_CLIENT $HOME_NET
ipvar DNP3_SERVER $HOME_NET
portvar DNP3_PORTS 20000

#-----------------------------
# Moki SCADA Rules
#     Only adding Modbus/TCP rules, due to missing 
#     variables in other rules from missing preprocessors.
#-----------------------------
include $RULE_PATH/modbus.rules
#include $RULE_PATH/dnp3.rules
#include $RULE_PATH/enip_cip.rules
#include $RULE_PATH/vulnerability.rules
## [Moki end]
EOF
    fi

    if [ ! -d $moki_data_dir/pcap ]; then
        echo "# Installing SCADA PCAP samples from Digital Bond to $moki_data_dir/pcap"
        $wget $url_quickdraw_pcap -O pcap.zip
        unzip pcap.zip -d $moki_data_dir/pcap
    fi
fi

if $snort_test ; then
    snort_rules_file="/etc/snort/snort.conf"
    pcap_modbus="$moki_data_dir/pcap/modbus_test_data_part1.pcap"
    if ! which snort; then
        echo "-> Error: snort not installed" >&2
        exit 1
    fi
    if [ ! -f $pcap_modbus ]; then
        echo "-> Error: $pcap_modbus missing" >&2
        exit 1
    fi

    echo "# Testing snort configuration file..."
    if ! snort -T -c "$snort_rules_file" 2>/dev/null 1>/dev/null; then
        echo -n "-> Error: snort doesn't like the config or active rules." >&2
        echo -n "  Maybe \$HOME_NET is 'any' in $snort_rules_file?" >&2
        echo    "  The PCAP files require monitoring 10.0.0.0/8." >&2
        exit 1
    fi

    echo "# Running test..."
    logdir="/tmp/moki"
    logfile="$logdir"/quickdraw.out
    rm -rf "$logdir"
    mkdir "$logdir"
    echo "$logfile"

    snort -c "$snort_rules_file" -l "$logdir" --pcap-single "$pcap_modbus" 2>"$logfile" 1>"$logfile"

    echo "# Checking alerts"
    if ! grep "Snort processed 118 packets" "$logfile"; then
        echo "-> Error: packets missing" >&2
        exit 1
    fi
    if ! grep "Alerts: * 20" "$logfile"; then
        echo "-> Error: alerts missing" >&2
        exit 1
    fi
    if ! grep "Logged: * 20" "$logfile"; then
        echo "-> Error: logged events missing" >&2
        exit 1
    fi
    echo "# I think everything worked out ok. See these files for details:"
    ls -al "$logdir"
fi


##################################################
# PLCscan tool
##################################################
if $plcscan_install ; then
    echo "# Installing PLCScan... "
    if ! $wget $url_plcscan_base/plcscan.py -O $bin_directory/plcscan.py; then
        echo "-> Error: could not get $url_plcscan_base/plcscan.py" >&2
        exit 1
    fi
    if ! $wget $url_plcscan_base/modbus.py -O $bin_directory/modbus.py; then
        echo "-> Error: could not get $url_plcscan_base/modbus.py" >&2
        exit 1
    fi
    if ! $wget $url_plcscan_base/s7.py -O $bin_directory/s7.py; then
        echo "-> Error: could not get $url_plcscan_base/s7.py" >&2
        exit 1
    fi
	chmod +x $bin_directory/plcscan.py
	vim -c ':set ff=unix|wq' $bin_directory/plcscan.py
	sed -i '1s/^/#!\/usr\/bin\/env python\n/' $bin_directory/plcscan.py
	ln -s $bin_directory/plcscan.py $bin_directory/plcscan
	cat >> $desktop_apps/plcscan.desktop << "EOF"
[Desktop Entry]
Name=plcscan
Encoding=UTF-8
Exec=sh -c "plcscan;${SHELL:-bash}"
Icon=kali-menu.png
StartupNotify=false
Terminal=true
Type=Application
Categories=Moki;Kali;01-09-service-fingerprinting;top10;
X-Kali-Package=plcscan
EOF

    echo "# To execute: $> plcscan"
fi


##################################################
# Digital Bond's CoDeSyS exploit tools
##################################################
if $codesys_install ; then
    echo "# Installing Wago Exploit... "
    if ! $wget $url_codesys_base/codesys-shell.py -O $bin_directory/codesys-shell.py; then
        echo "-> Error: could not get $url_codesys_base/codesys-shell.py" >&2
        exit 1
    fi
    if ! $wget $url_codesys_base/codesys-transfer.py -O $bin_directory/codesys-transfer.py; then
        echo "-> Error: could not get $url_codesys_base/codesys-transfer.py" >&2
        exit 1
    fi
    if ! $wget $url_codesys_base/codesys.nse -O $nmap_scripts/codesys.nse; then
        echo "-> Error: could not get $url_codesys_base" >&2
        exit 1
    fi
	chmod +x {$bin_directory/codesys-shell.py,$bin_directory/codesys-transfer.py}
	vim -c ':set ff=unix|wq' $bin_directory/codesys-shell.py
	vim -c ':set ff=unix|wq' $bin_directory/codesys-transfer.py
	sed -i '1s/^/#!\/usr\/bin\/env python\n/' $bin_directory/codesys-shell.py
	sed -i '1s/^/#!\/usr\/bin\/env python\n/' $bin_directory/codesys-transfer.py
	ln -s $bin_directory/codesys-shell.py $bin_directory/codesys-shell
	ln -s $bin_directory/codesys-transfer.py $bin_directory/codesys-transfer
	cat >> $desktop_apps/codesys-shell.desktop << "EOF"
[Desktop Entry]
Name=codesys-shell
Encoding=UTF-8
Exec=sh -c "codesys-shell;${SHELL:-bash}"
Icon=kali-menu.png
StartupNotify=false
Terminal=true
Type=Application
Categories=Moki;Kali;06-04-network-exploitation;top10;
X-Kali-Package=codesys-shell
EOF
	
	cat >> $desktop_apps/codesys-transfer.desktop << "EOF"
[Desktop Entry]
Name=codesys-transfer
Encoding=UTF-8
Exec=sh -c "codesys-transfer;${SHELL:-bash}"
Icon=kali-menu.png
StartupNotify=false
Terminal=true
Type=Application
Categories=Moki;Kali;06-04-network-exploitation;08-02-tunneling;top10;
X-Kali-Package=codesys-transfer
EOF

    echo "# To execute: $> codesys-shell or codesys-transfer"
fi


##################################################
# modscan tool
##################################################
if $modscan_install ; then
    echo "# Installing ModScan... "
    if ! $wget $url_modscan -O $bin_directory/modscan.py; then
        echo "-> Error: could not get $url_modscan" >&2
        exit 1
    fi
    chmod +x $bin_directory/modscan.py
	ln -s $bin_directory/modscan.py $bin_directory/modscan
	cat >> $desktop_apps/modscan.desktop << "EOF"
[Desktop Entry]
Name=modscan
Encoding=UTF-8
Exec=sh -c "modscan;${SHELL:-bash}"
Icon=kali-menu.png
StartupNotify=false
Terminal=true
Type=Application
Categories=Moki;Kali;01-09-service-fingerprinting;top10;
X-Kali-Package=modscan
EOF

    echo "# To execute: $>  modscan"
fi


##################################################
# metasploit module: old S7-exploit
##################################################
if $s7metasploit_install ; then
    echo "# Installing an old metasploit module for this S7 exploit:"
    echo "#   http://www.exploit-db.com/exploits/19832/... "
    if ! git clone "$git_s7metasploit"; then
        echo "-> Error: could not get $git_s7metasploit" >&2
        exit 1
    fi
    mkdir -p $meta_module_dir/simatic
    if ! mv s7-metasploit-modules/*.rb "$meta_module_dir"; then
        echo "-> Error: could not put files into $meta_module_dir" >&2
        exit 1
    fi
fi


##################################################
# custom background image
##################################################
background_dest="/usr/share/backgrounds/gnome/moki.jpg"
background_conf="/etc/dconf/db/local.d/01-moki-tweaks"
if [ ! -f $background_conf ]; then
    echo "# Changing custom background image... "
    $wget $url_background -O $background_dest
    cat > $background_conf << "EOF"
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/gnome/moki.jpg'
picture-options='scaled'
primary-color='000000'
secondary-color='FFFFFF'
EOF
    dconf update
fi

##################################################
# cleanup
##################################################

if true ; then
    # Clean up after the installs.
    echo "# Cleaning packages... "
    sudo apt-get -y --force-yes clean
    sudo apt-get -y --force-yes autoclean
    sudo apt-get -y --force-yes autoremove
fi

rm -rf "$dir"

##################################################
# finished
##################################################
echo "# "
echo "# All Done!"
echo "# "
