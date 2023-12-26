#!/bin/bash

level=$(cat /sys/class/power_supply/BAT1/capacity)
if [[ $level -gt 70 ]]; then
    /usr/local/bin/ectool led power green
elif [[ $level -gt 45 ]]; then
    /usr/local/bin/ectool led power white
elif [[ $level -gt 20 ]]; then
    /usr/local/bin/ectool led power yellow
else
    /usr/local/bin/ectool led power red
fi
