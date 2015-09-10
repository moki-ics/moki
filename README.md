Moki Linux
====

Moki is a modification of Kali to encorporate various ICS/SCADA Tools scattered around the internet, to create a customized Kali Linux geared towards ICS/SCADA pentesting professionals. 

Some projects have been locally archived under `mirror`, as they are not maintained in a stable location externally.

Install
-------
To get and run the core bash script, from a fresh install of Kali, run:

    wget https://goo.gl/Sn7Cwi -O setup.sh
    sh setup.sh --help


Current Tools
-------------

- [Quickdraw] SCADA Snort Rules from Digital Bond
- [CoDeSys exploit] from Digital Bond
- [PLC Scan] from Dmitry Efanov
- [Modscan] from Mark Bristow
- [Siemens S7 metasploit] modules from Dillon Beresford
- [Siemens S7 wireshark dissector] from Thomas Wiens





[CoDeSys exploit]: http://www.digitalbond.com/tools/basecamp/3s-codesys/
[Quickdraw]: https://github.com/digitalbond/quickdraw
[PLC Scan]: http://plcscan.googlecode.com
[Modscan]: https://code.google.com/p/modscan/
[Siemens S7 metasploit]: https://github.com/moki-ics/s7-metasploit-modules
[Siemens S7 wireshark dissector]: http://sourceforge.net/projects/s7commwireshark/
