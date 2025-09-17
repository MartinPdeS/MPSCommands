#!/bin/bash

# Load GITHUB_TOKEN and OWNER from ~/__tokens__
if [ -f ~/__tokens__ ]; then
  source ~/__tokens__
else
  echo "Error: ~/__tokens__ file not found. Please create the file and define GITHUB_TOKEN and OWNER."
  exit 1
fi

# Check if GITHUB_TOKEN and OWNER are set
if [ -z "$GITHUB_TOKEN" ] || [ -z "$OWNER" ]; then
  echo "Error: GITHUB_TOKEN or OWNER is not set in ~/__tokens__."
  exit 1
fi

REPO=$1
KEEP_N=4  # Default number of most recent deployments to keep

if [ -z "$REPO" ]; then
  echo "Usage: $0 <repo_name> [keep_n]"
  echo "Example: $0 PyOptik 10"
  exit 1
fi

# Check if the user specified the number of deployments to keep
if [ -n "$2" ]; then
  KEEP_N=$2
fi

API_URL="https://api.github.com/repos/$OWNER/$REPO/deployments"

echo "OWNER: $OWNER"
echo "REPO: $REPO"
echo "GITHUB_TOKEN: ${GITHUB_TOKEN:0:4}..."
echo "Number of recent deployments to keep: $KEEP_N"

# --- Functions ---

# Deactivate all statuses of a deployment
deactivate_deployment_statuses() {
  local deployment_id=$1
  echo "Deactivating statuses for deployment ID: $deployment_id"

  statuses=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                  -H "Accept: application/vnd.github.v3+json" \
                  "$API_URL/$deployment_id/statuses" | jq -r '.[].id')

  for status_id in $statuses; do
    curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" \
         -H "Accept: application/vnd.github.v3+json" \
         -d '{"state":"inactive"}' \
         "$API_URL/$deployment_id/statuses" > /dev/null
  done
}

# Delete a deployment (after deactivating statuses)
delete_deployment() {
  local deployment_id=$1
  deactivate_deployment_statuses "$deployment_id"
  echo "Deleting deployment ID: $deployment_id"
  curl -X DELETE -s -H "Authorization: token $GITHUB_TOKEN" \
       -H "Accept: application/vnd.github.v3+json" \
       "$API_URL/$deployment_id"
  echo ""  # newline
}

# Fetch and process deployments with pagination
fetch_and_process_deployments() {
  local page=1
  local offset=0

  while :; do
    echo "Fetching page $page..."
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                     -H "Accept: application/vnd.github.v3+json" \
                     "$API_URL?per_page=100&page=$page")

    # Save the response for debugging if invalid
    if ! echo "$response" | jq . > /dev/null 2>&1; then
      echo "Error: Invalid JSON response from the API. Response saved to debug_response.json"
      echo "$response" > debug_response.json
      exit 1
    fi

    # Sanitize the response and extract deployment IDs
    sanitized_response=$(echo "$response" | tr -d '\000-\031')
    deployment_ids=$(echo "$sanitized_response" | jq -r '.[].id')

    # Break if no deployments are found on the current page
    if [ -z "$deployment_ids" ]; then
      echo "No more deployments found."
      break
    fi

    # Process each deployment ID
    while read -r deployment_id; do
      offset=$((offset + 1))
      if [ -n "$deployment_id" ]; then
        if [ "$offset" -le "$KEEP_N" ]; then
          echo "Skipping deployment ID: $deployment_id (within the most recent $KEEP_N deployments)"
        else
          delete_deployment "$deployment_id"
        fi
      fi
    done <<< "$deployment_ids"

    # Increment the page number
    page=$((page + 1))
  done
}

# --- Run ---
fetch_and_process_deployments
