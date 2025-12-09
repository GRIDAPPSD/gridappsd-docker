#!/bin/bash

# WARNING: This script stops and removes ALL Docker containers and unused networks
# on your system, not just GridAPPS-D containers. Use with caution!
#
# For removing only GridAPPS-D containers, use: ./stop.sh -c

echo "WARNING: This will stop and remove ALL Docker containers and unused networks on your system!"
echo "This includes containers from other projects, not just GridAPPS-D."
echo ""
read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Stopping all containers..."
    docker stop $(docker ps -q) 2>/dev/null
    echo ""
    echo "Removing all containers..."
    docker rm $(docker ps -a -q) 2>/dev/null
    echo ""
    echo "Removing all networks..."
    docker network prune -f
    echo "Done."
else
    echo "Aborted."
    echo ""
    echo "To remove only GridAPPS-D containers, use:"
    echo "  ./stop.sh -c"
fi
