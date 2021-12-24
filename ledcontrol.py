#!/usr/bin/python3
##
## control 'trafic light' on raspberry
##
##pv=2021071101
##
##start=20210711

## sources
from gpiozero import LED
from time import sleep
from signal import pause
import sys


## vars
red = LED(13)
yellow = LED(6)
green = LED(5)

## functions


## main
red.off()
yellow.off()
green.off()

CMD=sys.argv[1]

if (CMD=="greenon"):
	green.on()
	pause()

if (CMD=="greenblink"):
        green.blink()
        pause()

if (CMD=="yellowon"):
        yellow.on()
        pause()

if (CMD=="yellowblink"):
        yellow.blink()
        pause()

if (CMD=="redon"):
        red.on()
        pause()

if (CMD=="redblink"):
        red.blink()
        pause()
