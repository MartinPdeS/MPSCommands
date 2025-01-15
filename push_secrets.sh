#!/bin/bash

# The name of the secret you want to add
SECRET_NAME=$1
# The value of the secret (replace with your actual Anaconda API token)
SECRET_VALUE=$2

# Fetch all repositories you own
REPOS=$(gh repo list MartinPdeS --json name --jq '.[].name')

# Loop through each repository and add the secret
for REPO in $REPOS; do
  echo "Adding secret to $REPO"
  gh secret set $SECRET_NAME -b"$SECRET_VALUE" -R "MartinPdeS/$REPO"
done