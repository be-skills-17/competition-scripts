#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <ORG_NAME>"
    exit 1
fi

# Set variables from script arguments
ORG_NAME="$1"

# Create organization
response=$(curl -s -k -X POST "$GITEA_URL/api/v1/orgs" \
    -H "Content-Type: application/json" \
    -H "Authorization: token $GITEA_TOKEN" \
    -d '{
        "username": "'"$ORG_NAME"'",
        "full_name": "'"$ORG_NAME"'"
    }')

echo "Organization '$ORG_NAME' created."
