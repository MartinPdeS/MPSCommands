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
#   and sets (or updates) the specified secret in each repo.
#   If the secret already exists, it is first removed, then re-created.

# set -Eeuo pipefail

# Check arguments
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <SECRET_NAME> <SECRET_VALUE>"
  exit 1
fi

SECRET_NAME="$1"
SECRET_VALUE="$2"

# # Iterate over each repository
gh repo list MartinPdeS --limit 1000 --json name --jq '.[].name' | while IFS= read -r REPO; do
  echo "Processing secret for $REPO"

  # 1) Check if the secret already exists in this repo
  #    If found, remove it before re-setting.
  #    Because 'gh secret set' can overwrite, you *could* skip removing it.
  #    However, removing ensures a clean update and doesn't rely on overwrite behavior.

  # We try listing secrets and grep for SECRET_NAME
  EXISTING_SECRET=$(gh secret list -R "MartinPdeS/$REPO" | grep -w "$SECRET_NAME" || true)

  if [[ -n "$EXISTING_SECRET" ]]; then
    echo "  -> Secret '$SECRET_NAME' already exists. Removing..."
    gh secret remove "$SECRET_NAME" -R "MartinPdeS/$REPO"
  fi

  # # 2) Now set (or re-set) the secret
  echo "  -> Setting secret '$SECRET_NAME': '$SECRET_VALUE' on '$REPO'"
  gh secret set "$SECRET_NAME" -b"$SECRET_VALUE" -R "MartinPdeS/$REPO"
done

echo "Done! Secret '$SECRET_NAME' has been updated in all repositories."
