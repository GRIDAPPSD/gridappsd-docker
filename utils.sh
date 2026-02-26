#!/bin/bash

# Common utilities for gridappsd-docker scripts

# Common variables
DATA_DIR="dumps"
MYSQL_FILE="gridappsd_mysql_dump.sql"

# Detect docker compose command (newer 'docker compose' vs older 'docker-compose')
detect_docker_compose() {
  if docker compose version &>/dev/null; then
    echo "docker compose"
  elif docker-compose --version &>/dev/null; then
    echo "docker-compose"
  else
    echo ""
  fi
}

# Initialize and validate docker compose command
# Sets DOCKER_COMPOSE_CMD variable and exits if not found
init_docker_compose() {
  DOCKER_COMPOSE_CMD=$(detect_docker_compose)
  if [ -z "$DOCKER_COMPOSE_CMD" ]; then
    echo "Error: Neither 'docker compose' nor 'docker-compose' command found"
    echo "Please install Docker Compose"
    exit 1
  fi
  echo "Using: $DOCKER_COMPOSE_CMD"
}

# Build compose files string from docker-compose.d/*.yml
get_compose_files() {
  local files=$( ls -1 docker-compose.d/*yml 2>/dev/null | sed -e 's/^/-f /g' | tr '\n' ' ' )
  echo "-f docker-compose.yml $files"
}
