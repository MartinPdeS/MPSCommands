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
KEEP_N=4  # Default number of most recent workflow runs to keep

if [ -z "$REPO" ]; then
  echo "Usage: $0 <repo_name> [keep_n]"
  echo "Example: $0 PyOptik 10"
  exit 1
fi

# Check if the user specified the number of runs to keep
if [ -n "$2" ]; then
  KEEP_N=$2
fi

API_URL="https://api.github.com/repos/$OWNER/$REPO/actions/runs"

echo "OWNER: $OWNER"
echo "REPO: $REPO"
echo "GITHUB_TOKEN: ${GITHUB_TOKEN:0:4}..."
echo "Number of recent runs to keep: $KEEP_N"

# Function to delete a workflow run
delete_workflow_run() {
  local run_id=$1
  echo "Deleting workflow run ID: $run_id"
  curl -X DELETE -s -H "Authorization: token $GITHUB_TOKEN" \
       -H "Accept: application/vnd.github.v3+json" \
       "$API_URL/$run_id"
}

# Function to fetch and process workflow runs with pagination
fetch_and_process_runs() {
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

    # Sanitize the response and extract workflow run IDs
    sanitized_response=$(echo "$response" | tr -d '\000-\031')
    run_ids=$(echo "$sanitized_response" | jq -r '.workflow_runs[].id')

    # Break if no runs are found on the current page
    if [ -z "$run_ids" ]; then
      echo "No more workflow runs found."
      break
    fi

    # Process each run ID
    while read -r run_id; do
      offset=$((offset + 1))
      if [ -n "$run_id" ]; then
        if [ "$offset" -le "$KEEP_N" ]; then
          echo "Skipping workflow run ID: $run_id (within the most recent $KEEP_N runs)"
        else
          delete_workflow_run "$run_id"
        fi
      fi
    done <<< "$run_ids"

    # Increment the page number
    page=$((page + 1))
  done
}

# Fetch and process workflow runs
fetch_and_process_runs
