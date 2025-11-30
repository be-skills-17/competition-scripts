#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <ORG_NAME> <TEAM_NAME> <CAN_CREATE_ORG_REPO>"
    exit 1
fi

# Set variables from script arguments
ORG_NAME="$1"
TEAM_NAME="$2"
CAN_CREATE_ORG_REPO="$3"

# API endpoint to create a team in an organization
API_ENDPOINT="$GITEA_URL/api/v1/orgs/$ORG_NAME/teams"

# Create a new team in the specified organization
response=$(curl -k -s -X POST -H "Content-Type: application/json" \
    -H "Authorization: token $GITEA_TOKEN" \
    -d '{
          "name": "'"$TEAM_NAME"'",
          "can_create_org_repo": '"$CAN_CREATE_ORG_REPO"',
          "units_map": {
            "repo.actions": "read",
            "repo.packages": "none",
            "repo.code": "write",
            "repo.issues": "write",
            "repo.ext_issues": "none",
            "repo.wiki": "admin",
            "repo.pulls": "owner",
            "repo.releases": "none",
            "repo.projects": "none",
            "repo.ext_wiki": "none"
          }
        }' \
    "$API_ENDPOINT")

# Extract the team ID from the response
# team_id=$(echo $response | jq -r '.id')
team_id=$(echo "$response" | awk -F'"id":' '{print $2}' | awk -F',' '{print $1}')

# Check if the team was successfully created
if [ "$team_id" == "null" ]; then
    echo "Failed to create team. Response: $response"
    exit 1
fi

# Output the created team ID
echo "Created team ID: $team_id"
