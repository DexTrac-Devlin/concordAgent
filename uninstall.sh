#!/bin/bash

# Formatting variables
# bold
b=$(tput bold)
# blue foreground
blue_fg=$(tput setaf 6)
# reset to default
reset=$(tput sgr0)

# Check if command is run with sudo, if not exit.
check_sudo() {
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run with sudo. Exiting."
  exit 1
fi
}

# Fetch/set the necessary variables
set_vars() {
WORKING_DIR=$(pwd)
source $WORKING_DIR/.env
}


# Stop containers
stop_containers() {
docker-compose down
}

# Remove containers
remove_containers() {
docker image rm concordagent_api:latest node:14 postgres:13
}

# Stop and remove service and service files
purge_service(){
sudo systemctl stop concord_indexer.service
sudo rm  /etc/systemd/system/concord_indexer.service
sudo rm -rf /opt/concordAgent
}

# Print results
print_results() {
echo "---------"
echo "${blue_fg}Stopped & removed postgres and api containers${reset}"
echo "${blue_fg}Deleted service files${reset}"
}

# Run
check_sudo
set_vars
stop_containers
remove_containers
purge_service
print_results
