#!/usr/bin/env bash
#
# Usage:
#   ./push_secret.sh SECRET_NAME SECRET_VALUE
#
# Example:
#   ./push_secret.sh MY_TOKEN "abcdef123456"
#
# Description:
#   This script retrieves all repositories under the "MartinPdeS" user
#   and sets (or updates) the specified secret in each repository.
#   If the secret already exists, it is first removed, then re-created.
#
# Prerequisites:
#   - GitHub CLI (gh) must be installed and authenticated.
#   - You must have the necessary permissions to manage repository secrets.

# Uncomment for safer bash scripting
# set -Eeuo pipefail

# Function to display comprehensive help information
show_help() {
  cat << 'EOF'
Usage:
  ./push_secret.sh SECRET_NAME SECRET_VALUE

Description:
  This script automates the process of updating a secret across all
  repositories under the "MartinPdeS" GitHub user. For each repository,
  the script will:

    1. Retrieve the list of repositories (up to 1000).
    2. Check if the specified secret (SECRET_NAME) already exists.
    3. If the secret exists, remove it to ensure a clean update.
    4. Set (or re-set) the secret with the new value (SECRET_VALUE).

Arguments:
  SECRET_NAME   The name of the secret to be updated or created in each repository.
  SECRET_VALUE  The value assigned to the secret.

Example:
  ./push_secret.sh MY_TOKEN "abcdef123456"

Additional Notes:
  - The script uses the GitHub CLI ('gh') to interact with GitHub.
  - Ensure that 'gh' is installed and that you are authenticated.
  - This script is designed for bulk updates of repository secrets,
    ensuring that each repository gets the updated secret value.
  - If you have more than 1000 repositories, you might need to modify the limit.

EOF
}

# If the user requests help, display the help information and exit.
if [[ ${1:-} == "--help" || ${1:-} == "-h" ]]; then
  show_help
  exit 0
fi

# Check arguments
if [[ $# -ne 2 ]]; then
  echo "Error: Incorrect number of arguments."
  echo "Usage: $0 <SECRET_NAME> <SECRET_VALUE>"
  exit 1
fi

SECRET_NAME="$1"
SECRET_VALUE="$2"

# Iterate over each repository
gh repo list MartinPdeS --limit 1000 --json name --jq '.[].name' | while IFS= read -r REPO; do
  echo "Processing secret for $REPO"

  # Check if the secret already exists; if so, remove it before re-setting.
  EXISTING_SECRET=$(gh secret list -R "MartinPdeS/$REPO" | grep -w "$SECRET_NAME" || true)

  if [[ -n "$EXISTING_SECRET" ]]; then
    echo "  -> Secret '$SECRET_NAME' already exists. Removing..."
    gh secret remove "$SECRET_NAME" -R "MartinPdeS/$REPO"
  fi

  # Now set (or re-set) the secret.
  echo "  -> Setting secret '$SECRET_NAME' with the provided value on '$REPO'"
  gh secret set "$SECRET_NAME" -b"$SECRET_VALUE" -R "MartinPdeS/$REPO"
done

echo "Done! Secret '$SECRET_NAME' has been updated in all repositories."
