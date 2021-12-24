#!/bin/bash
##
PROGVERSION=2021121401
##
PROGFILENAME=amdb.sh
##
PROGNAME=
##
PROGDESCRIPTION="audio media data base"
#
##
PROGAUTHOR="dlkvk"
##
## Notes
##
## 2021102202 start writing code
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

#declare PGDATABASE=amdb
#declare PGHOST=
#declare PGUSER=
#declare PGPASSWORD=

declare KEY=0
declare MAINLOOP=1
declare COMMAND="waiting your command"
declare LIST="main"
declare -r TMPDIR="/dev/shm"
declare -r PRINTDIR="$HOME/.cache/amdb"
mkdir -p $PRINTDIR
declare -r SQL="psql -d amdb -c "
declare DATEHOUR

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

# MENU ITEM A - ADD PERFORMER
menuaddperformer(){
    while true ; do
        setstatus
        echo -e "\033[05;01H1. Add performer"
        echo "2. List last entrys"
        echo "0. Return to menu"
        readKey
        echo -e "\033[08;01H   "
        case $KEY in
            1|A|a) addperformer ; clear ;;
            2) lastperformerentrys;;
            0|$END|$ESCAPE) break ;;
            *) KEY="!" ; echo "Please choose from list" ;;
        esac
    done
}

addperformer(){
    local sql ; local performer ; local comment

    while true ; do
        if [ $KEY -eq $ENTER ] ; then KEY="Enter" ; fi
        setstatus
        echo "Please enter data" ; echo

        read -p "Performer: " performer
        read -p "Comment  : " comment

        echo
        echo "Is this information correct? (Yes/no/escape) " ; readKey
        case $KEY in
            [Yy]*|$ENTER )
                if [ -z "${performer}" ] ; then
                    echo "Empty performer not allowed."
                else
                    sql="INSERT INTO performer (id,name,comment) VALUES (DEFAULT,'$performer','$comment');"
                    eval '${SQL}"${sql}"' | tail -n +2
                fi
                while true ; do
                    echo "Do you wish to add another performer? (Yes/no)" ; readKey
                    case $KEY in
                        [Yy]*|$ENTER ) echo ; echo ; break ;;
                        [Nn]*|0|$ESCAPE|$END ) return ;;
                        * ) KEY="!" ; echo "Please answer yes or no.";;
                    esac
                done ;;
            [Nn]* ) echo ;;
            $END|$ESCAPE|0) return ;;
            * ) KEY="!" ; echo ; echo "Please answer yes or no." ; echo ;;
        esac
    done
}

lastperformerentrys(){
    local sql
    setstatus
    sql="SELECT id, left(name, 40) AS performer, left(comment,32) AS comment FROM performer ORDER BY id DESC LIMIT 15;"
    eval '${SQL}"${sql}"' | tail -n +2
    pak
}

# MENU ITEM B - ADD ALBUM
menuaddalbum(){
    while true ; do
        if [ $KEY -eq $ENTER ] ; then KEY="Enter" ; fi
        setstatus
        echo -e "\033[05;01H1. Add album"
        echo "2. List last entrys"
        echo "0. Return to menu"
        readKey
        echo -e "\033[08;01H   "
        case $KEY in
            1|B|b) addalbum ; clear ;;
            2) lastalbumentrys;;
            0|$END|$ESCAPE) break ;;
            *) KEY="!" ; echo "Please choose from list" ;;
        esac
    done
}

addalbum(){
    local sql ; local sqlrc ; local mselect=0 ; local frecords
    local album ; local year ; local comment ; local performer ; local performerid

    while true ; do
        if [ $KEY -eq $ENTER ] ; then KEY="Enter" ; fi
        setstatus
        sqlrc=-1
        echo "Please enter data" ; echo

        read -e -p "Performer: " -i "$performer" performer
        read -e -p "Album    : " -i "$album" album
        read -e -p "Year     : " -i "$year" year
        read -e -p "Comment  : " -i "$comment" comment

        # TRACKLISTING
        echo
        echo "Do you want to add tracklisting to the comments? (Yes/no) " ; readKey
        case $KEY in
            [Yy]*|$ENTER )
                tracks=`gettracks.py "$performer" "$album"`
                tracks=$(echo $tracks | sed -e 's/\n//g' | sed -e "s/'//g")
                if [ -z "${comment}" ] ; then comment="${tracks}" ; else comment="$comment ${tracks}" ; fi
                read -e -p "Comment   : " -i "$comment" comment ;;
            * ) ;;
           esac
        echo
        echo "Is this information correct? (Yes/no/escape) " ; readKey
        case $KEY in
            [Yy]*|$ENTER )
                if [ -z "${album}" ] ; then
                    echo "Empty album not allowed." ; pak ; return
                else 
                    ## Count matches
                    sql="SELECT id,name FROM performer WHERE name ILIKE '${performer}%';"
                    sqlrc=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2 | wc -l`

                    ## Get performer id
                    if [ $sqlrc -gt 0 ] ; then
                        sql2="SELECT id FROM performer WHERE name ILIKE '${performer}%';"
                        frecords=`eval '${SQL}"${sql2}"' | tail -n +4 | head -n -2` ; fi
                fi

                if [ $sqlrc -eq 1 ] ; then
                    sql="INSERT INTO album (id,name,performer,year,comment) VALUES (DEFAULT,'$album',$frecords,$year,'$comment');"
                    eval '${SQL}"${sql}"' | tail -n +2
                else
                    if [ $sqlrc -eq 0 ] ; then
                        echo "No Matches found in performer table."
                    else
                        eval '${SQL}"${sql}"' | tail -n +4 | head -n -2
                        read -p "Select number of performer or 0 for exit: " mselect
frecords=" $frecords"
                        if [[ ${frecords} =~ (^|[[:space:]])"${mselect}"($|[[:space:]]) ]]; then
                            sql="INSERT INTO album (id,name,performer,year,comment) VALUES (DEFAULT,'$album',$mselect,$year,'$comment');"
                            eval '${SQL}"${sql}"' | tail -n +2
                        else
                            echo "No performer selected, exit" ; pak ; break
                        fi
                        mselect=0
                    fi
                fi
                while true ; do
                    sql="SELECT id, left(performer, 25) AS performer, left(album,25) AS album, year, left(comment,9) AS comment FROM viewallalbum ORDER BY id DESC LIMIT 1;"
                    eval '${SQL}"${sql}"' | tail -n +2 
                    echo "Do you wish to add another album? (Yes/no)" ; readKey
                    case $KEY in
                        [Yy]*|$ENTER )
                            performer=`echo` ; album=`echo` ; year=`echo` ; comment=`echo` 
                            echo ; echo ; break ;;
                        [Nn]*|0|$ESCAPE|$END ) return ;;
                        * ) KEY="!" ; echo "Please answer yes or no.";;
                    esac
                done ;;
            [Nn]* ) echo ;;
            $END|$ESCAPE|0) return ;;
            * ) KEY="!" ; echo ; echo "Please answer yes or no." ; echo ;;
        esac
    done
}

lastalbumentrys(){
    local sql
    setstatus
#    sql="SELECT left(artist, 30) AS performer, id, left(album,35) AS album, year FROM viewalbum ORDER BY id DESC LIMIT 15;"
sql="SELECT id, left(performer, 25) AS performer, left(album,25) AS album, year, left(comment,9) AS comment FROM viewallalbum  ORDER BY id DESC LIMIT 15;"
    eval '${SQL}"${sql}"' | tail -n +2 
    pak
}

# MENU ITEM C - ADD TYPE
menuaddtype(){
    while true ; do
        setstatus
        echo -e "\033[05;01H1. Add type"
        echo "2. List last entrys"
        echo "0. Return to menu"
        readKey
        echo -e "\033[08;01H   "
        case $KEY in
            1|C|c) addtype ; clear ;;
            2) lasttypeentrys;;
            0|$END|$ESCAPE) break ;;
            *) KEY="!" ; echo "Please choose from list" ;;
        esac
    done
}

addtype(){
    local sql ; local type ; local comment

    while true ; do
        if [ $KEY -eq $ENTER ] ; then KEY="Enter" ; fi
        setstatus
        echo "Please enter data" ; echo

        read -p "Type   : " type
        read -p "Comment: " comment

        echo
        echo "Is this information correct? (Yes/no/escape) " ; readKey
        case $KEY in
            [Yy]*|$ENTER )
                if [ -z "${type}" ] ; then
                    echo "Empty type not allowed."
                else
                    sql="INSERT INTO type (id,name,comment) VALUES (DEFAULT,'$type','$comment');"
                    eval '${SQL}"${sql}"' | tail -n +2
                fi
                while true ; do
                    echo "Do you wish to add another type? (Yes/no)" ; readKey
                    case $KEY in
                        [Yy]*|$ENTER ) echo ; echo ; break ;;
                        [Nn]*|0|$ESCAPE|$END ) return ;;
                        * ) KEY="!" ; echo "Please answer yes or no.";;
                    esac
                done ;;
            [Nn]* ) echo ;;
            $END|$ESCAPE|0) return ;;
            * ) KEY="!" ; echo ; echo "Please answer yes or no." ; echo ;;
        esac
    done
}

lasttypeentrys(){
    local sql
    setstatus
    sql="SELECT id, left(name, 40) AS type, left(comment,32) AS comment FROM type ORDER BY id DESC LIMIT 15;"
    eval '${SQL}"${sql}"' | tail -n +2
    pak
}

# MENU ITEM D - ADD MEDIUM
menuaddmedium(){
    while true ; do
        if [ $KEY -eq $ENTER ] ; then KEY="Enter" ; fi
        setstatus
        echo -e "\033[05;01H1. Add medium"
        echo "2. List last entrys"
        echo "0. Return to menu"
        readKey
        echo -e "\033[08;01H   "
        case $KEY in
            1|D|d) addmedium ; clear ;;
            2) lastmediumentrys;;
            0|$END|$ESCAPE) break ;;
            *) KEY="!" ; echo "Please choose from list" ;;
        esac
    done
}

addmedium(){
    local sql ; local sql2 ; local sqlrc ; local mselect=0 ; local frecords
    local sqlt ; local sqlrct ; local sqls ; local sqlc
    local frecordst ; local frecordss ; local frecordsc
    local album ; local typeid ; local number ; local comment
    local status ; local condition
    local numcheck=0

    while true ; do
        if [ $KEY -eq $ENTER ] ; then KEY="Enter" ; fi
        setstatus
        sqlrc=-1
        echo "Please enter data" ; echo

        while true ; do
            read -e -p "Number    : " -i "$number" number
            sql="SELECT id FROM media WHERE number=$number;"
            numcheck=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2 | wc -l`
            if [ $numcheck -eq 0 ] ; then break ; else
            echo "Number is in use" ; fi
        done

        read -e -p "Type      : " -i "$typeid" typeid
        read -e -p "Album     : " -i "$album" album
        read -e -p "Status    : " -i "$status" status
        read -e -p "Condition : " -i "$condition" condition
        read -e -p "Comment   : " -i "$comment" comment

        echo
        echo "Is this information correct? (Yes/no/escape) " ; readKey
        case $KEY in
            [Yy]*|$ENTER )
                if [ -z "${album}" ] ; then
                    echo "Empty album not allowed." ; pak ; return ; fi
                if [ -z "${typeid}" ] ; then
                    echo "Empty type not allowed." ; pak ; return ; fi
                if [ -z "${number}" ] ; then
                    echo "Empty number not allowed." ; pak ; return ; fi

                sql="SELECT id,performer,album FROM viewallalbum WHERE album ILIKE '${album}%';"
                sqlrc=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2 | wc -l`

                ## Get album id
                if [ $sqlrc -gt 0 ] ; then                    
                    sql2="SELECT id FROM album WHERE name ILIKE '${album}%';"
                    frecords=`eval '${SQL}"${sql2}"' | tail -n +4 | head -n -2`

                ## Get type id
                    sqlt="SELECT id FROM type WHERE name ILIKE '${typeid}%';"
                    frecordst=`eval '${SQL}"${sqlt}"' | tail -n +4 | head -n -2`

                ## Get status id
                    sqls="SELECT id FROM status WHERE name ILIKE '${status}%';"
                    frecordss=`eval '${SQL}"${sqls}"' | tail -n +4 | head -n -2`

                ## Get condition id
                    sqlc="SELECT id FROM condition WHERE name ILIKE '${condition}%';"
                    frecordsc=`eval '${SQL}"${sqlc}"' | tail -n +4 | head -n -2`
                fi

                if [ $sqlrc -eq 1 ] ; then
                    sql="INSERT INTO media (id,number,type,album,comment,status,condition) VALUES (DEFAULT,$number,$frecordst,$frecords,'$comment',$frecordss,$frecordsc);"
                    eval '${SQL}"${sql}"' | tail -n +2
                else    
                    if [ $sqlrc -eq 0 ] ; then
                        echo "No Matches found in album table."
                    else
                        eval '${SQL}"${sql}"' | tail -n +4 | head -n -2
                        read -p "Select number of performer or 0 for exit: " mselect
frecords=" $frecords"
                        if [[ ${frecords} =~ (^|[[:space:]])"${mselect}"($|[[:space:]]) ]]; then
                            sql="INSERT INTO media (id,number,type,album,comment,status,condition) VALUES (DEFAULT,$number,$frecordst,$mselect,'$comment',$frecordss,$frecordsc);"
                            eval '${SQL}"${sql}"' | tail -n +2
                        else
                            echo "No album selected, exit" ; pak ; break
                        fi
                        mselect=0
                    fi
                fi

                while true ; do
                    #sql="SELECT id, number, left(type, 2) AS ty, left(performer, 19) AS performer, left(album,19) AS album,  left(comment,9) AS comment FROM viewallmedia OFFSET ((SELECT count(*) FROM viewallmedia)-1);"
                    sql="SELECT id, number, left(status, 1) AS s, left(condition, 1) AS c, left(type, 2) AS ty, left(performer, 15) AS performer, left(album,15) AS album,  left(comment,9) AS comment FROM viewallmedia ORDER BY id DESC LIMIT 1;"
                    eval '${SQL}"${sql}"' | tail -n +2
                    echo "Do you wish to add another medium? (Yes/no)" ; readKey
                    case $KEY in
                        [Yy]*|$ENTER )
                            number=`echo` ; typeid=`echo` ; album=`echo` ; comment=`echo` 
                            echo ; echo ; break ;;


                        [Nn]*|0|$ESCAPE|$END ) return ;;
                        * ) KEY="!" ; echo "Please answer yes or no.";;
                    esac
                done ;;
            [Nn]* ) echo ;;
            $END|$ESCAPE|0) return ;;
            * ) KEY="!" ; echo ; echo "Please answer yes or no." ; echo ;;
        esac
    done
}

lastmediumentrys(){
    local sql 
    setstatus
    #sql="SELECT id, number, left(type, 2) AS ty, left(performer, 19) AS performer, left(album,19) AS album,  left(comment,9) AS comment FROM viewallmedia ORDER BY id DESC LIMIT 15;"
    sql="SELECT id, number, left(status, 1) AS s, left(condition, 1) AS c, left(type, 2) AS ty, left(performer, 15) AS performer, left(album,15) AS album,  left(comment,9) AS comment FROM viewallmedia ORDER BY id DESC LIMIT 15;"

    eval '${SQL}"${sql}"' | tail -n +2
    pak
}

# MENU ITEM E - EDIT PERFORMER
editperformer(){
    local sid ; local performer ; local comment
    local sql ; local sqlrc
    local sql2 ; local frecords ; local mselect

    while true ; do
        if [ $KEY -eq $ENTER ] ; then KEY="Enter" ; fi
        setstatus
        sqlrc=-1

        echo "Please enter data" ; echo
        read -p "Performer : " sid
        sql="SELECT id,name,comment FROM performer WHERE name ILIKE '${sid}%' ORDER BY id;"
        sqlrc=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2 | wc -l`

        # If more then one record shows up...
        if [ $sqlrc -gt 1  ] ; then
            sql2="SELECT id FROM performer WHERE name ILIKE '${sid}%';"
            frecords=`eval '${SQL}"${sql2}"' | tail -n +4 | head -n -2`

            # show records
            echo ; eval '${SQL}"${sql}"' | tail -n +4 | head -n -2 ; echo
            while true ; do

                # choose record
                read -p "Select number to edit or 0 for exit: " mselect ; echo
                frecords=" $frecords"

                if [[ ${frecords} =~ (^|[[:space:]])"${mselect}"($|[[:space:]]) ]]; then
                    # edit performer
                    sql="SELECT name FROM performer WHERE id=$mselect;"
                    performer=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                    read -e -p "Performer :" -i "$performer" performer

                    # edit comment
                    sql="SELECT comment FROM performer WHERE id=$mselect;"
                    comment=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                    read -e -p "Comment   :" -i "$comment" comment

                    # last check and sql
                    echo
                    echo "Is this information correct? (Yes/no) " ; readKey
                    case $KEY in
                        [Yy]*|$ENTER )
                            sql="UPDATE performer SET name='$performer', comment='$comment' WHERE id=$mselect;"
                            echo
                            eval '${SQL}"${sql}"' | tail -n +2
                            break;;
                        [Nn]*|$ESCAPE|$END|0 ) break ;;
                        * ) KEY="!" ; echo "Please answer yes or no.";;
                    esac
                else
                    if [ $mselect -eq 0 ] ; then break ; fi
                    echo "No selection"
                fi
            done
        fi

        # if one record is found then edit 
        if [ $sqlrc -eq 1 ] ; then
            while true ; do
                echo
                # edit performer
                sql="SELECT name FROM performer WHERE name ILIKE '${sid}%';"
                performer=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                read -e -p "Performer :" -i "$performer" performer

                # edit comment
                sql="SELECT comment FROM performer WHERE name ILIKE '${sid}%';"
                comment=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                read -e -p "Comment   :" -i "$comment" comment
                echo

                # last check and sql
                echo "Is this information correct? (Yes/no) " ; readKey
                case $KEY in
                    [Yy]*|$ENTER )
                        sql="UPDATE performer SET name='$performer', comment='$comment' WHERE  name ILIKE '${sid}%';"
                        echo
                        eval '${SQL}"${sql}"' | tail -n +2
                        break ;;
                    [Nn]*|$ESCAPE|$END|0 ) break ;;
                    * ) KEY="!" ; echo "Please answer yes or no.";;
                esac
            done
        fi

        # no records found
        if [ $sqlrc -eq 0 ] ; then
            echo ; echo "No data found"
        fi

        # continue editing?
        while true ; do
            echo
            echo "Do you want to continue with editing? (Yes/no)" ; readKey
            case $KEY in
                [Yy]*|$ENTER ) echo ; echo ; break ;;
                [Nn]*|$ESCAPE|$END|0 ) return ;;
                * ) KEY="!" ; echo "Please answer yes or no.";;
            esac
        done
    done
}

# MENU ITEM F - EDIT ALBUM
editalbum(){
    local sid ; local performer ; local comment ; local album ; local year ; local tracks
    local sql ; local sqlrc ; local sql2 ; local sqlrc2 ; local sql3
    local frecords ; local mselect ; local performerid

    while true ; do
        if [ $KEY -eq $ENTER ] ; then KEY="Enter" ; fi
        setstatus
        sqlrc=-1

        echo "Please enter data" ; echo
        read -p "Album     : " sid
        sql="SELECT id, left(performer, 25) AS performer, left(album,25) AS album, year, left(comment,9) AS comment FROM viewallalbum WHERE album ILIKE '${sid}%' ORDER BY performer,album;"
        sqlrc=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2 | wc -l`

        # If more then one record shows up...
        if [ $sqlrc -gt 1  ] ; then

            sql2="SELECT id FROM viewallalbum WHERE album ILIKE '${sid}%';"
            frecords=`eval '${SQL}"${sql2}"' | tail -n +4 | head -n -2`

            # show records
            echo ; eval '${SQL}"${sql}"' | tail -n +2 | head -n -2 ; echo

            while true ; do
                # choose record
                read -p "Select number to edit or 0 for exit: " mselect ; echo
frecords=" $frecords"
                if [[ ${frecords} =~ (^|[[:space:]])"${mselect}"($|[[:space:]]) ]]; then

                    # edit performer
                    sql="SELECT performer FROM viewallalbum WHERE id=$mselect;"
                    performer=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                    read -e -p "Performer :" -i "$performer" performer

                    # edit album
                    sql="SELECT album FROM viewallalbum WHERE id=$mselect;"
                    album=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                    read -e -p "Album     :" -i "$album" album

                    # edit year
                    sql="SELECT year FROM viewallalbum WHERE id=$mselect;"
                    year=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                    read -e -p "Year      :" -i "$year" year

                    # edit comment
                    sql="SELECT comment FROM viewallalbum WHERE id=$mselect;"
                    comment=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                    read -e -p "Comment   :" -i "$comment" comment

                    # TRACKLISTING
                    echo
                    echo "Do you want to add tracklisting to the comments? (Yes/no) " ; readKey
                    case $KEY in
                        [Yy]*|$ENTER )
                            tracks=`gettracks.py "$performer" "$album"`
                            tracks=$(echo $tracks | sed -e 's/\n//g')
                            tracks=$(echo $tracks | tr -d "'")
                            if [ -z "${comment}" ] ; then comment="${tracks}" ; else comment="${comment} ${tracks}" ; fi
                            read -e -p "Comment   : " -i "$comment" comment ;;
                        * ) ;;
                    esac

                    # last check and sql
                    echo
                    echo "Is this information correct? (Yes/no) " ; readKey
                    case $KEY in
                        [Yy]*|$ENTER )

                            if [ -z "${album}" ] ; then
                                echo "Empty album not allowed." ; pak ; break
                            else
                                ## Count matches
                                sql2="SELECT id,name FROM performer WHERE name ILIKE '${performer}%';"
                                sqlrc2=`eval '${SQL}"${sql2}"' | tail -n +4 | head -n -2 | wc -l`

                                ## Get performer id
                                if [ $sqlrc2 -gt 0 ] ; then
                                    sql3="SELECT id FROM performer WHERE name ILIKE '${performer}%';"
                                    frecords=`eval '${SQL}"${sql3}"' | tail -n +4 | head -n -2` ; fi
                            fi

                            if [ $sqlrc2 -eq 1 ] ; then
                                sql="UPDATE album SET performer=$frecords, name='$album', year=$year, comment='$comment' WHERE id=$mselect;"
                                eval '${SQL}"${sql}"' | tail -n +2
                            else
                                if [ $sqlrc2 -eq 0 ] ; then
                                    echo "No Matches found in performer table."
                                else
                                    eval '${SQL}"${sql2}"' | tail -n +4 | head -n -2
                                    read -p "Select number of performer or 0 for exit: " performerid
frecords=" $frecords"
                                    if [[ ${frecords} =~ (^|[[:space:]])"${mselect}"($|[[:space:]]) ]]; then
                                        sql="UPDATE album SET performer=$performerid, name='$album', year=$year, comment='$comment' WHERE id=$mselect;"
                                        eval '${SQL}"${sql}"' | tail -n +2
                                    else
                                        echo "No performer selected, exit" ; pak ; break
                                    fi
                                fi
                            fi
                            break;;
                        [Nn]*|$ESCAPE|$END|0 ) break ;;
                        * ) KEY="!" ; echo "Please answer yes or no.";;
                    esac
                else
                    if [ $mselect -eq 0 ] ; then break ; fi
                    echo "No selection"
                fi
            done
        fi

        # if one record is found then edit
        if [ $sqlrc -eq 1 ] ; then
            while true ; do
                echo
                # edit performer
                sql="SELECT performer FROM viewallalbum WHERE album ILIKE '${sid}%';"
                performer=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                read -e -p "Performer :" -i "$performer" performer

                # edit album
                sql="SELECT album FROM viewallalbum WHERE album ILIKE '${sid}%';"
                album=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                read -e -p "Album     :" -i "$album" album

                # edit year
                sql="SELECT year FROM viewallalbum WHERE album ILIKE '${sid}%';"
                year=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                read -e -p "Year      :" -i "$year" year

                # edit comment
                sql="SELECT comment FROM viewallalbum WHERE album ILIKE '${sid}%';"
                comment=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                read -e -p "Comment   :" -i "$comment" comment

                # TRACKLISTING
                echo
                echo "Do you want to add tracklisting to the comments? (Yes/no) " ; readKey
                case $KEY in
                    [Yy]*|$ENTER )
                        tracks=`gettracks.py "$performer" "$album"`
                        tracks=$(echo $tracks | sed -e 's/\n//g' | sed -e "s/'//g")
                        if [ -z "${comment}" ] ; then comment="${tracks}" ; else comment="$comment ${tracks}" ; fi
                        read -e -p "Comment   : " -i "$comment" comment ;;
                    * ) ;;
                esac

                # last check and sql
                echo
                echo "Is this information correct? (Yes/no) " ; readKey

                case $KEY in
                    [Yy]*|$ENTER )
                        if [ -z "${album}" ] ; then
                            echo "Empty album not allowed." ; pak ; break
                        else
                            ## Count matches
                            sql2="SELECT id,name FROM performer WHERE name ILIKE '${performer}%';"
                            sqlrc2=`eval '${SQL}"${sql2}"' | tail -n +4 | head -n -2 | wc -l`

                            ## Get performer id
                            if [ $sqlrc2 -gt 0 ] ; then
                                sql3="SELECT id FROM performer WHERE name ILIKE '${performer}%';"
                                frecords=`eval '${SQL}"${sql3}"' | tail -n +4 | head -n -2`
                            fi
                        fi

                        # One performer match or else zero or multiple
                        if [ $sqlrc2 -eq 1 ] ; then
                            sql="UPDATE album SET performer=$frecords, name='$album', year=$year, comment='$comment' WHERE name ILIKE '${sid}%';"
                            eval '${SQL}"${sql}"' | tail -n +2
                        else
                            if [ $sqlrc2 -eq 0 ] ; then
                                echo "No Matches found in performer table."
                            else
                                eval '${SQL}"${sql2}"' | tail -n +4 | head -n -2 
                                frecords=" $frecords"
                                read -p "Select number of performer or 0 for exit: " performerid

                                if [[ ${frecords} =~ (^|[[:space:]])"${performerid}"($|[[:space:]]) ]]; then
                                    sql="UPDATE album SET performer=$performerid, name='$album', year=$year, comment='$comment' WHERE name ILIKE '${sid}%';"
                                    eval '${SQL}"${sql}"' | tail -n +2
                                else
                                    echo "No performer selected, exit" ; pak ; break
                                fi
                            fi
                        fi
                        break;;
                    [Nn]*|$ESCAPE|$END|0 ) break ;;
                    * ) KEY="!" ; echo "Please answer yes or no.";;
                esac
            done
        fi

        # no records found
        if [ $sqlrc -eq 0 ] ; then
            echo ; echo "No data found"
        fi

        # continue editing?
        while true ; do
            echo
            echo "Do you want to continue with editing? (Yes/no)" ; readKey
            case $KEY in
                [Yy]*|$ENTER ) echo ; echo ; break ;;
                [Nn]*|$ESCAPE|$END|0 ) return ;;
                * ) KEY="!" ; echo "Please answer yes or no.";;
            esac
        done
    done
}

# MENU ITEM G - EDIT TYPE
edittype(){
    local sid ; local typeid ; local comment
    local sql ; local sqlrc
    local sql2 ; local frecords ; local mselect

    while true ; do
        if [ $KEY -eq $ENTER ] ; then KEY="Enter" ; fi
        setstatus
        sqlrc=-1

        echo "Please enter data" ; echo
        read -p "Type    : " sid
        sql="SELECT id,name,comment FROM type WHERE name ILIKE '${sid}%' ORDER BY id;"
        sqlrc=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2 | wc -l`

        # If more then one record shows up...
        if [ $sqlrc -gt 1  ] ; then
            sql2="SELECT id FROM type WHERE name ILIKE '${sid}%';"
            frecords=`eval '${SQL}"${sql2}"' | tail -n +4 | head -n -2`
            # show records
            echo ; eval '${SQL}"${sql}"' | tail -n +4 | head -n -2 ; echo
            while true ; do
                # choose record
                read -p "Select number to edit or 0 for exit: " mselect ; echo
frecords=" $frecords"
                if [[ ${frecords} =~ (^|[[:space:]])"${mselect}"($|[[:space:]]) ]]; then
                    # edit type
                    sql="SELECT name FROM type WHERE id=$mselect;"
                    typeid=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                    read -e -p "Type    :" -i "$typeid" typeid
                    # edit comment
                    sql="SELECT comment FROM type WHERE id=$mselect;"
                    comment=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                    read -e -p "Comment :" -i "$comment" comment
                    # last check and sql
                    echo
                    echo "Is this information correct? (Yes/no) " ; readKey
                    case $KEY in
                        [Yy]*|$ENTER )
                            sql="UPDATE type SET name='$typeid', comment='$comment' WHERE id=$mselect;"
                            echo
                            eval '${SQL}"${sql}"' | tail -n +2
                            break;;
                        [Nn]*|$ESCAPE|$END|0 ) break ;;
                        * ) KEY="!" ; echo "Please answer yes or no.";;
                    esac
                else
                    if [ $mselect -eq 0 ] ; then break ; fi
                    echo "No selection"
                fi
            done
        fi

        # if one record is found then edit 
        if [ $sqlrc -eq 1 ] ; then
            while true ; do
                echo
                # edit type
                sql="SELECT name FROM type WHERE name ILIKE '${sid}%';"
                typeid=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                read -e -p "Type    :" -i "$typeid" typeid
                # edit comment
                sql="SELECT comment FROM type WHERE name ILIKE '${sid}%';"
                comment=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                read -e -p "Comment :" -i "$comment" comment
                echo
                # last check and sql
                echo "Is this information correct? (Yes/no) " ; readKey
                case $KEY in
                    [Yy]*|$ENTER )
                        sql="UPDATE type SET name='$typeid', comment='$comment' WHERE  name ILIKE '${sid}%';"
                        echo
                        eval '${SQL}"${sql}"' | tail -n +2
                        break ;;
                    [Nn]*|$ESCAPE|$END|0 ) break ;;
                    * ) KEY="!" ; echo "Please answer yes or no.";;
                esac
            done
        fi

        # no records found
        if [ $sqlrc -eq 0 ] ; then
            echo ; echo "No data found"
        fi

        # continue editing?
        while true ; do
            echo
            echo "Do you want to continue with editing? (Yes/no)" ; readKey
            case $KEY in
                [Yy]*|$ENTER ) echo ; echo ; break ;;
                [Nn]*|$ESCAPE|$END|0 ) return ;;
                * ) KEY="!" ; echo "Please answer yes or no.";;
            esac
        done
    done
}

# MENU ITEM H - EDIT MEDIUM
editmedium(){
    local sid ; local performer ; local comment ; local album ; local type ; local number
    local sql ; local sqlrc ; local sql2 ; local sqlrc2 ; local sql3
    local frecords ; local mselect ; local albumid
    local frecordss ; local frecordsc ; local sqls ; local sqlc
    local sqlt ; local sqlrct ; local frecordst ; local fid
    local numcheck=0

    while true ; do
        if [ $KEY -eq $ENTER ] ; then KEY="Enter" ; fi
        setstatus
        sqlrc=-1

        echo "Please enter data" ; echo

        read -p "Album     : " sid

        sql="SELECT id, number, left(type, 2) AS ty, left(status, 1) AS s, left(condition, 1) AS c, left(performer, 15) AS performer, left(album,15) AS album,  left(comment,9) AS comment FROM viewallmedia WHERE album ILIKE '${sid}%' ORDER BY performer,album;"

        sqlrc=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2 | wc -l`

        # If more then one record shows up...
        if [ $sqlrc -gt 1  ] ; then

            sql2="SELECT id FROM viewallmedia WHERE album ILIKE '${sid}%';"
            frecords=`eval '${SQL}"${sql2}"' | tail -n +4 | head -n -2`

            # show records
            echo ; eval '${SQL}"${sql}"' | tail -n +2 | head -n -2 ; echo

            while true ; do

                # choose record
                read -p "Select number to edit or 0 for exit: " mselect ; echo
frecords=" $frecords"
                if [[ ${frecords} =~ (^|[[:space:]])"${mselect}"($|[[:space:]]) ]]; then

                    # view performer
                    sql="SELECT performer FROM viewallmedia WHERE id=$mselect;"
                    performer=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
#                    read -e -p "Performer :" -i "$performer" performer
                    echo "Performer :$performer"

                    # edit album
                    sql="SELECT album FROM viewallmedia WHERE id=$mselect;"
                    album=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                    read -e -p "Album     :" -i "$album" album

                    # edit type
                    sql="SELECT type FROM viewallmedia WHERE id=$mselect;"
                    type=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                    read -e -p "Type      :" -i "$type" type

                    # edit number
                    sql="SELECT number FROM viewallmedia WHERE id=$mselect;"
                    number=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`

                    while true ; do
                        read -e -p "Number    :" -i "$number" number
                        sql="SELECT id FROM media WHERE number=$number AND id!=$mselect;"
                        numcheck=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2 | wc -l`
                        if [ $numcheck -eq 0 ] ; then break ; else
                            echo "Number is used" ; fi
                    done

                    # edit comment
                    sql="SELECT comment FROM viewallmedia WHERE id=$mselect;"
                    comment=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                    read -e -p "Comment   :" -i "$comment" comment

                    # edit status
                    sql="SELECT status FROM viewallmedia WHERE id=$mselect;"
                    status=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                    read -e -p "Status    :" -i "$status" status

                    # edit condition
                    sql="SELECT condition FROM viewallmedia WHERE id=$mselect;"
                    condition=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                    read -e -p "Condition :" -i "$condition" condition

                    # last check and sql
                    echo
                    echo "Is this information correct? (Yes/no) " ; readKey
                    case $KEY in
                        [Yy]*|$ENTER )

                            if [ -z "${album}" ] ; then
                                echo "Empty album not allowed." ; pak ; break
                            else
                                ## Count matches album
                                sql2="SELECT id, left(album,25) AS album, year, left(performer,25) AS performer FROM viewallalbum WHERE album ILIKE '${album}%';"
                                #sql2="SELECT id, left(album,25) AS album, left(performer, 25) AS performer, year, left(comment,9) AS comment FROM viewallalbum  WHERE album ILIKE '${album}%' ORDER BY performer,year,album;"
                                sqlrc2=`eval '${SQL}"${sql2}"' | tail -n +4 | head -n -2 | wc -l`

                                ## Get album id
                                if [ $sqlrc2 -gt 0 ] ; then
                                    sql3="SELECT id FROM album WHERE name ILIKE '${album}%';"
                                    frecords=`eval '${SQL}"${sql3}"' | tail -n +4 | head -n -2`
                                fi

                                ## Get type id
                                sqlt="SELECT id FROM type WHERE name ILIKE '${type}%';"
                                frecordst=`eval '${SQL}"${sqlt}"' | tail -n +4 | head -n -2` #; fi

                                ## Get status id
                                sqls="SELECT id FROM status WHERE name ILIKE '${status}%';"
                                frecordss=`eval '${SQL}"${sqls}"' | tail -n +4 | head -n -2` #; fi

                                ## Get condition id
                                sqlc="SELECT id FROM condition WHERE name ILIKE '${condition}%';"
                                frecordsc=`eval '${SQL}"${sqlc}"' | tail -n +4 | head -n -2` #; fi
                            fi

                            if [ $sqlrc2 -eq 1 ] ; then
#                                sql="UPDATE media SET album=$frecords, number=$number, type=$frecordst, comment='$comment' WHERE id=$mselect;"
                                sql="UPDATE media SET album=$frecords, number=$number, type=$frecordst, comment='$comment', status=$frecordss, condition=$frecordsc WHERE id=$mselect;"
                                eval '${SQL}"${sql}"' | tail -n +2
                            else
                                if [ $sqlrc2 -eq 0 ] ; then
                                    echo "No Matches found in album table."
                                else
                                    eval '${SQL}"${sql2}"' | tail -n +4 | head -n -2
                                    read -p "Select number of album or 0 for exit: " albumid
                                    #read -p "Select number of album or 0 for exit: " mselect
frecords=" $frecords"
                                    if [[ ${frecords} =~ (^|[[:space:]])"${albumid}"($|[[:space:]]) ]]; then
                                        sql="UPDATE media SET album=$albumid, number=$number, type=$frecordst, comment='$comment', status=$frecordss, condition=$frecordsc WHERE id=$mselect;"
                                        eval '${SQL}"${sql}"' | tail -n +2
                                    else
                                        echo "No album selected, exit" ; pak ; break
                                    fi
                                fi
                            fi
                            break;;
                        [Nn]*|$ESCAPE|$END|0 ) break ;;
                        * ) KEY="!" ; echo "Please answer yes or no.";;
                    esac
                else
                    if [ $mselect -eq 0 ] ; then break ; fi
                    echo "No selection"
                fi
            done
        fi

        # if one record is found then edit
        if [ $sqlrc -eq 1 ] ; then
            while true ; do
                echo
                # get id
                sql="SELECT id FROM viewallmedia WHERE album ILIKE '${sid}%';"
                fid=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`

                # view performer
                sql="SELECT performer FROM viewallmedia WHERE album ILIKE '${sid}%';"
                performer=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                echo "Performer :$performer"

                # edit album
                sql="SELECT album FROM viewallmedia WHERE album ILIKE '${sid}%';"
                album=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                read -e -p "Album     :" -i "$album" album

                # edit type
                sql="SELECT type FROM viewallmedia WHERE album ILIKE '${sid}%';"
                type=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                read -e -p "Type      :" -i "$type" type

                # edit number
                sql="SELECT number FROM viewallmedia WHERE album ILIKE '${sid}%';"
                number=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`

                while true ; do
                    read -e -p "Number    :" -i "$number" number
                    sql="SELECT id FROM media WHERE number=$number AND id!=$fid;"
                    numcheck=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2 | wc -l`
                    if [ $numcheck -eq 0 ] ; then break ; else
                    echo "Number is used" ; fi
                done

                # edit comment
                sql="SELECT comment FROM viewallmedia WHERE album ILIKE '${sid}%';"
                comment=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                read -e -p "Comment   :" -i "$comment" comment

                # edit status
                sql="SELECT status FROM viewallmedia WHERE album ILIKE '${sid}%';"
                status=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                read -e -p "Status    :" -i "$status" status

                # edit condition
                sql="SELECT condition FROM viewallmedia WHERE album ILIKE '${sid}%';"
                condition=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`
                read -e -p "Condition :" -i "$condition" condition

                # last check and sql
                echo
                echo "Is this information correct? (Yes/no) " ; readKey

                case $KEY in
                    [Yy]*|$ENTER )
                        if [ -z "${album}" ] ; then
                            echo "Empty album not allowed." ; pak ; break
                        else
                            ## Count matches album
#                            sql2="SELECT id,name FROM album WHERE name ILIKE '${album}%';"
                            sql2="SELECT id, left(album,25) AS album, left(performer, 25) AS performer, year, left(comment,9) AS comment FROM viewallalbum  WHERE album ILIKE '${album}%' ORDER BY performer,year,album;"

                            sqlrc2=`eval '${SQL}"${sql2}"' | tail -n +4 | head -n -2 | wc -l`

                            ## Get performer id
                            if [ $sqlrc2 -gt 0 ] ; then
                                sql3="SELECT id FROM album WHERE name ILIKE '${album}%';"
                                frecords=`eval '${SQL}"${sql3}"' | tail -n +4 | head -n -2`
                            fi

                            ## Get type id
                            sqlt="SELECT id FROM type WHERE name ILIKE '${type}%';"
                            frecordst=`eval '${SQL}"${sqlt}"' | tail -n +4 | head -n -2`

                            ## Get status id
                            sqls="SELECT id FROM status WHERE name ILIKE '${status}%';"
                            frecordss=`eval '${SQL}"${sqls}"' | tail -n +4 | head -n -2`

                            ## Get condition id
                            sqlc="SELECT id FROM condition WHERE name ILIKE '${condition}%';"
                            frecordsc=`eval '${SQL}"${sqlc}"' | tail -n +4 | head -n -2`
                        fi

                        # One album match or else zero or multiple
                        if [ $sqlrc2 -eq 1 ] ; then
                            sql="UPDATE media SET album=$frecords, number=$number, type=$frecordst, comment='$comment', status=$frecordss, condition=$frecordsc WHERE id=$fid;"
                            eval '${SQL}"${sql}"' | tail -n +2
                        else
                            if [ $sqlrc2 -eq 0 ] ; then
                                echo "No Matches found in album table."
                            else
                                eval '${SQL}"${sql2}"' | tail -n +4 | head -n -2 
                                frecords=" $frecords"
                                read -p "Select number of album or 0 for exit: " albumid

                                if [[ ${frecords} =~ (^|[[:space:]])"${performerid}"($|[[:space:]]) ]]; then
                                    sql="UPDATE media SET album=$albumid, number=$number, type=$frecordst, comment='$comment', status=$frecordss, condition=$frecordsc WHERE id=$fid;"
                                    eval '${SQL}"${sql}"' | tail -n +2
                                else
                                    echo "No album selected, exit" ; pak ; break
                                fi
                            fi
                        fi
                        break;;
                    [Nn]*|$ESCAPE|$END|0 ) break ;;
                    * ) KEY="!" ; echo "Please answer yes or no.";;
                esac
            done
        fi

        # no records found
        if [ $sqlrc -eq 0 ] ; then
            echo ; echo "No data found"
        fi

        # continue editing?
        while true ; do
            echo
            echo "Do you want to continue with editing? (Yes/no)" ; readKey
            case $KEY in
                [Yy]*|$ENTER ) echo ; echo ; break ;;
                [Nn]*|$ESCAPE|$END|0 ) return ;;
                * ) KEY="!" ; echo "Please answer yes or no.";;
            esac
        done
    done
}

# MENU ITEM K - LIST TYPE
listtype(){
    local result ; local sql ; local ypos=3
    local tcount ; local mcount ; local lcount ; local counter=0
    setstatus

    # total counts
    sql="'SELECT count(*) FROM media;'"
    mcount=`eval ${SQL}${sql} | tail -n +4 | head -n -2 | cut -c 3-`

    # type count
    sql="'SELECT count(*) FROM type;'"
    tcount=`eval ${SQL}${sql} | tail -n +4 | head -n -2 | cut -c 3-`
    # type print
echo -e "\033[02;0H"
    sql="'SELECT name AS type,id AS cunt FROM type;'"
    eval ${SQL}${sql} | tail -n +2 | head -n -2
    echo -e "\033[0${ypos};9H$mcount                                          "
    ypos="$((ypos+1))"

    # type count print
    while [ $counter -lt $tcount ] ; do
        let counter++ ; let ypos++
        sql="'SELECT count(*) FROM media WHERE type=$counter;'"
        lcount=`eval ${SQL}${sql} | tail -n +4 | head -n -2 | cut -c 3-`
        if [ -z $lcount ] ; then lcount=0 ; fi
        echo -e "\033[0${ypos};9H$lcount"
    done

    # Yep, its the cursor
    ypos="$((ypos+1))" ; echo -e "\033[0${ypos};01H" ; let ypos++

    # status count
    sql="'SELECT count(*) FROM status;'"
    tcount=`eval ${SQL}${sql} | tail -n +4 | head -n -2 | cut -c 3-`
    # status print
    sql="'SELECT name AS status,id AS cunt FROM status;'"
    eval ${SQL}${sql} | tail -n +2 | head -n -2
    echo -e "\033[0${ypos};15H$mcount"
    ypos="$((ypos+1))" ; counter=0

    # status count print
    while [ $counter -lt $tcount ] ; do
        let counter++ ; let ypos++
        sql="'SELECT count(*) FROM media WHERE status=$counter;'"
        lcount=`eval ${SQL}${sql} | tail -n +4 | head -n -2 | cut -c 3-`
        if [ -z $lcount ] ; then lcount=0 ; fi
        echo -e "\033[0${ypos};15H$lcount"
    done

    # continue editing?
 #   while true ; do
 #       echo
 #       echo "Do you want to see condition stats? (Yes/no)" ; readKey
 #       if [ $KEY == $ENTER ] ; then KEY="Enter" ; fi
 #       case $KEY in
 #           [Yy]*|$ENTER ) echo ; echo ; KEY="Y" break ;;
 #           [Nn]*|$ESCAPE|$END|0 ) return ;;
 #           * ) KEY="!" ; echo "Please answer yes or no.";;
 #       esac
 #   done

    # condition count
  #  setstatus
    #ypos=5

    # Yep, its the cursor
    ypos="$((ypos+1))" ; echo -e "\033[0${ypos};01H" ; let ypos++


    sql="'SELECT count(*) FROM condition;'"
    tcount=`eval ${SQL}${sql} | tail -n +4 | head -n -2 | cut -c 3-`
    # condition print
    sql="'SELECT name AS condition,id AS cunt FROM condition;'"

eval ${SQL}${sql} | tail -n +2 | head -n -2
    echo -e "\033[0${ypos};14H$mcount"
    ypos="$((ypos+1))" ; counter=0

    # condition count print
    while [ $counter -lt $tcount ] ; do
        let counter++ ; let ypos++
        sql="'SELECT count(*) FROM media WHERE condition=$counter;'"
        lcount=`eval ${SQL}${sql} | tail -n +4 | head -n -2 | cut -c 3-`
        if [ -z $lcount ] ; then lcount=0 ; fi
        echo -e "\033[0${ypos};14H$lcount"
    done

#    ypos="$((ypos+1))" ; echo -e "\033[0${ypos};01H" ; pak
#pak
    read -s -N1 tmp
    return
}

# MENU ITEM Q - QUERY MEDIA
menuquerymedia(){
    while true ; do
        setstatus
        echo -e "\033[05;01H1. Mini Disc"
        echo "2. Compact Disc"
        echo "3. Vinyl Disc"
        echo "4. Cassette Tape"
        echo "5. Reel Tape"
        echo "6. Sort on id"
        echo "7. Sort on year"
        echo "0. Return to menu"
        readKey
        echo -e "\033[13;01H   "
        case $KEY in
            1) querymedia MD ;;
            2) querymedia CD ;;
            3) querymedia VD ;;
            4) querymedia CT ;;
            5) querymedia RT ;;
            6) sql="SELECT id, number, left(status, 1) AS s, left(condition, 1) AS c, left(type, 2) As ty, left(performer, 16) AS performer, left(album, 16) AS album, left(comment, 7) AS comment FROM viewallmedia ORDER BY id DESC;"
               setstatus ; eval '${SQL}"${sql}"' | tail -n +2 | more -19 ; pak ;;
            7) #echo "Sort year coming up next year" ; echo ; pak ;;
sql="SELECT number, left(status, 1) AS s, left(condition, 1) AS c, left(type, 2) As ty, year, left(performer, 16) AS performer, left(album, 16) AS album, left(comment, 6) AS comment FROM viewallmedia ORDER BY year,performer,album ;"
               setstatus ; eval '${SQL}"${sql}"' | tail -n +2 | more -19 ; pak ;;
            0|$END|$ESCAPE) break ;;
            *) KEY="!" ; echo "Please choose from menu" ; echo ; pak ;;
        esac
    done
}

querymedia(){
    sql="SELECT number, left(status, 1) AS s, left(condition, 1) AS c, left(type, 2) As ty, left(performer, 15) AS performer, left(album, 16) AS album, year, left(comment, 7) AS comment FROM viewallmedia WHERE type='$1' ORDER BY number;"
    setstatus ; eval '${SQL}"${sql}"' | tail -n +2 | more -19 ; pak
}

# MENU ITEM R - REQUEST MEDIUM
reqmedium(){
    local sid ; local performer ; local comment ; local album ; local status ; local condition
    local type ; local number ; local timestamp ; local year ; local record
    local sql ; local sqlrc ; local sql2 ; local sqlrc2 ; local sql3
    local frecords ; local mselect ; local albumid
    local sqlt ; local sqlrct ; local frecordst ; local fid
    local numcheck=0

    while true ; do
        if [ $KEY -eq $ENTER ] ; then KEY="Enter" ; fi
        setstatus
        sqlrc=-1

        echo "Please enter data" ; echo

        while true ; do
            read -p "Number    : " sid

            sql="SELECT * FROM viewallmedia WHERE number=$sid;"
            sqlrc=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2 | wc -l`

            if [ $sqlrc -eq 0 ] ; then
                while true ; do
                    echo "Number not found. Try again? (Yes/no)" ; readKey
                    case $KEY in
                        [Yy]*|$ENTER ) break;;
                        [Nn]*|$ESCAPE|$END|0 ) return ;;
                        * ) KEY="!" ; echo "Please answer yes or no.";;
                    esac
                done
            else
                break
            fi
        done

        # get the data!
        record=`eval '${SQL}"${sql}"' | tail -n +4 | head -n -2`

        id=`echo $record | awk -F'|' '{print $1}'`
        echo "Id        : $id"
        timestamp=`echo $record | awk -F'|' '{print $8}' | rev | cut -c 12- | rev`
        echo "Timestamp :$timestamp"
        status=`echo $record | awk -F'|' '{print $11}'`
        echo "Status    :$status"
        condition=`echo $record | awk -F'|' '{print $12}'`
        echo "Condition :$condition"
        type=`echo $record | awk -F'|' '{print $3}'`
        echo "Type      :$type"
        comment=`echo $record | awk -F'|' '{print $6}'`
        echo "Comment   :$comment"
        performer=`echo $record | awk -F'|' '{print $4}'`
        echo "Performer :$performer"
        comment=`echo $record | awk -F'|' '{print $9}'`
        echo "Comment   :$comment"
        album=`echo $record | awk -F'|' '{print $5}'`
        echo "Album     :$album"
        year=`echo $record | awk -F'|' '{print $7}'`
        echo "Year      :$year"
        comment=`echo $record | awk -F'|' '{print $10}'`
        echo "Comment   :$comment"

        # continue request?
        while true ; do
            echo
            echo "Do you want to request more? (Yes/no)" ; readKey
            case $KEY in
                [Yy]*|$ENTER ) echo ; echo ; break ;;
                [Nn]*|$ESCAPE|$END|0 ) return ;;
                * ) KEY="!" ; echo "Please answer yes or no.";;
            esac
        done
    done
}

# MENU AND DISPLAY FUNCTIONS
listprog(){
    echo "${PROGSHOWNAME} / ${PROGDESCRIPTION} / ${PROGVERSION}"
    echo
}

liststatus(){
    echo "AMDB | COMMAND = $COMMAND | KEY = $KEY | `basename "$PWD"`"
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

Recommended amdb number format
------------------------------
YYYYMMDD99, where 99 is an serial number. For tapes:

YYYYMM[40|70|90]99 where 99 is an serial number
40=Side A tape / 50 cassette
70=Side B tape / 60 cassette
90=Side A & B tape /80 cassette

This allows you to number you tapes with three numbers only up til 100.

45=5 inch single
78=10 inch mini lp

Entering Data
-------------
First enter an performer. The album table depends on it. For comment the 
country of origin is recommended. Then you can enter the albums made by that 
performer.

The album table has a field called 'year'. This intented for the release year. 

For entering a medium not only an album is needed, but also an medium type, eg
MD for mini disc, or VD for Vynil disc.

For comments in the medium table recommended is to fill in the label of the 
vinyl record (i.e. Parlophone, Columbia) or the method of recording, e.g.
'toslink' or 'analog' for minidisc. 

These are just recommendations, you are free to do what you like. In the 
database however are some things enforced for integrety. You find these in the 
README file
EOF
    echo ; pak
}

mkgreen(){
#    if [ "$DEVTTY" -eq "0" ] ; then echo -e "\[\033[0;32m" ; fi
AAAAAAAAAAAAAAAAAAAAAAA="A"
}

refresh(){
    mkgreen
    case $LIST in
        main)
            listprog; liststatus; listmainmenu;;
        record)
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
echo "FUNCTIONALITY: addperformer mistake memorize fields"
echo "INTEGRETY: "
echo "TUNING"
echo "MISC:"
echo "WORKING NOW: "
echo "0-0-0-0-0-0-0-0-0-0-0-0-"
echo ":-) :-( :-| :-D ;-) :-?"
echo "0-0-0-0-0-0-0-0-0-0-0-0-"
}

listmainmenu(){
    echo "A. Add performer"
    echo "B. Add album"
    echo "C. Add type"
    echo "D. Add medium"
    echo "E. Edit performer"
    echo "F. Edit album"
    echo "G. Edit type"
    echo "H. Edit medium"
    echo "I. List performer"
    echo "J. List album"
    echo "K. List type"
    echo "L. List medium"
    echo "M. Print performer"
    echo "N. Print album"
    echo "O. Print type"
    echo "P. Print medium"
    echo "Q. Query media"
    echo "R. Request medium"
    echo "S. SQL"
}

## MAIN (THE REAL ONE :-)
echo "file = $PROGFILENAME | version = $PROGVERSION"
echo "$PROGDESCRIPTION"
echo "=================================="

read -sN1 -t $PAUSE tmp

until [ $MAINLOOP -eq 0 ] ; do
    clear
    refresh ; readKey ; mkgreen
    DATEHOUR=`date "+%d-%m-%Y %H:%M"`

    case $KEY in
        0|$END|$ESCAPE)
            COMMAND="quit"
            doHUP ;;
        A|a)
            COMMAND="add performer";menuaddperformer;;
        B|b)
            COMMAND="add album";menuaddalbum;;
        C|c)
            COMMAND="add type";menuaddtype;;
        D|d)
            COMMAND="add medium";menuaddmedium;;
        E|e)
            COMMAND="edit performer";editperformer;;
        F|f)
            COMMAND="edit album";editalbum;;
        G|g)
            COMMAND="edit type";edittype;;
        H|h)
            COMMAND="edit medium";editmedium;;
        I|i)
            COMMAND="list performer"
            sql="SELECT id, left(name, 34) AS performer, left(comment,34) AS comment FROM performer ORDER BY performer;"
            setstatus ; eval '${SQL}"${sql}"' | tail -n +2 | more -19 ; pak ;;
        J|j)
            COMMAND="list album"
            sql="SELECT id, left(performer, 25) AS performer, left(album,25) AS album, year, left(comment,9) AS comment FROM viewallalbum ORDER BY performer,year,album;"
            setstatus ; eval '${SQL}"${sql}"' | tail -n +2 | more -19 ; pak ;;
        K|k)
            COMMAND="list type" ; listtype ;;
        L|l)
            COMMAND="list medium"
            sql="SELECT number, left(status, 1) AS s, left(condition, 1) AS c, left(type, 2) As ty, left(performer, 15) AS performer, left(album, 16) AS album, year, left(comment, 7) AS comment FROM viewallmedia ORDER BY performer,year,album,number;"
            setstatus ; eval '${SQL}"${sql}"' | tail -n +2 | more -19 ; pak ;;
        M|m)
            COMMAND="print performer"
            echo "AMDB list of performers printed on $DATEHOUR" > $PRINTDIR/performer.txt
            echo >> $PRINTDIR/performer.txt
            sql="'SELECT '*' FROM performer;'"
            setstatus ; eval ${SQL}${sql} | tail -n +2 >> $PRINTDIR/performer.txt ; pak ;;
        N|n)
            COMMAND="print album"
            echo "AMDB list of albums printed on $DATEHOUR" > $PRINTDIR/album.txt
            echo >> $PRINTDIR/album.txt
            sql="'SELECT '*' FROM viewallalbum;'"
            setstatus ; eval ${SQL}${sql} | tail -n +2 >> $PRINTDIR/album.txt ; pak ;;
        O|o)
            COMMAND="print type"
            echo "AMDB list of types printed on $DATEHOUR" > $PRINTDIR/type.txt
            echo >> $PRINTDIR/type.txt
            sql="'SELECT '*' FROM type;'"
            setstatus ; eval ${SQL}${sql} | tail -n +2 >> $PRINTDIR/type.txt ; pak ;;

        P|p)
            COMMAND="print medium"
            echo "AMDB list of media printed on $DATEHOUR" > $PRINTDIR/media.txt
            echo >> $PRINTDIR/media.txt
#            sql="'SELECT '*' FROM viewpmedia;'"
            sql="SELECT number, left(status, 1) AS s, left(condition, 1) AS c, left(type, 2) As ty, left(performer, 15) AS performer, left(album, 16) AS album, year, left(comment, 7) AS comment FROM viewallmedia ORDER BY performer,year,album,number;"

            setstatus ; eval '${SQL}"${sql}"' | tail -n +2 >> $PRINTDIR/media.txt ; pak ;;
        Q|q)
            COMMAND="query media" ; menuquerymedia ;;
        R|r)
            COMMAND="request medium" ; reqmedium ;;
        S|s)
            COMMAND="sql"
            setstatus ; psql -d amdb;;
        $F01)
            COMMAND="help"
            helpmainmenu ;;
        *)
            COMMAND="unknown command"
            KEY="?" ;;

    esac
    if [ $KEY == $END ] ; then KEY="END" ; fi
done

# N O T E S
#for f in *\ *; do cp "$f" "${f// /_}"; done
#for f in *\ *; do mv "$f" "${f// /_}"; done
