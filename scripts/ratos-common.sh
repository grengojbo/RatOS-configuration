#!/bin/bash
report_status()
{
    echo -e "\n\n###### $1"
}

disable_modem_manager()
{
	report_status "Checking if ModemManager is enabled..."
	
	if ! sudo systemctl is-enabled ModemManager.service &> /dev/null; then
		report_status "Disabling ModemManager..."
		sudo systemctl mask ModemManager.service
	else
		report_status "Modem manager is already disabled, continuing..."
	fi
}

install_obico()
{
	sudo="sudo"
	if [ "$1" = "root" ]
	then
		sudo=""
	fi
	OBICO_DIR="/home/pi/moonraker-obico"
	report_status "Installing obico..."

	if [ ! -d "${OBICO_DIR}" ]; then
		if [[ ! -e /etc/sudoers.d/040-moonraker-obico ]]
		then
			touch /tmp/040-moonraker-obico
			cat << '#EOF' > /tmp/040-moonraker-obico
pi  ALL=(ALL) NOPASSWD: /home/pi/moonraker-obico/install.sh
#EOF
		$sudo chown root:root /tmp/040-moonraker-obico
		$sudo chmod 440 /tmp/040-moonraker-obico
		$sudo cp --preserve=mode /tmp/040-moonraker-obico /etc/sudoers.d/040-moonraker-obico
		fi

		pushd "/home/pi" || return
		# cd ~
		git clone https://github.com/TheSpaghettiDetective/moonraker-obico.git
		cd ${OBICO_DIR}
		# ./install.sh
		echo "[TODO] Run cd ${OBICO_DIR} && ./install.sh]"
		popd || return
	else
		echo "obico: obico already installed, skipping..."
		return
	fi
}

install_beacon()
{
	KLIPPER_DIR="/home/pi/klipper"
	KLIPPER_ENV="/home/pi/klippy-env"
	BEACON_DIR="/home/pi/beacon"
    report_status "Installing beacon module..."

	if [ -d "$BEACON_DIR" ] || [ -e "$KLIPPER_DIR/klippy/extras/beacon.py" ]; then
		echo "beacon: beacon already installed, skipping..."
		return
	fi

	if [ ! -d "$KLIPPER_DIR" ] || [ ! -d "$KLIPPER_ENV" ]; then
		echo "beacon: klipper or klippy env doesn't exist"
		return
	fi

	pushd "/home/pi" || return
	git clone https://github.com/beacon3d/beacon_klipper.git beacon
	chown -R pi:pi beacon
	popd || return

	# install beacon requirements to env
	echo "beacon: installing python requirements to env."
	"${KLIPPER_ENV}/bin/pip" install -r "${BEACON_DIR}/requirements.txt"

	# update link to beacon.py
	echo "beacon: registering beacon with the configurator."
	register_klippy_extension "beacon" "$BEACON_DIR" "beacon.py"

}

register_klippy_extension() {
	EXT_NAME=$1
    EXT_PATH=$2
    EXT_FILE=$3
	ERROR_IF_EXISTS=$4
	[[ "$ERROR_IF_EXISTS" == "false" ]] && ERROR_IF_EXISTS="false" || ERROR_IF_EXISTS="true"

    report_status "Registering klippy extension '$EXT_NAME' with the RatOS Configurator..."
    if [ ! -e "$EXT_PATH/$EXT_FILE" ]
    then
        echo "ERROR: The file you're trying to register does not exist"
        exit 1
    fi

    
    if curl --fail -X POST 'http://localhost:3000/configure/api/trpc/klippy-extensions.register' \
		-H 'content-type: application/json' \
		--data-raw "{\"json\":{\"extensionName\":\"$EXT_NAME\",\"path\":\"$EXT_PATH\",\"fileName\":\"$EXT_FILE\",\"errorIfExists\":$ERROR_IF_EXISTS}}"
    then
        echo "Registered $EXT_NAME successfully."
    else
        echo "ERROR: Failed to register $EXT_NAME. Is the RatOS configurator running?"
        exit 1
    fi
}

register_gcode_shell_command()
{
    EXT_NAME="gcode_shell_extension"
    EXT_PATH=$(realpath $SCRIPT_DIR/../klippy)
    EXT_FILE="gcode_shell_command.py"
    register_klippy_extension $EXT_NAME $EXT_PATH $EXT_FILE
}

register_ratos_homing()
{
    EXT_NAME="ratos_homing_extension"
    EXT_PATH=$(realpath $SCRIPT_DIR/../klippy)
    EXT_FILE="ratos_homing.py"
	# Don't error if extension is already registered
    register_klippy_extension $EXT_NAME $EXT_PATH $EXT_FILE "false"
}

install_hooks()
{
    report_status "Installing git hooks"
	if [[ ! -e /home/pi/printer_data/config/RatOS/.git/hooks/post-merge ]]
	then
 	   ln -s /home/pi/printer_data/config/RatOS/scripts/ratos-post-merge.sh /home/pi/printer_data/config/RatOS/.git/hooks/post-merge
	fi
	if [[ ! -e /home/pi/klipper/.git/hooks/post-merge ]]
	then
 	   ln -s /home/pi/printer_data/config/RatOS/scripts/klipper-post-merge.sh /home/pi/klipper/.git/hooks/post-merge
	fi
	if [[ ! -e /home/pi/moonraker/.git/hooks/post-merge ]]
	then
 	   ln -s /home/pi/printer_data/config/RatOS/scripts/moonraker-post-merge.sh /home/pi/moonraker/.git/hooks/post-merge
	fi
}

ensure_service_permission()
{
	report_status "Updating service permissions"
	if ! cat /home/pi/printer_data/moonraker.asvc | grep "klipper_mcu" &>/dev/null; then
		cat << '#EOF' > /home/pi/printer_data/moonraker.asvc
klipper_mcu
webcamd
MoonCord
KlipperScreen
moonraker-telegram-bot
moonraker-obico
sonar
crowsnest
octoeverywhere
ratos-configurator
#EOF

		report_status "Configurator added to moonraker service permissions"
	fi
}

ensure_sudo_command_whitelisting()
{
	sudo="sudo"
	if [ "$1" = "root" ]
	then
		sudo=""
	fi
    report_status "Updating whitelisted commands"
	# Whitelist RatOS git hook scripts
	if [[ -e /etc/sudoers.d/030-ratos-githooks ]]
	then
		$sudo rm /etc/sudoers.d/030-ratos-githooks
	fi
	touch /tmp/030-ratos-githooks
	cat << '#EOF' > /tmp/030-ratos-githooks
pi  ALL=(ALL) NOPASSWD: /home/pi/printer_data/config/RatOS/scripts/ratos-update.sh
pi  ALL=(ALL) NOPASSWD: /home/pi/printer_data/config/RatOS/scripts/klipper-mcu-update.sh
pi  ALL=(ALL) NOPASSWD: /home/pi/printer_data/config/RatOS/scripts/moonraker-update.sh
pi  ALL=(ALL) NOPASSWD: /home/pi/printer_data/config/RatOS/scripts/moonraker-update.sh
#EOF

	$sudo chown root:root /tmp/030-ratos-githooks
	$sudo chmod 440 /tmp/030-ratos-githooks
	$sudo cp --preserve=mode /tmp/030-ratos-githooks /etc/sudoers.d/030-ratos-githooks

	# Whitelist change hostname script
	if [[ ! -e /etc/sudoers.d/031-ratos-change-hostname ]]
	then
		touch /tmp/031-ratos-change-hostname
		cat << '#EOF' > /tmp/031-ratos-change-hostname
pi  ALL=(ALL) NOPASSWD: /home/pi/printer_data/config/RatOS/scripts/change-hostname-as-root.sh
#EOF

		$sudo chown root:root /tmp/031-ratos-change-hostname
		$sudo chmod 440 /tmp/031-ratos-change-hostname
		$sudo cp --preserve=mode /tmp/031-ratos-change-hostname /etc/sudoers.d/031-ratos-change-hostname
	fi
}

install_templates() 
{
	if [[ ! -e /dev/${BOARD_NAME} ]]; then
		echo "[ERROR] Board ${BOARD_NAME} not found"
		exit 1
	fi

	if [[ ! -f /home/pi/printer_data/config/RatOS/templates/${PRINTER_TEMPLATE}-printer.template.cfg ]]; then
		echo "[ERROR] Template ${PRINTER_TEMPLATE}-printer.template.cfg not found"
		exit 1
	fi
	echo "Installing ${PRINTER_NAME} template ${PRINTER_TEMPLATE}-printer.template.cfg to printer.cfg ..."
	tail -n +2 /home/pi/printer_data/config/RatOS/templates/${PRINTER_TEMPLATE}-printer.template.cfg > /home/pi/printer_data/config/printer.cfg
	
	if [[ "${PRINTER_SENSORLESS_HOMING}" == "yes" ]]; then
		echo "Installing template sensorless-homing-tmc2209.cfg ..."
		tail -n +2 /home/pi/printer_data/config/RatOS/templates/sensorless-homing-tmc2209.cfg > /home/pi/printer_data/config/sensorless-homing-tmc2209.cfg
	elif [[ "${PRINTER_SENSORLESS_HOMING}" == "xy" ]]; then
		echo "Installing template sensorless-x-homing-tmc2209.cfg and sensorless-y-homing-tmc2209.cfg ..."
		tail -n +2 /home/pi/printer_data/config/RatOS/templates/sensorless-x-homing-tmc2209.cfg > /home/pi/printer_data/config/sensorless-x-homing-tmc2209.cfg
		tail -n +2 /home/pi/printer_data/config/RatOS/templates/sensorless-y-homing-tmc2209.cfg > /home/pi/printer_data/config/sensorless-y-homing-tmc2209.cfg
	fi
	
	echo "Setting ${BOARD_NAME} ..."
	sed -i "s/#\[include RatOS\/boards\/CUSTOM\/config.cfg\]/\[include RatOS\/boards\/${BOARD_NAME}\/config.cfg\]/g" /home/pi/printer_data/config/printer.cfg
	if [ $? -eq 0 ] 
	then
		echo "Changed include board ${BOARD_NAME}"
	else
		echo "[ERROR] Is not changed include board ${BOARD_NAME}"
		#exit 1
	fi
}