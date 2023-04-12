#!/bin/bash

# Formatting variables
# bold
b=$(tput bold)
# blue foreground
blue_fg=$(tput setaf 6)
# reset to default
reset=$(tput sgr0)

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
sudo systemcstl stop concord_indexer.service
sudo rm  /etc/systemd/system/concord_indexer.service
sudo rm -rf /opt/concordAgent
}

# Print results
print_results() {
echo "stopped & removed postgres and api containers"
echo "deleted service files"
}

# Run
set_vars
stop_containers
remove_containers
purge_service
print_results
