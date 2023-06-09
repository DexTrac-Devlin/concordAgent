#!/bin/bash

# Load environment variables from .env file
set -o allexport
source /opt/concordAgent/.env
set +o allexport

# Chainlink Nodes Variables
API_USERNAME="$API_USERNAME"
API_PASSWORD="$API_PASSWORD"

# PostgreSQL Variables
POSTGRES_TIMEOUT_SECONDS=3
POSTGRES_HOST="$POSTGRES_HOST"
POSTGRES_PORT="$POSTGRES_PORT"
POSTGRES_DB="$POSTGRES_DB"
POSTGRES_USER="$POSTGRES_USER"
POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
POSTGRES_TABLE='chainlink_bridges'

# Test PostgreSQL connection with provided vars
if nc -z -w 1 "$POSTGRES_HOST" "$POSTGRES_PORT"; then
    echo "PostgreSQL is listening on port $POSTGRES_PORT. Proceeding with further commands."
else
    echo "Unable to connect to PostgreSQL at $POSTGRES_HOST:$POSTGRES_PORT. Aborting."
    exit 1
fi

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
MAX_ATTEMPTS=20
COUNTER=0
while ! nc -z -w 5 "$POSTGRES_HOST" "$POSTGRES_PORT"; do
  sleep 1
  counter=$((counter + 1))
  if [ $counter -gt 60 ]; then
    echo "Unable to connect to PostgreSQL after 60 seconds. Exiting."
    exit 1
  fi
done
echo "PostgreSQL is ready."

# Fetch running containers and identify which ones are Chainlink nodes
for CONTAINER in $(docker ps --quiet --filter "status=running"); do
  if docker exec "$CONTAINER" sh -c 'command -v chainlink > /dev/null'; then

    # Get container(s)' IP address(es)
    CHAINLINK_URL=$(docker inspect --format '{{ .NetworkSettings.Networks.bridge.IPAddress }}' "$CONTAINER"):6689

    # Define BRIDGE_TYPES_URL
    BRIDGE_TYPES_URL=https://${CHAINLINK_URL}/v2/bridge_types

    # Get an auth cookiefile
    curl -k -s -c cookiefile -X POST -H 'Content-Type: application/json' -d "{\"email\":\"$API_USERNAME\", \"password\":\"$API_PASSWORD\"}" https://${CHAINLINK_URL}/sessions

    # Query the endpoint to extract the bridge name and associated URL
    BRIDGE_NAMES=$(curl -c cookiefile -b cookiefile --insecure --silent --show-error $BRIDGE_TYPES_URL | jq -r '.data[] | .attributes.name')
    BRIDGE_URLS=$(curl -c cookiefile -b cookiefile --insecure --silent --show-error $BRIDGE_TYPES_URL | jq -r '.data[] | .attributes.url')

    # Update chainlink_bridges table with bridge names and bridge urls
    BRIDGE_DATA=$(paste <(echo "$BRIDGE_NAMES") <(echo "$BRIDGE_URLS"))
    while read -r BRIDGE_NAME BRIDGE_URL; do
      PGPASSWORD=${POSTGRES_PASSWORD} psql --host="${POSTGRES_HOST}" --port="${POSTGRES_PORT}" --username="${POSTGRES_USER}" --dbname="${POSTGRES_DB}" <<EOSQL
INSERT INTO ${POSTGRES_TABLE} (node_url, bridge_name, bridge_url) VALUES ('${CHAINLINK_URL}', '${BRIDGE_NAME}', '${BRIDGE_URL}')
ON CONFLICT (node_url, bridge_name) DO UPDATE SET bridge_url = EXCLUDED.bridge_url;
EOSQL
    done <<< "$BRIDGE_DATA"

  fi
done

# Print results
echo "Chainlink bridges:"
PGPASSWORD=${POSTGRES_PASSWORD} psql --host="${POSTGRES_HOST}" --port="${POSTGRES_PORT}" --username="${POSTGRES_USER}" --dbname="${POSTGRES_DB}" --command "SELECT * FROM chainlink_bridges;"
