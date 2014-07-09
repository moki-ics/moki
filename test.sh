#!/bin/bash

digitalbond__url="https://www.digitalbond.com/wp-content/uploads/2011/02"
snort_url="http://www.snort.org/dl/snort-current"
background_uri="http://fc00.deviantart.net/fs71/f/2014/189/4/f/moki_by_mokotoy-d7ptvix.jpg"

##################################################
# Parse Inputs
##################################################
VERBOSE=false

do_update=false
install_snort=false
download_rules=false
edit_conf=false
echo=false
loop=false

### Check Inputs ###
while true; do
case "$1" in
    -v | --verbose )
        VERBOSE=true;
        shift
        ;;
    --all )
        do_update=true
        shift
        ;;
    --snort | --Snort )
        install_snort=true
        shift
        ;;
    --rules )
        download_rules=true
        shift
        ;;
    --conf )
        edit_conf=true
        shift
        ;;
    --echo )
        echo=true
        shift
        ;;
    --loop )
        loop=true
        shift
        ;;
    * ) break
        ;;
   esac
done

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

##################################################
# Do Each Install Option
##################################################
if $do_update ; then
    echo "# Updating apt-get & Upgrading all packages... "
    apt-get -y --force-yes update
    apt-get -y --force-yes upgrade
fi


if $install_snort ; then
    echo "# Installing Snort..."
    wget $snort_url/snort-2.9.6.1.tar.gz
    tar zxf snort*.tar.gz
    ./snort*/configure
    make
    make install
fi


if $download_rules ; then
    echo "# Downloading rules... "
    wget --no-check-certificate https://www.digitalbond.com/wp-content/uploads/2011/02/quickdraw_4_3_1.zip
    unzip quickdraw_4_3_1.zip

    # Copies Digital Bond's Quickdraw SCADA Snort rules to the rules directory
    cp {dnp3*.rules,modbus*.rules,enip_cip*.rules,vulnerability*.rules} /etc/snort/rules
fi


if $edit_conf ; then
    echo "# Editing Configuration File... "
    # Input User's Client and Server IP Addresses
    echo "# Please enter Client Address (CIDR Notation: X.X.X.X/XX) "
    read client_address
    echo "# Please enter Server Address (CIDR Notation: X.X.X.X/XX) "
    read server_address
    
    # Checks for user entry. If empty, default is "any"
    if [[ -z "$client_address" ]] ; then
        client_address="any"
        echo "You didn't enter shit. Default is $client_address"
    else
        echo "You entered: $client_address"
    fi
    if [[ -z "$server_address" ]] ; then
        server_address="any"
        echo "Default Server Address is $server_address "
    else
        echo "You entered: $server_address"
    fi

    # Append to configuration file

    ### Test/Debugging Script. Remove Later
    echo "Current Directory "
    pwd


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
include \$RULE_PATH/modbus*.rules
include \$RULE_PATH/dnp3*.rules
include \$RULE_PATH/enip_cip*.rules
include \$RULE_PATH/vulnerability*.rules" >> $HOME/Desktop/test/test.conf
## Test cat script, comment out later

## Real cat script, uncommnet later
# >> /etc/snort/snort.conf

fi

if $echo ; then
    echo "# Testing echo command in a file... "
    regex="\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"
    # Input User's Client and Server IP Addresses
    echo -n "# Please enter Client Address (CIDR Notation: X.X.X.X) "
    read client_address

    CHECK="$(echo $client_address | egrep $regex)"
    if [[ "$?" -eq 0 ]] ; then
      echo -n "Correct IP address"
    else
      echo -n "Incorrect IP address, please try again: "
    fi

    echo "# Please enter Server Address (CIDR Notation: X.X.X.X/XX) "
    read server_address
    # Checks for user entry. If empty, default is "any"
    if [[ -z "$client_address" ]] ; then
        client_address="any"
        echo "You didn't enter shit. Default is $client_address"
    else
        echo "You entered: $client_address"
    fi
    if [[ -z "$server_address" ]] ; then
        server_address="any"
        echo "Default Server Address is $server_address "
    else
        echo "You entered: $server_address "   
    fi

fi 

if $loop ; then
    correctIP=false
    regex="\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b"

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
#*#*# Do The Same Thing Above For $server_address #*#*#*
fi

##################################################
# Install Custom Backgroun Image
##################################################
echo "# Changing custome background image"
wget -O /usr/share/backgrounds/gnome/moki.jpg $background_uri
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
