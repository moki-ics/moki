#!/bin/bash

digitalbond__url="https://www.digitalbond.com/wp-content/uploads/2011/02"
#snort_url="http://www.snort.org/dl/snort-current"
background_url="http://fc00.deviantart.net/fs71/f/2014/189/4/f/moki_by_mokotoy-d7ptvix.jpg"

##################################################
# Parse Inputs
##################################################
VERBOSE=false
pre_install=false
man_page=false
do_update=false
install_snort=false
download_rules=false
edit_conf=false
post_install=false
install_plcscan=false
install_wago=false
install_modscan=false
edit_ipvar_conf=false


### Check Inputs ###
while true; do
case "$1" in
    -v | --verbose )
        VERBOSE=true;
        shift
        ;;
    -h | --help )
        man_page=true
        shift
        ;;
    --all )
        pre_install=true
        do_update=true
        install_snort=true
        download_rules=true
        edit_conf=true
        post_install=true
		install_plcscan=true
		install_wago=true
		install_modscan=true
        shift
        ;;
    --snort | --Snort )
        pre_install=true
        do_update=true
        install_snort=true
        post_install=true
        shift
        ;;
    --db | --digitalbond ) # Select This Option if Snort is already installed
        pre_install=true
        download_rules=true
        edit_conf=true
        post_install=true
        shift
        ;;
	--plcscan )
		install_plcscan=true
		shift
		;;
	--wago )
		install_wago=true
		shift
		;;
	--modscan )
		install_modscan=true
		shift
		;;
    * ) break
        ;;
   esac
done

if $man_page ; then
    echo -e "Usage: setup.sh [options] \n \n
    Installs SCADA/ICS Tools Enhancement for Kali Linux Machine \n
    Options: \n
        --all  \t\t\t Installs all tools in the toolbox. \n
        --snort | --Snort \t Installs Snort. \n
        --db | --digitalbond \t Installs Digital Bond's ICS Snort Rules. \n
        \t\t\t Select this option if Snort is already installed. \n
	--plcsan \t\t Installs PLCScan \n
	--wago \t\t\t Installs Wago Exploit on 3S CoDeSys Runtime software \n
	--modscan \t\t Installs ModScan \n
        -h | --help \t\t This manual page. \n
        -v | --verbose \t\t Verbose."
fi

if $pre_install ; then
    #### test folder in ~/ ####
    dir="$HOME/test"
    rm -rf "$dir"
    mkdir "$dir"
    if ! cd "$dir" ; then 
        echo "-> Error: could not cd to \"$dir\"" >&2
        exit 1
    fi

    ########## Run this to get sudo access ###########
    echo "# Checking for sudo access... "
    sudo ls >/dev/null
fi 

##################################################
# Do Each Install Option
##################################################
# Adds Official Kali Linux Repositories and update & upgrades system
if $do_update ; then
    echo "# Adding Official Kali Linux Repositories... " 
    echo "## Regular repositories
    deb http://http.kali.org/kali kali main non-free contrib
    ## Source repositories
    deb-src http://http.kali.org/kali main non-free contrib
    deb-src http://security.kali.org/kali-security kali/updates main contrib non-free" >> /etc/apt/sources.list
    
    echo "# Updating apt-get & Upgrading all packages... "
    apt-get clean
    apt-get update -y --force-yes
    apt-get upgrade -y --force-yes
    apt-get dist-upgrade -y --force-yes
fi

# Installs Snort using apt-get
if $install_snort ; then
    echo "# Installing Snort... "
    apt-get install -y snort \
    snort-common \
    snort-common-libraries
fi

# Downloads Quickdraw Snort Rules and Sample Traffic from Digital Bond's Website and puts the rules 
# in snort's rules directory
if $download_rules ; then
    echo "# Downloading rules... "
    wget --no-check-certificate https://www.digitalbond.com/wp-content/uploads/2011/02/quickdraw_4_3_1.zip
    unzip quickdraw_4_3_1.zip

    # Copies Digital Bond's Quickdraw SCADA Snort rules to the rules directory
    cp {dnp3*.rules,modbus*.rules,enip_cip*.rules,vulnerability*.rules} /etc/snort/rules
    
    echo "# Downloading Traffic Samples from Digital Bond"
    wget http://digitalbond.com/wp-content/uploads/2011/02/Quickdraw_PCAPS_4_0.zip
    unzip Quickdraw_PCAPS_4_0.zip -d Quickdraw_PCAPS_4_0
    cp Quickdraw_PCAPS_4_0 /Desktop
	
	echo "# Downloading Script for testing Quickdraw Snort Rules"
	wget --no-check-certificate https://raw.githubusercontent.com/mokotoy/moki/master/testSnortRules.sh
	chmod +x testSnortRules.sh
	cp testSnortRules /Desktop
fi


# Configures Snort with Digital Bond's Quickdraw SCADA IDS Snort Rules using specific ipvar settings
if $edit_ipvar_conf ; then
    correctIP=false
    regex="\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"
    echo "# Editing Configuration File... "

    ## Receives Client IP address input from user
    echo "Please Enter Client IP Address (X.X.X.X)"
    read client_address
    CHECK="$(echo $client_address | egrep $regex)"
    if [[ "$?" -eq 0 ]] ; then
        correctIP=true
        echo "You entered the correct IP Address. Good Job!"
    fi
    
    while [ $correctIP != true ] 
    do
        echo "Incorrect IP, Please re-nter Client IP Address (X.X.X.X)"
          read client_address
          CHECK="$(echo $client_address | egrep $regex)"
          if [[ "$?" -eq 0 ]] ; then
            correctIP=true
            echo "You finally did something right!"
          fi
    done
    
    ## Receives Server IP address input from user
    echo "Please Enter Server IP Address (X.X.X.X)"
    read server_address
    CHECK="$(echo $server_address | egrep $regex)"
    if [[ "$?" -eq 0 ]] ; then
        correctIP=true
        echo "You entered the correct IP Address. Good Job!"
    fi

    while [ $correctIP != true ] 
    do
        echo "Incorrect IP, Please re-nter Server IP Address (X.X.X.X)"
          read server_address
          CHECK="$(echo $server_address | egrep $regex)"
          if [[ "$?" -eq 0 ]] ; then
            correctIP=true
            echo "You finally did something right!"
          fi
    done

    ## Updates Snort Configuration file
    echo -e "#################
# SCADA Variables
#################
ipvar MODBUS_CLIENT $client_address
ipvar MODBUS_SERVER $server_address
ipvar ENIP_CLIENT $client_address
ipvar ENIP_SERVER $server_address
ipvar DNP3_CLIENT $client_address
ipvar DNP3_SERVER $server_address
portvar DNP3_PORTS 20000

##############
# SCADA Rules
##############
include \$RULE_PATH/modbus_1_2.rules
include \$RULE_PATH/dnp3_1_2.rules
include \$RULE_PATH/enip_cip_1_1.rules
include \$RULE_PATH/vulnerability_1_5.rules" >> /etc/snort/snort.conf

fi

# Configures Snort with Digital Bond's Quickdraw SCADA IDS Snort Rules using default 
# Only adding Modbus/TCP rules due to missing variables in other rules from missing 
# preprocessors
if $edit_conf ; then

    ## Updates Snort Configuration file
    echo "#################
# SCADA Variables
#################
ipvar MODBUS_CLIENT $HOME_NET
ipvar MODBUS_SERVER $HOME_NET
ipvar ENIP_CLIENT $HOME_NET
ipvar ENIP_SERVER $HOME_NET
ipvar DNP3_CLIENT $HOME_NET
ipvar DNP3_SERVER $HOME_NET
portvar DNP3_PORTS 20000

##############
# SCADA Rules
##############
include $RULE_PATH/modbus_1_2.rules" >> /etc/snort/snort.conf

fi

if $install_plcscan ; then
# Installs PLCScan
	echo "# Installing PLCScan... "
	wget http://plcscan.googlecode.com/svn/trunk/plcscan.py \
	http://plcscan.googlecode.com/svn/trunk/modbus.py \
	http://plcscan.googlecode.com/svn/trunk/s7.py
	
	# Create a directory for the PLCScan files
	mkdir ~/Desktop/PLCScan
	mv {plcscan.py,modbus.py,s7.py} ~/Desktop/PLCScan
	
	echo "# To execute PLCScan, type: \"Python plcscan.py\""
	
fi

if $install_wago ; then
# Installs Digital Bond's Wago Exploit on 3S CoDeSys Runtime Software
	echo "# Installing Wago Exploit... "
	wget --no-check-certificate \
	https://raw.githubusercontent.com/mokotoy/moki/master/codesys-shell.py \
	https://raw.githubusercontent.com/mokotoy/moki/master/codesys-transfer.py \
	https://raw.githubusercontent.com/mokotoy/moki/master/codesys.nse
	
	# Create a directory for the Wago Exploit files
	mkdir ~/Desktop/WagoExploit
	mv {codesys-shell.py,codesys-transfer.py,codesys.nse} ~/Desktop/WagoExploit
	
	echo "# To execute python files, type: \"Python codesys-shell.py\""

fi

if $install_modscan ; then
	# Installs ModScan
	echo "# Installing ModScan... "
	wget http://modscan.googlecode.com/svn/trunk/modscan.py
	chmod +x modscan.py
	ln -s modscan.py modscan
	mv {modscan.py,modscan} /usr/bin
	
fi


# Installs custom background and cleans up tmp folder
if $post_install ; then
    ##################################################
    # Install Custom Backgroun Image
    ##################################################
    echo "# Changing custom background image... "
    wget -O /usr/share/backgrounds/gnome/moki.jpg $background_url
    gsettings set org.gnome.desktop.background picture-uri "file:///usr/share/backgrounds/gnome/moki.jpg"

    ##################################################
    # Cleanup
    ##################################################

    if true ; then
        # Clean up after the installs.
        echo "# Cleaning packages... "
        sudo apt-get -y --force-yes clean
        sudo apt-get -y --force-yes autoclean
        sudo apt-get -y --force-yes autoremove
    fi

    ls -l
    rm -rf "$dir"

    ##################################################
    # Finished Testing
    ##################################################
    echo "# "
    echo "# All Done, Check the .conf file and rules directory"
    echo "# "
	echo "# Go to Desktop and execute ./testSnortRules.sh to test Snort Rules"
	echo "# "
fi

