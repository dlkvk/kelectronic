# kelectronic
Shell scripts for vintage audio

Written in bash 5.0-4 on Devuan Beowulf / Debian Buster. 

This is software "As Is". It means the scripts are far from completed. They where also intented for personal use. No doubt you have to make adjustments for use in your own setup. 

Before making this scripts I made a lot of (more or less) simple one target scripts whith no interface, the output comes through cron mail. So I learned a lot while writing these scripts. This reflects on the quality of the work.

But in spite of this, I like to share my work in the hope you can find some use for it. Now follows an brief description of the scripts followed by some words about dependencies.

<b>amdb.sh / Audio Media Data Base</b><br>
Menu driven interface for a postgresql database (9.6) for your vintage audio media, like minidisc, vinyl and tapes. An sql dump (amdb.sql) is added to build the database.

<b>omrecorder.sh / versatile cdda & md recorder</b><br>
Menu driven application to manage an variety of tasks, like ripping / burning CD, recording minidisc, add titles and tracks. included getCdTracks.py and getTracks.py

<b>remotecontrol.sh / grid remote control</b><br>
An interface for sending infrared signals with lirc. Control your vintage audio equipment with just the numecric keypad.

<b>unixrecorder.sh / versatile disc recorder</b><br>
This is intented as the software heart of real hardware. I have it working on an raspberry with infrared sensor, an 4 digit led display and 3 color led indicators sitting in the old shell of an sattelite receiver. Control by numeric keypad and infrared signals. included ledcontrol.py and leddisplay.py

<b>dependencies</b><br>
The script sound.sh will run on most debian based distros. You might want to look into the script before running it. specialkeys.sh is used by the scripts for recognizing keys like space, enter, end, arrows and function keys. 

<i>- The code is not the documentation, but in this case... :-D </i>
