#!/bin/bash

source scripts/generate-env.sh

source scripts/init-cert.sh
source scripts/init-keycloak.sh
source scripts/update-versions.sh

echo -e '\nInstallation complete!'    
echo -e '\nYou can now run "make up" to start the services.'
