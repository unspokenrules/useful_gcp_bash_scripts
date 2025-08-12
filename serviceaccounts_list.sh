#!/bin/bash
echo "Select an option:"
echo "1. Print service account roles for a specific service account"
echo "2. Print all service account roles in a project"
read -p "Enter your choice 1 or 2: " choice
if [[ "$choice" == "1" ]]; then
    read -p "Enter the Service Account Email: " service_account_email
    read -p "Enter a comma-separated list of project names: " project_names
    read -p "Enter the output CSV file path: " output_path
    IFS=',' read -ra projects <<< "$project_names"
    echo "Project,Role,Member" > "$output_path"
    for project in "${projects[@]}"
    do
        echo "Project: $project"
        output=$(gcloud projects get-iam-policy "$project" --flatten="bindings[].members" --filter="bindings.members:$service_account_email" --format="csv[no-heading](bindings.role,bindings.members)")
        if [[ -n "$output" ]]; then
            echo "$output"
            echo "$output" | sed "s|^|$project,|g" >> "$output_path"
        else
            echo "No matching roles found for the service account in this project."
        fi
    done
    echo "Output saved to $output_path"
elif [[ "$choice" == "2" ]]; then
    read -p "Enter a comma-separated list of project names: " project_names
    read -p "Enter the output CSV file path: " output_path
    IFS=',' read -ra projects <<< "$project_names"
    echo "Member,Role,Project" > "$output_path"
    for project in "${projects[@]}"
    do
        echo "Project: $project"
        output=$(gcloud projects get-iam-policy "$project" --flatten="bindings[].members" --format="table(bindings.members,bindings.role)")
        if [[ -n "$output" ]]; then
            filtered_output=$(echo "$output" | awk -F' ' '$1 ~ /iam/ { print $0 }')
            if [[ -n "$filtered_output" ]]; then
                echo "$filtered_output"
                echo "$filtered_output" | awk -F' ' -v proj="$project" '{ print $1, $2, proj }' OFS=',' >> "$output_path"
            else
                echo "No matching service account roles found in this project."
            fi
        else
            echo "No matching roles found for this project."
        fi
    done
    echo "Output saved to $output_path"
else
    echo "Invalid choice. Please select either 1 or 2."
fi
