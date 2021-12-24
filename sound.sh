#!/bin/bash
##
PROGVERSION=2021100301
##
PROGFILENAME=sound.sh
##
PROGNAME=
##
PROGDESCRIPTION="install sound and od tools"
##
PROGAUTHOR="dlkvk"
##
## HISTORY
## =======
## 20210412 start writing code


## SOURCES
##########


## VARS
#######
DEBIAN_FRONTEND=noninteractive
DEBIAN_PRIORITY=critical
INSTALLMODE=$1
LOOP=1
DATE=`date "+%Y-%m-%d_%H:%M:%S"`
STAMP=`echo "stamp.install.$DATE"`
INSTALLDIR=/root/.__INSTALL


## FUNCTIONS
############


## MAIN 
#######

echo "file = $PROGFILENAME | version = $PROGVERSION"
echo "$PROGDESCRIPTION"

apt -y install mplayer sox wodim libcdio-utils cdrskin cdrdao xorriso mp3cd mp3info mp3rename vorbis-tools flactag lirc lirc-compat-remotes osspd mpv socat cdtool abcde w3m minidisc-utils

echo "STAMP=$STAMP"
echo EOP
