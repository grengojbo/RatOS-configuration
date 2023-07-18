#!/bin/bash

if [[ -e /dev/btt-octopus-11 ]]; then
	echo "Installing Voron V0 btt-octopus-11 ..."
	tail -n +2 /home/pi/printer_data/config/RatOS/templates/voron-v0.btt-octopus-11.printer.template.cfg > /home/pi/printer_data/config/printer.cfg
	tail -n +2 /home/pi/printer_data/config/RatOS/templates/sensorless-homing-tmc2209.cfg > /home/pi/printer_data/config/sensorless-homing-tmc2209.cfg
else
	echo "Installing Voron V0 btt-skr-mini-e3-30 ..."
	tail -n +2 /home/pi/printer_data/config/RatOS/templates/voron-v01-printer.template.cfg > /home/pi/printer_data/config/printer.cfg
fi
