#!/bin/bash
TIMEOUT=600
POLLING_INTERVAL=5

EXECUTION_ID=$(gcloud run jobs executions list --region=$(REGION) --project=$(PROJECT_NAME)  --job=$(CLOUD_RUN_MIGRATION_JOB) --limit=1 --sort-by="~createTime" --format="value(name)")

echo "Latest Execution ID: $EXECUTION_ID"

if [ -z "$EXECUTION_ID" ]; then
  echo "Failed to start the job execution."
  exit 1
fi

# Function to check the status of the job execution
check_status() {
  output=$(gcloud run jobs executions describe  $EXECUTION_ID --project $(PROJECT_NAME) --region $(REGION) --format="json")
  STATUS=$(echo "$output" | jq -r '.status.conditions[] | select(.type == "Completed") | .status')
  
  if [ "$STATUS" == "True" ]; then
    echo "Job execution completed successfully."
    return 0
  elif [ "$STATUS" == "False" ]; then
    echo "Job execution failed."
    return 1
  else
    echo "Job execution in progress..."
    return 2
  fi
}

START_TIME=$(date +%s)
# Poll the job status until it completes or fails
while true; do
  check_status
  STATUS_CODE=$?

  if [ $STATUS_CODE -eq 0 ]; then
    # Job completed successfully
    break
  elif [ $STATUS_CODE -eq 1 ]; then
    # Job failed
    echo "Cloud Run job failed"
    exit 1
  else
    # Check if the timeout has been reached
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
    
    if [ $ELAPSED_TIME -ge $TIMEOUT ]; then
      echo "Cloud Run job did not complete within 10 minutes. Exiting with error."
      exit 1  # Exit with error code to fail the pipeline
    fi
    # Job still in progress, wait for a while before checking again
    sleep $POLLING_INTERVAL # Wait for 10 min
  fi
done
