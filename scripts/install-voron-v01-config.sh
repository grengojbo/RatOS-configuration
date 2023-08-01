#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/ratos-common.sh

# BOARD_NAME=btt-skr-mini-e3-30
BOARD_NAME="btt-manta-m5p"
PRINTER_NAME="Voron V0.2"
PRINTER_TEMPLATE="voron-v01"
# no / yes / xy
PRINTER_SENSORLESS_HOMING="yes"

install_templates
