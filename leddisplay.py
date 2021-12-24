#!/usr/bin/env python3
#
# 2021082802

## SOURCES
import tm1637
import sys

## VARS
CLK = 3
DIO = 2
CMD = sys.argv[1]
DATA = " ".join(sys.argv[2:])

## INIT
tm = tm1637.TM1637(clk=CLK, dio=DIO)

## FUNCTIONS


## MAIN
if (CMD=="blankdisplay"):
    tm.write([0, 0, 0, 0])
    DATA = int(DATA)
    sys.exit()
if (CMD=="brightness"):
    DATA = int(DATA)
    tm.brightness(val=DATA)
else:
    CMD = int(CMD)
    tm.brightness(val=CMD)
    tm.write([0, 0, 0, 0])
    tm.show(DATA)
