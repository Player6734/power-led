#!/bin/bash
sudo su
previouslevel=0
while true
do
	level=$(cat /sys/class/power_supply/BAT1/capacity)
	if [[ previouslevel -ne $level ]]
	then
		if [[ $level -gt 70 ]]
		then
			/usr/bin/local/ectool led power green
		elif [[ $level -gt 45 ]] 
		then
			/usr/bin/local/ectool led power white
		elif [[ $level -gt 20 ]] 
		then
			/usr/bin/local/ectool led power yellow
		else
			/usr/bin/local/ectool led power red
		fi
	fi
	previouslevel=$level
	sleep 10
done
