#!/bin/bash
##
PROGVERSION=2021120801
##
PROGFILENAME=unixrecorder.sh
##
PROGNAME=unixrecorder
##
PROGDESCRIPTION="versatile disc recorder / VDR-8024-C" # "record from digital input to media"
##
PROGAUTHOR="dlkvk"
##
## Notes
##
## 2021022801 start writing code
## 2021120401 rollback $PLAY and find playlists
##
##
## C O P Y R I G H T
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
##
## You can receive a copy of the GNU General Public License
## at <http://www.gnu.org/licenses/>.


## DEBUG
declare PAUS=9
#declare TMP_DEBUG=`amixer get Master |grep Front|grep Left|grep -v channels | awk '{print $5 $6}'`


## SOURCES
#source /local/bin/style.sh
source /usr/local/lib/specialkeys.sh


## VARS AND INIT
#declare PROGSHOWNAME="U N I X R E C O R D E R"
#declare PROGSHOWNAME="D E L E C T R O N I C"
declare PROGSHOWNAME="K E L E C T R O N I C"

#declare -r TMPFILE=`mktemp $TMP/unixrecorder-$USER.XXXXXXXXX`

devtty=`tty | grep tty`
if [ -z "$devtty" ] ; then  declare -ir DEVTTY=1
else declare -ir DEVTTY=0 ; fi

declare CONFIG=~/.config/unixrecorder/config
declare AUTOSAVE=~/.cache/unixrecorder/autosave

if [ ! -d ~/.config/unixrecorder ] ; then mkdir -p ~/.config/unixrecorder ; fi
if [ ! -d ~/.cache/unixrecorder ] ; then mkdir -p ~/.cache/unixrecorder ; fi

if [ ! -f $AUTOSAVE ] ; then
    touch "$AUTOSAVE"
    echo "RADIOCOUNTER=1" > $AUTOSAVE
    echo "CDCURTRACK=0" >> $AUTOSAVE
    echo "HDCURTRACK=0" >> $AUTOSAVE
    echo "FDCURTRACK=0" >> $AUTOSAVE
    echo "TEST=0" >> $AUTOSAVE
fi

if [ ! -f $CONFIG ] ; then
    touch "$CONFIG"
    echo "CDROM=/mnt/cdrom" >> $CONFIG
    echo "HARRDISC=~/Music" >> $CONFIG
    echo "FLOPPY=/mnt/floppy" >> $CONFIG
fi

declare -r TMP=/dev/shm

#declare -r TMPFILE=$TMP/unixrecorderdata
declare -r CDDATAFILE=$TMP/unixrecordercddata
if [ ! -f "$CDDATAFILE" ] ; then touch "$CDDATAFILE" ; fi

declare -r PIPE=$TMP/unixrecorderpipe
if [ ! -p "$PIPE" ] ; then mkfifo "$PIPE" ; fi

declare -r CDSOCKET=$TMP/unixrecordercdsocket
declare -r HDSOCKET=$TMP/unixrecorderhdsocket
declare -r FDSOCKET=$TMP/unixrecorderfdsocket

#files
declare CDPLAYLIST=$TMP/cdplaylist.mu3
declare HDPLAYLIST=$TMP/hdplaylist.mu3
declare FDPLAYLIST=$TMP/fdplaylist.mu3

#save files & tracks
declare -r CDFILEPLAYLIST=$TMP/cdplaylist.mu3 ; declare CDFILEAUDIOTRACKS
declare -r HDFILEPLAYLIST=$TMP/hdplaylist.mu3 ; declare HDFILEAUDIOTRACKS
declare -r FDFILEPLAYLIST=$TMP/fdplaylist.mu3 ; declare FDFILEAUDIOTRACKS

#files random
declare -r CDRANDPLAYLIST=$TMP/cdrandplaylist.mu3
declare -r HDRANDPLAYLIST=$TMP/hdrandplaylist.mu3
declare -r FDRANDPLAYLIST=$TMP/fdrandplaylist.mu3

#playlists
declare -r CDPLAYPLAYLIST=$TMP/cdplayplaylist.mu3
declare -r HDPLAYPLAYLIST=$TMP/hdplayplaylist.mu3
declare -r FDPPLAYLAYLIST=$TMP/fdplayplaylist.mu3

declare -i PLAYMODE=0
declare PLAYMODEDISPLAY="ALL"

declare KEY=""
declare KEYRC=1
declare IRKEYRC=1

declare -i INPUT=0   # 0=CD 1=HD 2=CM 3=RADIO
declare -i SOURCE=2  # 0=CD 1=OI 2=AI 3=ANALOG
declare -i PLAY=0    # 0=STOP 1=PLAY 2=PAUSE
declare -i LASTPLAY=0 # store previous value of play for ledcontrol
declare -i RECORD=0  # 0=OFF 1=ON
declare -i EJECT=0   # 0=OFF 1=ON
declare -i DISPLAY=0 # 0=default
declare -i TONLI=0   # 0=default 1 = other devices then tis one
declare AUXM         # message if TONLI!=0
declare -i DISPLAYBRIGHTNESS=3

declare -r CDDEV=/dev/sr0
declare -r CDMNT=/mnt/cdrom
declare -i HDDEV=0
declare -r HDMNT=/home/public/media/audio
declare -r FDDEV=/dev/sdc1
declare -r FDMNT=/mnt/flash
#declare -r FDDEV=/dev/fd0
#declare -r FDMNT=/mnt/floppy

#declare -r FDDEV=`cat $CONFIG |grep FLOPPY | awk -F = '{print $2}'`

declare -i PIDOFLEDCONTROL=0
declare -i PIDOFRADIO=0
declare -i PIDOFIREXEC=0
declare LIRCCONFFILE=/etc/lirc/unixrecorder.lircrc
if [ "$DEVTTY" -eq "0" ] ; then 
    /usr/bin/irexec -d $LIRCCONFFILE --loglevel debug
    PIDOFIREXEC=`/bin/pidof irexec`
fi

declare -i MAINLOOP=1
declare -i READLOOP=1

declare COMMAND="waiting your command"
declare LIST="main"

# Sound
declare AUDIOVOLUME=`amixer get Master |grep Front|grep Left|grep -v channels | awk '{print $5 $6}'`

## Optical Disk
declare -i TRAY_STATUS=0 #0=closed 1=opening 2=open 3=closing 4=loading
declare -i OD_MEDIA_STATUS=`udevadm info -q property /dev/cdrom|grep ID_CDROM_MEDIA > /dev/null;echo $?`
declare -i LAST_OD_MEDIA_STATUS=3 # force read OD in first loop. This status does not exist, only 0 || 1
declare OD_INFO
declare -i OD_TYPE=99 # 0=unknown 1=cd-audio 2=cd-text 3=cd-data 4=dvd-data 5=dvd-video 6=blu-ray 7=vcd

# Floppy Disk
declare -i FD_MEDIA_STATUS= #`udevadm info -q property /dev/cdrom|grep ID_CDROM_MEDIA > /dev/null;echo $?`
declare -i LAST_FD_MEDIA_STATUS=3 # force read FD in first loop. This status does not exist, only 0 || 1

mainteller=0
readteller=0

declare RADIOCOUNTER=`cat $AUTOSAVE |grep RADIOCOUNTER | tr -dc '0-9'`
declare RADIOEXE="mplayer -really-quiet -nolirc -nocache -afm ffmpeg"
#declare RADIOEXE="mplayer -really-quiet -nolirc -cache 8192 -afm ffmpeg"
declare RADIOLINK
declare RADIOINFO
declare RA01LINK="http://icecast.omroep.nl/radio1-bb-mp3 &"
declare RA01INFO="NPO1";declare RA01METANAME="NPO Radio 1";declare RA01METAPTY="News"
declare RA02LINK="http://icecast.vrtcdn.be/radio1-mid.mp3 &"
declare RA02INFO="VRT1";declare RA02METANAME="VRT Radio 1";declare RA02METAPTY="News"
declare RA03LINK="http://stream.live.vc.bbcmedia.co.uk/bbc_world_service &"
declare RA03INFO="BBCwrl";declare RA03METANAME="BBC World Service";declare RA03METAPTY="News"
declare RA04LINK="http://stream.live.vc.bbcmedia.co.uk/bbc_radio_fourlw_online_nonuk &"
declare RA04INFO="BBC4";declare RA04METANAME="BBC Radio 4";declare RA04METAPTY="News"
declare RA05LINK="http://st01.dlf.de/dlf/01/128/mp3/stream.mp3 &"
declare RA05INFO="DeFUNK";declare RA05METANAME="Deutschland Funk";declare RA05METAPTY="News"
declare RA06LINK="http://d3pvma9xb2775h.cloudfront.net/icecast/omropfryslan/radio.mp3 &"
declare RA06INFO="OmrFRY";declare RA06METANAME="Omrop Fryslan";declare RA06METAPTY="Regio"
declare RA07LINK="http://media.rtvnoord.nl/icecast/rtvnoord/radio?.mp3 &"
declare RA07INFO="RtvNRD";declare RA07METANAME="RTV Noord";declare RA07METAPTY="Regio"
declare RA08LINK="http://20133.live.streamtheworld.com/SUBLIME.mp3?dist=tunein &"
declare RA08INFO="RaSubli";declare RA08METANAME="Radio Sublime";declare RA08METAPTY="Jazz"
declare RA09LINK="http://icecast.omroep.nl/radio6-bb-mp3 &"
declare RA09INFO="NPO6";declare RA09METANAME="NPO Radio 2 Soul and Jazz";declare RA09METAPTY="Jazz"
declare LEDRADIOINFO="ZERO" # in case something goes wrong this goes to display
declare RAMINUTE;declare RAHOUR;declare RACLOCK="0" # clock
declare D4RADIOINFO="TU 0" # if you see this on display, there are no radiostations defined

#  C D - H D - F D
declare CDINFO="CD 0"
declare D4CDINFO=$CDINFO
declare HDINFO="HD 0"
declare D4HDINFO=$HDINFO
declare FDINFO="FD 0"
declare D4FDINFO=$FDINFO

declare CDDAPERFORMER;declare CDDAALBUMTITLE;declare CDTRACK_TITLE_LIST         # types 1&2: cdda
declare CDVOLUME;declare CDPERFORMER;declare CDALBUMTITLE;declare CDTRACKTITLE  # all other optical discs
declare HDVOLUME;declare HDPERFORMER;declare HDALBUMTITLE;declare HDTRACKTITLE  # hard drive
declare FDVOLUME;declare FDPERFORMER;declare FDALBUMTITLE;declare FDTRACKTITLE  # floppy disc ;-)

declare -i CDCURTRACK=`cat $AUTOSAVE |grep CDCURTRACK | tr -dc '0-9'`
declare -i CDLASTTRACK=$CDCURTRACK ; declare -i CDREALTRACK=0
declare -i CDTRACKS=0 ; declare -i CDAUDIOTRACKS=0
declare -i CDPLAY=0    # 0=STOP 1=PLAY 2=PAUSE
declare CD_PLAY_TIME

declare -i HDCURTRACK=`cat $AUTOSAVE |grep HDCURTRACK | tr -dc '0-9'`
declare -i HDLASTTRACK=$HDCURTRACK ; declare -i HDREALTRACK=0
declare -i HDTRACKS=0 ; declare -i HDAUDIOTRACKS=0
declare -i HDPLAY=0    # 0=STOP 1=PLAY 2=PAUSE
#declare HD_PLAY_TIME=00:00:00

declare -i FDCURTRACK=`cat $AUTOSAVE |grep FDCURTRACK | tr -dc '0-9'`
declare -i FDLASTTRACK=$FDCURTRACK ; declare -i FDREALTRACK=0
declare -i FDTRACKS=0 ; declare -i FDAUDIOTRACKS=0
declare -i FDPLAY=0    # 0=STOP 1=PLAY 2=PAUSE
#declare FD_PLAY_TIME=00:00:00

declare -i BROWSEID
declare BROWSESTRING

# VFD
# 0=USB 1=_HD_ 2=HDD 3=E3 4=MP3 5=0 6=<< 7=> 8=|| 9=>> 10=_REC_ 11=P


## FUNCTIONS

## internal functions

doKill(){
    if [ "$DEVTTY" -eq "0" ] ; then
    	ledcontrol.py redon&
        if [ $PIDOFLEDCONTROL -ne 0 ] ; then kill -TERM $PIDOFLEDCONTROL ; fi
        leddisplay.py blankdisplay 0;fi

    sed -i -- '/^RADIOCOUNTER/d' $AUTOSAVE;echo "RADIOCOUNTER=${RADIOCOUNTER}" >> $AUTOSAVE
    sed -i -- '/^CDCURTRACK/d' $AUTOSAVE;echo "CDCURTRACK=${CDCURTRACK}" >> $AUTOSAVE
    sed -i -- '/^HDCURTRACK/d' $AUTOSAVE;echo "HDCURTRACK=${HDCURTRACK}" >> $AUTOSAVE
    sed -i -- '/^FDCURTRACK/d' $AUTOSAVE;echo "FDCURTRACK=${FDCURTRACK}" >> $AUTOSAVE

    if [ $PIDOFIREXEC -ne 0 ] ; then kill -TERM $PIDOFIREXEC ; fi
    rm $CDDATAFILE; rm $PIPE
    if [ $PIDOFRADIO -ne 0 ] ; then kill -TERM $PIDOFRADIO ; fi
    if [ $OD_TYPE -eq 10 ] || [ $OD_TYPE -eq 3 ] || [ $OD_TYPE -eq 2 ] || [ $OD_TYPE -eq 1 ] ; then
        if [ $CDPLAY -ne 0 ] ; then
            echo 'quit' | socat - $CDSOCKET ; rm $CDSOCKET ; fi
    umount $CDMNT ; fi
    if [ $HDPLAY -ne 0 ] ; then
        echo 'quit' | socat - $HDSOCKET ; rm $HDSOCKET ; fi
    if [ $FDPLAY -ne 0 ] ; then
        echo 'quit' | socat - $FDSOCKET ; rm $FDSOCKET ; fi
    umount $FDMNT
    rm $CDPLAYLIST ;  rm $HDPLAYLIST ;  rm $FDPLAYLIST

    tput sgr0
    #reset
}

doHUP(){
    doKill
    exit 0
}

trap doHUP SIGINT SIGTERM

readKey(){
    unset K1 K2 K3 K4 K5
    read -s -N1 -t 0.1 ;  KEYRC=$?  ## if first read succeeded, this becomes 0
    K1="$REPLY"
    read -s -N2 -t 0.001
    K2="$REPLY"
    read -s -N1 -t 0.001
    K3="$REPLY"
    read -s -N1 -t 0.001
    K4="$REPLY"
    read -s -N1 -t 0.001
    K5="$REPLY"
    KEY="$K1$K2$K3$K4$K5"
}

readIrkey(){
    if [ "$DEVTTY" -eq "0" ] ; then
        unset tmp
        #read -t 0.1 tmp <> /dev/shm/unixrecorderpipe #$PIPE    # use <> for timeout to work
        read -t 0.1 tmp <> $PIPE     # use <> for timeout to work
    	IRKEY=${tmp}

    	if [ ! -z ${tmp} ] ; then
	        KEY=${tmp:0:3}
            IRKEYRC=0
        else
            sleep 0.1
        fi
	else
        sleep 0.1
    fi
}

makeledstring(){
local countchars=${#2}
local nchar

if [ $PLAY -ne 0 ] ; then
    case $countchars in
    1)  nchar="0$2" ;;
    2)  nchar="$2" ;;
    3)  nchar="${2:1:2}" ;;
    4)  nchar="${2:2:2}" ;;
    5)  nchar="${2:3:2}" ;;
    esac
else
    case $countchars in
    1)  nchar="0$2" ;;
    2)  nchar="$2" ;;
    3)  nchar="${2:0:1}c" ;;
    4)  nchar="${2:0:1}m" ;;
    5)  nchar="${2:0:1}d" ;;
    *)  nchar="${2:0:1}p" ;;
    esac
fi
case $1 in
CD) D4CDINFO="$1$nchar" ;;
HD) D4HDINFO="$1$nchar" ;;
FD) D4FDINFO="$1$nchar" ;; 
TU) D4RADIOINFO="$1$nchar" ;;
esac
}

setdisplaybrightness(){
    if [ $KEY -eq 206 ] ; then
        let DISPLAYBRIGHTNESS++ ; if [ $DISPLAYBRIGHTNESS -eq 8 ] ; then DISPLAYBRIGHTNESS=7 ; fi
    fi

    if [ $KEY -eq 205 ] ; then
        let DISPLAYBRIGHTNESS-- ; if [ $DISPLAYBRIGHTNESS -eq -1 ] ; then DISPLAYBRIGHTNESS=0 ; fi
    fi

    #leddisplay.py brightness $DISPLAYBRIGHTNESS

}


# O P T I C A L   D I S C  and other disc operations --->>>
readodstatus(){
    # udevadm asks /proc 
    # cd-info reads the disk
    declare RC=1088111

    if [ -e "$CDDEV" ] ; then
        OD_MEDIA_STATUS=`udevadm info -q property /dev/cdrom|grep ID_CDROM_MEDIA > /dev/null;echo $?`
    else
        OD_MEDIA_STATUS=1 # not only the disk is missing, the drive itself to. We let this as is.
    fi

    if [ $OD_MEDIA_STATUS -eq 0 ] ; then    #there is an OD
        RC=`udevadm info -q property /dev/cdrom|grep ID_CDROM_MEDIA_CD > /dev/null;echo $?`
        if [ $RC -eq 0 ] ; then        # return value 0 means compact disc
            CDTRACKS=`udevadm info -q property /dev/cdrom|grep ID_CDROM_MEDIA|grep AUDIO|sed 's/[^0-9]*//g'`

            if [ $CDTRACKS -gt 0 ] ; then     # this track count is audio tracks only
                if [ $OD_TYPE -ne 2 ] ;then
                    OD_TYPE=1
                fi
            else
                RC=`udevadm info -q property /dev/cdrom|grep TRACK_COUNT_DATA | cut -c 33-`
                if [ $RC -gt 1 ] ; then
                    OD_TYPE=4
                else
                    OD_TYPE=3
                    watchmp3cd # why here and not in readodinfo?
               fi
            fi
        fi

        RC=`udevadm info -q property /dev/cdrom|grep ID_CDROM_MEDIA_DVD > /dev/null;echo $?`
        if [ $RC -eq 0 ] ; then        # return value 0 means compact disc
            OD_TYPE=10
            watchmp3cd
        fi
    fi

    setodinfo
    # 0=unknown 1=cd-audio 2=cd-text 3=cd-data 4=vcd 10=dvd
    # 0=unknown 1=cd-audio 2=cd-text 3=cd-data 4=dvd-data 5=dvd-video 6=blu-ray 7=vcd

    # HD and FD
    if [ -d "$HDMNT" ] ; then watchmp3cd ; fi
    if [ -d "$FDMNT" ] ; then watchmp3cd ; fi
}

watchmp3cd()    # MOUNT OR WATCH CURTRACK
{
    local cdmount ; local fdmount ; local fddev

    # CD
    if [ $OD_TYPE -eq 3 ] || [ $OD_TYPE -eq 10 ] ; then
        cdmount=`cat /proc/mounts | grep cdrom | wc -l`
        if [ $cdmount -ne 1 ] ; then
            mount $CDMNT  > /dev/null 2>&1
            echo "#EXTM3U" > $CDPLAYLIST  # make playlist....
            echo "#EXTM3U" > $CDRANDPLAYLIST  # make playlist....
            echo "#EXTM3U" > $CDPLAYPLAYLIST  # make playlist....
            find $CDMNT -type f -name "*.mp3" -o -name "*.wav" -o -name "*.flac" -o -name "*.ogg"  -o -name "*.opus" | sort >> $CDPLAYLIST
            find $CDMNT -type f -name "*.mp3" -o -name "*.wav" -o -name "*.flac" -o -name "*.ogg"  -o -name "*.opus" | shuf >> $CDRANDPLAYLIST
            find $CDMNT -type f -name "*.m3u" | sort >> $CDPLAYPLAYLIST
            CDAUDIOTRACKS=`cat $CDPLAYLIST | wc -l` ; let CDAUDIOTRACKS--
            CDFILEAUDIOTRACKS=$CDAUDIOTRACKS
            CDINFO="CD $CDAUDIOTRACKS"; makeledstring CD $CDAUDIOTRACKS
        fi
    fi

    if [ $CDPLAY -eq 1 ] ; then
        case $OD_TYPE in
        1|2)  CDCURTRACK=`echo '{ "command": ["get_property", "chapter"] }' | socat - $CDSOCKET | tr -dc '0-9'` ;;
        3|10) CDCURTRACK=`echo '{ "command": ["get_property", "playlist-pos"] }' | socat - $CDSOCKET | tr -dc '0-9'` ;;
        esac
    fi

    # HD
    if [ $HDDEV -eq 0 ] ; then
        # make playlist....
        echo "#EXTM3U" > $HDPLAYLIST #/dev/shm/playlist.mu3
        echo "#EXTM3U" > $HDRANDPLAYLIST #/dev/shm/playlist.mu3
        echo "#EXTM3U" > $HDPLAYPLAYLIST #/dev/shm/playlist.mu3
        find $HDMNT -type f -name "*.mp3" -o -name "*.wav" -o -name "*.flac" -o -name "*.ogg"  -o -name "*.opus" | sort >> $HDPLAYLIST
        find $HDMNT -type f -name "*.mp3" -o -name "*.wav" -o -name "*.flac" -o -name "*.ogg"  -o -name "*.opus" | shuf >> $HDRANDPLAYLIST
        find $HDMNT -type f -name "*.m3u" | sort >> $HDPLAYPLAYLIST
        HDAUDIOTRACKS=`cat $HDPLAYLIST | wc -l` ; let HDAUDIOTRACKS--
        HDFILEAUDIOTRACKS=$HDAUDIOTRACKS
        HDINFO="HD $HDAUDIOTRACKS"; makeledstring HD $HDAUDIOTRACKS
        HDDEV=1 # this happens only once in runtime
    else
        if [ $HDPLAY -eq 1 ] ; then
            HDCURTRACK=`echo '{ "command": ["get_property", "playlist-pos"] }' | socat - $HDSOCKET | tr -dc '0-9'` 
        fi
    fi

    # FD
    fdmount=`cat /proc/mounts | grep $FDMNT | wc -l`
    if [ $fdmount -ne 1 ] ; then # mount is not in proc, so not mounted
#        fddev=`lsblk --list --output=PATH | grep $FDDEV > /dev/null;echo $?` # 0='disc' in drive
        fddev=`lsblk --list --paths | grep $FDDEV > /dev/null;echo $?` # 0='disc' in drive
        if [ $fddev -eq 0 ] ; then
            if [ -d $FDMNT ] ; then
                mount $FDMNT  > /dev/null 2>&1
                fdmount=`cat /proc/mounts | grep $FDMNT | wc -l`
                if [ $fdmount -eq 1 ] ; then
                    # make playlist....
                    echo "#EXTM3U" > $FDPLAYLIST #/dev/shm/playlist.mu3
                    echo "#EXTM3U" > $FDRANDPLAYLIST #/dev/shm/playlist.mu3
                    echo "#EXTM3U" > $FDPLAYPLAYLIST #/dev/shm/playlist.mu3
                    find $FDMNT -type f -name "*.mp3" -o -name "*.wav" -o -name "*.flac" -o -name "*.ogg"  -o -name "*.opus" | sort >> $FDPLAYLIST
                    find $FDMNT -type f -name "*.mp3" -o -name "*.wav" -o -name "*.flac" -o -name "*.ogg"  -o -name "*.opus" | shuf >> $FDRANDPLAYLIST
                    find $FDMNT -type f -name "*.m3u" | sort >> $FDPLAYPLAYLIST
                    FDAUDIOTRACKS=`cat $FDPLAYLIST | wc -l` ; let FDAUDIOTRACKS--
                    FDFILEAUDIOTRACKS=$FDAUDIOTRACKS
                    FDINFO="FD $FDAUDIOTRACKS"; makeledstring FD $FDAUDIOTRACKS
                fi
            fi
        fi
    else
        if [ $FDPLAY -eq 1 ] ; then
            FDCURTRACK=`echo '{ "command": ["get_property", "playlist-pos"] }' | socat - $FDSOCKET | tr -dc '0-9'` 
        fi
    fi
}

readodinfo(){
    cd-info --dvd > $CDDATAFILE

    case $OD_TYPE in
        1)
            readcdda
            ;;
        3|10)
            CDVOLUME=`cat $CDDATAFILE |grep Volume|grep -v Set|awk '{print$3}'`
            ;;
        4)
            readvcd
            ;;
#        *)
#            TMP_DEBUG=""
#            ;;
    esac

    setodinfo
}

setodinfo(){
    case $OD_TYPE in
        1)
            #OD_INFO="CD AUDIO | $CDTRACKS TR | $CD_PLAY_TIME"
            OD_INFO="CD AUDIO | $CDTRACKS TR"
            ;;
        2)
            #OD_INFO="CD TEXT | $CDTRACKS TR | $CD_PLAY_TIME | CD-TEXT"
            OD_INFO="CD TEXT | $CDTRACKS TR"
            ;;
        3)
            OD_INFO="CD DATA | $CDAUDIOTRACKS TR"
            ;;
        4)
            OD_INFO="VCD | $CD_PLAY_TIME"
            ;;
        10)
            OD_INFO="DVD | $CDAUDIOTRACKS TR"
            ;;
        99)
            OD_INFO="UNKNOWN DISC"
            ;;
#        *)
#            TMP_DEBUG=""
#            ;;
    esac
}

readcdda(){
    local titlecount=`cat $CDDATAFILE | grep 'TITLE' | wc -l`
    local counter=1

    if [ $titlecount -gt 0 ] ; then
        OD_TYPE=2
        CDDAALBUMTITLE=`cat $CDDATAFILE | grep 'TITLE'| cut -c 9-|head -n 1`

        if [ `cat $CDDATAFILE | grep 'PERFORMER'| uniq | wc -l` -eq 1 ] ; then
            CDDAPERFORMER=`cat $CDDATAFILE | grep 'PERFORMER' | uniq | cut -c 13-`
        else
            CDDAPERFORMER="Multiple performers"
        fi

        CDTRACK_TITLE_LIST=`cat -E $CDDATAFILE | grep 'TITLE'| cut -c 9-|sed -e 's/\\$/\\\n/g'`
        echo "#EXTM3U" > $CDPLAYLIST    # create the fake playlist for cd-text
        echo -e $CDTRACK_TITLE_LIST|tail -n +2 |cut -c 2- >> $CDPLAYLIST
    else
        echo "#EXTM3U" > $CDPLAYLIST    # create the fake playlist for non cd-text
        until [ $counter -gt $CDTRACKS ] ; do
            echo "Track $counter"  >> $CDPLAYLIST; let counter++ ; done
    fi

    CD_PLAY_TIME=`cat $CDDATAFILE |grep 170: | awk  '{ print $2 }'`
    CDAUDIOTRACKS=$CDTRACKS
    CDINFO="CD $CDAUDIOTRACKS"; makeledstring CD $CDAUDIOTRACKS
}

readvcd(){
    CD_PLAY_TIME=`cat $CDDATAFILE |grep 170: | awk  '{ print $2 }'`
    CDALBUMTITLE=`cat $CDDATAFILE | grep Volume |grep -v Set | cut -c 14-`
    # TMP_DEBUG="$ALBUM_TITLE"
}

listodstatus(){
    if [ $OD_MEDIA_STATUS -eq 0 ] ; then
        echo -e "\033[01;37m${OD_INFO}\033[00;32m | COMMAND = $COMMAND | KEY = $KEY | VOLUME $AUDIOVOLUME | $PLAYMODEDISPLAY"
    else
        echo -e "\033[01;31mNO DISC\033[00;32m | COMMAND = $COMMAND | KEY = $KEY | VOLUME $AUDIOVOLUME | $PLAYMODEDISPLAY"
    fi

   echo
}

listinfo(){
    echo
    case $INPUT in
        0) case $OD_TYPE in
            1|2)    echo "Volume = $CD_PLAY_TIME"
                    echo "Artist = $CDPERFORMER"
                    echo "Album  = $CDALBUMTITLE"
                    echo "Song   = $CDTRACKTITLE"
                    ;;
            3|10)   echo "Volume = $CDVOLUME"
                    echo "Artist = $CDPERFORMER"
                    echo "Album  = $CDALBUMTITLE"
                    echo "Song   = $CDTRACKTITLE"
                    ;;
            4)  echo "album title = $ALBUM_TITLE"
                ;;
            *)  echo "No CD, VCD or DVD" ;;
           esac ;;
        1)  echo "Volume = $HDMNT"
            echo "Artist = $HDPERFORMER"
            echo "Album  = $HDALBUMTITLE"
            echo "Song   = $HDTRACKTITLE" ;;
        2)  echo "Volume = $FDMNT"
            echo "Artist = $FDPERFORMER"
            echo "Album  = $FDALBUMTITLE"
            echo "Song   = $FDTRACKTITLE";;
        3)  echo "Station = $RADIONAME"
            echo "Genre   = $RADIOPTY"
            echo "Time    = $RAHOUR:$RAMINUTE GMT";;
    esac
}

setcdinfo(){
local performer ; local albumtitle ; local tracktitle ; local socket
local cdda=1

if [ $OD_TYPE -eq 1 ] ; then cdda=0 ; fi
if [ $OD_TYPE -eq 2 ] ; then cdda=0 ; fi

case $INPUT in
0) socket=$CDSOCKET;;
1) socket=$HDSOCKET;;
2) socket=$FDSOCKET;;
esac

# play = play or pause and input is not radio
if [ $PLAY -ne 0 ] &&  [ $INPUT -ne 3 ] ; then

    #if mp3 OD
    if [ $cdda -eq 1 ] || [ $INPUT -eq 1 ] || [ $INPUT -eq 2 ] ; then
        performer=`echo '{ "command": ["get_property", "metadata/artist"] }' | socat - $socket | awk -F'"' '{print $4}'`
        albumtitle=`echo '{ "command": ["get_property", "metadata/album"] }' | socat - $socket | awk -F'"' '{print $4}'`
        tracktitle=`echo '{ "command": ["get_property", "metadata/title"] }' | socat - $socket | awk -F'"' '{print $4}'`
    else
        #cdda, no cd-text
        if [ $OD_TYPE -eq 1 ] ; then
            tracktitle="track $CDREALTRACK"
        fi
        #cdda, with cd-text
        if [ $OD_TYPE -eq 2 ] ; then 
            tracktitle=`echo -e $CDTRACK_TITLE_LIST | tail -n +2 | awk -F'\n' 'NR=='$CDREALTRACK' {print $1}' |cut -c 2-`
            performer=$CDDAPERFORMER ; albumtitle=$CDDAALBUMTITLE
        fi
    fi
fi

# play is stop and input is not radio
if [ $PLAY -eq 0 ] &&  [ $INPUT -ne 3 ] ; then
        performer=`echo "o no"`
        albumtitle=`echo ""`
        tracktitle=`echo ""`
fi

case $INPUT in
0) CDPERFORMER=$performer; CDALBUMTITLE=$albumtitle; CDTRACKTITLE=$tracktitle;;
1) HDPERFORMER=$performer; HDALBUMTITLE=$albumtitle; HDTRACKTITLE=$tracktitle;;
2) FDPERFORMER=$performer; FDALBUMTITLE=$albumtitle; FDTRACKTITLE=$tracktitle;;
esac
}

#setcdddainfo(){
#if [ $OD_TYPE -eq 2 ] ; then
##    CDPERFORMER=`echo '{ "command": ["get_property", "metadata/artist"] }' | socat - $CDSOCKET | awk -F'"' '{print $4}'`
##    CDALBUMTITLE=`echo '{ "command": ["get_property", "metadata/album"] }' | socat - $CDSOCKET | awk -F'"' '{print $4}'`
#    CDTRACKTITLE=`echo -e $CDTRACK_TITLE_LIST | tail -n +2 | awk -F'\n' 'NR=='$CDREALTRACK' {print $1}' |cut -c 2-`
#else
#    CDTRACKTITLE="track $CDREALTRACK"
#fi
#}

playcd(){
local cddastart=#$((CDCURTRACK+1))
case $INPUT in
    0)  if [ $CDPLAY -eq 0 ] ; then
            case $OD_TYPE in
            1|2)  mpv --start=$cddastart --pause --cdda-speed=1 --input-ipc-server $CDSOCKET cdda://  > /dev/null 2>&1 & ;;
            3|10) mpv --playlist-start=$CDCURTRACK --pause --input-ipc-server $CDSOCKET $CDPLAYLIST > /dev/null 2>&1 & ;;
#             1|2)  mpv --start=$cddastart --cdda-speed=1 --input-ipc-server $CDSOCKET cdda://  > /dev/null 2>&1 & ;;
#             3|10) mpv --playlist-start=$CDCURTRACK --input-ipc-server $CDSOCKET $CDPLAYLIST > /dev/null 2>&1 & ;;
            esac
            PIDOFCDPLAY=`echo $!`
            CDPLAY=1 
            #sleep 5 #socket is slow
            CDLASTTRACK=$CDCURTRACK ; CDREALTRACK=$CDCURTRACK ; let CDREALTRACK++
            CDINFO="CD > $CDREALTRACK" ; makeledstring CD $CDREALTRACK
            clear ; refresh
            sleep 2 #socket is slow
            echo 'cycle pause' | socat - $CDSOCKET ; fi
            if [ $CDPLAY -eq 2 ] ; then echo 'cycle pause'   | socat - $CDSOCKET ; CDPLAY=1 ; CDINFO="CD > $CDREALTRACK" ; fi ;;
    1)  if [ $HDPLAY -eq 0 ] ; then
            mpv --playlist-start=$HDCURTRACK --pause --input-ipc-server $HDSOCKET $HDPLAYLIST > /dev/null 2>&1 &
            PIDOFHDPLAY=`echo $!`
            PLAY=1  
            #sleep 5 #socket is slow
            if [ $PLAYMODE -eq 2 ] ; then
                HDREALTRACK=1 ; HDLASTTRACK=$HDCURTRACK
            else
                HDLASTTRACK=$HDCURTRACK ; HDREALTRACK=$HDCURTRACK ; let HDREALTRACK++
            fi
            HDINFO="HD > $HDREALTRACK" ; makeledstring HD $HDREALTRACK
            clear ; refresh
            sleep 2 #socket is slow
            echo 'cycle pause' | socat - $HDSOCKET ; HDPLAY=1 ; fi
            if [ $HDPLAY -eq 2 ] ; then echo 'cycle pause'   | socat - $HDSOCKET ; PLAY=1 ; HDPLAY=1 ; HDINFO="HD > $HDREALTRACK" ; fi ;;
    2)   if [ $FDPLAY -eq 0 ] && [ $FDAUDIOTRACKS -gt 0 ]  ; then
            mpv --playlist-start=$FDCURTRACK --pause --input-ipc-server $FDSOCKET $FDPLAYLIST > /dev/null 2>&1 &
            PIDOFFDPLAY=`echo $!`
            PLAY=1
            #sleep 5 #socket is slow
            FDLASTTRACK=$FDCURTRACK ; FDREALTRACK=$FDCURTRACK ; let FDREALTRACK++
            FDINFO="FD > $FDREALTRACK" ; makeledstring FD $FDREALTRACK
            clear ; refresh 
            sleep 2 #socket is slow
            echo 'cycle pause' | socat - $FDSOCKET ; FDPLAY=1 ; fi
        if [ $FDPLAY -eq 2 ] ; then echo 'cycle pause'   | socat - $FDSOCKET ; PLAY=1 ; FDPLAY=1 ; fi ;;
esac
sleep 0.5
setcdinfo
}

pausecd(){
    local input=$INPUT
    if [ $1 -eq 2 ] ; then let input-- ; fi

    case $input in
    0)  if [ $CDPLAY -eq 1 ] && [ $CDAUDIOTRACKS -gt 0 ] ; then echo 'cycle pause' | socat - $CDSOCKET ; CDPLAY=2 ; PLAY=2
        CDREALTRACK=$CDCURTRACK;let CDREALTRACK++
        CDINFO="CD I $CDREALTRACK"
        makeledstring CD $CDREALTRACK ; fi ;;
    1)  if [ $HDPLAY -eq 1 ] && [ $HDAUDIOTRACKS -gt 0 ] ; then echo 'cycle pause' | socat - $HDSOCKET ; HDPLAY=2 ; PLAY=2


if [ $PLAYMODE -eq 2 ] ; then
                HDREALTRACK=1 ; HDLASTTRACK=$HDCURTRACK
            else
                HDLASTTRACK=$HDCURTRACK ; HDREALTRACK=$HDCURTRACK ; let HDREALTRACK++
            fi


#        HDREALTRACK=$HDCURTRACK;let HDREALTRACK++
        HDINFO="HD I $HDREALTRACK"
        makeledstring HD $HDREALTRACK ; fi ;;
    2)  if [ $FDPLAY -eq 1 ] ; then echo 'cycle pause' | socat - $FDSOCKET ; FDPLAY=2 ; PLAY=2
        FDREALTRACK=$FDCURTRACK;let FDREALTRACK++
        FDINFO="FD I $input $FDREALTRACK"
        makeledstring FD $FDREALTRACK  ; fi ;;
    esac
}

stopcd(){
case $INPUT in
0)  echo 'quit' | socat - $CDSOCKET ; CDPLAY=0 ; rm $CDSOCKET
    CDINFO="CD $CDAUDIOTRACKS" ; makeledstring CD $CDAUDIOTRACKS
    CDREALTRACK=0 ; CDCURTRACK=0 ; CDLASTTRACK=0 ;;
1)  echo 'quit' | socat - $HDSOCKET ; HDPLAY=0 ; rm $HDSOCKET
    HDINFO="HD $HDAUDIOTRACKS" ; makeledstring HD $HDAUDIOTRACKS
    HDREALTRACK=0 ; HDCURTRACK=0 ; HDLASTTRACK=0 ;;
2)  echo 'quit' | socat - $FDSOCKET ; FDPLAY=0 ; rm $FDSOCKET
    FDINFO="FD $FDAUDIOTRACKS" ; makeledstring FD $FDAUDIOTRACKS
    FDREALTRACK=0 ; FDCURTRACK=0 ; FDLASTTRACK=0 ;;
esac ; setcdinfo
}

ejectcd(){
case $INPUT in
0)
    if [ $CDPLAY -ne 0 ] ; then
        stopcd;fi

    if [ $EJECT -eq 0 ] ; then # this is always 0, seteject not in use
        if [ $OD_TYPE -eq 10 ]  || [ $OD_TYPE -eq 3 ] ; then
            umount $CDMNT
            CDPLAY=0 ; PLAY=0
        fi
        sed -i -- '/^CDCURTRACK/d' $AUTOSAVE;echo "CDCURTRACK=0" >> $AUTOSAVE
        HDINFO="HD 0"
        eject
    else
        eject -t
    fi
    PLAY=0
    OD_TYPE=99
    COMMAND="eject cd"
;;
1)
    COMMAND="nothing to eject"
;;
2)
    if [ $FDPLAY -ne 0 ] ; then
        stopcd;fi

    if [ $EJECT -eq 0 ] ; then  # this is always 0, seteject not in use
        fdmount=`cat /proc/mounts | grep $FDMNT | wc -l`
        if [ $fdmount -eq 1 ] ; then
            sleep 1
            umount $FDMNT
            FDPLAY=0 ; FDINFO="FD 0"
            sed -i -- '/^FDCURTRACK/d' $AUTOSAVE;echo "FDCURTRACK=0" >> $AUTOSAVE
        fi
        # eject
#    else
        # eject -t
    fi
    PLAY=0
    COMMAND="eject fd"
;;
3)
    COMMAND="nothing to eject"
;;
esac
}

setcd(){
    # next / previous track
    # first do next /previous track, then ask the new tracknumber

    local cddacmd

    if [ $PLAY -ne 0 ] ; then
        if [ $KEY -eq 8 ] || [ $KEY -eq 118 ] ; then
            case $INPUT in
            0)  case $OD_TYPE in
                1|2)  let CDCURTRACK++ ;cddacmd='{ "command": ["set_property", "chapter", "'$CDCURTRACK'"] }';echo $cddacmd | socat - $CDSOCKET > /dev/null 2>&1 ;let CDREALTRACK++ ;;
                3|10) echo 'playlist-next' | socat - $CDSOCKET;let CDREALTRACK++ ;;
                esac
                if [ $CDREALTRACK -gt $CDAUDIOTRACKS ] ; then CDREALTRACK=$CDAUDIOTRACKS ; fi ;;
            1)  echo 'playlist-next' | socat - $HDSOCKET;let HDREALTRACK++
                if [ $HDREALTRACK -gt $HDAUDIOTRACKS ] ; then HDREALTRACK=$HDAUDIOTRACKS ; fi;;
            2)  echo 'playlist-next' | socat - $FDSOCKET;let FDREALTRACK++
                if [ $FDREALTRACK -gt $FDAUDIOTRACKS ] ; then FDREALTRACK=$FDAUDIOTRACKS ; fi;;
            esac
        fi

        if [ $KEY -eq 2 ] || [ $KEY -eq 119 ] ; then
            case $INPUT in
            0)  case $OD_TYPE in
                1|2)  let CDCURTRACK-- ;cddacmd='{ "command": ["set_property", "chapter", "'$CDCURTRACK'"] }';echo $cddacmd | socat - $CDSOCKET > /dev/null 2>&1 ;let CDREALTRACK-- ;;
                3|10) echo 'playlist-prev' | socat - $CDSOCKET;let CDREALTRACK-- ;;
                esac
                if [ $CDREALTRACK -eq 0 ] ; then CDREALTRACK=1 ; fi ;;
            1)  echo 'playlist-prev' | socat - $HDSOCKET;let HDREALTRACK--
                if [ $HDREALTRACK -eq 0 ] ; then HDREALTRACK=1 ; fi ;;
            2)  echo 'playlist-prev' | socat - $FDSOCKET;let FDREALTRACK--
                if [ $FDREALTRACK -eq 0 ] ; then FDREALTRACK=1 ; fi ;;
            esac
        fi

        sleep 0.7

        case $INPUT in
        0)  case $OD_TYPE in
            1|2)  CDCURTRACK=`echo '{ "command": ["get_property", "chapter"] }' | socat - $CDSOCKET | tr -dc '0-9'` ;;
            3|10) CDCURTRACK=`echo '{ "command": ["get_property", "playlist-pos"] }' | socat - $CDSOCKET | tr -dc '0-9'` ;;
            esac
            CDLASTTRACK=$CDCURTRACK ; setcdinfo
            if [ $CDPLAY -eq 1 ] ; then CDINFO="CD > $CDREALTRACK";makeledstring CD $CDREALTRACK;else CDINFO="CD I $CDREALTRACK";makeledstring CD $CDREALTRACK;fi;;
        1)  HDCURTRACK=`echo '{ "command": ["get_property", "playlist-pos"] }' | socat - $HDSOCKET | tr -dc '0-9'`
            HDLASTTRACK=$HDCURTRACK ; setcdinfo
            if [ $HDPLAY -eq 1 ] ; then HDINFO="HD > $HDREALTRACK";makeledstring HD $HDREALTRACK;else HDINFO="HD I $HDREALTRACK";makeledstring HD $HDREALTRACK;fi ;;
        2)  FDCURTRACK=`echo '{ "command": ["get_property", "playlist-pos"] }' | socat - $FDSOCKET | tr -dc '0-9'`
            FDLASTTRACK=$FDCURTRACK ; setcdinfo
            if [ $FDPLAY -eq 1 ] ; then FDINFO="FD > $FDREALTRACK";makeledstring FD $FDREALTRACK;else FDINFO="FD I $FDREALTRACK";makeledstring FD $FDREALTRACK;fi ;;
        esac
    fi
}

listbrowsecd(){
    case $INPUT in
    0) if [ $CDAUDIOTRACKS -eq 0 ] ; then echo "No playlist - press options again" ; return ; fi ;;
    1) if [ $HDAUDIOTRACKS -eq 0 ] ; then echo "No playlist - press options again" ; return ; fi ;;
    2) if [ $FDAUDIOTRACKS -eq 0 ] ; then echo "No playlist - press options again" ; return ; fi ;;
    3) echo "No options - press options again" ; return ;;
    esac

    local browseid1 ; local browseid2 ; local browseid3 ; local browseid4 ; local browseid5 ; local browseid6 ; local browseid7 ; local browseid8 ; local browseid9
    local playlist1 ; local playlist2 ; local playlist3 ; local playlist4 ; local playlist5 ; local playlist6 ; local playlist7 ; local playlist8 ; local playlist9
    local curtrack ; local playlist ; local audiotracks

    #case input....
    case $INPUT in
    0) curtrack=$CDCURTRACK;playlist=$CDPLAYLIST;audiotracks=$CDAUDIOTRACKS;mount=$CDMNT;;
    1) curtrack=$HDCURTRACK;playlist=$HDPLAYLIST;audiotracks=$HDAUDIOTRACKS;mount=$HDMNT;;
    2) curtrack=$FDCURTRACK;playlist=$FDPLAYLIST;audiotracks=$FDAUDIOTRACKS;mount=$FDMNT;;
    esac

    # calculate
    if [ $KEY -eq 5 ] || [ $KEY -eq 117 ] ; then
        browseid1=$((curtrack+1)) ; browseid2=$((browseid1+1)) ; browseid3=$((browseid2+1))
        browseid4=$((curtrack+4)) ; browseid5=$((curtrack+5)) ; browseid6=$((curtrack+6))
        browseid7=$((curtrack+7)) ; browseid8=$((curtrack+8)) ; browseid9=$((curtrack+9)) 
        BROWSEID=$curtrack
    else
        browseid1=$((BROWSEID+1)) ; browseid2=$((browseid1+1)) ; browseid3=$((browseid2+1))
        browseid4=$((browseid3+1)) ; browseid5=$((browseid4+1)) ; browseid6=$((browseid5+1))
        browseid7=$((browseid6+1)) ; browseid8=$((browseid7+1)) ; browseid9=$((browseid8+1))
    fi

    playlist1=`cat $playlist | awk 'NR=='$browseid1' {print;exit}'` ; setbrowsecdawk "${playlist1}" "${mount}" ; playlist1=$BROWSESTRING
    playlist2=`cat $playlist | awk 'NR=='$browseid2' {print;exit}'` ; setbrowsecdawk "${playlist2}" "${mount}" ; playlist2=$BROWSESTRING
    playlist3=`cat $playlist | awk 'NR=='$browseid3' {print;exit}'` ; setbrowsecdawk "${playlist3}" "${mount}" ; playlist3=$BROWSESTRING
    playlist4=`cat $playlist | awk 'NR=='$browseid4' {print;exit}'` ; setbrowsecdawk "${playlist4}" "${mount}" ; playlist4=$BROWSESTRING
    playlist5=`cat $playlist | awk 'NR=='$browseid5' {print;exit}'` ; setbrowsecdawk "${playlist5}" "${mount}" ; playlist5=$BROWSESTRING
    playlist6=`cat $playlist | awk 'NR=='$browseid6' {print;exit}'` ; setbrowsecdawk "${playlist6}" "${mount}" ; playlist6=$BROWSESTRING
    playlist7=`cat $playlist | awk 'NR=='$browseid7' {print;exit}'` ; setbrowsecdawk "${playlist7}" "${mount}" ; playlist7=$BROWSESTRING
    playlist8=`cat $playlist | awk 'NR=='$browseid8' {print;exit}'` ; setbrowsecdawk "${playlist8}" "${mount}" ; playlist8=$BROWSESTRING
    playlist9=`cat $playlist | awk 'NR=='$browseid9' {print;exit}'` ; setbrowsecdawk "${playlist9}" "${mount}" ; playlist9=$BROWSESTRING

    # Playmode
    case $PLAYMODE in
    0) PLAYMODEDISPLAY="ALL";;
    1) PLAYMODEDISPLAY="RANDOM";;
    2) PLAYMODEDISPLAY="ALBUM";;
    esac

    # print results
    echo "8 | UP      = select one track backward     PLAYMODE = $PLAYMODEDISPLAY"
    echo "4 | LEFT    = select ten tracks backward    ====================="
    echo "2 | DOWN    = select one track forward      - | VOL DOWN = all"
    echo "2 | RIGHT   = select ten tracks forward     + | VOL UP   = random"
    echo "5 | OPTIONS = return to main menu           E | MUTE     = album"
    echo
    echo "* | PLAY    = play selected nr $browseid1"
    echo

    if [ $browseid1 -eq 1 ] ; then  #echo "- - -$browseid1"
        echo -e  "\033[30;42m$playlist2\033[0;32m"
        echo "$playlist3" ; echo "$playlist4" ; echo "$playlist5" ; echo "$playlist6" ; echo "$playlist7" ; echo "$playlist8" ; echo "$playlist9" ; fi

 #   if [ $browseid1 -eq $audiotracks ] ; then
 #       echo "$playlist1" ; echo -e "\033[30;42m$playlist2\033[0;32m"
 #       echo "LAST TRACK IS SELECTED" ; fi

    if [ $browseid1 -gt 1 ] && [ $browseid1 -le $audiotracks ] ; then
        echo "$playlist1" ; echo -e "\033[30;42m$playlist2\033[0;32m"
        echo "$playlist3" ; echo "$playlist4" ; echo "$playlist5" ; echo "$playlist6" ; echo "$playlist7" ; echo "$playlist8" ; echo "$playlist9" ; fi
}

setbrowsecdawk(){
local eval playlist="$1"
local eval mnt="$2"
local mountnr=`echo $mnt | awk -F/ '{print NF-1}'`
local fields=`echo $playlist | awk -F/ '{print NF-1}'`
local printfields=$((fields-mountnr))
local cdda=1

if [ $PLAYMODE -eq 2 ] ; then printfields=1 ; fi

if [ $OD_TYPE -eq 1 ] ; then cdda=0 ; fi
if [ $OD_TYPE -eq 2 ] ; then cdda=0 ; fi

if [ $cdda -eq 1 ] || [ $INPUT -eq 1 ] || [ $INPUT -eq 2 ] ; then
    case $printfields in
    1) BROWSESTRING=`echo $playlist | rev | awk -F'/' '{print $1}' | rev`;;
    2) BROWSESTRING=`echo $playlist | rev | awk -F'/' '{print $1" # "$2}' | rev`;;
    3) BROWSESTRING=`echo $playlist | rev | awk -F'/' '{print $1" # "$2" # " $3}' | rev`;;
    4) BROWSESTRING=`echo $playlist | rev | awk -F'/' '{print $1" # "$2" # " $3" # "$4}' | rev`;;
    5) BROWSESTRING=`echo $playlist | rev | awk -F'/' '{print $1" # "$2" # " $3" # "$4" # "$5}' | rev`;;
    esac
else
    BROWSESTRING=$playlist
fi

BROWSESTRING=`echo $BROWSESTRING | cut -c -80`

}

setbrowsecd(){
    case $INPUT in
    0) if [ $CDAUDIOTRACKS -eq 0 ] ; then return ; fi ;;
    1) if [ $HDAUDIOTRACKS -eq 0 ] ; then return ; fi ;;
    2) if [ $FDAUDIOTRACKS -eq 0 ] ; then return ; fi ;;
    3) return ;;
    esac

    local alltracks

    case $INPUT in
        0) alltracks=$CDAUDIOTRACKS;;
        1) alltracks=$HDAUDIOTRACKS;;
        2) alltracks=$FDAUDIOTRACKS;;
    esac

    let alltracks--

    case $KEY in
        4|120) let BROWSEID=$BROWSEID-10 ;;
        8|118) let BROWSEID=$BROWSEID-1 ;;
        6|111) let BROWSEID=$BROWSEID+10 ;;
        2|119) let BROWSEID=$BROWSEID+1 ;;
        -|124)       PLAYMODE=0 ;; # ALL
        +|123)       PLAYMODE=1 ;; # RANDOM
        $ENTER|125)  PLAYMODE=2 ;; # ALBUM
    esac

    if [ $BROWSEID -lt 0 ] ; then BROWSEID=0 ; fi
    if [ $BROWSEID -ge $alltracks ] ; then BROWSEID=$alltracks ; fi

    #PLAYCD
    if [ "$KEY" == "*" ] ||  [ $KEY -eq 110 ] ; then
        stopcd ; sleep 0.5
        case $INPUT in
        0) CDCURTRACK=$BROWSEID;;
        1) HDCURTRACK=$BROWSEID;;
        2) FDCURTRACK=$BROWSEID;;
        esac
        COMMAND="play"; LIST="main" ; PLAY=1 ; playcd #; read -sN1 tmp
        #playcd ; PLAY=1 ; LIST="main" ; read -sN1 tmp # THIS GOES WRONG!
# if [ $PLAYMODE -eq 2 ] ; then HDCURTACK=0 ; fi

    else
        KEY=10000
    fi
}


#  O P T I C A L   D I S C    <<<---
################################################################
#  --->>>    I N T E R N E T   R A D I O

playradio(){
    if [ $PIDOFRADIO -eq 0 ] ; then
        eval "$RADIOEXE $RADIOLINK 2>/dev/null"
        PIDOFRADIO=`echo $!`
    else
        kill -CONT $PIDOFRADIO
    fi
}

setradio(){
    if [ $KEY -eq 8 ] || [ $KEY -eq 118 ] ; then
        let RADIOCOUNTER++ ; if [ $RADIOCOUNTER -eq 10 ] ; then RADIOCOUNTER=1 ; fi
    fi

    if [ $KEY -eq 2 ] || [ $KEY -eq 119 ] ; then
        let RADIOCOUNTER-- ; if [ $RADIOCOUNTER -eq 0 ] ; then RADIOCOUNTER=9 ; fi
    fi
    setradiostation

    makeledstring TU $RADIOCOUNTER

    kill -TERM $PIDOFRADIO
    eval "$RADIOEXE $RADIOLINK 2>/dev/null"  
    PIDOFRADIO=`echo $!`
}

setradiostation(){
case $RADIOCOUNTER in
1)RADIOLINK=$RA01LINK;RADIOINFO="$RADIOCOUNTER $RA01INFO";LEDRADIOINFO="$RA01INFO";RADIONAME="$RA01METANAME";RADIOPTY="$RA01METAPTY";;
2)RADIOLINK=$RA02LINK;RADIOINFO="$RADIOCOUNTER $RA02INFO";LEDRADIOINFO="$RA02INFO";RADIONAME="$RA02METANAME";RADIOPTY="$RA02METAPTY";;
3)RADIOLINK=$RA03LINK;RADIOINFO="$RADIOCOUNTER $RA03INFO";LEDRADIOINFO="$RA03INFO";RADIONAME="$RA03METANAME";RADIOPTY="$RA03METAPTY";;
4)RADIOLINK=$RA04LINK;RADIOINFO="$RADIOCOUNTER $RA04INFO";LEDRADIOINFO="$RA04INFO";RADIONAME="$RA04METANAME";RADIOPTY="$RA04METAPTY";;
5)RADIOLINK=$RA05LINK;RADIOINFO="$RADIOCOUNTER $RA05INFO";LEDRADIOINFO="$RA05INFO";RADIONAME="$RA05METANAME";RADIOPTY="$RA05METAPTY";;
6)RADIOLINK=$RA06LINK;RADIOINFO="$RADIOCOUNTER $RA06INFO";LEDRADIOINFO="$RA06INFO";RADIONAME="$RA06METANAME";RADIOPTY="$RA06METAPTY";;
7)RADIOLINK=$RA07LINK;RADIOINFO="$RADIOCOUNTER $RA07INFO";LEDRADIOINFO="$RA07INFO";RADIONAME="$RA07METANAME";RADIOPTY="$RA07METAPTY";;
8)RADIOLINK=$RA08LINK;RADIOINFO="$RADIOCOUNTER $RA08INFO";LEDRADIOINFO="$RA08INFO";RADIONAME="$RA08METANAME";RADIOPTY="$RA08METAPTY";;
9)RADIOLINK=$RA09LINK;RADIOINFO="$RADIOCOUNTER $RA09INFO";LEDRADIOINFO="$RA09INFO";RADIONAME="$RA09METANAME";RADIOPTY="$RA09METAPTY";;
esac
}


#  I N T E R N E T   R A D I O    <<<---
################################################################
#  --->>>    S U B M E N U S

listrecordmenu(){
    echo "==================================================="
    echo 
    echo "m = record from minidisc l = record from line"
    echo ""
    echo "==================================================="
}

#   S U B M E N U S    <<<---
################################################################
#  --->>>    M A I N   M E N U

listprog(){
    echo -e "\033[03;01;36m${PROGSHOWNAME} / ${PROGDESCRIPTION} / ${PROGVERSION}\033[0m"
    echo
}

listbiginfo(){
    if [ $TONLI -eq 0 ] ; then
        case $INPUT in
        0)
            case $OD_TYPE in
                1|2|3|10)
                    figlet -f ANSI\ Regular "$CDINFO"
                    ;;
                *)  figlet -f ANSI\ Regular "NO DATA"
                    ;;
                esac
                ;;
        1)
            figlet -f ANSI\ Regular "$HDINFO" ;;
        2)
            figlet -f ANSI\ Regular "$FDINFO" ;;
        3)
            figlet -f ANSI\ Regular "$RADIOINFO" ;;
        esac
    else
        figlet -f ANSI\ Regular "$AUXM"
    fi
}

setinput(){
    let INPUT++ ; if [ $INPUT -eq 4 ] ; then INPUT=0 ; fi
    case $INPUT in
        0)  if [ $PLAY -ne 0 ] ; then PLAY=0 ; fi
            if [ $CDPLAY -eq 2 ] ; then PLAY=2 ; fi
            kill -STOP $PIDOFRADIO
            ;;
        1)  if [ $PLAY -ne 0 ] ; then PLAY=0 ; fi
            if [ $CDPLAY -eq 1 ] ; then pausecd 2; fi
            if [ $HDPLAY -eq 2 ] ; then PLAY=2 ; fi
            ;;
        2)  if [ $PLAY -ne 0 ] ; then PLAY=0 ; fi
            if [ $HDPLAY -eq 1 ] ; then pausecd 2; fi
            if [ $FDPLAY -eq 2 ] ; then PLAY=2 ; fi
            ;;
        3)  if [ $PLAY -ne 0 ] ; then PLAY=0 ; fi
            if [ $FDPLAY -eq 1 ] ; then pausecd 2; fi
            playradio
            ;;
    esac
}

setsource(){
    let SOURCE++ ; if [ $SOURCE -eq 4 ] ; then SOURCE=0 ; fi
}

setrecord(){
    let RECORD++ ; if [ $RECORD -eq 2 ] ; then RECORD=0 ; fi
}

seteject(){
    let EJECT++ ; if [ $EJECT -eq 2 ] ; then EJECT=0 ; fi
}

setdisplay(){
    let DISPLAY++ ; if [ $DISPLAY -eq 2 ] ; then DISPLAY=0 ; fi
}

listmainmenu(){
#    echo "==================== main menu ===================="
#    echo
#    echo "a = status || e = eject || c = close || t = cd-text"
#    echo "c = copy || b = burn || p = rip || m = record"
#    echo "d = edit || o = combine || v = devide || r = erase"
#    echo
#    echo "---------------------------------------------------"
#    echo
#    echo "s = settings || x = mixer || q = quit"\033[30;42m CD     \033[0;32m
#    echo \033[30;43m ANALOG \033[0;32m
#    echo "==================================================="
#    echo
    case $PLAY in
        0) SHOWPLAY=' STOP' ; LEDCONTROL='yellowon&' ; 
            if [ $INPUT -eq 3 ] ; then LEDCONTROL='greenon&' ; fi ;;
        1) SHOWPLAY='\033[30;42m PLAY     \033[0;32m' ; LEDCONTROL='greenon&';;
        2) SHOWPLAY=' PAUSE'
            if [ $LASTPLAY -eq 0 ] && [ $INPUT -ne 0 ]; then LEDCONTROL='yellowblink&'
                else LEDCONTROL='greenblink&' ; fi 
            if [ $LASTPLAY -eq 1 ] ; then LEDCONTROL='greenblink&' ; fi ;;
    esac

    case $RECORD in
        0) SHOWRECORD=' RECORD' ;;
        1) SHOWRECORD='\033[30;41m RECORD   \033[0;32m'
            if [ $PLAY -eq 0 ] || [ $PLAY -eq 2 ] ; then LEDCONTROL='redblink&' 
            else LEDCONTROL='redon&' ; fi ;;
    esac

    case $SOURCE in
        0) SOURCECD='\033[30;43mCOMPACT DISC\033[0;32m' ; SOURCEOI='OPTICAL IN'
            SOURCEAI='ANALOG IN' ; SOURCEAN=' ANALOG LP' ;;
        1) SOURCEOI='\033[30;43mOPTICAL IN\033[0;32m' ; SOURCECD='COMPACT DISC'
            SOURCEAI='ANALOG IN' ; SOURCEAN=' ANALOG LP' ;;
        2) SOURCEAI='\033[30;43mANALOG IN\033[0;32m' ; SOURCEOI='OPTICAL IN'
            SOURCECD='COMPACT DISC' ; SOURCEAN=' ANALOG LP' ;;
        3) SOURCEAN='\033[30;43m ANALOG LP\033[0;32m' ; SOURCEOI='OPTICAL IN'
            SOURCEAI='ANALOG IN' ; SOURCECD='COMPACT DISC' ;;
    esac

    case $INPUT in
        0) SHOWCD='\033[30;42m CD       \033[0;32m' ; SHOWHD=' HD' ; SHOWCM=' FD' ; SHOWRA=' RADIO' ;;
        1) SHOWHD='\033[30;42m HD       \033[0;32m' ; SHOWCD=' CD' ; SHOWCM=' FD' ; SHOWRA=' RADIO' ;;
        2) SHOWCM='\033[30;42m FD       \033[0;32m' ; SHOWHD=' HD' ; SHOWCD=' FD' ; SHOWRA=' RADIO' ;;
        3) SHOWRA='\033[30;42m RADIO    \033[0;32m' ; SHOWHD=' HD' ; SHOWCM=' FD' ; SHOWCD=' CD' ;;
    esac

    echo -e "N = numlock         |  / = record       |  * = play         | $SHOWPLAY"
    echo -e "7 = eject           |  8 = up           |  9 = pause        | $SHOWRECORD" 
    echo -e "4 = display         |  5 = options      |  6 = stop         | $SHOWCD"
    echo -e "1 = scroll          |  2 = down         |  3 = input        | $SHOWHD" 
    echo -e "E = mute            |  0 = quit         |  . = source       | $SHOWCM"
    echo -e "Volume Control      |  - = up           |  + = down         | $SHOWRA"
    #echo -e "COMPACT DISC        |  OPTICAL IN       |  ANALOG IN        | "
    echo -e "$SOURCECD        |  $SOURCEOI       |  $SOURCEAI        | $SOURCEAN"
## tmpdebug
    if [ "$DEVTTY" -eq "0" ] ; then ledcontrol ; leddisplay ; fi
}

ledcontrol(){
    if [ $PIDOFLEDCONTROL -ne 0 ] ; then kill -TERM $PIDOFLEDCONTROL ; fi
    eval "ledcontrol.py $LEDCONTROL"
    PIDOFLEDCONTROL=`echo $!`
}

leddisplay(){
    local leddisplaydata

    case $INPUT in
    0) leddisplaydata=$D4CDINFO;;
    1) leddisplaydata=$D4HDINFO;;
    2) leddisplaydata=$D4FDINFO;;
    3) leddisplaydata=$D4RADIOINFO;;
    esac

    eval "leddisplay.py $DISPLAYBRIGHTNESS $leddisplaydata"
}

#listcommand(){
#    echo -e "COMMAND = $COMMAND | KEY = $KEY | VOLUME $AUDIOVOLUME | BRIGHTNESS $DISPLAYBRIGHTNESS" 
#     echo -e
#     echo -e "COMMAND = $COMMAND | KEY = $KEY | VOLUME $AUDIOVOLUME | BRIGHTNESS $DISPLAYBRIGHTNESS" 
#     echo -e
# temp in list odstatus()
#}

listoptions(){
    case $INPUT in
        0)
            case $PLAYMODE in
                0) CDPLAYLIST=$CDFILEPLAYLIST ; CDAUDIOTRACKS=$CDFILEAUDIOTRACKS ;;
                1) CDPLAYLIST=$CDRANDPLAYLIST ; CDCURTRACK=0 ;;
                2) CDPLAYLIST=$CDPLAYPLAYLIST ; CDCURTRACK=0 ;;
            esac
            ;;
        1)
            case $PLAYMODE in
                0) HDPLAYLIST=$HDFILEPLAYLIST ; HDAUDIOTRACKS=$HDFILEAUDIOTRACKS ;;
                1) HDPLAYLIST=$HDRANDPLAYLIST ;; #; HDCURTRACK=0 ;;
                2) HDPLAYLIST=$HDPLAYPLAYLIST ;; #; HDCURTRACK=0 ;;
            esac
            ;;
        2)
            case $PLAYMODE in
                0) FDPLAYLIST=$FDFILEPLAYLIST ; FDAUDIOTRACKS=$FDFILEAUDIOTRACKS ;;
                1) FDPLAYLIST=$FDRANDPLAYLIST ; FDCURTRACK=0 ;;
                2) FDPLAYLIST=$FDPLAYPLAYLIST ; FDCURTRACK=0 ;;
            esac
            ;;
    esac

    listbrowsecd
}

refresh(){
    case $LIST in
        main)
            listprog; listodstatus #; echo -en '\033[32m'
            listbiginfo
            listmainmenu
            #listcommand
            listinfo
            ;;
        record)
            listprog; listodstatus #; echo -en '\033[32m'; listinfo
            listrecordmenu
            ;;
        options)
            listprog; listodstatus #; echo -en '\033[32m'; listcdinfo
            listoptions
            ;;
    esac
}


tmpdebug(){
#    echo -e "OD=$OD_TYPE | KEY=$KEY | COMMAND=$COMMAND | VOLUME $AUDIOVOLUME"
#    echo -e "MAINLOOPS=$mainteller | READLOOPS=$readteller $TMP_DEBUG2"
echo "FDAUDIOTRACKS = $FDAUDIOTRACKS FDPLAY = $FDPLAY PLAY = $PLAY"

     #echo -e '\033[0m'
}

## MAIN (THE REAL ONE :-)
#clear
echo "file = $PROGFILENAME | version = $PROGVERSION"
echo "$PROGDESCRIPTION"
echo "=================================="

declare -i RC
tput civis

setradiostation
makeledstring TU $RADIOCOUNTER


if [ "$DEVTTY" -eq "1" ] ; then read -sN1 -t $PAUS temp;fi

until [ $MAINLOOP -eq 0 ] ; do
    clear
    let mainteller++
    refresh
    READLOOP=1

    until [ $READLOOP -eq 0 ] ; do
        let readteller++
        readKey;readIrkey
        if [ $KEYRC -eq 0 ] || [ $IRKEYRC -eq 0 ] ; then    ## $KEYRC = 0 when key is pressed.
            READLOOP=0
        else
            readodstatus
            # If media changed...then
            if [ $OD_MEDIA_STATUS -ne $LAST_OD_MEDIA_STATUS ] ; then #CDCOUNTER=0 ; CDSELECT=0
                LAST_OD_MEDIA_STATUS=$OD_MEDIA_STATUS
                if [ $OD_MEDIA_STATUS -eq 0 ] ; then
                    LIST="main"; clear;refresh; readodinfo
                fi
                READLOOP=0
            fi

            ## radio clock and rss nos news
            if [ $INPUT -eq 3 ] ; then RAHOUR="`date -u +%H`" ; RAMINUTE="`date +%M`"
                if [ $RAMINUTE != $RACLOCK ] ; then echo -e "\033[22;01H\033[0;32mTime    = $RAHOUR:$RAMINUTE GMT"
#                    rssfeed=`w3m -dump  http://feeds.nos.nl/nosnieuwsalgemeen |grep CDATA|grep title|head -n 2|tail -n 1|cut -c 23-|rev|cut -c 12-|rev |tr -d '\n'`
#                    rssfeedcnt=`echo $rssfeed|wc -c` ; if 
                    echo -ne "\033[24;01H                                                                                "
                    echo -ne "\033[24;01H`w3m -dump  http://feeds.nos.nl/nosnieuwsalgemeen|grep CDATA|grep title|head -n 2|tail -n 1|cut -c 23-|rev|cut -c 12-|rev|cut -c -80|tr -d '\n'`"
                    RACLOCK="$RAMINUTE" ; fi
            else
                RACLOCK=0
            fi
            # If CD plays next track
            if [ $CDCURTRACK -gt 0 ] && [ $CDCURTRACK -ne $CDLASTTRACK ] && [ $INPUT -eq 0 ] ; then CDLASTTRACK=$CDCURTRACK ; let CDREALTRACK++ ; BROWSEID=$CDCURTRACK
                if [ "$LIST" != "options" ] ; then
                    echo -e "\033[04;01H" ; figlet -f ANSI\ Regular "                                               |"
                    echo -e "\033[04;01H" ; figlet -f ANSI\ Regular "CD > ${CDREALTRACK}"
                else
                    echo -e "\033[04;01H\033[0;32m                                                                             "
                    echo -e "\033[05;01H\033[0;32mCD > $CDREALTRACK"
                fi
                sleep 1; setcdinfo
                if [ "$LIST" != "options" ] ; then
                    echo -e "\033[20;01H\033[0;32m                                                                             "
                    case $OD_TYPE in
                    1|2)  echo -e "\033[20;01H\033[0;32mVolume = $CD_PLAY_TIME";;
                    3|10) echo -e "\033[20;01H\033[0;32mVolume = $CDVOLUME";;
                    esac
                    echo -e "\033[21;01H\033[0;32m                                                                             "
                    echo -e "\033[21;01H\033[0;32mArtist = $CDPERFORMER"
                    echo -e "\033[22;01H\033[0;32m                                                                             "
                    echo -e "\033[22;01H\033[0;32mAlbum  = $CDALBUMTITLE"
                    echo -e "\033[23;01H\033[0;32m                                                                             "
                    echo -e "\033[23;01H\033[0;32mSong   = $CDTRACKTITLE"
                fi
                CDINFO="CD > $CDREALTRACK";makeledstring CD $CDREALTRACK
                if [ "$DEVTTY" -eq "0" ] ; then leddisplay ; fi
            fi
            # if HD plays next track
            if [ $HDCURTRACK -gt 0 ] && [ $HDCURTRACK -ne $HDLASTTRACK ] && [ $INPUT -eq 1 ] ; then HDLASTTRACK=$HDCURTRACK ; let HDREALTRACK++ ; BROWSEID=$HDCURTRACK
                if [ "$LIST" != "options" ] ; then
                    echo -e "\033[04;01H" ; figlet -f ANSI\ Regular "                                               |"
                    echo -e "\033[04;01H" ; figlet -f ANSI\ Regular "HD > ${HDREALTRACK}"
                else
                    echo -e "\033[04;01H\033[0;32m                                                                             "
                    echo -e "\033[05;01H\033[0;32mHD > $HDREALTRACK"
                fi
                sleep 1 ; setcdinfo
                if [ "$LIST" != "options" ] ; then
                    echo -e "\033[20;01H\033[0;32m                                                                             "
                    echo -e "\033[20;01H\033[0;32mVolume = $HDMNT"
                    echo -e "\033[21;01H\033[0;32m                                                                             "
                    echo -e "\033[21;01H\033[0;32mArtist = $HDPERFORMER"
                    echo -e "\033[22;01H\033[0;32m                                                                             "
                    echo -e "\033[22;01H\033[0;32mAlbum  = $HDALBUMTITLE"
                    echo -e "\033[23;01H\033[0;32m                                                                             "
                    echo -e "\033[23;01H\033[0;32mSong   = $HDTRACKTITLE"
                fi
                HDINFO="HD > $HDREALTRACK";makeledstring HD $HDREALTRACK
                if [ "$DEVTTY" -eq "0" ] ; then leddisplay ; fi
            fi
            # if FD plays next track
            if [ $FDCURTRACK -gt 0 ] && [ $FDCURTRACK -ne $FDLASTTRACK ] && [ $INPUT -eq 2 ] ; then FDLASTTRACK=$FDCURTRACK ; let FDREALTRACK++ ; BROWSEID=$FDCURTRACK
                if [ "$LIST" != "options" ] ; then
                    echo -e "\033[04;01H" ; figlet -f ANSI\ Regular "                                               |"
                    echo -e "\033[04;01H" ; figlet -f ANSI\ Regular "FD > ${FDREALTRACK}"
                else
                    echo -e "\033[04;01H\033[0;32m                                                                             "
                    echo -e "\033[05;01H\033[0;32mFD > $FDREALTRACK"
                fi
                sleep 1; setcdinfo
                if [ "$LIST" != "options" ] ; then
                    echo -e "\033[20;01H\033[0;32m                                                                             "
                    echo -e "\033[20;01H\033[0;32mVolume = $FDMNT"
                    echo -e "\033[21;01H\033[0;32m                                                                             "
                    echo -e "\033[21;01H\033[0;32mArtist = $FDPERFORMER"
                    echo -e "\033[22;01H\033[0;32m                                                                             "
                    echo -e "\033[22;01H\033[0;32mAlbum  = $FDALBUMTITLE"
                    echo -e "\033[23;01H\033[0;32m                                                                             "
                    echo -e "\033[23;01H\033[0;32mSong   = $FDTRACKTITLE"
                fi
                FDINFO="FD > $FDREALTRACK";makeledstring FD $FDREALTRACK
                if [ "$DEVTTY" -eq "0" ] ; then leddisplay ; fi
            fi
        fi
    done  # end readloop

        case $KEY in
            $END)
                COMMAND="quit"
                doHUP ;;
            0|127) #if [ "$LIST" != "options" ] ; then
                COMMAND="power"
                doKill
                if [ "$DEVTTY" -eq "0" ] ; then read -sN1 -t 3 temp;sudo /sbin/poweroff;else exit 0;fi
                #fi
                 ;;
            1|116) if [ "$LIST" != "options" ] ; then
                COMMAND="scroll"
                if [ $OD_TYPE = 2 ] ;then
                    LIST="cdtext"
                else
                    LIST="main"
                fi
                fi ;;
            2|119) if [ "$LIST" != "options" ] ; then
                    LIST="main"; #updown
                    if  [ $INPUT -ne 3 ] ; then setcd ; fi
                    if  [ $INPUT -eq 3 ] ; then setradio ; fi
                else
                    LIST="options" ; setbrowsecd
                fi ; COMMAND="down";;
            3|115) if [ "$LIST" != "options" ] ; then
                COMMAND="input"; LIST="main";
                if [ $RECORD -ne 1 ] ; then setinput ; fi
                fi ;;
            4|120) if [ "$LIST" != "options" ] ; then
                    LIST="main";COMMAND="display"
                    if [ $INPUT -eq 3 ] ; then
                        eval "leddisplay.py $DISPLAYBRIGHTNESS $LEDRADIOINFO" ; sleep 3 ; fi
                    else
                        LIST="options" ; setbrowsecd
                   fi ;;
            5|117) if [ "$LIST" != "options" ] ; then
                LIST="options"
                else
                LIST="main"
                fi ; COMMAND="options";;
            6|111) if [ "$LIST" != "options" ] ; then
                    LIST="main" ; PLAY=0 ; if [ $RECORD -eq 1 ] ; then RECORD=0 ; fi
                    if  [ $INPUT -ne 3 ] ; then stopcd ; fi
                else
                    LIST="options" ; setbrowsecd
                fi ; COMMAND="stop" ;;
            7|114) if [ "$LIST" != "options" ] ; then
                    #COMMAND="eject cd" # set in ejectcd(), $PLAY idem
                    ejectcd
                    LIST="main"
                fi ;;
            8|118) if [ "$LIST" != "options" ] ; then
                LIST="main"; #updown
                    if  [ $INPUT -ne 3 ] ; then setcd ; fi
                    if  [ $INPUT -eq 3 ] ; then setradio ; fi
                else
                    LIST="options"; setbrowsecd
                fi ; COMMAND="up";;
            9|112) if [ "$LIST" != "options" ] ; then
                COMMAND="pause"; LIST="main" ; if [ $PLAY -ne 2 ] ; then LASTPLAY=$PLAY ; fi ; PLAY=2 #is not set in function
                    if  [ $INPUT -ne 3 ] ; then pausecd 1; fi
                fi ;;
            /|113) if [ "$LIST" != "options" ] ; then
                COMMAND="record" ; LIST="main" ; if [ $PLAY -ne 0 ] ; then PLAY=0 ; fi ; setrecord
                fi ;;
            '*'|110) if [ "$LIST" != "options" ] ; then
                COMMAND="play"; LIST="main" ; PLAY=1 #is set in function
                    if [ $INPUT -ne 3 ] ; then playcd ; fi
                else
                    LIST="options" ; setbrowsecd
                fi ;;
            .|126) if [ "$LIST" != "options" ] ; then
                COMMAND="source"; LIST="main" 
                if [ $RECORD -ne 1 ] ; then setsource ; fi
                fi ;;
            +|123) if [ "$LIST" != "options" ] ; then
                LIST="main" ; amixer set Master 13%+ > /dev/null 2>&1
                    AUDIOVOLUME=`amixer get Master |grep Front|grep Left|grep -v channels | awk '{print $5 $6}'` ##|cut -c 2-|cut -c -2`
                else
                    LIST="options"; setbrowsecd
                fi
                COMMAND="volume up"; ;;
            -|124) if [ "$LIST" != "options" ] ; then
                LIST="main" ; amixer set Master 13%- > /dev/null 2>&1
                    AUDIOVOLUME=`amixer get Master |grep Front|grep Left|grep -v channels | awk '{print $5 $6}'` ## |cut -c 2-|cut -c -2`
                else
                    LIST="options"; setbrowsecd
                fi
                COMMAND="volume down" ;;
        	$ENTER|125) if [ "$LIST" != "options" ] ; then
                LIST="main"; amixer set Master toggle > /dev/null 2>&1
                    AUDIOVOLUME=`amixer get Master |grep Front|grep Left|grep -v channels | awk '{print $5 $6}'`
                else
                    LIST="options"; setbrowsecd
                fi
                COMMAND="mute" ;;
            201) if [ "$LIST" != "options" ] ; then
                COMMAND="loudness"; LIST="main"; ssh operator@eemnes "echo 201 > /dev/shm/unixrecorderpipe"
                fi ;;
            202) if [ "$LIST" != "options" ] ; then
                COMMAND="AUX SELECT to 1"; LIST="main"; ssh operator@eemnes "echo 202 > /dev/shm/unixrecorderpipe"
                fi ;;
            203) if [ "$LIST" != "options" ] ; then
                COMMAND="TV AV"; LIST="main"; ssh operator@eemnes "echo 203 > /dev/shm/unixrecorderpipe"
                fi ;;
            204) if [ "$LIST" != "options" ] ; then
                COMMAND="RCV FUNCTION"; LIST="main"; ssh operator@eemnes "echo 204 > /dev/shm/unixrecorderpipe"
                fi ;;
            205) if [ "$LIST" != "options" ] ; then COMMAND="BRIGHTNESS DOWN"; LIST="main"; setdisplaybrightness
#                COMMAND="RVC VOL DOWN"; LIST="main"; ssh operator@eemnes "echo 205 > /dev/shm/unixrecorderpipe"
                fi ;;
            206) if [ "$LIST" != "options" ] ; then COMMAND="BRIGHTNESS UP"; LIST="main"; setdisplaybrightness
 #               COMMAND="RCV VOL UP"; LIST="main"; ssh operator@eemnes "echo 206 > /dev/shm/unixrecorderpipe"
                fi ;;
#            301) if [ "$LIST" != "options" ] ; then
#                COMMAND="tonliEEN"; LIST="main"; TONLI=0 ; AUXM=""
#                fi ;;
#            302) if [ "$LIST" != "options" ] ; then
#                COMMAND="tonli2"; LIST="main"; TONLI=1 ; AUXM="LD"
#                fi ;;
#            303) if [ "$LIST" != "options" ] ; then
#                COMMAND="tonli3"; LIST="main"; TONLI=1 ; AUXM="TU"
#                fi ;;
#            304) if [ "$LIST" != "options" ] ; then
#                COMMAND="tonliVIER"; LIST="main"; TONLI=1 ; AUXM="CD"
#                fi ;;
#            305) if [ "$LIST" != "options" ] ; then
#                COMMAND="tonliVIJF"; LIST="main"; TONLI=1 ; AUXM="MD"
#                fi ;;
#            306) if [ "$LIST" != "options" ] ; then
#                COMMAND="tonli6"; LIST="main"; TONLI=1 ; AUXM="PC"
#                fi ;;
#            307) if [ "$LIST" != "options" ] ; then
#                COMMAND="tonli7"; LIST="main"; TONLI=1 ; AUXM="DVD"
#                fi ;;
#            308) if [ "$LIST" != "options" ] ; then
#                COMMAND="tonli8"; LIST="main"; TONLI=1 ; AUXM="RCV"
#                fi ;;

        esac
#KEY=""
KEYRC=1
IRKEYRC=1
done # end mainloop

# T O   D O   L I S T
#
# PTS client
# CU-XR009 (op logitech AB, geen coding here)
# Blink Timer (e.g. Volume, mute)
# Display / info / aux screens (figlet for fonts) eg figlet -f ANSI\ Regular "CD > 1234567890"
# mediaDB (sglite)

#fonts ANSI\ Regular Bigfig

#unixrecorder.sh souns.sh figlet toilet en ANSI\ Regular

#
# LED
# cd hd fd = geel / play = groen / pause = geel/groen knipper
# radio = groen / pause = geel/groen knipper / play = geel
# record/pause = rood/geel knipper
# play/pause = geel/groen knipper
#
# # # # # # # # # #
#
# D O N E
#
# IR server (via ssh)
# tuner-  RCVR loudness 201 | tuner+   AUX1 (tonli)  202
# ------------------------------------------------------
# tape <  TV av         203 | tape >   RCVR function 204
# ------------------------------------------------------
# tape << RCVR vol-     205 | tape >>  RCVR vol+     206
