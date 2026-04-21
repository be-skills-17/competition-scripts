#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <REPO_PATH> <REPO_NAME>"
    exit 1
fi

GITEA_URL="git.${DOMAIN}"

echo "Gitea : ${GITEA_URL}"
echo "Gitea token : ${GITEA_TOKEN}"

# Set variables from script arguments
REPO_PATH=$1
REPO_NAME=$2
WORKFLOW_FILE='docker-ci.yml'
ORG_NAME='frameworks'


cd "$REPO_PATH" || exit
echo "Move into $(pwd)"




# Configure git
git init -b main
git config user.name "Init Bot"
git config user.email "iniot@skill17.com"
git config http.sslVerify false

# Replace the URL in the GitHub Action file
# sed -i '' "s|git.local.skill17.com|$GITEA_URL|g" ".github/workflows/$WORKFLOW_FILE"
sed -i "s|git.local.skill17.com|$GITEA_URL|g" ".github/workflows/$WORKFLOW_FILE"

# Commit the changes
git add -A
git commit -m "Initial commit"
git branch -M main

echo "Before upload"
# Create the repository on Gitea under the "frameworks" organization
create_repo_response=$(curl -s -k -X POST "https://$GITEA_URL/api/v1/orgs/$ORG_NAME/repos" \
-H "Authorization: token $GITEA_TOKEN" \
-H "Content-Type: application/json" \
-d '{
  "name": "'"$REPO_NAME"'",
  "private": false,
  "template": true
}')

# Check if the repository was created successfully
if echo "$create_repo_response" | grep -q '"id":'; then
    echo "Repository $REPO_NAME created in the $ORG_NAME organization on Gitea."
else
    echo "Failed to create repository on Gitea: $create_repo_response"
    exit 1
fi

# Add Gitea remote and push the changes

git remote remove gitea 2>/dev/null
git remote add gitea "https://$USERNAME:$PASSWORD@$GITEA_URL/$ORG_NAME/$REPO_NAME.git"
git push -u gitea main --force

# Output response for debugging
echo "Repository $REPO_NAME pushed to the $ORG_NAME organization on Gitea with updated GitHub Action!"
