#!/bin/bash

"""
This script tests the installed Quickdraw SCADA IDS Snort Rules using
sample packet captures provided by Digital Bond
"""

# Checks and ensures user have sudo access... not really necessary for Kali
echo "# Checking sudo access..."
sudo ls >/dev/null

# Test Snort Configuration Files by executing the -T option on Snort
echo "# Testing Snort Configuration Files..."
Snort -T -c /etc/snort/snort.conf

# Run Snort -- Not sure how to run this and run other commands at the same time...
#snort -v -i eth0 -c /etc/snort/snort.conf -l /var/log/snort

# Test Modbus/TCP Rules by running one of the traffic samples provided by Digital Bond
echo "# Testing MODBUS/TCP Rules... "
cd ~/Desktop/Quickdraw_PCAPS_*
tcpreplay -t -i eth0 modbus_test_data_part1.pcap

