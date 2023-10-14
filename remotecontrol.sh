#!/bin/bash
##
PROGVERSION=2023082701
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
## 2022012502 edit md is back
## 2023082701 38 = wol birmingham (sony bd broken)
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
##
## History
## 2023011102 two keys
## 2023042201 power dcc
## 2023042401 2 / 3 key operation / editmd / 7x group (dcc/acc)


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

#declare -i KEYMODE=2
declare -i LOCKMODE=0
declare KEY=0
declare KEYS=01
declare MAINLOOP=1
#declare COMMAND="waiting your command"
declare COMMAND="help"
declare LIST="twokey"
declare PREVLIST
declare DEVICE="HINT:"

# infrared devices and commands
declare IRCOMMAND="irsend SEND_ONCE"	    # lircd command
declare IRCMD="irsend SEND_ONCE"	    # lircd command

# 1. minidsic
declare IRMD="rm-d29m" #IRDD29			    # sony ir commands
declare IRMDCHAR="rm-d10p" #IRD10			# sony ir characters 
declare IRMDCOM="RM-D7M" #IRD7M			    # sony ir commands

# 2. compact disc
declare IRCD="yamahaCd_VV27520" #YACD1

# 3. blu ray
declare IRBDP1="Sony_RMT-B101A"
declare IRBDP2="SONY_RMT_B104P"

# 4. dvd
declare IRDVDP1="Philips_DVD-724"
declare IRDVDP2="Philips_DVP-5982"

# 5. laserdisc
declare IRLD="cu-cld115" #pioneer

# 6. sony vhs
declare IRVHS1="Sony_RMT-V256_1" #VHS SONY SLV-SE60 - RMT-V256A 
declare IRVHS2="Sony_RMT-V256_2" #VHS SONY SLV-SE60 - RMT-V256A 
declare IRVHSA="Sony-RMT-V256A" #VHS SONY SLV-SE60 - RMT-V256A

# 7a. denon cassettedeck
declare IRCT="denoncassettedeck" #CC

# 7b philips dcc
declare IRDCC="philipdcc"
declare IRDCC2="filipdcc" #power 06

# AMP. receiver
declare IRRCV="pioneerReceiver_CU-SX109" #IRSX109 # pioneer ir commands

# TV. samsung tv
declare IRTV="samsungTv_BN59-00865A"

# DVD. sony dvd
declare IRDVD="sonydvd" #DVD
declare IRRF="philips" #DVD (RF modulator only)

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

read2key(){
    local device ; local command ; local kei=$KEYS
    unset key1 key2

    read -s -N1
    key1="$REPLY"

#    if [ "$key1" = $'\x0a' ] || "$key1" = "/" ] || [ "$key1" = "*" ] || [ "$key1" = "-" ] || [ "$key1" = "+" ]  || [ "$key1" = "." ] ; then
    if [ "$key1" = "/" ] || [ "$key1" = "*" ] || [ "$key1" = "-" ] || [ "$key1" = "+" ]  || [ "$key1" = "." ] ; then
 
        KEYS=$key1
        case $KEYS in
            -) DEVICE="amp";COMMAND="vol down";;
            +) DEVICE="amp";COMMAND="vol up";;
            /) DEVICE="amp";COMMAND="function";;
            '*')DEVICE="tv";COMMAND="av";;
            .) DEVICE="amp";COMMAND="muting";;
            $'\x0a') DEVICE='TEST';COMMAND='TEST';;
        esac
        return
    else
        if [ $kei = "01" ] ; then
            echo -e "\033[23;69H$key1"
        else
            echo -e "\033[15;69H\033[0;31m"
            figlet -r -f ANSI\ Regular "$key1"
            mkallgreen
        fi

        read -s -N1
        key2="$REPLY"
    fi

    if [ $key1 -ge 0 ] && [ $key1 -lt 10 ] ; then
        KEYS="${key1}${key2}"
    else
        KEYS=0
    fi

    device="${key1}"
    case $device in
        1) DEVICE="MD";;
        2) DEVICE="CD";;
        3) DEVICE="BD";;
        4) DEVICE="DVD";;
        5) DEVICE="LD";;
        6) DEVICE="VCR";;
        7) DEVICE="ACC / DCC";;
        8) DEVICE="TV / AMP";;
        9) DEVICE="BD / DVD";;
        0) if [ $KEYS -ne 01 ] ; then DEVICE="AUXILERY" ; fi  ;;
        *) DEVICE="UNKNOWN"
    esac

    command="${key2}"
    case $command in
        #main
        1) COMMAND="play";;
        2) COMMAND="stop";;
        3) COMMAND="pause";;
        4) COMMAND="rewind";;
        5) COMMAND="display";;
        6) COMMAND="fst forw";;
        7) COMMAND="eject";;
        8) COMMAND="power";;
        9) COMMAND="select";;
        0) COMMAND="lock";;
    esac
    
    command="${key1}${key2}"
    case $command in
        #main 
        35) COMMAND="menu";;
        27) COMMAND="next disc";;
        47) COMMAND="top menu";;
        57) COMMAND="resume";;
	69) DEVICE="dcc";;

        #acc/dcc
        71) COMMAND="a play";;
        72) COMMAND="a stop";;
        73) COMMAND="a fst forw";;
        74) COMMAND="a rewind";;
        75) COMMAND="d a/b";;
        76) COMMAND="d rewind";;
        77) COMMAND="d play";;
        78) COMMAND="d stop";;
        79) COMMAND="d fst forw";;
        
        #tv/amp 8 
        81) COMMAND="pwr tv";;
        82) COMMAND="tv down";;
        83) COMMAND="pwr amp";;
        84) COMMAND="tools";;
        85) COMMAND="tv ok";;
        86) COMMAND="tape2";;
        87) COMMAND="aspect";;
        88) COMMAND="tv up";;
        89) COMMAND="loudness";;
        
        #dvd/aux 9
        91) COMMAND="dvd pwr";;
        92) COMMAND="bd down";;
        93) COMMAND="rf pwr";;
        94) COMMAND="bd left";;
        95) COMMAND="bd ok";;
        96) COMMAND="bd right";;
        97) COMMAND="dvd av";;
        98) COMMAND="bd up";;
        99) COMMAND="quit";;
        
        #auxilery 0
        # 01) COMMAND="info";;
        02) COMMAND="dvd down";;
        03) COMMAND="function";;
        04) COMMAND="function";;
        05) COMMAND="dvd ok";;
        06) COMMAND="dcc power";;
        07) COMMAND="edit md;";;
        08) COMMAND="dvd up";;
        09) COMMAND="3 key";;
        00) COMMAND="unlock";;
    esac
}

read3Key(){
    local device ; local command
    unset key1 key2 key3

    read -s -N1
    key1="$REPLY" # ; if [ $key1 = $ENTER ] ; then key1=0 ; fi #ToDo testKey
    echo -e "\033[23;69H$key1"

    if [ "$key1" = "/" ] || [ "$key1" = "*" ] || [ "$key1" = "-" ] || [ "$key1" = "+" ]  || [ "$key1" = "." ] ; then
        KEYS=$key1
        case $KEYS in
            -) DEVICE="receiver";COMMAND="main volume down";;
            +) DEVICE="receiver";COMMAND="main volume up";;
            /) DEVICE="receiver";COMMAND="av select";;
            '*') DEVICE="tv";COMMAND="av select";;
            .) DEVICE="receiver";COMMAND="muting";;
        esac
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
        31|32|33|34) DEVICE="bluray";;
        41|42|43|44) DEVICE="dvd";;
        51|52|43|44) DEVICE="laserdisc" ;;
        61|62|63|64) DEVICE="vhs";;
        71|72|73|74) DEVICE="cassettedeck";;
        81|82|83|84) DEVICE="dcc";;

        #X5z - X8z GROUP
        15|16|17|18) DEVICE="receiver";;
        25|26|27|28) DEVICE="tv";;
        35|36|37|38) DEVICE="dvd recorder" ;;
        45|46|47|48) DEVICE="dreambox";;
        55|56|57|58) DEVICE="vcr";;
        65|66|67|68) DEVICE="tv tuner";;
        75|76|77|78) DEVICE="dab radio";;
        85|86|87|88) DEVICE="unixrecoder";;
        
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
        21|61) COMMAND="channel down";;  # "return";;
        22|62) COMMAND="arrow down";;
        23|63) COMMAND="av down";;
        24|64) COMMAND="arrow left";;
        25|65) COMMAND="ok";;
        26|66) COMMAND="arrow right";;
        27|37) COMMAND="channel up";; # "exit";;
        28|28) COMMAND="arrow up";;
        29|69) COMMAND="av up";;

        #audio &video
        31|71) COMMAND="aspect";;
        32|72) COMMAND="volume down";;
        33|73) COMMAND="home/exit";;
        34|74) COMMAND="subtitle";;
        35|75) COMMAND="mute";; #"tools";;
        36|76) COMMAND="menu";; # on tv this is tools
        37|77) COMMAND="audio";;
        38|78) COMMAND="volume up";;
        39|79) COMMAND="disc menu";;

        #auxilery control
        41|81) COMMAND="guide";;
        42|82) COMMAND="info";;
        43|83) COMMAND="record";; #"band";; moved to blue;receiver only function
        44|84) COMMAND="yellow";;
        45|85) COMMAND="scroll";;
        46|86) COMMAND="return";; #"class";; moved to yellow;receiver only function
        47|87) COMMAND="red";;
        48|88) COMMAND="green";;
        49|89) COMMAND="blue";;
#        |) COMMAND="";;
    esac
}

editmd(){
    local loop=1

    until [ $loop -eq 0 ] ; do
        readKey
        echo -e "\033[19;01H                                         "
        echo -e "\033[20;01H                                         "
        echo -e "\033[21;01H                                         "
        echo -e "\033[22;01H                                         "
        echo -e "\033[19;01H                                         "

        case $KEY in
        #COMMANDS
        $HOMEKEY|$END)  loop=0 ; return ;;
        $ENTER)   $IRCOMMAND  $IRMDCOM WRITE_NAME ;;
        $F01)     $IRCOMMAND  $IRMD KEY_POWER;;
        $F02)     $IRCOMMAND  $IRMD KEY_EJECTCD;;
        $F05)     $IRCOMMAND  $IRMD skip_back;;
        $F06)     $IRCOMMAND  $IRMD skip_forw;;
        $F07)     $IRCOMMAND  $IRMD KEY_PAUSE;;
        $F08)     $IRCOMMAND  $IRMD KEY_STOP;;
        $SPACE)   $IRCOMMAND  $IRMDCHAR KEY_SPACE;;
        $DELETE)  $IRCOMMAND  $IRMD KEY_CLEAR;;
    	$AR_LEFT)  $IRCOMMAND  $IRMD KEY_BACK;;
    	$AR_RIGHT) $IRCOMMAND  $IRMD forw;;
    	$F11)      $IRCOMMAND  $IRMD scroll;;
    	$F12)      $IRCOMMAND  $IRMD display;;
        #CHARS AND NUMBERS
        a)        $IRCOMMAND $IRMDCHAR cap_a ;;
        b)        $IRCOMMAND $IRMDCHAR cap_b ;;
        c)        $IRCOMMAND $IRMDCHAR cap_c ;;
        d)        $IRCOMMAND $IRMDCHAR cap_d ;;
        e)        $IRCOMMAND $IRMDCHAR cap_e ;;
        f)        $IRCOMMAND $IRMDCHAR cap_f ;;
        g)        $IRCOMMAND $IRMDCHAR cap_g ;;
        h)        $IRCOMMAND $IRMDCHAR cap_h ;;
        i)        $IRCOMMAND $IRMDCHAR cap_i ;;
        j)        $IRCOMMAND $IRMDCHAR cap_j ;;
        k)        $IRCOMMAND $IRMDCHAR cap_k ;;
        l)        $IRCOMMAND $IRMDCHAR cap_l ;;
        m)        $IRCOMMAND $IRMDCHAR cap_m ;;
        n)        $IRCOMMAND $IRMDCHAR cap_n ;;
        o)        $IRCOMMAND $IRMDCHAR cap_o ;;
        p)        $IRCOMMAND $IRMDCHAR cap_p ;;
        q)        $IRCOMMAND $IRMDCHAR cap_q ;;
        r)        $IRCOMMAND $IRMDCHAR cap_r ;;
        s)        $IRCOMMAND $IRMDCHAR cap_s ;;
        t)        $IRCOMMAND $IRMDCHAR cap_t ;;
        u)        $IRCOMMAND $IRMDCHAR cap_u ;;
        v)        $IRCOMMAND $IRMDCHAR cap_v ;;
        w)        $IRCOMMAND $IRMDCHAR cap_w ;;
        x)        $IRCOMMAND $IRMDCHAR cap_x ;;
        y)        $IRCOMMAND $IRMDCHAR cap_y ;;
        z)        $IRCOMMAND $IRMDCHAR cap_z ;;
        $)        $IRCOMMAND $IRMDCHAR dollar ;;
        -)        $IRCOMMAND $IRMDCHAR dash ;;
        .)        $IRCOMMAND $IRMDCHAR period ;;
        ,)        $IRCOMMAND $IRMDCHAR comma ;;
        0)        $IRCOMMAND $IRMDCHAR KEY_0 ;;
        1)        $IRCOMMAND $IRMDCHAR KEY_1 ;;
        2)        $IRCOMMAND $IRMDCHAR KEY_2 ;;
        3)        $IRCOMMAND $IRMDCHAR KEY_3 ;;
        4)        $IRCOMMAND $IRMDCHAR KEY_4 ;;
        5)        $IRCOMMAND $IRMDCHAR KEY_5 ;;
        6)        $IRCOMMAND $IRMDCHAR KEY_6 ;;
        7)        $IRCOMMAND $IRMDCHAR KEY_7 ;;
        8)        $IRCOMMAND $IRMDCHAR KEY_8 ;;
        9)        $IRCOMMAND $IRMDCHAR KEY_9 ;;
        esac
    done
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

mkallblue(){
    echo -e "\[\033[${KOLOR}m"
}

refresh(){
    mkgreen
    case $LIST in
        main)
            listprog; liststatus; listmainmenu;;
        editmd)
            listprog; liststatus; listeditmd ; editmd ; clear
            listprog 
            if [ $PREVLIST = "twokey" ] ; then LIST="twokey";list2key;fi
            if [ $PREVLIST = "main" ] ; then LIST="main";liststatus;listmainmenu;fi
            ;;
        options)
            listprog; liststatus; listoptions;;
        twokey)
            mkallblue; listprog; list2key ;;
        twokeyinfo)
            listprog; liststatus; list2keyinfo; LIST="twokey" ;; 
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
echo "FUNCTIONALITY: lock keys"
echo "               do case catch enter and all other evil"
echo "INTEGRETY: "
echo "TUNING"
echo "MISC:"
echo "WORKING NOW: "
echo "0-0-0-0-0-0-0-0-0-0-0-0-"
echo ":-) :-( :-| :-D ;-) :-?"
echo "0-0-0-0-0-0-0-0-0-0-0-0-"
}

list2key(){
    figlet -f ANSI\ Regular "$DEVICE"
    figlet -f ANSI\ Regular "$COMMAND"
    figlet -f ANSI\ Regular "KEY: $KEYS"
    # LOCMODE LATER
}

listeditmd(){
    echo -e "\033[06;01Ha - z    = A - Z"
    echo -e "\033[07;01H0 - 9    = 0 - 9"
    echo -e "\033[08;01HSPACE    = space"
    echo -e "\033[09;01H$ - . ,"

    echo -e "\033[11;01HF5/red   = previous track         F01 = power"
    echo -e "\033[12;01HF6/black = next track             F02 = eject"
    echo -e "\033[13;01HF7/green = pause / play           F11 = scroll"
    echo -e "\033[14;01HF8/blue  = stop                   F12 = display"

    echo -e "\033[16;01HHOME     = back to main menu"
    echo -e "\033[17;01HENTER    = edit"
    echo -e "\033[18;01HDELETE   = delete"
    echo -e "\033[19;01H"
}

list2keyinfo(){
    ## MAIN
    echo -e "\033[05;01H\033[${KOLOR}mKEYS MAIN [1-7]x\033[0;32m"
    echo -e "\033[06;01H7. eject/menu"
    echo -e "\033[07;01H4. rewind"
    echo -e "\033[08;01H1. play"

    echo -e "\033[06;15H8. power"
    echo -e "\033[07;15H5. display"
    echo -e "\033[08;15H2. stop"

    echo -e "\033[06;30H9. select"
    echo -e "\033[07;30H6. fst forward"
    echo -e "\033[08;30H3. pause"

    ## TV AMP
    echo -e "\033[10;01H\033[${KOLOR}mKEYS TV / AMP 8x\033[0;32m"
    echo -e "\033[11;01H7. aspect" #exit"
    echo -e "\033[12;01H4. tools"
    echo -e "\033[13;01H1. power tv" #return"

    echo -e "\033[11;15H8. tv up"
    echo -e "\033[12;15H5. tv ok"
    echo -e "\033[13;15H2. tv down"

    echo -e "\033[11;30H9. loudness"
    echo -e "\033[12;30H6. tape2"
    echo -e "\033[13;30H3. power amp"

    ## BD DVD
    echo -e "\033[15;01H\033[${KOLOR}mKEYS BD / DVD 9x\033[0;32m"
    echo -e "\033[16;01H7. dvd av"
    echo -e "\033[17;01H4. bd left"
    echo -e "\033[18;01H1. power dvd"

    echo -e "\033[16;15H8. bd up"
    echo -e "\033[17;15H5. bd ok"
    echo -e "\033[18;15H2. bd down"

    echo -e "\033[16;30H9. quit"
    echo -e "\033[17;30H6. bd right" # on tv this is tools
    echo -e "\033[18;30H3. power rf" # home ; the same

    ## AUX
    echo -e "\033[20;01H\033[${KOLOR}mAUXILERY 0x\033[0;32m"
    echo -e "\033[21;01H7. edit md"
    echo -e "\033[22;01H4. amp av 4"
    echo -e "\033[23;01H1. help"

    echo -e "\033[21;15H8. dvd up"
    echo -e "\033[22;15H5. dvd ok"
    echo -e "\033[23;15H2. dvd down"

    echo -e "\033[21;30H9. 3 key"
    echo -e "\033[22;30H6. dcc power"
    echo -e "\033[23;30H3. amp av 3"

    ## DEVIATING KEYS
    echo -e "\033[05;45H\033[${KOLOR}mDEVIATING KEYS x5\033[0;32m"
    echo -e "\033[06;45H15. md display"
    echo -e "\033[07;45H25. cd display"
    echo -e "\033[08;45H35. bd menu"
    echo -e "\033[09;45H45. dvd display"
    echo -e "\033[10;45H55. ld display"
    echo -e "\033[11;45H65. vcr display"
    echo -e "\033[12;45H--."
    echo -e "\033[13;45H--."

    echo -e "\033[15;45H\033[${KOLOR}mDEVIATING KEYS x7\033[0;32m"
    echo -e "\033[16;45H17. "
    echo -e "\033[17;45H27. cd next disc"
    echo -e "\033[18;45H37. bd eject"
    echo -e "\033[19;45H47. dvd topmenu"
    echo -e "\033[20;45H57. ld resume"
    echo -e "\033[21;45H67. vcr eject"
    echo -e "\033[22;45H--. "
    echo -e "\033[23;45H69. dcc select"

    ## 7x
    echo -e "\033[05;65H\033[${KOLOR}m7x GROUP\033[0;32m"
    echo -e "\033[06;65H71 acc play"
    echo -e "\033[07;65H72 acc stop"
    echo -e "\033[08;65H73 acc forward"
    echo -e "\033[09;65H74 acc rewind"
    echo -e "\033[10;65H75 dcc a/b"
    echo -e "\033[11;65H76 dcc rewind"
    echo -e "\033[12;65H77 dcc forward"
    echo -e "\033[13;65H78 dcc stop"
    echo -e "\033[14;65H79 dcc play"
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
    echo -e "\033[11;01H7. ch up" #exit"
    echo -e "\033[12;01H4. left"
    echo -e "\033[13;01H1. ch down" #return"

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
    echo -e "\033[17;15H5. mute" # tools"
    echo -e "\033[18;15H2. volume down"

    echo -e "\033[16;30H9. disc menu"
    echo -e "\033[17;30H6. menu" # on tv this is tools
    echo -e "\033[18;30H3. exit" # home ; the same

    ## FORTH GROUP
    echo -e "\033[20;01H\033[${KOLOR}mx4Z / x8Z KEYS auxilery control\033[0;32m"
    echo -e "\033[21;01H7. red"
    echo -e "\033[22;01H4. yellow"
    echo -e "\033[23;01H1. guide"

    echo -e "\033[21;15H8. green"
    echo -e "\033[22;15H5. scroll"
    echo -e "\033[23;15H2. info"

    echo -e "\033[21;30H9. blue"
    echo -e "\033[22;30H6. return" #class" moved to yellow;receiver only function
    echo -e "\033[23;30H3. record" #band" moved to blue;receiver only function


    ## 100
    echo -e "\033[05;45H\033[${KOLOR}mX1z - X4z GROUP\033[0;32m"
    echo -e "\033[06;45H1. minidisc"
    echo -e "\033[07;45H2. compact disc"
    echo -e "\033[08;45H3. bluray player"
    echo -e "\033[09;45H4. dvd player"
    echo -e "\033[10;45H5. laserdisc"
    echo -e "\033[11;45H6. vcr video"
    echo -e "\033[12;45H7. cassettedeck"
    echo -e "\033[13;45H8. dcc"

    echo -e "\033[15;45H\033[${KOLOR}mX5z - X8z GROUP\033[0;32m"
    echo -e "\033[16;45H1. receiver"
    echo -e "\033[17;45H2. tv"
    echo -e "\033[18;45H3. dvd recorder"
    echo -e "\033[19;45H4. dreambox"
    echo -e "\033[20;45H5. vcr audio"
    echo -e "\033[21;45H6. tv tuner"
    echo -e "\033[22;45H7. dab radio"
    echo -e "\033[23;45H8. unixrecorder"

    ## 900
    echo -e "\033[05;63H\033[${KOLOR}m9YZ GROUP\033[0;32m"
    echo -e "\033[06;63H991 ld"
    echo -e "\033[07;63H992 dcc"
    echo -e "\033[08;63H993 dab"
    echo -e "\033[09;63H994 cd"
    echo -e "\033[10;63H995 md"
    echo -e "\033[11;63H996 pc"
    echo -e "\033[12;63H997 unixrecorder"
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
sleep 1

if [ "$DEVTTY" -eq "0" ] ; then tput civis ; fi
if [ $LIST = "main" ] ; then mkallgreen ; else mkallblue ; fi
SLEEPAMP=0.5
#read -sN1 -t $PAUSE tmp

until [ $MAINLOOP -eq 0 ] ; do
    clear
    refresh

    if [ $LIST = "main" ] ; then read3Key ; else read2key ; fi

    case $KEYS in
        902) LIST="twokey" ;;
        911) COMMAND="quit";doHUP ;;
        941) /local/bin/wol birmingham ;;

        # COMMON KEYS
        -) $IRCOMMAND $IRRCV KEY_VOLUMEDOWN;;
        +) $IRCOMMAND $IRRCV KEY_VOLUMEUP;;
        /) $IRCOMMAND $IRRCV function;;
        '*') $IRCOMMAND $IRTV KEY_CYCLEWINDOWS;;
        .) $IRCOMMAND $IRRCV muting;;


        # # # T W O   K E Y   O P E R A T I O N

        #MD
        11) $IRCOMMAND $IRMD KEY_PLAY ;;
        12) $IRCOMMAND $IRMD KEY_STOP ;;
        13) $IRCOMMAND $IRMD KEY_PAUSE ;;
        14) $IRCOMMAND $IRMD skip_back ;;
        15) $IRCOMMAND $IRMD display ;;
        16) $IRCOMMAND $IRMD skip_forw ;;
        18) $IRCOMMAND $IRMD KEY_POWER ;;
        19) $IRCOMMAND $IRAUX KEY_5 ;;
        #10 LOCK

        #CD
        21) $IRCOMMAND $IRCD KEY_PLAY;;
        22) $IRCOMMAND $IRCD STOP ;;
        23) $IRCOMMAND $IRCD PAUSE ;;
        24) $IRCOMMAND $IRCD SKIP_BCK ;;
        25) $IRCOMMAND $IRCD KEY_TIME ;;
        26) $IRCOMMAND $IRCD SKIP_FORWARD ;;
        27) $IRCOMMAND $IRCD DISC_SKIP_FORWARD;;
        # 28) $IRCOMMAND $IRCD p o w e r;;
        29) $IRCOMMAND $IRAUX KEY_4 ;;
        #20 LOCK

        #BD 3
        31) $IRCOMMAND $IRBDP1 KEY_PLAY ;;
        32) $IRCOMMAND $IRBDP1 KEY_STOP ;;
        33) $IRCOMMAND $IRBDP1 KEY_PAUSE ;;
        34) $IRCOMMAND $IRBDP1 KEY_PREVIOUS ;;
        35) $IRCOMMAND $IRBDP1 SYSTEM_MENU ;;
        36) $IRCOMMAND $IRBDP1 KEY_NEXT ;;
        37) $IRCOMMAND $IRBDP1 KEY_EJECTCD ;;
        ##38) $IRCOMMAND $IRBDP2 KEY_POWER ;;
	38) wol birmingham ;;
        39) $IRCOMMAND $IRBDP1 KEY_SUBTITLE ;;
        # 30) $IRCOMMAND $IRBDP

        #DVD 4
        41) $IRCOMMAND $IRDVDP1 KEY_PLAY;;
        42) $IRCOMMAND $IRDVDP1 KEY_STOP ;;
        43) $IRCOMMAND $IRDVDP1 KEY_PAUSE ;;
        44) $IRCOMMAND $IRDVDP1 Skip_Left Skip_Left ;;
        45) $IRCOMMAND $IRDVDP1 Display ;;
        46) $IRCOMMAND $IRDVDP1 Skip_Right ;;
        47) $IRCOMMAND $IRDVDP1 KEY_Disc_Menu;;
        48) $IRCOMMAND $IRDVDP2 KEY_POWER;;
        49) $IRCOMMAND $IRAUX KEY_1 ;;

        #LD 5
        51) $IRCOMMAND $IRLD KEY_PLAY;;
        52) $IRCOMMAND $IRLD KEY_STOP ;;
        53) $IRCOMMAND $IRLD KEY_PAUSE ;;
        54) $IRCOMMAND $IRLD KEY_BACK ;;
        55) $IRCOMMAND $IRLD KEY_INFO ;;
        56) $IRCOMMAND $IRLD KEY_FORWARD ;;
        57) $IRCOMMAND $IRLD KEY_MEMO ;;
        58) $IRCOMMAND $IRLD KEY_POWER ;;
        59) $IRCOMMAND $IRAUX KEY_1 ;;

        # VCR
        # This machine has everything to be told twice :-(
        61) $IRCOMMAND $IRVHS2 KEY_PLAY KEY_PLAY ;;
        62) $IRCOMMAND $IRVHS2 KEY_STOP KEY_STOP;;
        63) $IRCOMMAND $IRVHS2 KEY_PAUSE KEY_PAUSE;;
        64) $IRCOMMAND $IRVHS2 KEY_REWIND KEY_REWIND;;
        65) $IRCOMMAND $IRVHS1 display display;;
        66) $IRCOMMAND $IRVHS2 KEY_FASTFORWARD KEY_FASTFORWARD;;
        67) $IRCOMMAND $IRVHS1 KEY_EJECTCD KEY_EJECTCD;;
        68) $IRCOMMAND $IRVHS1 KEY_POWER KEY_POWER;;
        69) $IRCOMMAND $IRAUX KEY_2 ;;
        #60 LOCK

        # ACC / DCC
        71) $IRCOMMAND $IRCT TAPE_PLAY ;;
        72) $IRCOMMAND $IRCT TAPE_STOP ;;
        73) $IRCOMMAND $IRCT TAPE_FF ;;
        74) $IRCOMMAND $IRCT TAPE_REW ;;
        75) $IRCOMMAND $IRDCC KEY_AB ;; #  DCC A/B
        76) $IRCOMMAND $IRDCC KEY_BACK ;; #DCC BACK
        77) $IRCOMMAND $IRDCC KEY_PLAY ;; #DCC PLAY
        78) $IRCOMMAND $IRDCC KEY_STOP ;; #DCC STOP
        79) $IRCOMMAND $IRDCC KEY_NEXT ;; #DCC FORWARD

        # TV / AMP
        81) $IRCOMMAND $IRTV KEY_POWER ;;
        82) $IRCOMMAND $IRTV KEY_DOWN ;;
        83) $IRCOMMAND $IRRCV KEY_RECORD;; #KEY_RECORD = POWER :-(
        84) $IRCOMMAND $IRTV TOOLS ;;
        85) $IRCOMMAND $IRTV ENTER-OK ;;
        86) $IRCOMMAND $IRRCV Monitor;;
        #87 aspect
        88) $IRCOMMAND $IRTV KEY_UP ;;
        89) $IRCOMMAND $IRRCV loudness;;

        # BD / DVD
        91) $IRCOMMAND $IRDVD KEY_POWER;;
        92) $IRCOMMAND $IRBDP1 NAV_DOWN;;
        93) $IRCOMMAND $IRRF KEY_POWER ;; #red
        94) $IRCOMMAND $IRBDP1 NAV_LEFT ;;
        95) $IRCOMMAND $IRBDP1 KEY_OK ;;
        96) $IRCOMMAND $IRBDP1 NAV_RIGHT ;;
        97) $IRCOMMAND $IRDVD KEY_CHANNELUP;;
        98) $IRCOMMAND $IRBDP1 NAV_UP ;;
        99) doHUP ;;

        #AUXILERY
        
        01) LIST="twokeyinfo" ;;
        02) $IRCOMMAND $IRDVDP1 KEY_DOWN ;;
        03) $IRCOMMAND $IRRCV function ; sleep $SLEEPAMP
            $IRCOMMAND $IRRCV function ; sleep $SLEEPAMP
            $IRCOMMAND $IRRCV function ;;
        04) $IRCOMMAND $IRRCV function ; sleep $SLEEPAMP
            $IRCOMMAND $IRRCV function ; sleep $SLEEPAMP
            $IRCOMMAND $IRRCV function ; sleep $SLEEPAMP
            $IRCOMMAND $IRRCV function ;;
        05) $IRCOMMAND $IRDVDP1 KEY_OK ;;
        06) $IRCOMMAND $IRDCC2 KEY_POWER ;;
        07) DEVICE="MD";COMMAND="edit";LIST="editmd";PREVLIST="twokey";;
        08) $IRCOMMAND $IRDVDP1 KEY_UP ;;
        09) LIST="main" ;; #THREE KEY
        # 00) LOCKMODE=
        
        
        # # # T H R E E   K E Y   O P E R A T I O N

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
        977) DEVICE="minidisc";COMMAND="edit";LIST="editmd";PREVLIST=main;;
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
        143) $IRCOMMAND $IRMD KEY_RECORD ;; #;DEVICE="minidisc";COMMAND="record";;
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
        247) $IRCOMMAND $IRCD RANDOM ; COMMAND="RANDOM RED" ;;
        248) $IRCOMMAND $IRCD KEY_MODE ; COMMAND="DISC MODE GREEN" ;;

        #$IRCOMMAND $IRCD PROG
        #$IRCOMMAND $IRCD RANDOM
        #$IRCOMMAND $IRCD DISC_SCAN


        # BLURAY / 31 32 33 34


        # VHS SONY / 61 62 63 64
        # This machine has everything to be told twice :-(
        611) $IRCOMMAND $IRVHS2 KEY_PLAY KEY_PLAY ;;
        612) $IRCOMMAND $IRVHS2 KEY_STOP KEY_STOP;;
        613) $IRCOMMAND $IRVHS2 KEY_PAUSE KEY_PAUSE;;
        614) $IRCOMMAND $IRVHS2 KEY_REWIND KEY_REWIND;;
        615) $IRCOMMAND $IRVHS1 KEY_EJECTCD KEY_EJECTCD;;
        616) $IRCOMMAND $IRVHS2 KEY_FASTFORWARD KEY_FASTFORWARD;;
        618) $IRCOMMAND $IRVHS1 KEY_POWER KEY_POWER;;

        623) $IRCOMMAND $IRVHS1 KEY_CLEAR KEY_CLEAR ;;

        642) $IRCOMMAND $IRVHS1 display display;;
        647) $IRCOMMAND $IRVHS1 KEY_SLOW KEY_SLOW;;
        648) $IRCOMMAND $IRVHS1 counter/remain counter/remain;;


        # cassettedeck / 71 72 73 74
        711) $IRCOMMAND $IRCT TAPE_PLAY ;;
        712) $IRCOMMAND $IRCT TAPE_STOP ;;
        713) $IRCOMMAND $IRCT TAPE_PAUSE ;;
        714) $IRCOMMAND $IRCT TAPE_REW ;;
        716) $IRCOMMAND $IRCT TAPE_FF ;;
        743) $IRCOMMAND $IRCT TAPE_REC ;;
        #TAPE_AB TAPE PLAYREV


        # DCC / 81 82 83 84
        811) $IRCOMMAND $IRDCC KEY_PLAY ;; #DCC PLAY
        812) $IRCOMMAND $IRDCC KEY_STOP ;; #DCC STOP
        815) $IRCOMMAND $IRDCC KEY_AB ;; #  DCC A/B
        817|816) $IRCOMMAND $IRDCC KEY_NEXT ;; #DCC FORWARD
        818) $IRCOMMAND $IRDCC2 KEY_POWER ;; #DCC POWER
        819|814) $IRCOMMAND $IRDCC KEY_BACK ;; #DCC BACK


        # RECEIVER / 15 16 17 18
        158) $IRCOMMAND $IRRCV KEY_RECORD;; #KEY_RECORD = POWER :-(

        161) $IRCOMMAND $IRRCV tunerdown;;
        167) $IRCOMMAND $IRRCV tunerup;;
    	163) $IRCOMMAND $IRRCV function;;

        182) $IRCOMMAND $IRRCV displaymode;;
        184) $IRCOMMAND $IRRCV class;; #yellow
        189) $IRCOMMAND $IRRCV fmam;; #blue (band)


        # TV / 25 26 27 28
        258) $IRCOMMAND $IRTV KEY_POWER ;;

        261) $IRCOMMAND $IRTV KEY_CHANNELDOWN ;;
        262) $IRCOMMAND $IRTV KEY_DOWN ;;
        263) $IRCOMMAND $IRTV KEY_CYCLEWINDOWS ;;
        264) $IRCOMMAND $IRTV KEY_LEFT ;;
        265) $IRCOMMAND $IRTV ENTER_OK ;;
        266) $IRCOMMAND $IRTV KEY_RIGHT ;;
        267) $IRCOMMAND $IRTV KEY_CHANNELUP ;;
        268) $IRCOMMAND $IRTV KEY_UP ;;
        269) $IRCOMMAND $IRTV KEY_CYCLEWINDOWS ;;

        # 731) $IRCOMMAND $IRTV KEY_ aspect?  ;;
        272) $IRCOMMAND $IRTV KEY_VOLUMEDOWN ;;
        273) $IRCOMMAND $IRTV KEY_EXIT ;;
        274) $IRCOMMAND $IRTV KEY_SUBTITLE ;;
        275) $IRCOMMAND $IRTV KEY_MUTE ;;
        276) $IRCOMMAND $IRTV TOOLS ;;
        278) $IRCOMMAND $IRTV KEY_VOLUMEUP ;;

        282) $IRCOMMAND $IRTV KEY_INFO ;;
        284) $IRCOMMAND $IRTV KEY_YELLOW ;;
        286) $IRCOMMAND $IRTV KEY_ENTER ;; # RETURN
        287) $IRCOMMAND $IRTV KEY_RED ;;
        288) $IRCOMMAND $IRTV KEY_GREEN ;;
        289) $IRCOMMAND $IRTV KEY_BLUE ;;


        # SONY DVD RECORDER / 35 36 37 38 
        351) $IRCOMMAND $IRDVD KEY_PLAY;;
        352) $IRCOMMAND $IRDVD KEY_STOP;;
        353) $IRCOMMAND $IRDVD KEY_PAUSE ;;
        355) $IRCOMMAND $IRDVD KEY_EJECTCD ;;
        357) $IRCOMMAND $IRDVD KEY_PREVIOUS ;;
        358) $IRCOMMAND $IRDVD KEY_POWER;;
        359) $IRCOMMAND $IRDVD KEY_NEXT ;;

        361|363) $IRCOMMAND $IRDVD KEY_CHANNELDOWN;;
        352) $IRCOMMAND $IRDVD KEY_DOWN;;
        354) $IRCOMMAND $IRDVD KEY_LEFT;;
        355) $IRCOMMAND $IRDVD KEY_OK;;
        366) $IRCOMMAND $IRDVD KEY_RIGHT;;
        367|369) $IRCOMMAND $IRDVD KEY_CHANNELUP;;
        368) $IRCOMMAND $IRDVD KEY_UP;;

        373) $IRCOMMAND $IRDVD KEY_EXIT;;
#        433) $IRCOMMAND $IRDVD KEY_TITLE;;
        374) $IRCOMMAND $IRDVD KEY_SUBTITLE;;
        376) $IRCOMMAND $IRDVD KEY_MENU;;
#        437) $IRCOMMAND $IRDVD audio;;
        379) $IRCOMMAND $IRDVD KEY_CONTEXT_MENU;;

        372) $IRCOMMAND $IRDVD KEY_INFO;;
        375) $IRCOMMAND $IRDVD KEY_DISPLAYTOGGLE;;
#        447) $IRCOMMAND $IRRF KEY_POWER KEY_POWER KEY_POWER;; #red
        377) $IRCOMMAND $IRRF KEY_POWER ;; #red
        378) $IRCOMMAND $IRDVD KEY_TV;; #green
        379) $IRCOMMAND $IRDVD KEY_TITLE ; COMMAND="TITLE BLUE";;


        # DREAMBOX / 45 46 47 48


        # VCR THOMSON / 55 56 57 58
        551) $IRCOMMAND $IRVCR KEY_PLAY;;
        552) $IRCOMMAND $IRVCR KEY_STOP;;
        553) $IRCOMMAND $IRVCR KEY_PAUSE;;
        554) $IRCOMMAND $IRVCR KEY_REWIND;;
#        555) $IRCOMMAND $IRVCR EJECT;;
        556) $IRCOMMAND $IRVCR F_FWD;;
        558) $IRCOMMAND $IRVCR KEY_POWER;;

        561) $IRCOMMAND $IRVCR KEY_CHANNELDOWN;;
        562) $IRCOMMAND $IRVCR KEY_DOWN;;
        563) $IRCOMMAND $IRVCR AV;;
        564) $IRCOMMAND $IRVCR KEY_LEFT;;
        565) $IRCOMMAND $IRVCR KEY_OK;;
        566) $IRCOMMAND $IRVCR KEY_RIGHT;;
        567) $IRCOMMAND $IRVCR KEY_CHANNELUP;;
        568) $IRCOMMAND $IRVCR KEY_UP;;
        569) $IRCOMMAND $IRVCR AV;;

        572) $IRCOMMAND $IRVCR KEY_VOLUMEDOWN;;
        573) $IRCOMMAND $IRVCR KEY_EXIT;;
        575) $IRCOMMAND $IRVCR KEY_MUTE;;
        576) $IRCOMMAND $IRVCR KEY_MENU;;
        578) $IRCOMMAND $IRVCR KEY_VOLUMEUP;;

        581) $IRCOMMAND $IRVCR SP_LP;;
        582) $IRCOMMAND $IRVCR INDEX;;
        583) $IRCOMMAND $IRVCR KEY_RECORD;;
        584) $IRCOMMAND $IRVCR KEY_YELLOW;;
        585) $IRCOMMAND $IRVCR MAGENTA;;
        586) $IRCOMMAND $IRVCR COUNTER_RESET;;
        587) $IRCOMMAND $IRVCR KEY_BLUE;;
        588) $IRCOMMAND $IRVCR KEY_GREEN;;
        589) $IRCOMMAND $IRVCR KEY_RED;;
    esac
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


