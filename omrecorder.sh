#!/bin/bash
##
PROGVERSION=2021121402
##
PROGFILENAME=omrecorder.sh
##
PROGNAME=omrecorder
##
PROGDESCRIPTION="versatile cdda & md recorder"
#"versatile optical & magnetic disc recorder" # "record from digital input to media"
##
PROGAUTHOR="dlkvk"
## 
## Notes
##
## 2021022801 start writing code on unixrecorder
## 2021092401 omrecorder is an extention to unixrecorder
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
declare PAUSE=$1
if [ -z $1 ] ; then PAUSE=0 ; else PAUSE=$1 ; fi

## SOURCES
source /usr/local/lib/specialkeys.sh


## VARS AND INIT
declare PROGSHOWNAME="K E L E C T R O N I C"

devtty=`tty | grep tty`
if [ -z "$devtty" ] ; then  declare -ir DEVTTY=1
else declare -ir DEVTTY=0 ; fi

declare WORKDIR=/home/public/media/misc/omrecorder
declare MUSICDIR=/home/public/media/audio
declare MP3DIR=/home/public/media/misc/audioMP3
declare KEY=0
declare MAINLOOP=1
declare COMMAND="waiting your command"
declare LIST="main"
declare -r TMPDIR="/dev/shm"
declare -r CDDATAFILE="$TMPDIR/omrecordercddata"
declare CDDEV="/dev/sr0"
declare -i OD_MEDIA_STATUS=0
declare OD_TYPE=99 # 1=cd-audio 2=cd-text 5=blank 6= unknown cd 99=no cdda
declare OD_INFO="NO DATA"
declare CDTRACKS=0
declare CDTOC=cdtoc.txt
declare MDPLAYLIST=mdplay.lst
declare MDTITLELIST=mdtitle.lst
declare MDTRACKLIST=mdtrack.lst
declare CDJC=jewelcase.txt

## FUNCTIONS

## internal functions

doKill(){
    echo "0-0-0-0-0-0-0-0-0-0-0-0-"
    fortune bofh-excuses
    echo "0-0-0-0-0-0-0-0-0-0-0-0-"
    todo
    echo bye
    if [ -e "$CDDATAFILE" ] ; then rm $CDDATAFILE ; fi
}

doHUP(){
    doKill
    exit 0
}

trap doHUP SIGINT SIGTERM

readKey(){
    unset K1 K2 K3 K4 K5
    read -s -N1 #-p "Press a key: "
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

# MENU ITEM P - CLOSE CD TRAY / GET CD STATUS
# O P T I C A L   D I S C  --->>>
readodstatus(){
    local rc=0
    local titlecount=0
    local cdrstatus=0
    OD_TYPE=99

    if [ -e "$CDDATAFILE" ] ; then rm $CDDATAFILE ; fi
    if [ -e "$CDDEV" ] ; then
        OD_MEDIA_STATUS=`udevadm info -q property /dev/cdrom|grep ID_CDROM_MEDIA > /dev/null;echo $?` ; else
        OD_MEDIA_STATUS=1 ; fi # not only the disk is missing, the drive itself to. We let this as is. 
    if [ $OD_MEDIA_STATUS -eq 0 ] ; then    #there is an OD
        rc=`udevadm info -q property /dev/cdrom|grep ID_CDROM_MEDIA_CD > /dev/null;echo $?`
        if [ $rc -eq 0 ] ; then        # return value 0 means compact disc
            CDTRACKS=`udevadm info -q property /dev/cdrom|grep ID_CDROM_MEDIA|grep AUDIO|sed 's/[^0-9]*//g'`
            if [ $CDTRACKS -gt 0 ] ; then     # this track count is audio tracks only
                OD_TYPE=1 # cdda no text
                cd-info --dvd > $CDDATAFILE
                chown .operators $CDDATAFILE
                OD_INFO="CD AUDIO | $CDTRACKS TR"
                titlecount=`cat $CDDATAFILE | grep 'TITLE' | wc -l`
                if [ $titlecount -gt 0 ] ; then OD_TYPE=2 # cdda cd-text
                OD_INFO="CD TEXT | $CDTRACKS TR" ; fi
            fi
            if [ $OD_TYPE -eq 99 ] ; then
                cdrstatus=`udevadm info -q property /dev/cdrom | grep 'ID_CDROM_MEDIA_STATE=blank' > /dev/null;echo $?`
                if [ $cdrstatus -eq 0 ] ; then OD_INFO="BLANK CD" ; OD_TYPE=5 ; else OD_INFO="UNKNOWN CD" ; OD_TYPE=6 ; fi
            fi
        else
            OD_TYPE=99
            OD_INFO="NO CDDA"
        fi
    fi
}

# MENU ITEM C - RIP MD
ripmd(){
    local duration ; local templocal ; local ripdev
    local yn ; local pidofarecord ; local lock=0 ; local rc1=1 ; local rc2=1

    setstatus

    rc1=`lsusb|grep CM106 > /dev/null ; echo $?`
    if [ $rc1 -eq 0 ] ; then rc2=`amixer -c 1 scontrols | grep IEC958 > /dev/null ; echo $?` ; fi
#    if [ $rc2 -eq 1 ] ; then echo "No optical in device found.";echo;pak;return;fi

    # no external soundcard, using internal line in analog
#    if [ $rc1 -eq 1 ] ; then
#        klm
#    fi

    # external soundcard found and hads optical in
    if [ $rc2 -eq 0 ] ; then 
        #ripdev="arecord --duration=$duration --quiet --vumeter=stereo --device iec958:CARD=Device,DEV=0 --format cd --file-type wav local/minidisc.wav"
        ripdev="iec958:CARD=Device,DEV=0"
    else
        echo "No optical in device found.";echo;pak;return
    fi

    while true ; do
        setstatus
        echo -e "\033[05;01H1. Test MD - Escape = STOP"
        echo "2. Rip MD"
#        echo "3. Set Input"
        echo "0. Return to menu"
        readKey
        echo -e "\033[08;01H   "
        case $KEY in
            1)
                echo ; echo ; echo .
                arecord --quiet --vumeter=stereo --device iec958:CARD=Device,DEV=0 -f cd | aplay --quiet -D hw:1 &
                pidofarecord=`echo $!` ; lock=1 ;;
            2) 
                while true ; do
                    read -p  "Enter duration of recording: " duration
                    case $duration in
                        [1-8]*)
                            while true ; do
                                read -N1 -p  "Yes for record $duration minutes, No for break: " yn
                                case $yn in
                                    [Yy]* ) if [ -e minidisc.wav ] ; then mv minidisc.wav minidisc.wav.$((`date +%g%m%d%H%M%S`)).bak ; fi
                                            templocal=`basename "$PWD"`
                                            mkdir -p /home/stations/local/omrecorder/$templocal
                                            ln -s /home/stations/local/omrecorder/$templocal local
                                            echo ; echo ; duration=$(($duration*60))
                                            #arecord --duration=$duration --quiet --vumeter=stereo --device iec958:CARD=Device,DEV=0 --format cd --file-type wav local/minidisc.wav
# klm
                                            arecord --duration=$duration --quiet --vumeter=stereo --device $ripdev -f cd --file-type wav local/minidisc.wav
                                            echo ; echo "Working..." ; sleep 1 ; mv local/minidisc.wav . ; rm local                                          
                                            chmod g+w minidisc.wav ; echo ; pak ; duration=0 ; return ;;
                                    [Nn]* ) echo ; echo "oke, stopping now" ; duration=0 ;  return ;;
                                    * )     KEY="!" ; echo "Please answer yes or no.";;
                                esac
                            done ;;
                        $END|0)   return ;;
                        * ) KEY="!" ; echo "Please give value between 1 and 89.";;
                    esac
                done
                ;;
            $ESCAPE) if [ $lock -eq 1 ] ; then kill $pidofarecord ; lock=0 ; fi ;;
            $F01) echo "Help                   " ; echo ; pak ;;
            0|$END) if [ $lock -eq 1 ] ; then kill $pidofarecord ; lock=0 ; fi ; break ;;
            * ) KEY="!" ; echo "Please choose from list" ;;
        esac
    done
}

# MENU ITEM B - RIP CD
ripcd(){
    local item ; local track
    local counter=1 ; local cddafile ; local cddacounter=0 ; local datetime

    setstatus
    if [ ! -e /dev/cdrom ]  ; then echo "No CD device.";echo;pak;return;fi

    rc=`udevadm info -q property /dev/cdrom|grep ID_CDROM_MEDIA > /dev/null;echo $?`
    if [ $rc -ne 0 ] ; then echo "No CD in tray.";echo;pak;return;fi

    rc=`udevadm info -q property /dev/cdrom | grep 'ID_CDROM_MEDIA_STATE=blank' > /dev/null;echo $?`
    if [ $rc -eq 0 ] ; then echo "CD is blank.";echo;pak;return;fi

    if [ $OD_TYPE -eq 1 ] ||  [ $OD_TYPE -eq 2 ]  ; then
        echo "ripping cd..." #; echo

        # backup previous rips
        rc=`ls *.ccda.wav > /dev/null 2>&1 ; echo $?`
        if [ $rc -eq 0 ] ; then cddafile=(`ls *.cdda.wav`)
            datetime=`date +%g%m%d%H%M%S` 
            while [ "$cddacounter" -lt "${#cddafile[@]}" ] ; do
                mv ${cddafile[$cddacounter]}  ${cddafile[$cddacounter]}.${datetime}.bak
                let cddacounter++
            done
        fi

        cdparanoia --batch --output-wav

        # backup previous toc
        if [ -e $MDTITLELIST ] ; then
            mv $MDTITLELIST $MDTITLELIST.$((`date +%g%m%d%H%M%S`)).bak ; fi

        # generate md playlist
        if [ $OD_TYPE -eq 1 ] ; then
            echo "downloading tracklisting from musicbrainz..." #; echo
            rc=`getCdTracks.py  > /dev/null 2>&1 ; echo $?`
            if [ $rc -ne 0 ] ; then

                while true ; do
                    echo "CD not found, try manually?? (Yes/no)" ; readKey
                    case $KEY in
                        [Yy]*|$ENTER ) 
                            getTracks.py
                            #echo ; echo
                            break ;;
                        [Nn]*|0|$ESCAPE|$END ) 
                            echo "disc_title=" > $MDTITLELIST
                            echo "disc_performer=" >> $MDTITLELIST
                            echo "disc_year=" >> $MDTITLELIST
                            until [  $counter -gt $CDTRACKS  ] ; do
                                echo "track_title$counter="  >> $MDTITLELIST
                                echo "track_performer$counter="  >> $MDTITLELIST
                                let counter++
                            done
                            break ;;
                        * ) KEY="!" ; echo "Please answer yes or no.";;
                    esac
                done
            fi
        fi

        # C D - T E X T
        if [ $OD_TYPE -eq 2 ] ; then
            # disc data
            item=`cat $CDDATAFILE | grep -A 2 'CD-TEXT for Disc:'|grep 'TITLE' | cut -c 9-`
            echo "disc_title=$item" > $MDTITLELIST
            item=`cat $CDDATAFILE | grep -A 2 'CD-TEXT for Disc:'|grep 'PERFORMER' | cut -c 13-`
            echo "disc_performer=$item" >> $MDTITLELIST
            echo "disc_year=" >> $MDTITLELIST

            # track data
            until [ $counter -gt $CDTRACKS ] ; do
                if [ $counter -lt 10 ] ; then
                    item=`cat $CDDATAFILE|grep -A 2 "CD-TEXT for Track  ${counter}" | grep 'TITLE' | cut -c 9-`
                else
                    item=`cat $CDDATAFILE|grep -A 2 "CD-TEXT for Track ${counter}" | grep 'TITLE' | cut -c 9-`
                fi
                echo "track_title$counter=$item"  >> $MDTITLELIST
                # one space less when counter = 10 :-(
                if [ $counter -lt 10 ] ; then
                    item=`cat $CDDATAFILE|grep -A 2 "CD-TEXT for Track  ${counter}" | grep 'PERFORMER' | cut -c 13-`
                else
                    item=`cat $CDDATAFILE|grep -A 2 "CD-TEXT for Track ${counter}" | grep 'PERFORMER' | cut -c 13-`
                fi
                echo "track_performer$counter=$item"  >> $MDTITLELIST
                let counter++
            done
        fi

        # review list
        while true ; do
        read -N1 -p  "Do you wish to edit the generated titlelist? " yn
            case $yn in
                [Yy]* ) nano $MDTITLELIST ; mkgreen ; echo ; echo ; break ;;
                [Nn]* ) echo ; echo "oke, you can do this later" ; echo ;  break ;;
                * ) KEY="!" ; echo ; echo "Please answer yes or no.";;
            esac
        done

        # generate toc
        while true ; do
        read -N1 -p  "Do you wish to generate an TOC? " yn
            case $yn in
                [Yy]* ) if [ -e $CDTOC ] ; then mv $CDTOC $CDTOC.$((`date +%g%m%d%H%M%S`)).bak ; fi
                        echo ; mkcdtoctxt $CDTRACKS ; echo ; break ;;
                [Nn]* ) echo ; echo "oke, you can do this later" ; break ;;
                * ) KEY="!" ; echo ; echo "Please answer yes or no." ; echo ;;
            esac
        done
    else
        echo "No CDDA in tray, maybe get CD status menu P"
    fi
    echo ; pak
}

# https://fedoramagazine.org/use-musicbrainz-get-cd-information/

# called from MENU B - ripcd and others
mkcdtoctxt(){
    local cdtracks=$1
    local item ; local track=(`ls track*.cdda.wav 2>/dev/null`)
    local counter=1 ; local cnts=0  # ; local charcnt
    local message="omrecorder toc"

    if [ ${#track[@]} -eq 0 ] ; then track=(`ls md.track*.wav 2>/dev/null`)
        if [ ${#track[@]} -eq 0 ] ; then track=(`ls processed*.wav 2>/dev/null`)
            if [ ${#track[@]} -eq 0 ] ; then 
                echo "No soundfiles found. Please correct this. "
                echo "Report: ${#track[@]} soundfiles, $cdtracks titles."
                return
            fi
        fi
    fi

    if [ $cdtracks -ne ${#track[@]} ] ; then 
        echo "Soundtracks not equal to titles in list. Please correct this. "
        echo "Report: ${#track[@]} soundfiles, $cdtracks titles."
        return
    fi

    if [ -e $MDTITLELIST ] ; then
    	echo "Generating cdtoc.txt from title list..."
        # generate toc.txt

        echo "CD_DA" > $CDTOC
        echo "" >> $CDTOC
        echo "CD_TEXT {" >> $CDTOC
        echo "  LANGUAGE_MAP {" >> $CDTOC
        echo "    0 : EN" >> $CDTOC
        echo "" >> $CDTOC
        echo "  }" >> $CDTOC
        echo "  LANGUAGE 0 {" >> $CDTOC

        #disc
        item=`cat $MDTITLELIST | grep 'disc_title'|awk -F'=' '{print $2}'`
        echo "    TITLE \"$item\"" >> $CDTOC
        item=`cat $MDTITLELIST | grep 'disc_performer'|awk -F'=' '{print $2}'`
        echo "    PERFORMER \"$item\"" >> $CDTOC
        item="$message $((`date +%g%m%d%H%M%S`))"
        echo "    MESSAGE \"$item\"" >> $CDTOC
        echo "  }" >> $CDTOC
        echo "}" >> $CDTOC
        echo "" >> $CDTOC

        #tracks
        until [ $counter -gt $cdtracks ] ; do
            echo "TRACK AUDIO" >> $CDTOC
            echo "CD_TEXT {" >> $CDTOC
            echo "  LANGUAGE 0 {" >> $CDTOC
#            if [ $counter -lt 10 ] ; then charcnt="0$counter" ; fi
            item=`cat $MDTITLELIST | grep "track_title$counter="|awk -F'=' '{print $2}'`
            echo "    TITLE \"$item\"" >> $CDTOC
            item=`cat $MDTITLELIST | grep "track_performer$counter="|awk -F'=' '{print $2}'`
            echo "    PERFORMER \"$item\"" >> $CDTOC
            item="$message $((`date +%g%m%d%H%M%S`))"
            echo "    MESSAGE \"$item\"" >> $CDTOC
            echo "  }" >> $CDTOC
            echo "}" >> $CDTOC
            echo "FILE \"${track[$cnts]}\" 0" >> $CDTOC # ; abc
            echo "" >> $CDTOC
            let counter++
            let cnts++
        done
    fi
}

# MENU ITEM I - CREATE PCM FILES
menupcmfiles(){
    local hdtracks ; local hdtrackintegrety ; local hdtracktype

    hdtrackintegrety=`find . -type f -name "*.mp3" -o -name "*.wav" -o -name "*.flac" -o -name "*.ogg"  -o -name "*.opus" | rev | awk -F'.' '{print $1}' | rev | sort | uniq |wc -l`

    if [ $hdtrackintegrety -eq 1 ] ; then
        hdtracktype=(`find . -type f -name "*.mp3" -o -name "*.wav" -o -name "*.flac" -o -name "*.ogg"  -o -name "*.opus" | rev | awk -F'.' '{print $1}' | rev | sort | uniq`)
        hdtracks=(`ls *.$hdtracktype`)
#        hdtracks=(`find . *.$hdtracktype`)
    fi

if [ $hdtrackintegrety -ne 1 ] ; then
    setstatus ; echo "Multiple file types found" ; echo ; pak ; return ; fi

    while true ; do
        setstatus
        echo -e "\033[05;01H1. View tags"
        echo "2. Edit tags"
        echo "3. Create PCM files"
	echo "0. Return to menu"
        readKey
        echo -e "\033[09;01H   "
        case $KEY in
            1) echo "View tags..." ; echo ; viewtags $hdtracktype ${hdtracks[@]} ;;
            2) edittags $hdtracktype;;
            3) createpcmfiles $hdtracktype;;
            $F01) echo "Help                   " ; echo ; pak ;;
            0|$END) break ;;
            *) KEY="!" ; echo "Please choose from list" ;;
        esac
    done
}

edittags(){
    local trackname ; local tracksize ; local duration
    local tracknumber=1 ; local trackcnt ; local trackcounter=0
    local album ; local artist ; local title
    local yn ; local tracktype=$1

    # test if sound files exist
    trackname=(`ls -l *.$tracktype | awk '{print $9}' 2>/dev/null`)

    # print warning or take count
    if [ ${#trackname[@]} -eq 0 ] ; then 
        echo ; echo "No soundfiles found. Please correct this. "
        echo ; pak ; return
    else
        trackcnt=${#trackname[@]}
        tracksize=(`ls -lh *.$tracktype | awk '{print $5'}`)
    fi
    
    while true ; do 
        #while true ; do 
            setstatus
            #print tracks
            until [ $trackcounter -eq $trackcnt ] ; do
                tracknumber=$trackcounter
                if [ $trackcounter -lt 10 ] ; then tracknumber=" $trackcounter" ; fi
                duration=`mediainfo ${trackname[$trackcounter]} |grep Duration | awk -F":" '{print $2}' | uniq`
                echo "$tracknumber ${trackname[$trackcounter]} ${tracksize[$trackcounter]} $duration"
                let trackcounter++
                let tracknumber++
            done

         #   echo ; read -N1 -p  "Do you want to edit a tag? " yn
         #   case $yn in
         #       [Yy]* ) echo ; break ;;
         #       [Nn]* ) echo ; return ;;
         #       $END|0) return ;;
         #       * ) KEY="!" ; echo ; echo "Please answer yes or no." ; pak ; return ; echo ;;
         #   esac
        #done

        echo ; read -p "Please enter track number of the file to edit: " tracknumber
        echo
        if [ $tracknumber -gt ${#trackname[@]} ] ; then 
            echo "Tracknumber does not exist, returning to menu." ; echo ; pak ; break ; fi

#        echo "File  : ${hdtracks[$pointer]}" >> $tmpfile
        artist=`mediainfo --Inform="General;%Performer%" ${trackname[$tracknumber]}`
        album=`mediainfo --Inform="General;%Album%" ${trackname[$tracknumber]}`
        title=`mediainfo --Inform="General;%Track%" ${trackname[$tracknumber]}`

        case $tracktype in 

        ogg|wav|opus)   echo "No edit for $tracktype files yet"
        ;;
        mp3)
            echo       "Track nr : ${trackname[$tracknumber]}"
            read -e -p "Performer: " -i "$artist" artist
            read -e -p "Album    : " -i "$album" album
            read -e -p "Title    : " -i "$title" title
            echo
            read -N1 -p  "Is this information correct? Y/N/Q " yn
            case $yn in
                [Yy]* ) mp3info -a "$artist" ${trackname[$tracknumber]}
                        mp3info -l "$album"  ${trackname[$tracknumber]}
                        mp3info -t "$title"  ${trackname[$tracknumber]}
                        id3v2 -d ${trackname[$tracknumber]}  >/dev/null 2>&1 ;;
                [Nn]* ) ;;
                [Qq]* ) break ;;
                $END|0) break ;;
                
            esac
        ;;
        flac)   echo "flac"
        ;;
        esac
        trackcounter=0 ; echo ; echo ; pak
    done

}

createpcmfiles(){
    local trackname ; local tracksize ; local duration
    local tracknumber=1 ; local trackcnt ; local trackcounter=0
    local album ; local artist ; local title
    local targetdir ; local targetpath ; local targettrack
    local targettrackcounter=1 ; local targettracknumber=1 ; local targetplaylist
    local yn ; local tracktype=$1 ; local stamp

    while true ; do
        read -N1 -p  "Continue creating PCM files? " yn
        case $yn in
            [Yy]* ) echo ; break ;;
            [Nn]* ) echo ; return ;;
            $END|0) return ;;
            * ) KEY="!" ; echo ; echo "Please answer yes or no." ; pak ; return ; echo ;;
        esac
    done

    # test if sound files exist
    trackname=(`ls -l *.$tracktype | awk '{print $9}' 2>/dev/null`)

    # print warning or take count
    if [ ${#trackname[@]} -eq 0 ] ; then 
        echo ; echo "No soundfiles found. Please correct this. "
        echo ; pak ; return
    else
        trackcnt=${#trackname[@]}
        tracksize=(`ls -lh *.$tracktype | awk '{print $5'}`)
    fi

    #mk workdir
    targetdir=`basename "${PWD//" "/_}"`
    targetpath=$WORKDIR/${tracktype}-$targetdir
    mkdir -p $targetpath
    targetplaylist=$targetpath/$MDPLAYLIST
    
    #HEADER
    echo "#EXTM3U" > $targetplaylist ; stamp=`date +%Y%m%d-%H%M%S`
    echo "#PLAYLIST:omrecorderPlaylistCompressedFiles $stamp"  >> $targetplaylist
    album=`mediainfo --Inform="General;%Album%" ${trackname[$tracknumber]}`
    year=`mediainfo --Inform="General;%Recorded_Date%"  ${trackname[$tracknumber]}`
    echo "#EXTALB:$album ($year)" >> $targetplaylist

#        artist=`mediainfo --Inform="General;%Performer%" ${trackname[$tracknumber]}`
#        album=`mediainfo --Inform="General;%Album%" ${trackname[$tracknumber]}`
#        title=`mediainfo --Inform="General;%Track%" ${trackname[$tracknumber]}`

    #TRACKS
    until [ $trackcounter -eq $trackcnt ] ; do
        tracknumber=$trackcounter
        if [ $trackcounter -lt 10 ] ; then tracknumber=" $trackcounter" ; fi
        duration=`mediainfo ${trackname[$trackcounter]} |grep Duration | awk -F":" '{print $2}' | uniq`
        echo "Processing: $tracknumber ${trackname[$trackcounter]} ${tracksize[$trackcounter]} $duration"

        if [ $targettrackcounter -lt 10 ] ; then targettracknumber="0$targettrackcounter" ; fi
        
        #proces playlist
        artist=`mediainfo --Inform="General;%Performer%" ${trackname[$tracknumber]}`
        title=`mediainfo --Inform="General;%Track%" ${trackname[$tracknumber]}`
        echo "#EXTINF:-1,$artist - $title" >> $targetplaylist
        echo "md.track${targettracknumber}.wav" >> $targetplaylist

        #proces file
#        echo "SOURCE=${trackname[$tracknumber]}"
#        echo "TARGET=${targetpath}/md.track${targettracknumber}.wav"
#pak

        sox ${trackname[$tracknumber]} ${targetpath}/md.track${targettracknumber}.wav

        let trackcounter++
        let tracknumber++
#        let targettracknumber++
        let targettrackcounter++
    done
pak
}

viewtags(){
    local hdtracktype=$1 ; local hdtracks=("$@")
    local pointer=1 ; local counter=0 ; local tmpfile=$TMPDIR/tags.txt
    local album ; local artist ; local title
    touch $tmpfile
    #echo $hdtracktype ; echo ${hdtracks[@]}

    while [ $pointer -lt ${#hdtracks[@]} ] ; do
        echo "File  : ${hdtracks[$pointer]}" >> $tmpfile
        echo "Artist: `mediainfo --Inform="General;%Performer%" ${hdtracks[$pointer]}`"  >> $tmpfile
        echo "Album : `mediainfo --Inform="General;%Album%" ${hdtracks[$pointer]}`"  >> $tmpfile
        echo "Title : `mediainfo --Inform="General;%Track%" ${hdtracks[$pointer]}`"  >> $tmpfile
        echo >> $tmpfile
        let counter++ ; let pointer++
    done

    cat $tmpfile | more -21 ; pak ; rm $tmpfile
}

# MENU ITEM J - BURN CD
menuburncd(){
    while true ; do
        setstatus
        echo -e "\033[05;01H1. Blank CD"
        echo "2. Burn CD"
        echo "3. Close CD tray / 2nd Get status"
        echo "4. Create jewel case text"
        echo "0. Return to menu"
        readKey
        echo -e "\033[10;01H   "
        case $KEY in
            1) blankcd;;
            2) burncd;;
            3) eject -t ; OD_INFO="NO DATA"; setstatus ; echo "Working..."; readodstatus  ;;
            4) createjewlcasetext;;
            $F01) echo "Help                   " ; echo ; pak ;;
            0|$END) break ;;
            *) KEY="!" ; echo "Please choose from list" ;;
        esac
    done
}

createjewlcasetext(){
    local disc_title ; local disc_performer ; local disc_year
    local track_title ; local track_duration ; local track_number=1 ;
    local track=(`ls track*.cdda.wav 2>/dev/null`)
    local track_counter=0 ; local plcnts=0  # ; local charcnt
    local datetime=`date +%g%m%d%H%M%S` ; local track_number_txt

    if [ ${#track[@]} -eq 0 ] ; then track=(`ls md.track*.wav 2>/dev/null`) ; fi

    if [ ! -e $MDTITLELIST ] ; then
        echo "No titlelist found, please create one. " ; echo ; pak ; return
    else
        plcnts=`cat $MDTITLELIST | grep track_title | wc -l`
        disc_title=`cat $MDTITLELIST | grep 'disc_title'|awk -F'=' '{print $2}'`
        disc_performer=`cat $MDTITLELIST | grep 'disc_performer'|awk -F'=' '{print $2}'`
        disc_year=`cat $MDTITLELIST | grep 'disc_year'|awk -F'=' '{print $2}'`
        disc_title=" * $disc_performer - $disc_title - $disc_year"

        # Title
        if [ -e $CDJC ] ; then mv $CDJC $CDJC.$datetime.bak ; fi
        echo "$disc_title" > $CDJC
        echo >> $CDJC

        # Tracks
        until [ $track_counter -eq $plcnts ] ; do
            track_title=`cat $MDTITLELIST | grep "track_title$track_number="|awk -F'=' '{print $2}'`
            track_duration=`mediainfo --Inform="General;%Duration/String3%" ${track[track_counter]} | awk -F':' '{print $2 ":" $3}'|awk -F'.' '{print $1}'`
            if [ $track_number -lt 10 ] ; then track_number_txt=" $track_number"
            else track_number_txt="$track_number"; fi
            echo " $track_number_txt $track_title  $track_duration " >> $CDJC
            let track_counter++
            let track_number++
        done

        echo >> $CDJC
        echo " burned with delectronics omrecorder" >> $CDJC
        echo " $datetime" >> $CDJC
        echo "Jewel case text: " ; echo ; cat $CDJC | more -21 ; echo ; pak
    fi
}

blankcd(){
    local yn ; local rc

    setstatus

    if [ ! -e /dev/cdrom ]  ; then echo "No CD device.";echo;pak;return;fi

    # Such a device would not recognize an blank cd, so this check is before the next one
    rc=`udevadm info -q property /dev/cdrom | grep ID_CDROM_CD_RW > /dev/null ; echo $?`
    if [ $rc -ne 0 ] ; then echo "CD device is no burner.";echo;pak;return;fi

    # Only now check for blank cd
    rc=`udevadm info -q property /dev/cdrom|grep ID_CDROM_MEDIA > /dev/null;echo $?`
    if [ $rc -ne 0 ] ; then echo "No CD in tray.";echo;pak;return;fi

#    rc=`udevadm info -q property /dev/cdrom | grep 'ID_CDROM_MEDIA_CD_R=' > /dev/null;echo $?`
#    if [ $rc -eq 0 ] ; then echo "CD is readonly.";echo;pak;return;fi

    rc=`udevadm info -q property /dev/cdrom | grep 'ID_CDROM_MEDIA_STATE=blank' > /dev/null;echo $?`
    if [ $rc -eq 0 ] ; then echo "CD is allready blank.";echo;pak;return;fi

    while true ; do
        read -N1 -p  "Yes for BLANK the CD , No for break: " yn
        case $yn in
            [Yy]* )  echo ; cdrdao blank --device /dev/sr0 ; eject ; pak ; return ;;
            [Nn]* )  echo ; return ;;
            * ) KEY="!" ; echo "Please answer yes or no.";;
        esac
    done
}

burncd(){
    local rc ; local yn

    eject -t 

    setstatus

    if [ ! -e /dev/cdrom ]  ; then echo "No CD device.";echo;pak;return;fi

    # Such a device would not recognize an blank cd, so this check is before the next one
    rc=`udevadm info -q property /dev/cdrom | grep ID_CDROM_CD_RW > /dev/null ; echo $?`
    if [ $rc -ne 0 ] ; then echo "CD is no burner.";echo;pak;return;fi 

    # Only now check for blank cd
    rc=`udevadm info -q property /dev/cdrom|grep ID_CDROM_MEDIA > /dev/null;echo $?`
    if [ $rc -ne 0 ] ; then echo "No CD in tray.";echo;pak;return;fi

#    rc=`udevadm info -q property /dev/cdrom | grep 'ID_CDROM_MEDIA_CD_R=' > /dev/null;echo $?`
#    if [ $rc -eq 0 ] ; then echo "CD is readonly.";echo;pak;return;fi

    rc=`udevadm info -q property /dev/cdrom | grep 'ID_CDROM_MEDIA_STATE=blank' > /dev/null;echo $?`
    if [ $rc -eq 1 ] ; then echo "CD is not blank.";echo;pak;return;fi

    if [ -e $CDTOC ] ; then
        rc=`cat $CDTOC|grep "FILE"> /dev/null;echo $?`
        if [ $rc -eq 0 ] ; then
            while true ; do
                read -N1 -p  "Yes for BURN the CD , No for break: " yn
                case $yn in
                    [Yy]* )  echo ; cdrdao write --device /dev/sr0 --driver generic-mmc:0x10 -v 2 -n --eject $CDTOC ; pak  ; return ;;
                    [Nn]* )  echo ; return ;;
                    * ) KEY="!" ; echo "Please answer yes or no.";;
                esac
            done
        fi
    else
        echo "No TOC, please create one." ; echo ; pak
    fi
### note: the cdrdao option "--driver generic-mmc:0x10 -v 2 -n" is necessary for cd-text
### https://apocalyptech.com/linux/cdtext/ 
### /home/public/media/misc/notes/CD-TEXTburningOnLinux.pdf
### also more in this documents about cd burning and cd-text in general
}

# MENU ITEM L - RENAME MD
renamemd(){
    local rc1 ; local rc2

    setstatus
    rc1=`lsusb|grep Sony|grep 'Net MD' > /dev/null ; echo $?`
    rc2=`which netmdcli > /dev/null ; echo $?`
    if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ] ; then echo "No net MD device found or missing netmdcli.";echo;pak;return;fi 

    while true ; do
        setstatus
        echo -e "\033[05;01H1. Rename MD titles in batch"
        echo "2. Rename disc title"
        echo "3. Rename track title"
        echo "0. Return to menu"
        echo
        netmdcli | head -n -4 | tail -n +3
        echo
        echo "Please choose from menu: "
        readKey
        echo -e "\033[09;01H   "
        case $KEY in
            1) renamemdbatch;;
            2) renamemddisc;;
            3) renamemdtrack;;
            $F01) echo "Help                   " ; echo ; pak ;;
            0|$END) break ;;
            *) KEY="!" ; echo "Please choose from list" ;;
        esac
    done
}

renamemdbatch(){
    local disc_title ; local disc_performer ; local disc_year
    local track_title ; local track_number ;

    clear # only here we clear the screen completely for clearness :-)
    netmdcli | head -n -4 | tail -n +3 
    echo

    if [ ! -e $MDTITLELIST ] ; then
        echo "No titlelist found, please create one. " ; echo ; pak ; return
    else
        disc_title=`cat $MDTITLELIST | grep 'disc_title'|awk -F'=' '{print $2}'`
        disc_performer=`cat $MDTITLELIST | grep 'disc_performer'|awk -F'=' '{print $2}'`
        disc_year=`cat $MDTITLELIST | grep 'disc_year'|awk -F'=' '{print $2}'`
        disc_title="$disc_title - $disc_performer - $disc_year"
        echo "Rename in: "
        echo
        echo "Disc Title: $disc_title"
        echo
        counter=1 ; track_number=0
        cat $MDTITLELIST  | grep 'track_title' | awk -F '=' '{print $2}' | while read track_title
        do
            echo "Track  $track_number: $track_title" ; let track_number++
        done
        echo
    fi

    while true ; do
        read -N1 -p  "Yes for continue, No for break: " yn
        case $yn in
            [Yy]* ) echo ; echo ; break ;;
            [Nn]* ) return ;;
            0) return ;;
            * ) KEY="!" ; echo "Please answer yes or no." ;;
        esac
    done

    # The Renaming itself!
    netmdcli settitle "$disc_title"
    track_number=0
    cat $MDTITLELIST  | grep 'track_title' | awk -F '=' '{print $2}' | while read track_title
    do
        netmdcli rename $track_number "$track_title" a ; let track_number++
    done
}

renamemddisc(){
    local disc_title
    netmdcli | head -n -4 | tail -n +3 
    echo
    while true ; do
        read -N1 -p  "Yes for rename title, no for break: " yn
        case $yn in
            [Yy]* ) echo ; echo ; break ;;
            [Nn]* ) return ;;
            * ) KEY="!" ; echo "Please answer yes or no." ;;
        esac
    done
    read -p "Enter disc title : " disc_title
    netmdcli settitle "$disc_title"
    #netmdcli | tail -n +3 |head -n 1
    #echo
    pak
}

renamemdtrack(){
    local track_number
    local track_title
    netmdcli | head -n -4 | tail -n +3 
    echo
    while true ; do
        read -N1 -p  "Yes for rename track, no for break: " yn
        case $yn in
            [Yy]* ) echo ; echo ; break ;;
            [Nn]* ) return ;;
            * ) KEY="!" ; echo "Please answer yes or no." ;;
        esac
    done
    #netmdcli | head -n -4 | tail -n +3 
    read -p "Enter track number: " track_number
    read -p "Enter track title : " track_title
    netmdcli rename $track_number "$track_title" a
    let "track_number += 5"
    netmdcli|sed -n ${track_number}p
    echo
    pak
}

# MENU ITEM M - CREATE COMPRESSED FILES
menucompressedfiles(){
    local cdtracks=(`ls track*.cdda.wav 2>/dev/null`)
    local mdtracks=(`ls md.track*.wav 2>/dev/null`)
    local vdtracks=(`ls processed*.wav 2>/dev/null`)
    local tracks

    setstatus

    if [ ${#mdtracks[@]} -eq 0 ] ; then tracks=${cdtracks[@]}
        else tracks=${mdtracks[@]} ; fi

    if [ ${#vdtracks[@]} -ne 0 ] ; then tracks=${vdtracks[@]} ; fi

    if [ -e $CDTOC ] ; then
        while true ; do
            setstatus
            echo -e "\033[05;01H1. Create, rename and tag flacs"
            echo "2. Create playlist and move flacs to music directory"
            echo "3. Create, rename and tag mp3s"
            echo "4. Create playlist and move mp3s to music directory"
            echo "5. List files"
            echo "0. Return to menu"
            readKey
            echo -e "\033[11;01H   " # 4 items = cursor on line 10
            case $KEY in
                1) createflac ${tracks[@]} ; renameflac ${tracks[@]};;
                2) createfileplaylist flac;;
                3) createmp3 ${tracks[@]} ; renamemp3 ${tracks[@]};;
                4) createfileplaylist mp3;;
                5) setstatus ; pwd ; echo ; ls | more -21 ; echo; pak ;;
                $F01) echo "Help                   " ; echo ; pak ;;
                0|$END) break ;;
                *) KEY="!" ; echo "Please choose from list" ;;
            esac
        done
    else
        echo "No TOC, please create one." ; echo ; pak
    fi
}

createfileplaylist(){
    # not only create list, moves list AND tracks as well to musicdir/disc-dir
    local hdtracktype=$1 ; local hdtracks=(`ls *.$hdtracktype`)   #; local hdtracks=("$@")

    local item ; local performer ; local title ; local year ; local album
    local unique ; local counter=0 ; local cnts=1 ; local trackcnt ;local disc_track

    local disc_title=`cat $MDTITLELIST | grep disc_title | awk -F'=' '{print $2}'`
    local disc_performer=`cat $MDTITLELIST | grep disc_performer | awk -F= '{print $2}'`
    local disc_dir

    case $hdtracktype in
        flac)  disc_dir="${MUSICDIR}/${disc_performer}/${disc_title}" ;;
        mp3)   disc_dir="${MP3DIR}/${disc_performer}/${disc_title}" ;;
    esac

    disc_dir="`echo ${disc_dir//"'"/_}`" ; disc_dir="`echo ${disc_dir//" "/_}`"

    local playlist=`echo ${disc_title//"'"/_}` ; playlist=`echo ${disc_title//" "/_}`
    playlist="${playlist}.m3u"

#echo PLAYLIST = $playlist
#echo DISC_DIR = $disc_dir
#echo ; pak ; return

    # HEADER
    echo "#EXTM3U" > $playlist ; stamp=`date +%Y%m%d-%H%M%S`
    echo "#PLAYLIST:omrecorderPlaylist $stamp"  >> $playlist
    year=`cat $MDTITLELIST | grep disc_year | awk -F'=' '{print $2}'`
    album=`cat $MDTITLELIST | grep disc_title | awk -F'=' '{print $2}'`
    echo "#EXTALB:$album ($year)" >> $playlist

    # TRACKS
    tracks=`cat $MDTITLELIST | grep track_title | wc -l`
    while [ $counter -lt $tracks ] ; do
        performer=`cat $MDTITLELIST | grep "track_performer$cnts=" | awk -F= '{print $2}'`
        title=`cat $MDTITLELIST | grep "track_title$cnts=" | awk -F'=' '{print $2}'`
        echo "#EXTINF:-1,$performer - $title" >> $playlist
        disc_track=${hdtracks[$counter]} 
        disc_track="`echo ${disc_track//"'"/_}`" ; disc_track="`echo ${disc_track//" "/_}`"
        #echo "${disc_dir}/$disc_track" >> $playlist
        echo "$disc_track" >> $playlist
        let counter++ ; let cnts++
    done

    # move files
    mkdir -p $disc_dir
    mv -bvi *.$hdtracktype $disc_dir
    mv -bvi $playlist $disc_dir

    echo "Ready!" ; echo ; pak
}

createflac(){
    local tracks=("$@") ; local counter=0
    local tracknr=1 ; local tracknrnul ; local trackname
    local datetime=`date +%g%m%d%H%M%S` ; local newfile

    echo "Creating ${#tracks[@]} flacs..."

    until [ $counter -eq ${#tracks[@]} ] ; do

        if [ $counter -lt 9 ] ; then tracknrnul="0${tracknr}"
            else tracknrnul="${tracknr}" ; fi        
        if [ -e ${tracknrnul}.flac ] ; then
            mv ${tracknrnul}.flac ${tracknrnul}.flac.${datetime}.bak ; fi
        #sox ${tracks[$counter]} ${tracknr}.flac 2>/dev/null
        sox ${tracks[$counter]} ${tracknrnul}.flac
        newfile=`ls -lh ${tracknrnul}.flac | awk '{print $9 "  " $5 }'`
        echo "$newfile"
        let counter++ ; let tracknr++
    done

    #pak
}

renameflac(){
    local tracks=("$@") ; local counter=0
    local tracknr=1 ; local tracknrnul ; local trackname
    local datetime=`date +%g%m%d%H%M%S` ; local newfile
    local albumtitle ; local item

    echo "Tagging ${#tracks[@]} flags..."

    albumtitle=`cat $MDTITLELIST | grep 'disc_title'|awk -F'=' '{print $2}'`

    until [ $counter -eq ${#tracks[@]} ] ; do
        if [ $counter -lt 9 ] ; then tracknrnul="0${tracknr}"
            else tracknrnul="${tracknr}" ; fi        
        if [ -e ${tracknrnul}.flac ] ; then
            metaflac ${tracknrnul}.flac --set-tag="ALBUM=$albumtitle"
            item=`cat $MDTITLELIST | grep "track_performer$tracknr="|awk -F'=' '{print $2}'`
            metaflac ${tracknrnul}.flac --set-tag="ARTIST=$item"
            item=`cat $MDTITLELIST | grep "track_title$tracknr="|awk -F'=' '{print $2}'`
            metaflac ${tracknrnul}.flac --set-tag="TITLE=$item"
            item=`echo ${item// /_}` ; item=`echo ${item//"'"/_}`
            mv ${tracknrnul}.flac ${tracknrnul}.$item.flac
            newfile=`ls -lh ${tracknrnul}.$item.flac | awk '{print $9 "  " $5 }'`
            echo "$newfile"
        fi
        let counter++ ; let tracknr++
    done

    pak

## https://xiph.org/flac/documentation_tools_metaflac.html
}

createmp3(){
    local tracks=("$@") ; local counter=0
    local tracknr=1 ; local tracknrnul ; local trackname
    local datetime=`date +%g%m%d%H%M%S` ; local newfile

    echo "Creating ${#tracks[@]} mp3s..."

    until [ $counter -eq ${#tracks[@]} ] ; do

        if [ $counter -lt 9 ] ; then tracknrnul="0${tracknr}"
            else tracknrnul="${tracknr}" ; fi        
        if [ -e ${tracknrnul}.mp3 ] ; then
            mv ${tracknrnul}.mp3 ${tracknrnul}.mp3.${datetime}.mp3 ; fi
        #sox ${tracks[$counter]} ${tracknr}.flac 2>/dev/null
        sox ${tracks[$counter]} ${tracknrnul}.mp3
        newfile=`ls -lh ${tracknrnul}.mp3 | awk '{print $9 "  " $5 }'`
        echo "$newfile"
        let counter++ ; let tracknr++
    done

    #pak
}

renamemp3(){
    local tracks=("$@") ; local counter=0
    local tracknr=1 ; local tracknrnul ; local trackname
    local datetime=`date +%g%m%d%H%M%S` ; local newfile
    local albumtitle ; local item

    echo "Tagging ${#tracks[@]} mp3s..."

    albumtitle=`cat $MDTITLELIST | grep 'disc_title'|awk -F'=' '{print $2}'`

    until [ $counter -eq ${#tracks[@]} ] ; do
        if [ $counter -lt 9 ] ; then tracknrnul="0${tracknr}"
            else tracknrnul="${tracknr}" ; fi        
        if [ -e ${tracknrnul}.mp3 ] ; then
            mp3info -l "$albumtitle" ${tracknrnul}.mp3
            item=`cat $MDTITLELIST | grep "track_performer$tracknr="|awk -F'=' '{print $2}'`
            mp3info -a "$item"  ${tracknrnul}.mp3
            item=`cat $MDTITLELIST | grep "track_title$tracknr="|awk -F'=' '{print $2}'`
            mp3info -t "$item" ${tracknrnul}.mp3
            item=`echo ${item// /_}` ; item=`echo ${item//"'"/_}`
            mv ${tracknrnul}.mp3 ${tracknrnul}.$item.mp3
            newfile=`ls -lh ${tracknrnul}.$item.mp3 | awk '{print $9 "  " $5 }'`
            echo "$newfile"
        fi
        let counter++ ; let tracknr++
    done

    pak
}

# MENU ITEM F - EDIT TOC
mdtoc(){
    local yn ; local cdtracks

    while true ; do
        setstatus
        echo -e "\033[05;01H1. Create TOC from titlelist"
        echo "2. Edit TOC"
        echo "3. View TOC"
        echo "4. View cd-info"
        echo "0. Return to menu"
        readKey
        echo -e "\033[10;01H   "
        case $KEY in
            1)
                if  [ ! -e $MDTITLELIST ] ; then
                    echo "Titlelist not found, please create one." ; echo ; pak ; return
                else
                    cdtracks=`cat $MDTITLELIST | grep track_title | wc -l`
                fi                

                if [ -e $CDTOC ] ; then
                    while true ; do
                        read -N1 -p  "TOC allready exist. Do you wish to overwrite? " yn
                        case $yn in
                            [Yy]* ) mv $CDTOC $CDTOC.$((`date +%g%m%d%H%M%S`)).bak ; echo ; echo ; echo "Working..." ; echo ; mkcdtoctxt $cdtracks; echo ; pak; break ;;
                            [Nn]* ) break ;;
                            * ) KEY="!" ; echo "Please answer yes or no." ;;
                        esac
                    done
                else
                    echo "Working..." ; echo ; mkcdtoctxt $cdtracks ; echo ; pak
                fi
                ;;
            2)  nano $CDTOC              ;mkgreen;;
            3)  cat $CDTOC | more -21 ; echo ; pak ; mkgreen;;
            4)  if [ $OD_TYPE -eq 1 ] ||  [ $OD_TYPE -eq 2 ]  ; then
                    cat $CDDATAFILE | more -21 ; echo ; pak ; mkgreen
                else
                    echo "No cdda found" ; echo ; pak ; mkgreen
                fi ;;
            $F01) echo "Help                   " ; echo ; pak ;;
            0|$END) break ;;
            * ) KEY="!" ; echo "Please choose from list" ;;
        esac
    done
}

# MENU ITEM H - EDIT TITLELIST
menutitlelist(){
    while true ; do
        setstatus
        echo -e "\033[05;01H1. Create titlelist from playlist"
        echo "2. Edit titlelist"
        echo "3. View titlelist"
        echo "4. Create titlelist / add tracks"
        echo "5. Create titlelist from MD"
        echo "6. Create titlelist with MusicBrainz"
        echo "0. Return to menu"
        readKey
        echo -e "\033[12;01H   "
        case $KEY in
            1) mktitlelistbatch;;
            2) nano $MDTITLELIST              ;mkgreen;;
            3) cat $MDTITLELIST | more -21 ; echo ; pak ;mkgreen;;
            4) mkmdtitlelist ;;
            5) mktitlelistfrommd ;;
            6) mktitlelistwithmusicbrainz ;;
            $F01) echo "Help                   " ; echo ; pak ;;
            0|$END) break ;;
            * ) KEY="!" ; echo "Please choose from list" ;;
        esac
    done
}

mktitlelistwithmusicbrainz(){
    if [ -e $MDTITLELIST ] ; then
        mv $MDTITLELIST $MDTITLELIST.$((`date +%g%m%d%H%M%S`)).bak
    fi
    #echo
    getTracks.py
    echo
    pak
}

mktitlelistfrommd(){
    local item  ; local counter=0 ; local cnts ; local tracknumber=1
    local disc_header ; local disc_performer
#    local track_title ; local track_number ; local track_performer
    local yn ; local ny ; local rc1 ; local rc2 ; local netmd=0

    rc1=`lsusb|grep Sony|grep 'Net MD' > /dev/null ; echo $?`
    rc2=`which netmdcli > /dev/null ; echo $?`
    if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ] ; then netmd=1 ; fi 

    if [ $netmd -eq 0 ] ; then
        if [ -e $MDTITLELIST ] ; then
            while true ; do
                read -N1 -p  "Titlelist allready exist. Do you wish to overwrite? " yn
                case $yn in
                    [Yy]* ) mv $MDTITLELIST $MDTITLELIST.$((`date +%g%m%d%H%M%S`)).bak ; echo ; echo ; break ;;
                    [Nn]* ) return ;;
                    * ) KEY="!" ; echo "Please answer yes or no." ;;
                esac
            done
        fi
        # HEADER
        disc_header=`netmdcli | grep "Disc Title:" | awk -F':' '{print $2}'`
        # disc title
        item=`echo $disc_header | awk -F'-' '{print $1}'|cut -c 1-`
        echo "disc_title=$item" > $MDTITLELIST
        # performer
        item=`echo $disc_header | awk -F'-' '{print $2}'|cut -c 2-`
        disc_performer=$item
        echo "disc_performer=$item" >> $MDTITLELIST
        # year
        item=`echo $disc_header | awk -F'-' '{print $3}'|cut -c 2-`
        echo "disc_year=$item" >> $MDTITLELIST
        # TRACKS
        # track title
        cnts=`netmdcli | head -n -4 | tail -n +5 | wc -l`
        while [ $counter -ne $cnts ] ; do
            item=`netmdcli | head -n -4 | tail -n +5 | grep "Track  ${counter}:"| awk -F"-" '{print $3}'|cut -c 2-`
            echo "track_title$tracknumber=$item"  >> $MDTITLELIST ; let counter++ ; let tracknumber++
        done
        #track performer
        counter=0
        tracknumber=1
        while [ $counter -ne $cnts ] ; do
            echo "track_performer$tracknumber=$disc_performer"  >> $MDTITLELIST ; let counter++ ; let tracknumber++
        done
        cat $MDTITLELIST | more -21 ; echo ; pak ;mkgreen
    else
        echo "No net MD device found or missing netmdcli." ;echo ; pak
    fi    
}

mkmdtitlelist(){
    local disc_title ; local disc_performer ; local disc_year
    local track_title ; local track_number ; local track_performer
    local yn ; local ny ; local rc

    if [ ! -e  $MDTITLELIST ] ; then 
        echo "Please enter the following information:"    
        read -p "Disc Title     : " disc_title ; echo "disc_title=$disc_title" >> $MDTITLELIST
        read -p "Disc Performer : " disc_performer ; echo "disc_performer=$disc_performer" >> $MDTITLELIST
        read -p "Disc Year      : " disc_year ; echo "disc_year=$disc_year" >> $MDTITLELIST
    else
        #mv $MDTITLELIST $MDTITLELIST.$((`date +%g%m%d%H%M%S`)).bak
        rc=`cat $MDTITLELIST | grep track_title | wc -l > /dev/null ; echo $?`
        if [ $rc -eq 0 ] ; then track_number=`cat $MDTITLELIST | grep track_title | wc -l`
        else track_number=0 ; fi ; let track_number++
        track_performer=`cat $MDTITLELIST |grep 'disc_performer' | awk -F '=' '{print $2}'`

        while true ; do
            echo       "Track nr : $track_number"
            read -e -p "Performer: " -i "$track_performer" track_performer
            read -e -p "Title    : " -i "$track_title" track_title
            echo
            read -N1 -p  "Is this information correct? " yn
            case $yn in
                [Yy]* ) #eko
                    echo "track_title$track_number=$track_title" >> $MDTITLELIST
                    echo "track_performer$track_number=$track_performer" >> $MDTITLELIST
                    while true ; do
                        echo ; echo
                        read -N1 -p  "Do you wish to add another track? " ny
                        case $ny in
                            [Yy]* ) track_title=`echo` ; let track_number++ ; echo ; echo ; break ;;
                            [Nn]* ) yn=0 ;  return ;;
                            * ) KEY="!" ; echo "Please answer yes or no.";;
                        esac
                    done ;;
                [Nn]* ) echo ;;
                $END|0) return ;;
                * ) KEY="!" ; echo ; echo "Please answer yes or no." ; echo ;;
            esac
        done
    fi
}

mktitlelistbatch(){
    local item ; local unique ; local counter ; local cnts

    if [ -e $MDPLAYLIST ] ; then
        if [ -e $MDTITLELIST ] ; then
            while true ; do
                read -N1 -p  "Titlelist allready exist. Do you wish to overwrite? " yn
                case $yn in
                    [Yy]* ) mv $MDTITLELIST $MDTITLELIST.$((`date +%g%m%d%H%M%S`)).bak ; echo ; echo ; break ;;
                    [Nn]* ) return ;;
                    * ) KEY="!" ; echo "Please answer yes or no." ;;
                esac
            done
        fi
        # HEADER
        # disc title
        item=`cat $MDPLAYLIST |grep '#EXTALB:' | cut -c 9- | awk -F '(' '{print $1}' | rev | cut -c 2- | rev`
        echo "disc_title=$item" > $MDTITLELIST
        # performer
        unique=`cat $MDPLAYLIST | grep '#EXTINF:' | cut -c 12- | awk -F - '{print $1}' | rev | cut -c 2- | rev | sort -u | wc -l`
        if  [ $unique -eq 1 ] ; then 
            item=`cat $MDPLAYLIST | grep '#EXTINF:' | cut -c 12- | awk -F - '{print $1}' | rev | cut -c 2- | rev | sort -u`
        else
            item="Multiple Performers"
        fi
        echo "disc_performer=$item" >> $MDTITLELIST
        # year
        item=`cat $MDPLAYLIST | grep '#EXTALB:' | cut -c 9- | awk -F '(' '{print $2}' | rev | cut -c 2- | rev`
        echo "disc_year=$item" >> $MDTITLELIST
        # TRACKS
        # track title
        counter=1
        cat $MDPLAYLIST  | grep '#EXTINF:' | awk -F ' - ' '{print $2}' | while read item
        do
            echo "track_title$counter=$item"  >> $MDTITLELIST ; let counter++
        done
        #track performer
        counter=1
        cat $MDPLAYLIST  | grep '#EXTINF:' | cut -c 12- | awk -F - '{print $1}' | rev | cut -c 2- | rev | while read item
        do
            echo "track_performer$counter=$item"  >> $MDTITLELIST ; let counter++
        done

        echo "Ready!"
    else
        echo "No playlist found, please generate one. "
    fi

    echo ; pak
}

# MENU ITEM G - EDIT PLAYLIST
menuplaylist(){
    local key
    while true ; do
        setstatus
        echo -e "\033[05;01H1. Create title only playlist from titlelist"
        echo "2. Edit playlist"
        echo "3. View playlist"
        echo "4. Create youtube playlist / add tracks"
        echo "5. Create empty youtube playlist from titlelist"
        echo "6. Create playlist from music file tags"
        echo "7. Create playlist from cdda / vd / md files and titlelist"
        echo "0. Return to menu"
        readKey
        echo -e "\033[13;01H   " # 11=5
        case $KEY in
            1) mkplaylistbatch 0;;
            2) nano $MDPLAYLIST               ; mkgreen ;;
            3) cat $MDPLAYLIST | more -21 ; echo ; pak ; mkgreen ;;
            4) mkmdyoutubeplaylist;;
            5) mkyoutubeplaylistbatch;;
            6) mkplaylistmusicfiles;;
            7) mkplaylistcddafiles;;
            $F01) echo "Help                   " ; echo ; pak ;;
            0|$END) break ;;
            * ) KEY="!" ; echo "Please choose from list" ;;
        esac
    done
}

mkplaylistmusicfiles(){
    local trackname ; local tracksize ; local duration
    local trackintegrety ; local tracktype
    local tracknumber=1 ; local trackcnt ; local trackcounter=0
    local album ; local artist ; local title
    #local targetdir ; local targetpath ; local targettrack
    local targettrackcounter=1 ; local targettracknumber=1 ; local targetplaylist
    local yn ; local tracktype=$1 ; local stamp
    local datetime=`date +%g%m%d%H%M%S`

    hdtrackintegrety=`find . -type f -name "*.mp3" -o -name "*.wav" -o -name "*.flac" -o -name "*.ogg"  -o -name "*.opus" | rev | awk -F'.' '{print $1}' | rev | sort | uniq |wc -l`

    if [ $hdtrackintegrety -eq 1 ] ; then
        tracktype=(`find . -type f -name "*.mp3" -o -name "*.wav" -o -name "*.flac" -o -name "*.ogg"  -o -name "*.opus" | rev | awk -F'.' '{print $1}' | rev | sort | uniq`)
        trackname=(`ls *.$tracktype`)
    fi

    if [ $hdtrackintegrety -ne 1 ] ; then
    setstatus ; echo "Multiple or no file types found" ; echo ; pak ; return ; fi
    targetplaylist=`mediainfo --Inform="General;%Album%" ${trackname[$tracknumber]}`
    targetplaylist=`echo "${targetplaylist//" "/_}"`
    targetplaylist=`echo "${targetplaylist}.m3u"`
    if [ -e $targetplaylist ] ; then mv $targetplaylist $targetplaylist.$datetime.bak ; fi 
    echo "Playlist=$targetplaylist"
    
    #HEADER
    echo "#EXTM3U" > $targetplaylist ; stamp=`date +%Y%m%d-%H%M%S`
    echo "#PLAYLIST:omrecorderPlaylist $stamp"  >> $targetplaylist
    album=`mediainfo --Inform="General;%Album%" ${trackname[$tracknumber]}`
    year=`mediainfo --Inform="General;%Recorded_Date%"  ${trackname[$tracknumber]}`
    echo "#EXTALB:$album ($year)" >> $targetplaylist

    #TRACKS
    until [ $trackcounter -eq $trackcnt ] ; do
        tracknumber=$trackcounter
        if [ $trackcounter -lt 10 ] ; then tracknumber=" $trackcounter" ; fi
        duration=`mediainfo --Inform="General;%Duration/String3%" ${trackname[tracknumber]} | awk -F':' '{print $2 ":" $3}'|awk -F'.' '{print $1}'`
        artist=`mediainfo --Inform="General;%Performer%" ${trackname[$tracknumber]}`
        title=`mediainfo --Inform="General;%Track%" ${trackname[$tracknumber]}`
        echo "#EXTINF:$duration,$artist - $title" >> $targetplaylist
        #echo "`pwd`/${trackname[$trackcounter]}" >> $targetplaylist
        echo "${trackname[$trackcounter]}" >> $targetplaylist
        let trackcounter++ ; let tracknumber++ ; let targettrackcounter++
    done

    cat $targetplaylist | more -21 ; pak
}

mkplaylistcddafiles(){
    local tracktitles
    local cdtracks=(`ls track*.cdda.wav 2>/dev/null`)

    if [ ${#cdtracks[@]} -eq 0 ] ; then cdtracks=(`ls processed*.wav 2>/dev/null`) ; fi

    if [ ${#cdtracks[@]} -eq 0 ] ; then cdtracks=(`ls md.track*.wav 2>/dev/null`) ; fi

    if  [ ! -e $MDTITLELIST ] ; then
        echo "No titlelist found, please create one." ; echo ; pak ; return
    else
        tracktitles=`cat $MDTITLELIST | grep track_title | wc -l`
    fi  

    if [ ${#cdtracks[@]} -eq 0 ] ; then 
        echo "No soundfiles found. Please correct this. "
        echo "Report: ${#track[@]} soundfiles, $cdtracks titles."
        echo ; pak ; return
    fi

    if [ $tracktitles -ne ${#cdtracks[@]} ] ; then 
        echo "Soundtracks not equal to titles in list. Please correct this. "
        echo "Report: ${#cdtracks[@]} soundfiles, $tracktitles titles."
        echo ; pak ; return
    fi

    mkplaylistbatch $tracktitles
}

mkplaylistbatch(){
    local item ; local performer ; local title ; local album ; local year
    local unique ; local counter=0 ; local cnts=1 ; local trackcnt ; local cdda=$1
    local cdtracks

    if [ $cdda -ne 0 ] ; then cdtracks=(`ls track*.cdda.wav 2>/dev/null`) ; fi

    if [ ${#cdtracks[@]} -eq 0 ] ; then cdtracks=(`ls processed*.wav 2>/dev/null`) ; fi

    if [ ${#cdtracks[@]} -eq 0 ] ; then cdtracks=(`ls md.track*.wav 2>/dev/null`) ; fi


    if [ -e $MDTITLELIST ] ; then
        if [ -e $MDPLAYLIST ] ; then
            while true ; do
                read -N1 -p  "Playlist allready exist. Do you wish to overwrite? " yn
                case $yn in
                    [Yy]* ) mv $MDPLAYLIST $MDPLAYLIST.$((`date +%g%m%d%H%M%S`)).bak ; echo ; echo ; break ;;
                    [Nn]* ) return ;;
                    * ) KEY="!" ; echo "Please answer yes or no." ;;
                esac
            done
        fi
        # HEADER
        echo "#EXTM3U" > $MDPLAYLIST ; stamp=`date +%Y%m%d-%H%M%S`
        if [ $cdda -eq 0 ] ; then
            echo "#PLAYLIST:omrecorderTitleOnlyPlaylist $stamp"  >> $MDPLAYLIST
        else
            echo "#PLAYLIST:omrecorderCddaPlaylist $stamp"  >> $MDPLAYLIST
        fi
        album=`cat mdtitle.lst | grep disc_title | awk -F'=' '{print $2}'`
        year=`cat mdtitle.lst | grep disc_year | awk -F'=' '{print $2}'`
        echo "#EXTALB:$album ($year)"   >> $MDPLAYLIST

        # TRACKS
        tracks=`cat $MDTITLELIST | grep track_title | wc -l`

        while [ $counter -lt $tracks ] ; do
            performer=`cat $MDTITLELIST | grep "track_performer$cnts=" | awk -F= '{print $2}'`
            title=`cat $MDTITLELIST | grep "track_title$cnts=" | awk -F'=' '{print $2}'`
            echo "#EXTINF:-1,$performer - $title" >> $MDPLAYLIST
            if [ $cdda -eq 0 ] ; then
                echo >> $MDPLAYLIST
            else
                echo "${cdtracks[$counter]}" >> $MDPLAYLIST
            fi
            let counter++ ; let cnts++
        done
        echo "Ready!" ; echo ; pak
    else
        echo "No titlelist found, please create one. "
    fi

}

mkyoutubeplaylistbatch(){
    local item ; local performer ; local title ; local album ; local year
    local unique ; local counter=0 ; local cnts=1 ; local trackcnt
    local stamp

    if [ -e $MDTITLELIST ] ; then
        if [ -e $MDPLAYLIST ] ; then
            while true ; do
                read -N1 -p  "Playlist allready exist. Do you wish to overwrite? " yn
                case $yn in
                    [Yy]* ) mv $MDPLAYLIST $MDPLAYLIST.$((`date +%g%m%d%H%M%S`)).bak ; echo ; echo ; break ;;
                    [Nn]* ) return ;;
                    * ) KEY="!" ; echo "Please answer yes or no." ;;
                esac
            done
        fi
        # HEADER
        echo "#EXTM3U" > $MDPLAYLIST ; stamp=`date +%Y%m%d-%H%M%S`
        echo "#PLAYLIST:omrecorderYoutubePlaylist $stamp"  >> $MDPLAYLIST
        album=`cat mdtitle.lst | grep disc_title | awk -F'=' '{print $2}'`
        year=`cat mdtitle.lst | grep disc_year | awk -F'=' '{print $2}'`
        echo "#EXTALB:$album ($year)"   >> $MDPLAYLIST
        echo "#EXT-X-SESSION-DATA:VOLUME=$volume" >> $MDPLAYLIST
        # TRACKS
        tracks=`cat $MDTITLELIST | grep track_title | wc -l`

        while [ $counter -lt $tracks ] ; do
            performer=`cat $MDTITLELIST | grep "track_performer$cnts=" | awk -F= '{print $2}'`
            title=`cat $MDTITLELIST | grep "track_title$cnts=" | awk -F'=' '{print $2}'`
            echo "#EXTINF:-1,$performer - $title" >> $MDPLAYLIST
            echo >> $MDPLAYLIST
            let counter++ ; let cnts++
        done
        echo "Ready!" ; echo ; pak
    else
        echo "No titlelist found, please create one. "
    fi
}

mkmdyoutubeplaylist(){
    local artist ; local track ; local album ; local url ; local volume=85
    local yn ; local ny ; local stamp

    if [ ! -e  $MDPLAYLIST ] ; then
        echo "#EXTM3U" > $MDPLAYLIST ; stamp=`date +%Y%m%d-%H%M%S`
        echo "#PLAYLIST:omrecorderYoutubePlaylist $stamp"  >> $MDPLAYLIST
        echo "Please enter the following information:"
        read -p "Album : " album ; echo "#EXTALB:$album" >> $MDPLAYLIST
        read -e -p "Volume: " -i "$volume" volume ; echo "#EXT-X-SESSION-DATA:VOLUME=$volume" >> $MDPLAYLIST
    else
        #mv $MDPLAYLIST $MDPLAYLIST.$((`date +%g%m%d%H%M%S`)).bak
        artist=`cat $MDPLAYLIST |grep '#EXTINF:' | cut -c 12- | awk -F - '{print $1}' | rev | cut -c 2- |rev | sort -u`
        while true ; do
            read -e -p "Artist: " -i "$artist" artist
            read -e -p "Track : " -i "$track" track 
            read -e -p "Url   : " -i "$url" url
#            read -p "Url   : " url

            echo
            read -N1 -p  "Is this information correct? " yn
            case $yn in
                [Yy]* ) #eko
                    echo "#EXTINF:-1,$artist - $track" >> $MDPLAYLIST
                    echo "$url" >> $MDPLAYLIST ; echo # ;;
                    while true ; do
                        read -N1 -p  "Do you wish to add another track? " ny
                        case $ny in
                            [Yy]* ) track=`echo` ; url=`echo` ; echo ; echo ; break ;;
                            [Nn]* ) yn=0 ;  return ;;
                            * ) KEY="!" ; echo "Please answer yes or no.";;
                        esac
                    done ;;
                [Nn]* ) echo ;;
                $END|0) return ;;
                * ) KEY="!" ; echo ; echo "Please answer yes or no." ; echo ;;
            esac
        done
    fi
}

# MENU ITEM K - RECORD MD
recordmd(){
    local rc1=1 ; local rc2=1 ; local yn ; local volume=85 ; local defaultvolume=85

    setstatus

    rc1=`lsusb |grep CM106 > /dev/null ; echo $?`
    if [ $rc1 -eq 0 ] ;then rc2=`amixer -c 1 scontrols |grep IEC958 > /dev/null ; echo $?` ; fi
    if [ $rc2 -eq 1 ] ; then echo "No optical out device found.";echo;pak;return;fi 

    if [ -e $MDPLAYLIST ] ; then
        rc=`cat $MDPLAYLIST|grep "#PLAYLIST:omrecorderYoutubePlaylist"> /dev/null;echo $?`
        if [ $rc -eq 0 ] ; then
            while true ; do
                read -N1 -p  "Yes for recording YOUTUBE playlist on minidisc , No for break: " yn
                case $yn in
                    [Yy]* )  volume=`cat $MDPLAYLIST | grep "#EXT-X-SESSION-DATA:VOLUME=" | awk -F= '{print $2}' 2>/dev/null`
                             if [ -z $volume ] ; then volume=$defaultvolume ; fi
                             echo ; mpv --ytdl-format=251 --pause --volume=$volume $MDPLAYLIST ; pak  ; return ;;
                    [Nn]* )  echo ; return ;;
                    * ) KEY="!" ; echo "Please answer yes or no.";;
                esac
            done
        else
            while true ; do
                read -N1 -p  "Yes for recording FILE playlist on minidisc , No for break: " yn
                case $yn in
                    [Yy]* )  echo ; mpv --audio-samplerate=48000 --pause --volume=95 $MDPLAYLIST ; pak  ; return ;;
                    [Nn]* )  echo ; return ;;
                    * ) KEY="!" ; echo "Please answer yes or no.";;
                esac
            done
        fi
    else
        echo "No playlist, please create one." ; pak
    fi
}

# MENU ITEM D - SPLIT TRACKS
menusplittracks(){
    local key
    while true ; do
        setstatus
        echo -e "\033[05;01H1. Split tracks by silence"
        echo "2. Listen track starts & endings"
        echo "3. View file listing and listen track"
        echo "4. Remove silent tracks"
        echo "5. Join tracks"
        echo "6. Split track in two"
        echo "7. Generate tracklist from MD"
        echo "8. Edit tracklist"
        echo "9. Split tracks by tracklist"
        echo "0. Return to menu"
        readKey
        echo -e "\033[15;01H   "
        case $KEY in
            1) splittracksbysilence ; clear ;;
            2) listentracks;;
            3) viewlistentracks ;;
            4) removesilenttracks ;;
            5) jointracks ;;
            6) splittracks ;;
            7) tracklistfrommd ;;
            8) nano -l $MDTRACKLIST;mkgreen ;;
            9) splittracksbylist ;;
            0|$END) break ;;
            *) KEY="!" ; echo "Please choose from list" ;;
        esac
    done
}

removesilenttracks(){
    find . -maxdepth 1 -name "*.wav" -type f -size -900k -exec mv {} {}.silence.bak \; ; echo ; pak ; clear
    #klm
}

viewlistentracks(){
    local trackname ; local tracksize ; local duration
    local tracknumber=1 ; local trackcnt ; local trackcounter=0
    local yn

    # test if sound files exist
    trackname=(`ls -l md.track*.wav | awk '{print $9}' 2>/dev/null`)

    # print warning or take count
    if [ ${#trackname[@]} -eq 0 ] ; then 
        echo ; echo "No soundfiles found. Please correct this. "
        echo ; pak ; return
    else
        trackcnt=${#trackname[@]}
        tracksize=(`ls -lh md.track*.wav | awk '{print $5'}`)
    fi
    
    while true ; do 
        while true ; do 
            setstatus
            #print tracks
            until [ $trackcounter -eq $trackcnt ] ; do
                tracknumber=$trackcounter
                if [ $trackcounter -lt 10 ] ; then tracknumber=" $trackcounter" ; fi
                duration=`mediainfo ${trackname[$trackcounter]} |grep Duration | awk -F":" '{print $2}' | uniq`
                echo "$tracknumber ${trackname[$trackcounter]} ${tracksize[$trackcounter]} $duration"
                let trackcounter++
                let tracknumber++
            done

            echo ; read -N1 -p  "Do you want to listen to a file? " yn
            case $yn in
                [Yy]* ) echo ; break ;;
                [Nn]* ) echo ; return ;;
                $END|0) return ;;
                * ) KEY="!" ; echo ; echo "Please answer yes or no." ; echo ;;
            esac
        done

        echo ; read -p "Please enter track number of the file to listen to: " tracknumber
        echo

        mpv  ${trackname[tracknumber]}
        trackcounter=0 ; echo
    done
}


listentracks(){
    local trackname ; local tracknumber=1 ; local trackcounter=0
    local duration=5 ; local title

    # test if sound files exist
    trackname=(`ls -l md.track*.wav | awk '{print $9}' 2>/dev/null`)

    # no soundfiles, quit
    if [ ${#trackname[@]} -eq 0 ] ; then 
        echo : echo "No soundfiles found. Please correct this. "
        echo ; pak ; return
    else
        read -e -p "Duration fragments in seconds: " -i $duration duration
        echo
    fi

    #play track starts and endings
    echo "Playing ${#trackname[@]} tracks" ; echo

    until [ $trackcounter -eq ${#trackname[@]} ] ; do
        if [ -e $MDTITLELIST ] ; then 
            title=`cat $MDTITLELIST | grep "track_title$tracknumber=" | awk -F'=' '{print $2}'`
        else
            title="no track title"
        fi
        #echo "playing track ${tracknumber}:" ;
        echo "START ---> track ${tracknumber} -0- $title -0-"
        echo "======================================================================"
        mpv --end=$duration ${trackname[$trackcounter]}  ; echo
        echo "Track ${tracknumber} <--- END"
        mpv --start=-$duration  ${trackname[$trackcounter]}  ; echo
        let tracknumber++ ; let trackcounter++
    done

    pak
}

splittracksbylist(){
    local counter=0 ; local trackcounter=1 ; local trackname
    local minute=(`cat $MDTRACKLIST | awk '{print $1}'`)
    local second=(`cat $MDTRACKLIST | awk '{print $2}'`)
    local fragment=(`cat $MDTRACKLIST | awk '{print $3}'`)
    local minutestart=0
    local secondstart=0
    local fragmentstart=0
    local datetime=`date +%g%m%d%H%M%S`

    if [ ! -e minidisc.wav ] ; then echo "No MD rip found, exit." ; return ; fi

    echo "Working..."

    until [ $trackcounter -eq ${#minute[@]} ] ; do
        if [ $counter -eq 0 ] ; then
            if [ -e md.track01.wav ] ; then mv md.track01.wav md.track01.wav.${datetime}.bak ; fi
            sox minidisc.wav md.track01.wav trim 0 ${minute[0]}:${second[0]}.${fragment[0]}
            minutestart=${minute[0]} ; secondstart=${second[0]} ; fragmentstart=${fragment[0]}
            echo "`ls -lh md.track01.wav`"
        fi

        if [ $counter -gt 0 ] ; then
            minutestart="$((minutestart+minute[$counter]))"
            secondstart="$((secondstart+second[$counter]))"
            if [ $secondstart -gt 59 ] ; then
            let minutestart++ ; secondstart=$(($secondstart-60)) ; fi
            fragmentstart="$((fragmentstart+fragment[$counter]))"
            if [ $fragmentstart -gt 99 ] ; then
            let secondstart++ ; fragmentstart=$(($fragmentstart-100)) ; fi
        fi

        let counter++
        let trackcounter++

        #echo "START    = $minutestart $secondstart $fragmentstart" 
        #echo "DURATION = ${minute[$counter]} ${second[$counter]} ${fragment[$counter]}"

#        if [ $trackcounter -gt 9 ] ; then trackname=md.track$counter.wav
        if [ $trackcounter -gt 9 ] ; then trackname=md.track$trackcounter.wav
        else trackname=md.track0$trackcounter.wav ; fi

        if [ -e $trackname ] ; then mv $trackname $trackname.${datetime}.bak ; fi

        if [ $trackcounter -eq ${#minute[@]} ] ; then
            sox minidisc.wav $trackname trim ${minutestart}:${secondstart}.${fragmentstart}
            #echo "IF $trackname"
        else
            #echo "$trackname"
            sox minidisc.wav $trackname trim ${minutestart}:${secondstart}.${fragmentstart} ${minute[$counter]}:${second[$counter]}.${fragment[$counter]}
        fi

        echo "`ls -lh $trackname`"
    done

    pak

}

tracklistfrommd(){
    local rc1 ; local rc2 ; local datetime=`date +%g%m%d%H%M%S` 

    setstatus
    rc1=`lsusb|grep Sony|grep 'Net MD' > /dev/null ; echo $?`
    rc2=`which netmdcli > /dev/null ; echo $?`
    if [ $rc1 -ne 0 ] || [ $rc2 -ne 0 ] ; then echo "No net MD device found or missing netmdcli.";echo;pak;return;fi 

    if [ -e $MDTRACKLIST ] ; then mv $MDTRACKLIST $MDTRACKLIST.$datetime.bak ; fi

    netmdcli | head -n -4 | tail -n +5 | awk '{print $6}' | awk -F":" '{print $1 " " $2 " " $3}' > $MDTRACKLIST
    echo "Duration of tracks in minutes, seconds and fragments:" ; echo
    cat $MDTRACKLIST | more -21 ; echo ; pak ; mkgreen
    #echo ; pak

}

splittracks(){
    local trackname ; local tracksize ; local tracksplit
    local minute ; local second ; local fragment ; local duration
    local newtrackone ; local newtracktwo ; local oldtrack
    local tracknumber=1 ; local trackcnt ; local trackcounter=0
    local datetime ; local newfile
    local yn

    # test if sound files exist
    trackname=(`ls -l md.track*.wav | awk '{print $9}' 2>/dev/null`)

    # print warning or take count
    if [ ${#trackname[@]} -eq 0 ] ; then 
        echo ; echo "No soundfiles found. Please correct this. "
        echo ; pak ; return
    else
        trackcnt=${#trackname[@]}
        tracksize=(`ls -lh md.track*.wav | awk '{print $5'}`)
    fi

    #print tracks
    until [ $trackcounter -eq $trackcnt ] ; do
        tracknumber=$trackcounter
        if [ $trackcounter -lt 10 ] ; then tracknumber=" $trackcounter" ; fi
        duration=`mediainfo ${trackname[$trackcounter]} |grep Duration | awk -F":" '{print $2}' |uniq`
        echo "$tracknumber ${trackname[$trackcounter]} ${tracksize[$trackcounter]} $duration"
        let trackcounter++
        let tracknumber++
    done

        echo
        echo "Please enter track number of the file to split:"
        echo

        while true ; do
            read -p "Track to split: " tracksplit
            echo
            datetime=`date +%g%m%d%H%M%S`
            oldtrack=`ls ${trackname[$tracksplit]} | awk -F. '{print $1 "." $2}'`
            newtrackone="${oldtrack}.1.wav"
            newtracktwo="${oldtrack}.2.wav"
            echo "old track : ${trackname[$tracksplit]} -> ${trackname[$tracksplit]}.${datetime}.bak"
            echo "New tracks: $newtrackone & $newtracktwo"
            echo
            read -N1 -p  "Is this information correct? " yn
            case $yn in
                [Yy]* ) echo ; break ;;
                [Nn]* ) echo ;;
                $END|0) return ;;
                * ) KEY="!" ; echo ; echo "Please answer yes or no." ; echo ;;
            esac
        done

        echo ; echo "Please enter the following information:" ; echo

        while true ; do
            read -p "Minute  : " minute
            read -p "Seconds : " second
            read -p "Fragment: " fragment
            echo
            read -N1 -p  "Is this information correct? " yn
            case $yn in
                [Yy]* ) 
                    soxcmd1="sox ${trackname[$tracksplit]} $newtrackone trim 0 $minute:$second.$fragment"
                    soxcmd2="sox ${trackname[$tracksplit]} $newtracktwo trim $minute:$second.$fragment"
                    echo ; echo ; break ;;
                [Nn]* ) echo ;;
                $END|0) return ;;
                * ) KEY="!" ; echo ; echo "Please answer yes or no." ; echo ;;
            esac
        done

        echo "Processing $newtrackone..."
        eval $soxcmd1
        echo
        echo "Processing $newtracktwo..."
        eval $soxcmd2
        echo
        mv ${trackname[$tracksplit]} ${trackname[$tracksplit]}.${datetime}.bak
        echo "Ready!"
        echo
        pak
}

jointracks(){
    local trackname ; local tracksize ; local duration
    local tracknumber=1 ; local trackcnt ; local trackcounter=0
    local trackone ; local tracktwo
    local datetime ; local newfile
    local yn

    # test if sound files exist
    trackname=(`ls -l md.track*.wav | awk '{print $9}' 2>/dev/null`)

    # print warning or take count
    if [ ${#trackname[@]} -eq 0 ] ; then 
        echo ; echo "No soundfiles found. Please correct this. "
        echo ; pak ; return
    else
        trackcnt=${#trackname[@]}
        tracksize=(`ls -l md.track*.wav | awk '{print $5'}`)
    fi

    #print tracks
    until [ $trackcounter -eq $trackcnt ] ; do
        tracknumber=$trackcounter
        if [ $trackcounter -lt 10 ] ; then tracknumber=" $trackcounter" ; fi
        duration=`mediainfo ${trackname[$trackcounter]} |grep Duration | awk -F":" '{print $2}' |uniq`
        echo "$tracknumber ${trackname[$trackcounter]} ${tracksize[$trackcounter]} $duration"
        let trackcounter++
        let tracknumber++
    done

        echo
        echo "Please enter track numbers of the files to join:"
        echo

        while true ; do
            read -p "Track 1: " trackone
            read -p "Track 2: " tracktwo
            echo
            read -N1 -p  "Is this information correct? " yn
            case $yn in
                [Yy]* ) soxcmd="sox ${trackname[$trackone]} ${trackname[$tracktwo]} md.track.temp.wav" ; echo ; echo ; break ;;
                [Nn]* ) echo ;;
                $END|0) return ;;
                * ) KEY="!" ; echo ; echo "Please answer yes or no." ; echo ;;
            esac
        done

        datetime=`date +%g%m%d%H%M%S` 
        eval $soxcmd
        mv ${trackname[$trackone]}  ${trackname[$trackone]}.${datetime}.bak
        mv ${trackname[$tracktwo]}  ${trackname[$tracktwo]}.${datetime}.bak
        mv md.track.temp.wav  ${trackname[$tracktwo]}
        newfile=`ls -l ${trackname[$tracktwo]} | awk '{print $9 "  " $5 }'`
        echo "New file: $newfile"
        echo
        pak
}

splittracksbysilence(){
    local yn ; local soxduration=5.0 ; local soxthreshold=0.05 ; local soxcmd
    local ccdafile ; local cddacounter=0 ; local datetime ; local rc

    if [ -e minidisc.wav ] ; then
        echo "Please enter the following information:"
        echo

        while true ; do
            read -e -p "Duration : " -i "$soxduration" soxduration
            read -e -p "Threshold: " -i "$soxthreshold" soxtrhreshold
            echo
            read -N1 -p  "Is this information correct? " yn
            case $yn in
                [Yy]* ) soxcmd="sox minidisc.wav md.track.wav silence -l 0 1 $soxduration $soxthreshold% : newfile : restart"
                        echo ; echo ; break ;;
                [Nn]* ) echo ;;
                $END|0) return ;;
                * ) KEY="!" ; echo ; echo "Please answer yes or no." ; echo ;;
            esac
        done

        # backup previous rips
        rc=`ls md.track*.wav > /dev/null 2>&1 ; echo $?`
        if [ $rc -eq 0 ] ; then cddafile=(`ls md.track*.wav`)
            datetime=`date +%g%m%d%H%M%S` 
            while [ "$cddacounter" -lt "${#cddafile[@]}" ] ; do
                mv ${cddafile[$cddacounter]}  ${cddafile[$cddacounter]}.${datetime}.bak
                let cddacounter++
            done
        fi

        echo "Split tracks by silent gaps. Working..."
        eval $soxcmd
        echo ; ls md.track*wav | more -21 ; echo ; pak
    else
        echo "No minidisc rip file found" ; pak
    fi
}

# MENU AND DISPLAY FUNCTIONS
listprog(){
    echo "${PROGSHOWNAME} / ${PROGDESCRIPTION} / ${PROGVERSION}"
    echo
}

listodstatus(){
    local wd
    local rc=`echo \`pwd\` | grep omrecorder > /dev/null ; echo $?`
    
    if [ $rc -ne 0 ] ; then wd="" ; else wd=" | W" ; fi

    if [ $OD_MEDIA_STATUS -eq 0 ] ; then
        echo "${OD_INFO} | COMMAND = $COMMAND | KEY = $KEY | `basename "$PWD"`$wd"
    else
        echo "NO DISC | COMMAND = $COMMAND | KEY = $KEY | `basename "$PWD"`$wd"
    fi
    echo
}

pak(){
#    echo
    echo "Press any key to continue"
    read -s -N1 tmp
}

setstatus(){
    clear; listprog; listodstatus
}

helpmainmenu(){
    setstatus
    echo "PROBLEMS"
    echo "--------"
    echo "cd status = NO DISC after closing tray: wait a few and press P again"
    echo
    echo "HINTS"
    echo "-----"
    echo "Hits are coming up: working..."
    echo
    pak
}


listmainmenu(){
    echo "A. Copy CD"
    echo "B. Rip CD"
    echo "C. Rip MD"
    echo "D. Split tracks"
    echo "E. Level volume"
    echo "F. Edit / create TOC"
    echo "G. Edit / create playlist"
    echo "H. Edit / create titlelist"
    echo "I. Edit / create PCM files"
    echo "J. Burn CD"
    echo "K. Record MD"
    echo "L. Rename MD"
    echo "M. Edit / create compressed files"
    echo "N. Create mp3 CD / Music DVD"
    echo "O. Eject CD tray"
    echo "P. Close CD tray / 2nd: get CD status"
    echo "Q. List"
    echo "R. Midnight Commander"
    echo "S. Shell"
#    tmpdebug
}

mkgreen(){
    if [ "$DEVTTY" -eq "0" ] ; then echo -e "\[\033[0;32m" ; fi
}

refresh(){
    mkgreen
    case $LIST in
        main)
            listprog; listodstatus; listmainmenu;;
        record)
            listprog; listodstatus; listrecordmenu;;
        options)
            listprog; listodstatus; listoptions;;
    esac
}

# DEBUG DISPLAY
abc(){
echo "ABC is het alfabet" ; echo ; pak
}

klm(){ 
echo "KLM is een een vliegenierstoestand" ; echo ; pak
}

xyz(){
echo "XYZ is een assenstelsel" ; echo ; pak
}

tmpdebug(){
    echo "OD_TYPE=$OD_TYPE";pak
}


todo(){
echo "T O   D O : "
echo "BUGS BUGS BUGS BUGS BUGS BUGS BUGS"
echo "Create Compressed files: 
Creating 1 flacs...
sox FAIL formats: can't open input file \`8': No such file or directory
ls: cannot access '01.flac': No such file or directory
Tagging 1 flags..."
echo "Something with passing on array....? dlkvk"
echo "FUNCTIONALITY:"
echo "Copy CD A, mp3Cd musicDVD, Musicbrainz"
echo "INTEGRETY:"
echo "sanity check files playlist, titlelist... something is done"
echo "sanity check cdtoc.txt... I think I'm ready enough"
echo "TUNING"
echo "Ffmpeg filters?"
echo "MISC:"
echo "dlkvkband for test :-)"
echo "WORKING NOW: " 
echo "0-0-0-0-0-0-0-0-0-0-0-0-"
echo ":-) :-( :-| :-D ;-) :-?"
echo "0-0-0-0-0-0-0-0-0-0-0-0-"
}

## MAIN (THE REAL ONE :-)
echo "file = $PROGFILENAME | version = $PROGVERSION"
echo "$PROGDESCRIPTION"
echo "=================================="

if [ `basename "$PWD"` == ${USER} ] ; then
    echo -e "Current directory equal to homedirectory. Please change to or create\n$WORKDIR/ALBUM and start this program again." ; pak ; exit
fi


read -sN1 -t $PAUSE tmp

until [ $MAINLOOP -eq 0 ] ; do
    clear
    refresh
    readKey

    case $KEY in
        0|$END|$ESCAPE)
            COMMAND="quit"
            doHUP ;;
        A|a)
            COMMAND="copy cd";;
        B|b)
            COMMAND="rip cd";ripcd;;
        C|c)
            COMMAND="rip md";ripmd;;
        D|d)
            COMMAND="split tracks";menusplittracks;;
        E|e)
            COMMAND="level volume";;
        F|f)
            COMMAND="edit toc";mdtoc;;
        G|g)
            COMMAND="edit playlist";menuplaylist;;
        H|h)
            COMMAND="edit titlelist";menutitlelist;;
        I|i)
            COMMAND="edit pcm";menupcmfiles;;
        J|j)
            COMMAND="burn cd";menuburncd;;
        K|k)
            COMMAND="record md";recordmd;;
        L|l)
            COMMAND="rename md";renamemd;;
        M|m)
            COMMAND="create compressed files";menucompressedfiles;;
        N|n)
            COMMAND="create mp3 cd / music dvd";;
        O|o)
            COMMAND="eject"
            eject ; OD_MEDIA_STATUS=1  ;;
        P|p)
            COMMAND="close tray"
            eject -t ; OD_INFO="NO DATA"; setstatus ; echo "Working..."; readodstatus  ;;
        Q|q)
            COMMAND="list"
            setstatus ; pwd ; echo ; ls | more -21 ; echo; pak ;;
        R|r)
            COMMAND="mc"
            mc ;;
        S|s)
            COMMAND="shell"
            setstatus; bash --rcfile <(cat ~/.bashrc ; echo 'PS1="\[\033[0;33m\]\u@omrecorder:\W>\[\033[00m\] "');;

        $F01)
            COMMAND="help"
            helpmainmenu ;;
        *)
            COMMAND="unknown command"
            KEY="?" ;;

    esac
    if [ $KEY == $END ] ; then KEY="END" ; fi
done


# T O   D O   L I S T

# N O T E S
#                    echo -e "\033[23;01H\033[0;32mSong   = $FDTRACKTITLE"

#copy cd
#####!/bin/bash
#function getkey()
#{
#    read yourentry
#}

#DEV=/dev/scd0
#TMP_FILE=/tmp/cd_data.raw
#echo Enter the CD to copy from:
#getkey

#readom dev=${DEV} -nocorr f=${TMP_FILE}
#echo Please enter a blank CD/DVD and press enter when ready ....
#getkey

###readom dev=${DEV} -w -nocorr f=${TMP_FILE}
#wodim dev=${DEV} -setdropts driveropts=singlesession
#wodim dev=${DEV} -dao -v ${TMP_FILE}

#wodim -eject



#### View tags with their own file type programs
#### I used the generic mediainfo program instead (dlkvk)
####
#    case $hdtracktype in
#        flac) 
#            while [ $pointer -lt ${#hdtracks[@]} ] ; do
#                echo "File: ${hdtracks[$pointer]}" >> $tmpfile
#                echo `metaflac --list ${hdtracks[$pointer]} |grep ALBUM | cut -c 17-`  >> $tmpfile
#                echo `metaflac --list ${hdtracks[$pointer]} |grep ARTIST | cut -c 17-`  >> $tmpfile
#                echo `metaflac --list ${hdtracks[$pointer]} |grep TITLE | cut -c 17-`  >> $tmpfile
#                echo >> $tmpfile
#                let counter++ ; let pointer++
#            done
#            ;;
#        wav) echo "wav" >> $tmpfile ; echo >> $tmpfile
#;;
#        mp3) 
#            while [ $pointer -lt ${#hdtracks[@]} ] ; do
#                echo "File: ${hdtracks[$pointer]}" >> $tmpfile
#                echo `mp3info -p "ALBUM=%l" ${hdtracks[$pointer]}` >> $tmpfile
#                echo `mp3info -p "ARTIST=%a" ${hdtracks[$pointer]}` >> $tmpfile
#                echo `mp3info -p "TITLE=%t" ${hdtracks[$pointer]}` >> $tmpfile
#                echo >> $tmpfile
#                let counter++ ; let pointer++
#            done
#        ;;
#        ogg) echo ogg >> $tmpfile ; echo >> $tmpfile
#;;
#        opus) echo opus >> $tmpfile ; echo >> $tmpfile
#;;
#        *) ;;
#    esac


#for f in *\ *; do cp "$f" "${f// /_}"; done
#for f in *\ *; do mv "$f" "${f// /_}"; done
