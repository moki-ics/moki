#!/bin/bash

url_moki_base="https://raw.githubusercontent.com/moki-ics/moki/master"
url_background="$url_moki_base/images/moki.jpg"

git_quickdraw="https://github.com/digitalbond/quickdraw"
url_modscan="https://raw.githubusercontent.com/moki-ics/modscan/master/modscan.py"
url_plcscan_base="https://raw.githubusercontent.com/moki-ics/plcscan/master"
url_codesys_base="$url_moki_base/mirror/digital-bond-codesys"
url_wireshark="https://1.na.dl.wireshark.org/src/wireshark-2.2.7.tar.bz2"
git_s7metasploit="https://github.com/moki-ics/s7-metasploit-modules.git"
git_s7wireshark="https://github.com/moki-ics/s7commwireshark.git"

moki_data_dir="/usr/local/share/moki"
meta_module_dir="/usr/share/metasploit-framework/modules/exploits"
moki_directory_path="/usr/share/desktop-directories/Moki.directory"
bin_directory="/usr/bin"
desktop_apps="/usr/share/applications"
nmap_scripts="/usr/share/nmap/scripts"

wget="wget --no-check-certificate --quiet"
add_to_moki="xdg-desktop-menu install --novendor --mode system $moki_directory_path"

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
s7wireshark_install=false

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
        --all           Installs all tools
        --offensive     Installs all offensive tools
        --defensive     Installs all defensive tools
        --quickdraw     Installs snort and Digital Bond's ICS snort Rules
        --plcsan        Installs PLCscan script
        --codesys       Installs CoDeSys Runtime exploit script
        --modscan       Installs ModScan script
        --s7wireshark   Installs the S7comm wireshark dissector
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
        s7wireshark_install=true
        shift
        ;;
    --offensive )
        do_update=true
        codesys_install=true
        modscan_install=true
        plcscan_install=true
        s7metasploit_install=true
        s7wireshark_install=true
        shift
        ;;
    --defensive )
        do_update=true
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
    --s7wireshark )
        do_update=true
        s7wireshark_install=true
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
cat > "$moki_directory_path" << "EOF"
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
deb http://http.us.debian.org/debian testing main non-free contrib
deb-src http://http.us.debian.org/debian testing main non-free contrib
deb http://http.kali.org/kali kali main non-free contrib
deb-src http://http.kali.org/kali main non-free contrib
deb-src http://security.kali.org/kali-security kali/updates main contrib non-free
## [Moki end]
EOF
    fi

    echo "# Updating apt-get & Upgrading all packages... "
    apt-get clean 2>/dev/null 1>/dev/null
    apt-get update -y --force-yes
    # apt-get upgrade -y --force-yes
    # apt-get dist-upgrade -y --force-yes
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
    if ! git clone "$git_quickdraw"; then
        echo "-> Error: could not get $git_quickdraw" >&2
        exit 1
    fi
    quickdraw_dir="$dir/quickdraw"

    echo "# Copying Quickdraw SCADA rules to the rules directory..."
    cp $quickdraw_dir/all-quickdraw.rules $snort_rules_dir/all-quickdraw.rules

    snort_rules_file="/etc/snort/snort.conf"
    if ! grep "Moki" $snort_rules_file; then
        echo "# Editing the snort rules file..."
        cat >> $snort_rules_file << "EOF"

## [Moki start]
#-----------------------------
# Moki SCADA Variables
#-----------------------------
# for Snort 2.9.7.3 and Quickdraw v1.3, use these:
ipvar MODICON_CLIENT $HOME_NET
ipvar BACNET_CLIENT $HOME_NET
ipvar FINS_CLIENT $HOME_NET
ipvar FINS_SERVER $HOME_NET
ipvar S7_SERVER $HOME_NET
ipvar S7_CLIENT $HOME_NET
ipvar MODBUS_CLIENT $HOME_NET
ipvar MODBUS_SERVER $HOME_NET
ipvar DNP3_CLIENT $HOME_NET
ipvar DNP3_SERVER $HOME_NET
portvar DNP3_PORTS 20000
# for Quickdraw prior to v1.3, use these too:
#ipvar ENIP_CLIENT $HOME_NET
#ipvar ENIP_SERVER $HOME_NET

#-----------------------------
# Moki SCADA Rules
#-----------------------------
include $RULE_PATH/all-quickdraw.rules
## [Moki end]
EOF
    fi
    
    # Change "ipvar HOME_NET any" to "ipvar HOME_NET 10.0.0.0/8" in /etc/snort/snort.conf
    # Future work: identify if this can be a variable; 10.0.0.0/8 came from Snort error log
    sed -i "s|ipvar HOME_NET any|ipvar HOME_NET 10.0.0.0/8|" /etc/snort/snort.conf
    
    if [ ! -d $moki_data_dir/pcap ]; then
        echo "# Installing SCADA pcap samples from Digital Bond to $moki_data_dir/pcap"
        mkdir $moki_data_dir/pcap
        cp $quickdraw_dir/*.pcap $moki_data_dir/pcap
    fi
fi

if $snort_test ; then
    snort_rules_file="/etc/snort/snort.conf"

    if ! which snort; then
        echo "-> Error: snort not installed" >&2
        exit 1
    fi

    if [ ! -d $moki_data_dir/pcap ]; then
        echo "-> Error: pcap files not found" >&2
        exit 1
    fi

    echo "# Testing snort configuration file..."
    if ! snort -T -c "$snort_rules_file" 2>/dev/null 1>/dev/null; then
        echo -n "-> Error: snort doesn't like the config or active rules." >&2
        echo -n "  Maybe \$HOME_NET is 'any' in $snort_rules_file?" >&2
        echo    "  The PCAP files require monitoring 10.0.0.0/8." >&2
        exit 1
    fi

    echo "# Running tests..."
    logdir="/tmp/moki"
    rm -rf "$logdir"
    mkdir "$logdir"

    for pcapfile in $moki_data_dir/pcap/*.pcap
    do
        pcapname=`basename "$pcapfile"`
        logfile="$logdir"/"$pcapname".out
        snort -c "$snort_rules_file" -l "$logdir" --pcap-single "$pcapfile" 2>"$logfile" 1>"$logfile"
    done

    echo "# Checking alerts..."
    testlog="$logdir"/bacnet_test.pcap.out
    if [ ! -f "$testlog" ]; then
        echo "-> Error: $testlog missing" >&2
    else
        if ! grep "Snort processed 26 packets" "$testlog"; then
            echo "-> Error: packets missing from $testlog" >&2
        fi
        if ! grep "Alerts: * 13 " "$testlog"; then
            echo "-> Error: alerts missing from $testlog" >&2
        fi
        if ! grep "Logged: * 13 " "$testlog"; then
            echo "-> Error: logged events missing from $testlog" >&2
        fi
    fi

    testlog="$logdir"/dnp3_test_data_part1.pcap.out
    if [ ! -f "$testlog" ]; then
        echo "-> Error: $testlog missing" >&2
    else
        if ! grep "Snort processed 181 packets" "$testlog"; then
            echo "-> Error: packets missing from $testlog" >&2
        fi
        if ! grep "Alerts: * 116 " "$testlog"; then
            echo "-> Error: alerts missing from $testlog" >&2
        fi
        if ! grep "Logged: * 116 " "$testlog"; then
            echo "-> Error: logged events missing from $testlog" >&2
        fi
    fi

    testlog="$logdir"/dnp3_test_data_part2.pcap.out
    if [ ! -f "$testlog" ]; then
        echo "-> Error: $testlog missing" >&2
    else
        if ! grep "Snort processed 33 packets" "$testlog"; then
            echo "-> Error: packets missing from $testlog" >&2
        fi
        if ! grep "Alerts: * 0 " "$testlog"; then
            echo "-> Error: alerts missing from $testlog" >&2
        fi
        if ! grep "Logged: * 0 " "$testlog"; then
            echo "-> Error: logged events missing from $testlog" >&2
        fi
    fi

    testlog="$logdir"/enip_test.pcap.out
    if [ ! -f "$testlog" ]; then
        echo "-> Error: $testlog missing" >&2
    else
        if ! grep "Snort processed 11 packets" "$testlog"; then
            echo "-> Error: packets missing from $testlog" >&2
        fi
        if ! grep "Alerts: * 0 " "$testlog"; then
            echo "-> Error: alerts missing from $testlog" >&2
        fi
        if ! grep "Logged: * 0 " "$testlog"; then
            echo "-> Error: logged events missing from $testlog" >&2
        fi
    fi

    testlog="$logdir"/fox_info.pcap.out
    if [ ! -f "$testlog" ]; then
        echo "-> Error: $testlog missing" >&2
    else
        if ! grep "Snort processed 10 packets" "$testlog"; then
            echo "-> Error: packets missing from $testlog" >&2
        fi
        if ! grep "Alerts: * 1 " "$testlog"; then
            echo "-> Error: alerts missing from $testlog" >&2
        fi
        if ! grep "Logged: * 1 " "$testlog"; then
            echo "-> Error: logged events missing from $testlog" >&2
        fi
    fi

    testlog="$logdir"/modbus_test_data_part1.pcap.out
    if [ ! -f "$testlog" ]; then
        echo "-> Error: $testlog missing" >&2
    else
        if ! grep "Snort processed 118 packets" "$testlog"; then
            echo "-> Error: packets missing from $testlog" >&2
        fi
        if ! grep "Alerts: * 20 " "$testlog"; then
            echo "-> Error: alerts missing from $testlog" >&2
        fi
        if ! grep "Logged: * 20 " "$testlog"; then
            echo "-> Error: logged events missing from $testlog" >&2
        fi
    fi

    testlog="$logdir"/modbus_test_data_part2.pcap.out
    if [ ! -f "$testlog" ]; then
        echo "-> Error: $testlog missing" >&2
    else
        if ! grep "Snort processed 350 packets" "$testlog"; then
            echo "-> Error: packets missing from $testlog" >&2
        fi
        if ! grep "Alerts: * 0 " "$testlog"; then
            echo "-> Error: alerts missing from $testlog" >&2
        fi
        if ! grep "Logged: * 0 " "$testlog"; then
            echo "-> Error: logged events missing from $testlog" >&2
        fi
    fi

    testlog="$logdir"/modicon_test.pcap.out
    if [ ! -f "$testlog" ]; then
        echo "-> Error: $testlog missing" >&2
    else
        if ! grep "Snort processed 191 packets" "$testlog"; then
            echo "-> Error: packets missing from $testlog" >&2
        fi
        if ! grep "Alerts: * 0 " "$testlog"; then
            echo "-> Error: alerts missing from $testlog" >&2
        fi
        if ! grep "Logged: * 0 " "$testlog"; then
            echo "-> Error: logged events missing from $testlog" >&2
        fi
    fi

    testlog="$logdir"/omron_test.pcap.out
    if [ ! -f "$testlog" ]; then
        echo "-> Error: $testlog missing" >&2
    else
        if ! grep "Snort processed 18 packets" "$testlog"; then
            echo "-> Error: packets missing from $testlog" >&2
        fi
        if ! grep "Alerts: * 2 " "$testlog"; then
            echo "-> Error: alerts missing from $testlog" >&2
        fi
        if ! grep "Logged: * 2 " "$testlog"; then
            echo "-> Error: logged events missing from $testlog" >&2
        fi
    fi

    testlog="$logdir"/s7_test.pcap.out
    if [ ! -f "$testlog" ]; then
        echo "-> Error: $testlog missing" >&2
    else
        if ! grep "Snort processed 39 packets" "$testlog"; then
            echo "-> Error: packets missing from $testlog" >&2
        fi
        if ! grep "Alerts: * 0" "$testlog"; then
            echo "-> Error: alerts missing from $testlog" >&2
        fi
        if ! grep "Logged: * 0" "$testlog"; then
            echo "-> Error: logged events missing from $testlog" >&2
        fi
    fi

    echo "# If there are any errors above, see $logdir for details:"
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
    vim -c ':set ff=unix|wq' $bin_directory/plcscan.py
    sed -i '1s/^/#!\/usr\/bin\/env python\n/' $bin_directory/plcscan.py
    chmod +x $bin_directory/plcscan.py
    ln -s $bin_directory/plcscan.py $bin_directory/plcscan
    cat > "$desktop_apps/plcscan.desktop" << "EOF"
[Desktop Entry]
Name=plcscan
Encoding=UTF-8
Exec=sh -c "plcscan;${SHELL:-bash}"
Icon=kali-menu.png
StartupNotify=false
Terminal=true
Type=Application
Categories=Moki;ICS;
EOF
    $add_to_moki "$desktop_apps/plcscan.desktop"
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
    vim -c ':set ff=unix|wq' $bin_directory/codesys-shell.py
    vim -c ':set ff=unix|wq' $bin_directory/codesys-transfer.py
    sed -i '1s/^/#!\/usr\/bin\/env python\n/' $bin_directory/codesys-shell.py
    sed -i '1s/^/#!\/usr\/bin\/env python\n/' $bin_directory/codesys-transfer.py
    chmod +x $bin_directory/codesys-shell.py
    ln -s $bin_directory/codesys-shell.py $bin_directory/codesys-shell
    chmod +x $bin_directory/codesys-transfer.py
    ln -s $bin_directory/codesys-transfer.py $bin_directory/codesys-transfer
    cat > "$desktop_apps/codesys-shell.desktop" << "EOF"
[Desktop Entry]
Name=codesys-shell
Encoding=UTF-8
Exec=sh -c "codesys-shell;${SHELL:-bash}"
Icon=kali-menu.png
StartupNotify=false
Terminal=true
Type=Application
Categories=Moki;ICS;
EOF
    cat > "$desktop_apps/codesys-transfer.desktop" << "EOF"
[Desktop Entry]
Name=codesys-transfer
Encoding=UTF-8
Exec=sh -c "codesys-transfer;${SHELL:-bash}"
Icon=kali-menu.png
StartupNotify=false
Terminal=true
Type=Application
Categories=Moki;ICS;
EOF
    $add_to_moki "$desktop_apps/codesys-shell.desktop"
    $add_to_moki "$desktop_apps/codesys-transfer.desktop"
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
    cat > "$desktop_apps/modscan.desktop" << "EOF"
[Desktop Entry]
Name=modscan
Encoding=UTF-8
Exec=sh -c "modscan;${SHELL:-bash}"
Icon=kali-menu.png
StartupNotify=false
Terminal=true
Type=Application
Categories=Moki;ICS;
EOF
    $add_to_moki "$desktop_apps/modscan.desktop"
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
    mkdir -p "$meta_module_dir/simatic"
    if ! mv s7-metasploit-modules/*.rb "$meta_module_dir/simatic"; then
        echo "-> Error: could not put files into $meta_module_dir" >&2
        exit 1
    fi
fi


##################################################
# s7comm wireshark dissector
##################################################

if $s7wireshark_install ; then
    echo "# Installing wireshark plugin dependencies..."
    apt-get install -y build-essential bison flex \
    libtool libtool-bin autoconf \
    libpcap-dev
    # libgtk-3-dev qt-sdk # we don't need these if we don't build the GUI
fi

if $s7wireshark_install ; then
    cwd=`pwd`
    echo "# Installing a wireshark plugin for the Siemens S7comm protocol:"
    if ! which wireshark; then
        echo "-> Error: wireshark not installed" >&2
        exit 1
    fi

    # grab the plugin code
    if ! git clone "$git_s7wireshark"; then
        echo "-> Error: could not get $git_s7wireshark" >&2
        exit 1
    fi

    # grab the wireshark code
    if ! $wget $url_wireshark; then
        echo "-> Error: could not get $url_wireshark" >&2
        exit 1
    fi
    tar xf wireshark-*
    wireshark_dir=`find . -type d -name "wireshark-*"`
    if [ x"$wireshark_dir" = x ]; then
        echo "-> Error: unpacking wireshark didn't seem to work " >&2
        exit 1
    fi

    # figure out the plugin destination
    plugins_dir=`find /usr/lib -type d -regex ".*/wireshark/plugins/.*"`
    if [ ! -d "$plugins_dir" ]; then
        plugins_dir="/usr/share/wireshark/plugins"
        mkdir -p $plugins_dir
    fi

    # copy plugin code to the wireshark source directory
    cp -R s7commwireshark/src/* $wireshark_dir/plugins

    # build wireshark (no GUI) just to be able to build the plugin libraries
    # then install the libraries to the plugin destination
    cd $wireshark_dir
    ./autogen.sh
    ./configure --enable-wireshark=No

    make -C plugins/s7comm all
    plugin="plugins/s7comm/.libs/s7comm.so"
    if [ ! -f "$plugin" ]; then
        echo "-> Error: $plugin missing" >&2
        exit 1
    fi
    cp $plugin $plugins_dir

    make -C plugins/s7comm_plus all
    plugin="plugins/s7comm_plus/.libs/s7comm_plus.so"
    if [ ! -f "$plugin" ]; then
        echo "-> Error: $plugin missing" >&2
        exit 1
    fi
    cp $plugin $plugins_dir
    cd $pwd

    # check that tshark detects the plugins are installed correctly
    echo "# Checking plugins are installed"
    s7plug1=`tshark -G plugins 2>/dev/null | grep s7comm.so`
    s7plug2=`tshark -G plugins 2>/dev/null | grep s7comm_plus.so`
    if [ x"$s7plug1" = x ] || [ x"$s7plug2" = x ]; then
        tshark -G plugins >&2
        echo "-> Error: wireshark plugins don't appear to have been installed properly" >&2
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
    sudo apt-get -y --force-yes clean      2>/dev/null 1>/dev/null
    sudo apt-get -y --force-yes autoclean  2>/dev/null 1>/dev/null
    sudo apt-get -y --force-yes autoremove 2>/dev/null 1>/dev/null
fi

rm -rf "$dir"

##################################################
# finished
##################################################
echo "# "
echo "# All Done!"
echo "# "
