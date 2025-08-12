#!/bin/bash
PROJECT_ID="your-project-id"  # Replace with your GCP project ID
SA_NAME="my-service-account"  # Desired service account name
SA_EMAIL="$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"
ROLE="roles/editor"  # Role to assign (e.g., roles/viewer, roles/owner)

# Create the service account
gcloud iam service-accounts create $SA_NAME \
  --display-name="My Service Account" \
  --project=$PROJECT_ID

# Assign the role to the service account at the project level
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role=$ROLE

echo "Service account created: $SA_EMAIL"
