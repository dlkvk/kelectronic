#!/bin/bash
##
## PREFACE
##
#PROGVERSION=2021031304 # 1 started 2 morning 3 afternoon 4 evening 5 night
##
#PROGFILENAME=specialkey.sh
##
#PROGDESCRIPTION="store special keys in vars for import in shell"
##
#PROGAUTHOR=dlkvk
##
## Release Notes
## =============
## 20210313 another dtools program
## store special keys in vars
## for import in shell
##
## Update Notes

## CODE STARTS HERE


## VARS
devtty=`tty | grep tty`
declare -i DEVTTY=0
declare MESSAGE

if [ -z "$devtty" ] ; then
    DEVTTY=1
    MESSAGE="No console"
else
	MESSAGE="Console"
fi

# On the console
if [ $DEVTTY -eq 0 ] ; then
    INSERT=$'\x1b\x5b\x32\x7e'
    DELETE=$'\x1b\x5b\x33\x7e'
    HOMEKEY=$'\x1b\x5b\x31\x7e'
    END=$'\x1b\x5b\x34\x7e'
    PG_UP=$'\x1b\x5b\x35\x7e'
    PG_DOWN=$'\x1b\x5b\x36\x7e'
    AR_UP=$'\x1b\x5b\x41'
    AR_DOWN=$'\x1b\x5b\x42'
    AR_RIGHT=$'\x1b\x5b\x43'
    AR_LEFT=$'\x1b\x5b\x44'
    ENTER=$'\x0a'
    SPACE=$'\x20'
    F01=$'\x1b\x5b\x5b\x41'
    F02=$'\x1b\x5b\x5b\x42'
    F03=$'\x1b\x5b\x5b\x43'
    F04=$'\x1b\x5b\x5b\x44'
    F05=$'\x1b\x5b\x5b\x45'
    F06=$'\x1b\x5b\x31\x37\x7e'
    F07=$'\x1b\x5b\x31\x38\x7e'
    F08=$'\x1b\x5b\x31\x39\x7e'
    F09=$'\x1b\x5b\x32\x30\x7e'
    F10=$'\x1b\x5b\x32\x31\x7e'
    F11=$'\x1b\x5b\x32\x33\x7e'
    F12=$'\x1b\x5b\x32\x34\x7e'
    ESCAPE=$'\x1b'
    BACKSPACE='$\x7f'
fi

# NOT on the console
if [ $DEVTTY -eq 1 ] ; then
    INSERT=$'\x1b\x5b\x32\x7e' #SAME
    DELETE=$'\x1b\x5b\x33\x7e' #SAME
    HOMEKEY=$'\x1b\x5b\x48'
    END=$'\x1b\x5b\x46'
    PG_UP=$'\x1b\x5b\x35\x7e' #SAME
    PG_DOWN=$'\x1b\x5b\x36\x7e' #SAME
    AR_UP=$'\x1b\x5b\x41' #SAME
    AR_DOWN=$'\x1b\x5b\x42' #SAME
    AR_RIGHT=$'\x1b\x5b\x43' #SAME
    AR_LEFT=$'\x1b\x5b\x44' #SAME
    ENTER=$'\x0a'
    SPACE=$'\x20' #SAME
    F01=$'\x1b\x4f\x50'
    F02=$'\x1b\x4f\x51'
    F03=$'\x1b\x4f\x52'
    F04=$'\x1b\x4f\x53'
    F05=$'\x1b\x5b\x31\x35\x7e'
    F06=$'\x1b\x5b\x31\x37\x7e' #SAME
    F07=$'\x1b\x5b\x31\x38\x7e' #SAME
    F08=$'\x1b\x5b\x31\x39\x7e' #SAME
    F09=$'\x1b\x5b\x32\x30\x7e' #SAME
    F10=$'\x1b\x5b\x32\x31\x7e' #SAME
    F11=$'\x1b\x5b\x32\x33\x7e' #SAME
    F12=$'\x1b\x5b\x32\x34\x7e' #SAME
    ESCAPE=$'\x1b'
    BACKSPACE='$\x7f'
fi

## FUNCTIONS


## MAIN
#echo "file = $PROGFILENAME | version = $PROGVERSION"
#echo "description = $PROGDESCRIPTION"
#echo
echo "This program stores the hexadecimal scancodes from special keys"
echo "like ENTER and HOME in variables. Only for import in the shell."
echo "==============================================================="
