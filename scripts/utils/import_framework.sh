#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <REPO_PATH> <REPO_NAME>"
    exit 1
fi

GITEA_URL="git.${DOMAIN}"

# Set variables from script arguments
REPO_PATH=$1
REPO_NAME=$2
WORKFLOW_FILE='docker-ci.yml'
ORG_NAME='frameworks'



cd "$REPO_PATH" || exit

echo "Configuring git repository..."
# Configure git
git init 
git config user.name "Init Bot"
git config user.email "iniot@skill17.com"
git config http.sslVerify false

echo "Commiting changes..."
git add -A
git commit -m "Initial commit" > $REDIRECT 2>&1
git branch -M main

echo "Creating the repository on Gitea"
# Create the repository on Gitea under the "frameworks" organization
create_repo_response=$(curl -s -k -X POST "https://$GITEA_URL/api/v1/orgs/$ORG_NAME/repos" \
-H "Authorization: token $GITEA_TOKEN" \
-H "Content-Type: application/json" \
-d '{
  "name": "'"$REPO_NAME"'",
  "private": false,
  "template": true
}')

if echo "$create_repo_response" | grep -q '"id":'; then
    echo "Repository $REPO_NAME created in the $ORG_NAME organization on Gitea."
else
    echo "Failed to create repository on Gitea: $create_repo_response"
    exit 1
fi

echo "Pushing the repository to Gitea..."
git remote remove gitea 2>/dev/null
git remote add gitea "https://$USERNAME:$PASSWORD@$GITEA_URL/$ORG_NAME/$REPO_NAME.git"
git push -u gitea main --force > $REDIRECT 2>&1

echo "Repository $REPO_NAME pushed to the $ORG_NAME organization !"
