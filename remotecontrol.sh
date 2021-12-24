#!/bin/bash
##
PROGVERSION=2021122401
##
PROGFILENAME=remotecontrol.sh
##
PROGNAME=
##
PROGDESCRIPTION="grid remote control / GRC-8024"
##
PROGAUTHOR="dlkvk"
##
## Notes
## 
## 2021121901 start writing code. This is a rewrite of dircontrol 20201126
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

if [ $DEVTTY -eq 0 ] ; then KOLOR="0;04"
else KOLOR="01;36" ; fi


declare KEY=0
declare KEYS=0
declare MAINLOOP=1
declare COMMAND="waiting your command"
declare LIST="main"
declare DEVICE="UNKNOWN"
#declare -r TMPDIR="/dev/shm"
#declare -r PRINTDIR="$HOME/.cache/amdb"
#mkdir -p $PRINTDIR
#declare -r SQL="psql -d amdb -c "
#declare DATEHOUR

# infrared devices and commands
declare IRCOMMAND="irsend SEND_ONCE"	    # lircd command
declare IRCMD="irsend SEND_ONCE"	    # lircd command

# 1. minidsic
declare IRMD="rm-d29m" #IRDD29			    # sony ir commands
declare IRMDCHAR="rm-d10p" #IRD10			# sony ir characters 
declare IRMDCOM="RM-D7M" #IRD7M			    # sony ir commands

# 2. cpmpact disc
declare IRCD="yamahaCd_VV27520" #YACD1

# 3. receiver
declare IRRCV="pioneerReceiver_CU-SX109" #IRSX109 # pioneer ir commands

# 4. sony dvd
declare IRDVD="sonydvd" #DVD
declare IRRF="philips" #DVD (RF modulator only)

# 5. sony vhs
declare IRVHS1="Sony_RMT-V256_1" #VHS SONY SLV-SE60 - RMT-V256A 
declare IRVHS2="Sony_RMT-V256_2" #VHS SONY SLV-SE60 - RMT-V256A 
declare IRVHSA="Sony-RMT-V256A" #VHS SONY SLV-SE60 - RMT-V256A

# 6. denon cassettedeck
declare IRCT="denoncassettedeck" #CC

# 7. samsung tv
declare IRTV="samsungTv_BN59-00865A"

# 991 / 998 - tonli auxilery av selector
declare IRAUX="tonli" #IRT			        # tonli AV selector


## FUNCTIONS

## internal functions

doKill(){
    echo "0-0-0-0-0-0-0-0-0-0-0-0-"
    fortune bofh-excuses
    echo "0-0-0-0-0-0-0-0-0-0-0-0-"
    todo
    echo bye
#    if [ -e "$CDDATAFILE" ] ; then rm $CDDATAFILE ; fi
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

read3Key(){
    local device ; local command
    unset key1 key2 key3

    read -s -N1
    key1="$REPLY" # ; if [ $key1 = $ENTER ] ; then key1=0 ; fi #ToDo testKey
    echo -e "\033[23;69H$key1"

    if [ "$key1" = "/" ] || [ "$key1" = "*" ] || [ "$key1" = "-" ] || [ "$key1" = "+" ]  || [ "$key1" = "." ] ; then
        KEYS=$key1
        return
    else
        read -s -N1
        key2="$REPLY" # ; if [ $key2 = $ENTER ] ; then key1=0 ; fi
    echo -e "\033[23;70H$key2"
        read -s -N1
        key3="$REPLY" #; if [ $key3 = $ENTER ] ; then key1=0 ; fi
    echo -e "\033[23;71H$key3"
    fi

    if [ $key1 -gt 0 ] && [ $key1 -lt 10 ] ; then
        KEYS="${key1}${key2}${key3}"
    else
        KEYS=0
    fi

    device="${key1}${key2}"
    case $device in
        #X1z - X4z GROUP
        11|12|13|14) DEVICE="minidisc";;
        21|22|23|24) DEVICE="compact disc";;
        31|32|33|34) DEVICE="receiver";;
        41|42|43|44) DEVICE="dvd";;
        51|52|43|44) DEVICE="vhs";;
        61|62|63|64) DEVICE="cassettedeck";;    
        71|72|73|74) DEVICE="tv";;
        81|82|83|84) DEVICE="unixrecoder";;

        #X5z - X8z GROUP
        15|16|17|18) DEVICE="bluray";;
        25|26|27|28) DEVICE="tv tuner";;
        35|36|37|38) DEVICE="dab radio";;
        45|46|47|48) DEVICE="dreambox";;
#        |||) DEVICE="";;
        *) DEVICE="UNKNOWN"
    esac

    command="${key2}${key3}"
    case $command in
        #main
        11|51) COMMAND="play";;
        12|52) COMMAND="stop";;
        13|53) COMMAND="pause";;
        14|54) COMMAND="rewind";;
        15|55) COMMAND="eject";;
        16|56) COMMAND="fast forward";;
        17|57) COMMAND="previous track";;
        18|58) COMMAND="power";;
        19|59) COMMAND="next track";;

        #arrow array
        21|61) COMMAND="return";;
        22|62) COMMAND="arrow down";;
        23|63) COMMAND="av down";;
        24|64) COMMAND="arrow left";;
        25|65) COMMAND="ok";;
        26|66) COMMAND="arrow right";;
        27|37) COMMAND="exit";;
        28|28) COMMAND="arrow up";;
        29|69) COMMAND="av up";;

        #audio &video
        31|71) COMMAND="aspect";;
        32|72) COMMAND="volume down";;
        33|73) COMMAND="home";;
        34|74) COMMAND="subtitle";;
        35|75) COMMAND="tools";;
        36|76) COMMAND="menu";;
        37|77) COMMAND="audio";;
        38|78) COMMAND="volume up";;
        39|79) COMMAND="disc menu";;

        #auxilery control
        41|81) COMMAND="guide";;
        42|82) COMMAND="info";;
        43|83) COMMAND="band";;
        44|84) COMMAND="yellow";;
        45|85) COMMAND="scroll";;
        46|86) COMMAND="class";;
        47|87) COMMAND="red";;
        48|88) COMMAND="green";;
        49|89) COMMAND="blue";;
#        |) COMMAND="";;
    esac
}

# MENU AND DISPLAY FUNCTIONS
listprog(){
    echo "${PROGSHOWNAME} / ${PROGDESCRIPTION} / ${PROGVERSION}"
    echo
}

liststatus(){
#    echo "COMMAND = $COMMAND | KEY = $KEY"
    echo "DEVICE = $DEVICE | COMMAND = $COMMAND | INPUT = $KEYS"
    echo
}

pak(){
    echo "Press any key to continue"
    read -s -N1 tmp
}

setstatus(){
    clear; listprog ; liststatus
}

helpmainmenu(){
    setstatus

    cat <<EOF | more -19
HINTS
=====

EOF
    echo ; pak
}

mkgreen(){
#    if [ "$DEVTTY" -eq "0" ] ; then echo -e "\[\033[0;32m" ; fi
#    echo -e "\[\033[0;32m"
AAAAAAAAAAAAAAAAAAAAAAA="A"
}

mkallgreen(){
    echo -e "\[\033[0;32m"
}

refresh(){
    mkgreen
    case $LIST in
        main)
            listprog; liststatus; listmainmenu;;
#            listprog; listmainmenu;;
        editmd)
            listprog; liststatus; listrecordmenu;;
        options)
            listprog; liststatus; listoptions;;
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
echo "FUNCTIONALITY: read3Key do case catch enter and all other evil"
echo "INTEGRETY: "
echo "TUNING"
echo "MISC:"
echo "WORKING NOW: "
echo "0-0-0-0-0-0-0-0-0-0-0-0-"
echo ":-) :-( :-| :-D ;-) :-?"
echo "0-0-0-0-0-0-0-0-0-0-0-0-"
}

listmainmenu(){
    ## FIRST GROUP
    echo -e "\033[05;01H\033[${KOLOR}mx1Z / x5Z KEYS main\033[0;32m"
    echo -e "\033[06;01H7. previous"
    echo -e "\033[07;01H4. rewind"
    echo -e "\033[08;01H1. play"

    echo -e "\033[06;15H8. power"
    echo -e "\033[07;15H5. eject"
    echo -e "\033[08;15H2. stop"

    echo -e "\033[06;30H9. next"
    echo -e "\033[07;30H6. fst forward"
    echo -e "\033[08;30H3. pause"

    ## SECOND GROUP
    echo -e "\033[10;01H\033[${KOLOR}mx2Z / x6Z KEYS arrow array\033[0;32m"
    echo -e "\033[11;01H7. exit"
    echo -e "\033[12;01H4. left"
    echo -e "\033[13;01H1. return"

    echo -e "\033[11;15H8. up"
    echo -e "\033[12;15H5. ok"
    echo -e "\033[13;15H2. down"

    echo -e "\033[11;30H9. av up"
    echo -e "\033[12;30H6. right"
    echo -e "\033[13;30H3. av down"

    ## THIRD GROUP
    echo -e "\033[15;01H\033[${KOLOR}mx3Z / x7Z KEYS audio & video\033[0;32m"
    echo -e "\033[16;01H7. audio"
    echo -e "\033[17;01H4. subtitle"
    echo -e "\033[18;01H1. aspect"

    echo -e "\033[16;15H8. volume up"
    echo -e "\033[17;15H5. tools"
    echo -e "\033[18;15H2. volume down"

    echo -e "\033[16;30H9. disc menu"
    echo -e "\033[17;30H6. menu"
    echo -e "\033[18;30H3. home"

    ## FORTH GROUP
    echo -e "\033[20;01H\033[${KOLOR}mx4Z / x8Z KEYS auxilery control\033[0;32m"
    echo -e "\033[21;01H7. red"
    echo -e "\033[22;01H4. yellow"
    echo -e "\033[23;01H1. guide"

    echo -e "\033[21;15H8. green"
    echo -e "\033[22;15H5. scroll"
    echo -e "\033[23;15H2. info"

    echo -e "\033[21;30H9. blue"
    echo -e "\033[22;30H6. class"
    echo -e "\033[23;30H3. band"


    ## 100
    echo -e "\033[05;45H\033[${KOLOR}mX1z - X4z GROUP\033[0;32m"
    echo -e "\033[06;45H1. minidisc"
    echo -e "\033[07;45H2. compact disc"
    echo -e "\033[08;45H3. receiver"
    echo -e "\033[09;45H4. dvd"
    echo -e "\033[10;45H5. vhs"
    echo -e "\033[11;45H6. cassettedeck"
    echo -e "\033[12;45H7. tv"
    echo -e "\033[13;45H8. unixrecorder"

    echo -e "\033[15;45H\033[${KOLOR}mX5z - X8z GROUP\033[0;32m"
    echo -e "\033[16;45H1. bluray"
    echo -e "\033[17;45H2. tv tuner"
    echo -e "\033[18;45H3. dab radio"
    echo -e "\033[19;45H4. dreambox"
    echo -e "\033[20;45H5. "
    echo -e "\033[21;45H6. "
    echo -e "\033[22;45H7. "
    echo -e "\033[23;45H8. "

    ## 900
    echo -e "\033[05;63H\033[${KOLOR}m9YZ GROUP\033[0;32m"
    echo -e "\033[06;63H991 unixrecorder"
    echo -e "\033[07;63H992 dab radio"
    echo -e "\033[08;63H993 dreambox"
    echo -e "\033[09;63H994 cd"
    echo -e "\033[10;63H995 md"
    echo -e "\033[11;63H996 pc"
    echo -e "\033[12;63H997 dvd"
    echo -e "\033[13;63H998 receiver"
    echo -e "\033[14;63H981 loudness"
    echo -e "\033[15;63H982 tape2"
    echo -e "\033[16;63H988 record md"
    echo -e "\033[17;63H977 edit md"
    echo -e "\033[18;63H961 md play mode"
    echo -e "\033[19;63H951 cd play mode"
    echo -e "\033[20;63H941 wol pc"
    echo -e "\033[21;63H911 quit"

    echo -e "\033[23;63H\033[${KOLOR}mINPUT=xyz\033[0;32m"




echo -e "\033[23;79H "
}

## MAIN (THE REAL ONE :-)
echo "file = $PROGFILENAME | version = $PROGVERSION"
echo "$PROGDESCRIPTION"
echo "=================================="

if [ "$DEVTTY" -eq "0" ] ; then tput civis ; fi
mkallgreen

#read -sN1 -t $PAUSE tmp

until [ $MAINLOOP -eq 0 ] ; do
    clear
    refresh ; read3Key #; mkgreen
#    refresh ; readKey ; mkgreen

    case $KEYS in
#    case $KEY in
        911) COMMAND="quit";doHUP ;;
        941) /local/bin/wol birmingham ;;

        # COMMON KEYS
        -) $IRCOMMAND $IRRCV KEY_VOLUMEDOWN;DEVICE="receiver";COMMAND="main volume down";;
        +) $IRCOMMAND $IRRCV KEY_VOLUMEUP;DEVICE="receiver";COMMAND="main volume up";;
        /) $IRCOMMAND $IRRCV function;DEVICE="receiver";COMMAND="av select";;
        '*') $IRCOMMAND $IRTV KEY_CYCLEWINDOWS;DEVICE="tv";COMMAND="av select";;
        .) $IRCOMMAND $IRRCV muting;DEVICE="receiver";COMMAND="muting";;

        # AUX SELECTOR and Other/ 900
        991) $IRCOMMAND $IRAUX KEY_1;DEVICE="Auxilery";COMMAND="Aux1";;
        992) $IRCOMMAND $IRAUX KEY_2;DEVICE="Auxilery";COMMAND="Aux2";;
        993) $IRCOMMAND $IRAUX KEY_3;DEVICE="Auxilery";COMMAND="Aux3";;
        994) $IRCOMMAND $IRAUX KEY_4;DEVICE="Auxilery";COMMAND="Aux4";;
        995) $IRCOMMAND $IRAUX KEY_5;DEVICE="Auxilery";COMMAND="Aux5";;
        996) $IRCOMMAND $IRAUX KEY_6;DEVICE="Auxilery";COMMAND="Aux6";;
        997) $IRCOMMAND $IRAUX KEY_7;DEVICE="Auxilery";COMMAND="Aux7";;
        998) $IRCOMMAND $IRAUX KEY_8;DEVICE="Auxilery";COMMAND="Aux8";;
        988) $IRCOMMAND $IRMD KEY_RECORD;DEVICE="minidisc";COMMAND="record";;
        988) $IRCOMMAND $IRMDCOM KEY_WRITE_NAME;DEVICE="minidisc";COMMAND="edit";;
        951) $IRCOMMAND $IRCD KEY_AGAIN;DEVICE="compact disc";COMMAND="repeat";;
        961) $IRCOMMAND $IRMD KEY_AGAIN;DEVICE="minidisc";COMMAND="repeat";;
        981) $IRCOMMAND $IRRCV loudness;DEVICE="receiver";COMMAND="loudness";;
        982) $IRCOMMAND $IRRCV Monitor;DEVICE="receiver";COMMAND="tape2";;

        # MINIDISC / 11 12 13 14
        111) $IRCOMMAND $IRMD KEY_PLAY ;;
        112) $IRCOMMAND $IRMD KEY_STOP ;;
        113) $IRCOMMAND $IRMD KEY_PAUSE ;;
        115) $IRCOMMAND $IRMD KEY_EJECTCD ;;
        117) $IRCOMMAND $IRMD skip_back ;;
        118) $IRCOMMAND $IRMD KEY_POWER ;;
        119) $IRCOMMAND $IRMD skip_forw ;;

        142) $IRCOMMAND $IRMD display ;;
        145) $IRCOMMAND $IRMD scroll ;;

        # COMPACT DISC / 21 22 23 24
        211) $IRCOMMAND $IRCD KEY_PLAY;;
        212) $IRCOMMAND $IRCD STOP ;;
        213) $IRCOMMAND $IRCD PAUSE ;;
        214) $IRCOMMAND $IRCD SEARCH_BACK ;;
        215) $IRCOMMAND $IRCD KEY_OPEN ;;
        216) $IRCOMMAND $IRCD SEARCH_FORWARD ;;
        217) $IRCOMMAND $IRCD SKIP_BACK ;;
        219) $IRCOMMAND $IRCD SKIP_FORWARD ;;

        224) $IRCOMMAND $IRCD DISC_SKIP_BCK ;;
        226) $IRCOMMAND $IRCD DISC_SKIP_FORWARD ;;

        242) $IRCOMMAND $IRCD KEY_TIME ;;

        #$IRCOMMAND $IRCD PROG
        #$IRCOMMAND $IRCD RANDOM
        #$IRCOMMAND $IRCD DISC_SCAN
        
        # RECEIVER / 31 32 33 34
        318) $IRCOMMAND $IRRCV KEY_RECORD;; #KEY_RECORD = POWER :-(

        323) $IRCOMMAND $IRRCV tunerdown;;
        329) $IRCOMMAND $IRRCV tunerup;;

        342) $IRCOMMAND $IRRCV displaymode;;
        346) $IRCOMMAND $IRRCV class;;
        343) $IRCOMMAND $IRRCV fmam;;


        # DVD / 41 42 43 44
        411) $IRCOMMAND $IRDVD KEY_PLAY;;
        412) $IRCOMMAND $IRDVD KEY_STOP;;
        413) $IRCOMMAND $IRDVD KEY_PAUSE ;;
        415) $IRCOMMAND $IRDVD KEY_EJECTCD ;;
        417) $IRCOMMAND $IRDVD KEY_PREVIOUS ;;
        418) $IRCOMMAND $IRDVD KEY_POWER;;
        419) $IRCOMMAND $IRDVD KEY_NEXT ;;

        421) $IRCOMMAND $IRDVD KEY_EXIT;;
        422) $IRCOMMAND $IRDVD KEY_DOWN;;
        423) $IRCOMMAND $IRDVD KEY_CHANNEL_UP;;
        424) $IRCOMMAND $IRDVD KEY_LEFT;;
        425) $IRCOMMAND $IRDVD KEY_OK;;
        426) $IRCOMMAND $IRDVD KEY_RIGHT;;
        427) $IRCOMMAND $IRDVD KEY_EXIT;;
        428) $IRCOMMAND $IRDVD KEY_UP;;
        429) $IRCOMMAND $IRDVD KEY_CHANNELDOWN;;

        433) $IRCOMMAND $IRDVD KEY_TITLE;;
        434) $IRCOMMAND $IRDVD KEY_SUBTITLE;;
        436) $IRCOMMAND $IRDVD KEY_MENU;;
#        437) $IRCOMMAND $IRDVD audio;;
        439) $IRCOMMAND $IRDVD KEY_CONTEXT_MENU;;
 
        442) $IRCOMMAND $IRDVD KEY_INFO;;
        445) $IRCOMMAND $IRDVD KEY_DISPLAYTOGGLE;;
#        447) $IRCOMMAND $IRRF KEY_POWER KEY_POWER KEY_POWER;; #red
        447) $IRCOMMAND $IRRF KEY_POWER ;; #red
        448) $IRCOMMAND $IRDVD KEY_TV;; #green

        # VHS SONY / 51 52 53 54
        # This machine has everything to be told twice :-(
        511) $IRCOMMAND $IRVHS2 KEY_PLAY KEY_PLAY ;;
        512) $IRCOMMAND $IRVHS2 KEY_STOP KEY_STOP;;
        513) $IRCOMMAND $IRVHS2 KEY_PAUSE KEY_PAUSE;;
        514) $IRCOMMAND $IRVHS2 KEY_REWIND KEY_REWIND;;
        515) $IRCOMMAND $IRVHS1 KEY_EJECTCD KEY_EJECTCD;;
        516) $IRCOMMAND $IRVHS2 KEY_FASTFORWARD KEY_FASTFORWARD;;
        518) $IRCOMMAND $IRVHS1 KEY_POWER KEY_POWER;;

        527) $IRCOMMAND $IRVHS1 KEY_CLEAR KEY_CLEAR ;;

        542) $IRCOMMAND $IRVHS1 display display;;
        547) $IRCOMMAND $IRVHS1 KEY_SLOW KEY_SLOW;;
        548) $IRCOMMAND $IRVHS1 counter/remain counter/remain;;
        # 5) $IRCOMMAND $IRVHS KEY ;;

        # cassettedeck / 61 62 63 64
        611) $IRCOMMAND $IRCT TAPE_PLAY ;;
        612) $IRCOMMAND $IRCT TAPE_STOP ;;
        613) $IRCOMMAND $IRCT TAPE_PAUSE ;;
        614) $IRCOMMAND $IRCT TAPE_REW ;;
        616) $IRCOMMAND $IRCT TAPE_FF ;;
        647) $IRCOMMAND $IRCT TAPE_REC ;;
        #TAPE_AB TAPE PLAYREV

        # TV / 71 72 73 74
        718) $IRCOMMAND $IRTV KEY_POWER ;;

        721) $IRCOMMAND $IRTV KEY_ENTER ;;
        722) $IRCOMMAND $IRTV KEY_DOWN ;;
        723) $IRCOMMAND $IRTV KEY_CHANNELDOWN ;;
        724) $IRCOMMAND $IRTV KEY_LEFT ;;
        725) $IRCOMMAND $IRTV ENTER_OK ;;
        726) $IRCOMMAND $IRTV KEY_RIGHT ;;
        727) $IRCOMMAND $IRTV KEY_EXIT ;;
        728) $IRCOMMAND $IRTV KEY_UP ;;
        729) $IRCOMMAND $IRTV KEY_CHANNELUP ;;

        # 731) $IRCOMMAND $IRTV KEY_ aspect?  ;;
        732) $IRCOMMAND $IRTV KEY_VOLUMEDOWN ;;
        734) $IRCOMMAND $IRTV KEY_SUBTITLE ;;
        735) $IRCOMMAND $IRTV TOOLS ;;
        736) $IRCOMMAND $IRTV KEY_MENU ;;
        738) $IRCOMMAND $IRTV KEY_VOLUMEUP ;;

        742) $IRCOMMAND $IRTV KEY_INFO ;;
        744) $IRCOMMAND $IRTV KEY_YELLOW ;;
        747) $IRCOMMAND $IRTV KEY_RED ;;
        748) $IRCOMMAND $IRTV KEY_GREEN ;;
        749) $IRCOMMAND $IRTV KEY_BLUE ;;

        # BLURAY / 81 82 83 84

        # UNIXRECORDER / 91 92 93 94
        811) $IRCOMMAND $IRRCV cdplay ;; #play '*'
        812) $IRCOMMAND $IRRCV cdstop ;; #stop 6
        813) $IRCOMMAND $IRRCV cdpause ;; #pause 9
        815) $IRCOMMAND $IRRCV preset ;;  #ejct 7
        817) $IRCOMMAND $IRRCV cdpre ;;   #updown 2
        818) $IRCOMMAND $IRRCV power05 ;;   #quit 0 poweroff
        819) $IRCOMMAND $IRRCV cdnext ;;  #updown 8

        822) $IRCOMMAND $IRRCV cdpre ;;   #updown 2
        823) $IRCOMMAND $IRRCV function5 ;; # input 3
        824) $IRCOMMAND $IRRCV snooze ;; #display 4
        825) $IRCOMMAND $IRRCV random ;; #options 5
        826) $IRCOMMAND $IRRCV cdstop ;; #stop 6 
        828) $IRCOMMAND $IRRCV cdnext ;;  #updown 8
        829) $IRCOMMAND $IRRCV smart ;; #source '.'

        832) $IRCOMMAND $IRRCV volumedown ;; #vol down -
        835) $IRCOMMAND $IRRCV smart ;; #mute ENTER
        836) $IRCOMMAND $IRRCV random ;; #options 5
        838) $IRCOMMAND $IRRCV volumeup ;; #vol up +


        842) $IRCOMMAND $IRRCV snooze ;; #display 4
        845) $IRCOMMAND $IRRCV sleep ;; #scroll 1
#        8) $IRCOMMAND $IRRCV  ;;

#        0) $IRCOMMAND $IR ;;
        # *) ;;
    esac

    #if [ $KEY == $END ] ; then KEY="END" ; fi
done

# N O T E S
#for f in *\ *; do cp "$f" "${f// /_}"; done
#for f in *\ *; do mv "$f" "${f// /_}"; done

# MENU ITEM A - 
#menuaddperformer(){
#    while true ; do
#        setstatus
#        echo -e "\033[05;01H1. Add performer"
#        echo "2. List last entrys"
#        echo "0. Return to menu"
#        readKey
#        echo -e "\033[08;01H   "
#        case $KEY in
#            1|A|a) addperformer ; clear ;;
#            2) lastperformerentrys;;
#            0|$END|$ESCAPE) break ;;
#            *) KEY="!" ; echo "Please choose from list" ;;
#        esac
#    done
#}

#addperformer(){
#    local sql ; local performer ; local comment
#
#    while true ; do
#        if [ $KEY -eq $ENTER ] ; then KEY="Enter" ; fi
#        setstatus
#        echo "Please enter data" ; echo
#
#        read -p "Performer: " performer
#        read -p "Comment  : " comment

#        echo
#        echo "Is this information correct? (Yes/no/escape) " ; readKey
#        case $KEY in
#            [Yy]*|$ENTER )
#                if [ -z "${performer}" ] ; then
#                    echo "Empty performer not allowed."
#                else
#                    sql="INSERT INTO performer (id,name,comment) VALUES #(DEFAULT,'$performer','$comment');"
#                    eval '${SQL}"${sql}"' | tail -n +2
#                fi
#                while true ; do
#                    echo "Do you wish to add another performer? (Yes/no)" ; readKey
#                    case $KEY in
#                        [Yy]*|$ENTER ) echo ; echo ; break ;;
#                        [Nn]*|0|$ESCAPE|$END ) return ;;
#                        * ) KEY="!" ; echo "Please answer yes or no.";;
#                    esac
#                done ;;
#            [Nn]* ) echo ;;
#            $END|$ESCAPE|0) return ;;
#            * ) KEY="!" ; echo ; echo "Please answer yes or no." ; echo ;;
#        esac
#    done
#}


