#!/bin/bash

# review_module.sh - An AI-powered review module using LiteLLM.

# --- Configuration ---
# Load configuration from the user's config file.
CONFIG_DIR="${HOME}/.config/pash"
CONFIG_FILE="${CONFIG_DIR}/config"
TEMPLATE_CONFIG_FILE="$(dirname "$0")/.pash_config"

# --- Helper Functions ---
# Function to print an error message and exit.
error() {
  echo "Error: $1" >&2
  exit 1
}

if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
else
  error "Configuration file not found: $CONFIG_FILE. Please run 'pash init' to create it."
fi

# Check for custom rules passed via environment variables
CUSTOM_RULES_CONTENT=""
if [ -n "$PASH_CUSTOM_RULES" ]; then
  # Parse comma-separated rule files
  IFS=',' read -ra RULE_FILES <<< "$PASH_CUSTOM_RULES"
  for rule_file in "${RULE_FILES[@]}"; do
    rule_file=$(echo "$rule_file" | xargs) # trim whitespace
    if [ -f "$rule_file" ]; then
      CUSTOM_RULES_CONTENT="$CUSTOM_RULES_CONTENT

$(cat "$rule_file")"
    fi
  done
fi

# Function to check if a command exists.
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# --- Pre-flight Checks ---
# Check for required commands.
for cmd in curl jq; do
  if ! command_exists "$cmd"; then
    error "'$cmd' is not installed. Please install it to use the AI review feature."
  fi
done

# Check if the LiteLLM configuration is complete.
if [ -z "$LITELLM_API_URL" ] || [ "$LITELLM_API_URL" == "your-litellm-api-url" ] || \
   [ -z "$LITELLM_API_KEY" ] || [ "$LITELLM_API_KEY" == "your-litellm-api-key" ] || \
   [ -z "$LITELLM_MODEL" ] || [ "$LITELLM_MODEL" == "your-model-name" ]; then
  error "LiteLLM is not configured. Please run 'pash init' to set it up."
fi

# --- Main Script ---
# Read the diff from standard input.
DIFF=$(cat)

# If the diff is empty, there's nothing to review.
if [ -z "$DIFF" ]; then
  echo "No changes detected to review."
  exit 0
fi

# --- Basic Review (Counts) ---
ADDED_LINES=$(echo "$DIFF" | grep -c "^\+")
REMOVED_LINES=$(echo "$DIFF" | grep -c "^\-")

echo "--- Basic Summary ---"
echo "  - Added lines: $ADDED_LINES"
echo "  - Removed lines: $REMOVED_LINES"
echo "---------------------"
echo ""

# --- AI-Powered Review ---
echo "--- AI Review ---"
echo "Analyzing changes with LiteLLM (Model: $LITELLM_MODEL)... (This may take a moment)"

# Prepare the prompt for the AI model.
# Include custom rules if provided, otherwise use default prompt.
if [ -n "$CUSTOM_RULES_CONTENT" ]; then
  PROMPT="You are an expert code reviewer performing a pre-push code review. Please review the following git diff according to the specific rules and guidelines provided below.

## Review Rules and Guidelines:
$CUSTOM_RULES_CONTENT

## Instructions:
- Follow the rules and guidelines above when reviewing the code
- Pay special attention to security issues like exposed secrets, API keys, or credentials
- Check for code quality issues as specified in the rules
- Provide specific, actionable feedback
- If you find any critical security issues, clearly state them and advise immediate action

Here is the diff to review:
\`\`\`diff
$DIFF
\`\`\`"
else
  PROMPT="You are an expert security engineer performing a pre-push code review. Your primary goal is to identify any secrets, API keys, credentials, or exposed environment variables. Also, check for other critical issues like major bugs or logic flaws.

Analyze the following git diff and provide your feedback. If you find any secrets, state it clearly and advise the user to remove them immediately.

Here is the diff:
\`\`\`diff
$DIFF
\`\`\`"
fi

# Create the JSON payload for the LiteLLM API.
JSON_PAYLOAD=$(jq -n --arg model "$LITELLM_MODEL" --arg prompt "$PROMPT" \
'{
  "model": $model,
  "messages": [
    {
      "role": "user",
      "content": $prompt
    }
  ]
}')

# Make the API call to LiteLLM.
# Remove trailing slash from URL if it exists, then append the path.
BASE_URL=$(echo "$LITELLM_API_URL" | sed 's:/*$::')
API_ENDPOINT="${BASE_URL}/chat/completions"

# Make a single API call, capturing both response body and HTTP status code
TEMP_RESPONSE_FILE=$(mktemp)
HTTP_CODE=$(curl -s -w "%{http_code}" -o "$TEMP_RESPONSE_FILE" -X POST \
  -H "Authorization: Bearer ${LITELLM_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD" \
  "$API_ENDPOINT")

RESPONSE=$(cat "$TEMP_RESPONSE_FILE")
rm "$TEMP_RESPONSE_FILE"

# Check for non-200 HTTP status codes, but also check if we have valid JSON response
if [ "$HTTP_CODE" -ne 200 ]; then
    # Check if response contains valid JSON with choices array (sometimes APIs return 502 but still have valid response)
    if echo "$RESPONSE" | jq -e '.choices[0].message.content' >/dev/null 2>&1; then
        echo "Warning: API returned HTTP $HTTP_CODE but response appears valid, proceeding..."
    else
        error "LiteLLM API returned a non-200 status code: $HTTP_CODE. Response: $RESPONSE"
    fi
fi

# Check for errors in the API response body.
if echo "$RESPONSE" | jq -e '.error' > /dev/null; then
  ERROR_MESSAGE=$(echo "$RESPONSE" | jq -r '.error.message')
  error "LiteLLM API returned an error: $ERROR_MESSAGE"
fi

# Extract and print the AI's review.
AI_REVIEW=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty')

if [ -z "$AI_REVIEW" ]; then
    # Try alternative response format
    AI_REVIEW=$(echo "$RESPONSE" | jq -r '.content // .message.content // empty')
fi

if [ -z "$AI_REVIEW" ]; then
    # If still empty, check if it's a direct text response
    if echo "$RESPONSE" | jq -e '.' >/dev/null 2>&1; then
        # It's valid JSON but doesn't have expected structure
        error "Failed to extract a valid review from the LiteLLM response. Raw response: $RESPONSE"
    else
        # It might be plain text response
        AI_REVIEW="$RESPONSE"
    fi
fi

# Create review output directory if it doesn't exist
REVIEW_DIR=".pash_reviews"
mkdir -p "$REVIEW_DIR"

# Generate timestamp for filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REVIEW_FILE="$REVIEW_DIR/review_$TIMESTAMP.md"

# Create markdown content
MARKDOWN_CONTENT="# PASH Code Review - $(date '+%Y-%m-%d %H:%M:%S')

## Basic Summary
- Added lines: $ADDED_LINES
- Removed lines: $REMOVED_LINES

## AI Review
$AI_REVIEW

---
*Generated by PASH Code Review Framework*
"

# Save to markdown file
echo "$MARKDOWN_CONTENT" > "$REVIEW_FILE"

# Print the review to console
echo "$AI_REVIEW"
echo "-----------------"
echo ""
echo "📝 Review saved to: $REVIEW_FILE"

exit 0
