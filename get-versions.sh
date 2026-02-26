#!/bin/bash

# Get available GridAPPS-D Docker image versions from Docker Hub
# Returns release tags in format: vyear.month.release (e.g., v2023.07.0)

usage() {
    echo "Usage: $0 [-a] [-n limit] [-h]"
    echo "       -a        Show all tags (including develop, latest, etc.)"
    echo "       -n limit  Limit number of results (default: 10)"
    echo "       -h        Show this help message"
    exit 0
}

# Default settings
SHOW_ALL=0
LIMIT=10

# Parse options
while getopts "an:h" option; do
    case $option in
        a) SHOW_ALL=1 ;;
        n) LIMIT="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Docker Hub API endpoint for gridappsd/gridappsd image
DOCKER_HUB_URL="https://hub.docker.com/v2/repositories/gridappsd/gridappsd/tags"

echo "Fetching available GridAPPS-D versions from Docker Hub..."
echo ""

# Fetch tags from Docker Hub (paginated, get first 100)
response=$(curl -s "${DOCKER_HUB_URL}?page_size=100")

if [ -z "$response" ] || echo "$response" | grep -q '"error"'; then
    echo "Error: Failed to fetch tags from Docker Hub"
    echo "Check your internet connection or try again later."
    exit 1
fi

# Extract tag names
all_tags=$(echo "$response" | grep -o '"name":"[^"]*"' | sed 's/"name":"//g' | sed 's/"//g')

if [ -z "$all_tags" ]; then
    echo "Error: No tags found or failed to parse response"
    exit 1
fi

if [ $SHOW_ALL -eq 1 ]; then
    echo "All available tags:"
    echo "==================="
    echo "$all_tags" | head -n "$LIMIT"

    total=$(echo "$all_tags" | wc -l)
    if [ "$total" -gt "$LIMIT" ]; then
        echo ""
        echo "... and $((total - LIMIT)) more (use -n to show more)"
    fi
else
    # Filter to only show release versions (vyear.month.release pattern)
    release_tags=$(echo "$all_tags" | grep -E '^v[0-9]{4}\.[0-9]{2}\.[0-9]+$' | sort -rV)

    if [ -z "$release_tags" ]; then
        echo "No release versions found matching pattern vyear.month.release"
        echo "Try running with -a to see all available tags"
        exit 1
    fi

    echo "Available release versions:"
    echo "==========================="
    echo "$release_tags" | head -n "$LIMIT"

    total=$(echo "$release_tags" | wc -l)
    if [ "$total" -gt "$LIMIT" ]; then
        echo ""
        echo "... and $((total - LIMIT)) more (use -n to show more)"
    fi

    echo ""
    echo "Other common tags: develop, latest"
    echo "(use -a to see all tags)"
fi

echo ""
echo "Usage: ./run.sh -t <version>"
echo "Example: ./run.sh -t v2023.07.0"
