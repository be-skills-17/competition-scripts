#!/bin/bash

CONFIG_FILE=$(realpath "config/main.json")
IMPORT_SCRIPT=$(realpath "./scripts/utils/import_framework.sh")

export DOMAIN=$(jq -r '.domain' $CONFIG_FILE)
export ENABLE_HTTPS=$(jq -r '.enable_https' $CONFIG_FILE)
export USERNAME=$(jq -r '.username' $CONFIG_FILE)
export PASSWORD=$(jq -r '.password' $CONFIG_FILE)

export MODULES=$(jq -r '.modules | join(" ")' $CONFIG_FILE)

FRAMEWORKS_REPO=$(jq -r '.frameworks_repo' "$CONFIG_FILE")
TEMP_DIR="/tmp/framework-templates"

mkdir -p ${DYNAMIC_DOCKER_DIR} ${DYNAMIC_FRAMEWORKS_DIR}
touch $LOCK_FILE

export GITEA_HOSTNAME=$DOMAIN
export ENABLE_HTTPS=$ENABLE_HTTPS
export MYSQL_ROOT_PASSWORD=$PASSWORD

if [ "$ENABLE_HTTPS" = "true" ]; then
  export ENTRYPOINT=websecure
  export GITEA_PROTOCOL=https
  export REGISTRY_PORT=443
else
  export ENTRYPOINT=web
  export GITEA_PROTOCOL=http
  export REGISTRY_PORT=5000
fi
function docker_compose() {
  local file="$1"
  docker compose -f $DOCKER_DIR/${file} up -d 
}
# create various config and creation files
# Start Traefik and Gitea using Docker Compose

docker_compose "traefik.yaml"
docker_compose "gitea.yaml"


# Wait for Gitea to start
function wait_for_gitea() {
  local retries=10
  local wait=5
  local count=0

  until curl -s http://localhost:3000/api/v1/version > /dev/null; do
    if [ $count -ge $retries ]; then
      echo "Gitea did not become ready in time."
      exit 1
    fi
    echo "Waiting for Gitea to be ready..."
    sleep $wait
    count=$((count + 1))
  done
}

function create_org() {
  local org="$1"
  $SCRIPTS_DIR/create_organisation.sh "$org"
}

function create_user_secret() {
    local user=$1
    local pass=$2
    local secret_name=$3
    local secret_value=$4
    
    curl -s -k -X PUT \
        -u "$user:$pass" \
        -H "Content-Type: application/json" \
        -d "{\"data\": \"$secret_value\"}" \
        "$GITEA_URL/api/v1/user/actions/secrets/$secret_name"
}

function import_framework() {
  local url="$1"
  local repo="$2"
  $SCRIPTS_DIR/import_framework.sh "$url" "$repo"
}

# Wait for Gitea to start
wait_for_gitea

# Create a new Gitea user using the username and password from the passwd file
docker exec gitea su -c "/app/gitea/gitea admin user create --username $USERNAME --password $PASSWORD --email $USERNAME@example.com --admin" git

# Generate a registration token for the Gitea runner
REGISTRATION_TOKEN=$(docker exec gitea su -c '/app/gitea/gitea actions generate-runner-token' git)
export REGISTRATION_TOKEN=$REGISTRATION_TOKEN

echo "Registration Token: $REGISTRATION_TOKEN"

# Start the Gitea runner with the registration token
docker_compose "gitea-runner.yaml"

#### START GTI PREP
export GITEA_URL="$GITEA_PROTOCOL://git.$DOMAIN"
export GITEA_TOKEN=$($SCRIPTS_DIR/create_pat.sh "$GITEA_PROTOCOL://git.$DOMAIN" "$USERNAME" "$PASSWORD")

# create org for demo repos
response=$(curl -s -k -X POST "$GITEA_URL/api/v1/orgs" \
    -H "Content-Type: application/json" \
    -H "Authorization: token $GITEA_TOKEN" \
    -d '{
        "username": "frameworks",
        "full_name": "frameworks"
    }')



create_org "images"
create_org "frameworks"


$SCRIPTS_DIR/create_team.sh "frameworks" "competitors" false
echo "Cloning templates repository..."
git clone "$FRAMEWORKS_REPO" "$TEMP_DIR"

cd "$TEMP_DIR" || exit
rm -rf .git

for dir in $(find . -maxdepth 1 -type d -not -path '*/.*' -not -path '.'); do
    framework_name=$(basename "$dir")
    framework_path=$(realpath "$dir")
    
    echo "------------------------------------------"
    echo "Found framework: $framework_name"
    
    bash "$IMPORT_SCRIPT" "$framework_path" "$framework_name"
done



docker pull nginx:latest > /dev/null 2>&1
docker login -u $USERNAME -p $PASSWORD git.$DOMAIN > /dev/null 2>&1

# Generate competitors.yaml
cat <<EOF > $DYNAMIC_DOCKER_DIR/competitors.yaml
services:
EOF

cat <<EOF > $CONFIG_DIR/mysql/competitors.sql
EOF

# initialize the basic modules
for row in $(jq -r '.competitors[] | @base64' "$CONFIG_FILE"); do
  _jq() {
    echo ${row} | base64 --decode | jq -r ${1}
  }

  echo "Processing competitor: $(_jq '.name')"

  user=$(_jq '.username')
  pass=$(_jq '.password')
  sub=$(_jq '.subdomain')
  echo "Creating Gitea user: $user with subdomain: $sub and password: $pass"
  docker exec gitea su -c '/app/gitea/gitea admin user create --username '$user' --password '$pass' --email '$user@example.com' --must-change-password=false' git
  $SCRIPTS_DIR/add_user_to_team.sh  "frameworks" "competitors" ${user}

  # Create user-level secrets for this user
  echo "Creating user-level secrets for $user..."

  # Create USER secret
  create_user_secret "$user" "$pass" "USER" "$user"
  create_user_secret "$user" "$pass" "PASS" "$pass"
  create_user_secret "$user" "$pass" "DOMAIN" "$DOMAIN"
  create_user_secret "$user" "$pass" "NPM_REGISTRY_URL" "http://verdaccio:4873"
  create_user_secret "$user" "$pass" "SERVER_IP" "127.0.0.1"

  curl -s -k -X PUT \
    -u "$user:$pass" \
    -H "Content-Type: application/json" \
    -d "{\"data\": \"$pass\"}" \
    "$GITEA_URL/api/v1/user/actions/secrets/PASS"

  for module in $MODULES; do
    echo "Processing module: $module for $user"

  cat <<EOF >> $DYNAMIC_DOCKER_DIR/competitors.yaml
  ${user}_${module}:
    image: git.${DOMAIN}/${user}/${module}:1.0.0
    container_name: ${user}_${module}
    restart: always
    networks:
      - gitea
    labels:
      - "wud.watch=true"
      - "wud.watch.digest=true"
      - "wud.registry=gitea.private"
      - 'wud.tag.include=^\d+\.\d+\.\d+\$\$'
      - "traefik.enable=true"
      - "traefik.http.routers.${user}_${module}.rule=Host(\`${sub}-${module}.$DOMAIN\`)"
      - "traefik.http.routers.${user}_${module}.entrypoints=${ENTRYPOINT}"
      - "traefik.http.routers.${user}_${module}.tls=${ENABLE_HTTPS}"
      - "traefik.http.services.${user}_${module}.loadbalancer.server.port=80"
      - "com.centurylinklabs.watchtower.enable=true"
EOF
    
    echo "pushing inital container"
    docker tag nginx:latest git.$DOMAIN/$user/$module:1.0.0
    docker tag nginx:latest git.$DOMAIN/$user/$module:latest
    
    docker push git.$DOMAIN/$user/$module:1.0.0 > $REDIRECT 2>&1
    docker push git.$DOMAIN/$user/$module:latest > $REDIRECT 2>&1

  cat <<EOF >> $CONFIG_DIR/mysql/competitors.sql
  CREATE DATABASE IF NOT EXISTS \`${user}_${module}\`;
  CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$pass';
  GRANT ALL PRIVILEGES ON \`${user}_${module}\`.* TO '$user'@'%';
EOF

  done
done

cat <<EOF >> $DYNAMIC_DOCKER_DIR/competitors.yaml

networks:
  gitea:
    external: true
EOF

# Start MySQL with the admin password as the root password
docker_compose "mysql.yaml"
docker_compose "wud.yaml"
docker_compose "verdaccio.yaml"

# Configure Verdaccio storage permissions to allow package uploads
chmod 777 -R ${DATA_DIR}/verdaccio

# Start competitors work
docker compose -f $DYNAMIC_DOCKER_DIR/competitors.yaml up -d 

# Write out environment variables to .env
cat <<EOF > .env
DOMAIN="$DOMAIN"
ENABLE_HTTPS="$ENABLE_HTTPS"
USERNAME="$USERNAME"
PASSWORD="$PASSWORD"
MODULES="$MODULES"
GITEA_HOSTNAME="$GITEA_HOSTNAME"
MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD"
ENTRYPOINT="$ENTRYPOINT"
GITEA_PROTOCOL="$GITEA_PROTOCOL"
REGISTRY_PORT="$REGISTRY_PORT"
REGISTRATION_TOKEN="$REGISTRATION_TOKEN"
BASE_DIR="$BASE_DIR"
CONFIG_DIR="$CONFIG_DIR"
SCRIPTS_DIR="$SCRIPTS_DIR"
DOCKER_DIR="$DOCKER_DIR"
DATA_DIR="$DATA_DIR"
DYNAMIC_DOCKER_DIR="$DYNAMIC_DOCKER_DIR"
DYNAMIC_FRAMEWORKS_DIR="$DYNAMIC_FRAMEWORKS_DIR"
EOF

echo "..all done!"

