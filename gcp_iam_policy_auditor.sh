#!/bin/bash

# IAM Policy Auditor Script
# Requires: gcloud, jq
# Usage: ./iam_policy_auditor.sh [organization_id]

# Check for required tools
command -v gcloud >/dev/null 2>&1 || { echo "gcloud is required but not installed. Exiting."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required but not installed. Exiting."; exit 1; }

# High-privilege roles to flag
HIGH_PRIV_ROLES=("roles/owner" "roles/editor" "roles/admin")

# Output CSV file
OUTPUT_CSV="iam_audit_$(date +%Y%m%d_%H%M%S).csv"
echo "Resource,Member,Role,HighPrivilege" > "$OUTPUT_CSV"

# Function to check if a role is high-privilege
is_high_privilege() {
  local role=$1
  for high_role in "${HIGH_PRIV_ROLES[@]}"; do
    if [[ "$role" == "$high_role" ]]; then
      echo "Yes"
      return
    fi
  done
  echo "No"
}

# Function to audit IAM policies for a project
audit_project() {
  local project_id=$1
  echo "Auditing project: $project_id"
  
  # Get IAM policy in JSON format
  policy=$(gcloud projects get-iam-policy "$project_id" --format=json 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    echo "Failed to retrieve IAM policy for project $project_id"
    return
  fi

  # Parse bindings with jq and export to CSV
  echo "$policy" | jq -r '.bindings[] | .role as $role | .members[] | 
    select(. != null) | 
    ["'$project_id'", . , $role, "'$(is_high_privilege "$role")'"] | 
    @csv' >> "$OUTPUT_CSV"
}

# Function to audit IAM policies for a folder (recursive)
audit_folder() {
  local folder_id=$1
  echo "Auditing folder: $folder_id"
  
  # Get IAM policy for folder
  policy=$(gcloud resource-manager folders get-iam-policy "$folder_id" --format=json 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    echo "Failed to retrieve IAM policy for folder $folder_id"
    return
  fi

  # Parse bindings with jq and export to CSV
  echo "$policy" | jq -r '.bindings[] | .role as $role | .members[] | 
    select(. != null) | 
    ["folder_'$folder_id'", . , $role, "'$(is_high_privilege "$role")'"] | 
    @csv' >> "$OUTPUT_CSV"

  # Recursively audit subfolders
  subfolders=$(gcloud resource-manager folders list --folder="$folder_id" --format="value(name)")
  for subfolder in $subfolders; do
    audit_folder "$subfolder"
  done
}

# Main function to process organization or all projects
main() {
  local org_id=$1

  if [[ -n "$org_id" ]]; then
    # Audit organization-level policies
    echo "Auditing organization: $org_id"
    policy=$(gcloud organizations get-iam-policy "$org_id" --format=json 2>/dev/null)
    if [[ $? -eq 0 ]]; then
      echo "$policy" | jq -r '.bindings[] | .role as $role | .members[] | 
        select(. != null) | 
        ["org_'$org_id'", . , $role, "'$(is_high_privilege "$role")'"] | 
        @csv' >> "$OUTPUT_CSV"
    fi

    # Get all folders under the organization
    folders=$(gcloud resource-manager folders list --organization="$org_id" --format="value(name)")
    for folder in $folders; do
      audit_folder "$folder"
    done

    # Get all projects under the organization
    projects=$(gcloud projects list --filter="parent.id=$org_id" --format="value(projectId)")
  else
    # Get all projects accessible to the user
    projects=$(gcloud projects list --format="value(projectId)")
  fi

  # Audit each project
  for project in $projects; do
    audit_project "$project"
  done

  echo "Audit complete. Results saved to $OUTPUT_CSV"
}

# Check for organization ID argument
if [[ $# -eq 1 ]]; then
  main "$1"
else
  main
fi
