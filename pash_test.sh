#!/bin/bash

# pash_test.sh - A script to review code changes before pushing to a remote repository.

# --- Script Location Discovery ---
# Resolve symlinks to find the true script directory.
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# --- Configuration ---
# The review module to use.
REVIEW_MODULE="$SCRIPT_DIR/review_module.sh"
CONFIG_DIR="${HOME}/.config/pash"
CONFIG_FILE="${CONFIG_DIR}/config"
TEMPLATE_CONFIG_FILE="$SCRIPT_DIR/.pash_config"

# Local project configuration
LOCAL_PASH_DIR=".pash"
LOCAL_RULES_DIR="$LOCAL_PASH_DIR/rules"

# Load configuration from the user's config file.
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
else
  # Default value if config is missing.
  MAX_FILES_TO_REVIEW=20
fi

# --- Helper Functions ---
# Function to print an error message and exit.
error() {
  echo "Error: $1" >&2
  exit 1
}

# --- Initialization Function ---
init() {
  echo "Initializing PASH Code Review Framework for LiteLLM..."

  # Create the config directory if it doesn't exist.
  mkdir -p "$CONFIG_DIR"

  # Copy the template config file if one doesn't already exist.
  if [ ! -f "$CONFIG_FILE" ]; then
    if [ ! -f "$TEMPLATE_CONFIG_FILE" ]; then
      error "Template configuration file not found: $TEMPLATE_CONFIG_FILE"
    fi
    cp "$TEMPLATE_CONFIG_FILE" "$CONFIG_FILE"
  fi

  # Prompt for the LiteLLM API URL.
  read -p "Enter your LiteLLM API URL (e.g., http://localhost:4000): " litellm_api_url

  # Prompt for the LiteLLM API Key.
  read -p "Enter your LiteLLM API Key: " litellm_api_key

  # Prompt for the Model Name.
  read -p "Enter the model name to use (e.g., gpt-4, claude-3-opus): " litellm_model

  # Update the configuration file.
  sed -i.bak "s|LITELLM_API_URL=.*|LITELLM_API_URL=\"$litellm_api_url\"|" "$CONFIG_FILE"
  sed -i.bak "s|LITELLM_API_KEY=.*|LITELLM_API_KEY=\"$litellm_api_key\"|" "$CONFIG_FILE"
  sed -i.bak "s|LITELLM_MODEL=.*|LITELLM_MODEL=\"$litellm_model\"|" "$CONFIG_FILE"

  # Remove the backup file created by sed.
  rm -f "${CONFIG_FILE}.bak"

  echo "Configuration saved to $CONFIG_FILE."
  echo "Initialization complete. You can now run 'pash' to review your code."
}

# --- Rule Management Functions ---
init_rules() {
  echo "Initializing local PASH rules for this repository..."
  
  # Create the local .pash directory structure
  mkdir -p "$LOCAL_RULES_DIR"
  
  # Create default rule files
  cat > "$LOCAL_RULES_DIR/security.md" << 'EOF'
# Security Review Rules

## Critical Issues to Check
- **API Keys & Secrets**: Look for hardcoded API keys, passwords, tokens, or any sensitive credentials
- **Environment Variables**: Check for exposed environment variables that might contain secrets
- **Database Credentials**: Look for database connection strings or credentials
- **Private Keys**: Check for private keys, certificates, or cryptographic material
- **URLs with Credentials**: Look for URLs containing usernames/passwords

## Security Best Practices
- Ensure all secrets are stored in environment variables or secure vaults
- Check for proper input validation and sanitization
- Look for potential SQL injection vulnerabilities
- Verify proper authentication and authorization checks
EOF

  cat > "$LOCAL_RULES_DIR/code-quality.md" << 'EOF'
# Code Quality Review Rules

## Code Structure
- **Function Length**: Flag functions that are too long (>50 lines)
- **Code Duplication**: Look for repeated code blocks
- **Naming Conventions**: Check for clear, descriptive variable and function names
- **Comments**: Ensure complex logic is properly documented

## Best Practices
- Check for proper error handling
- Look for unused variables or imports
- Verify consistent code formatting
- Check for proper logging practices
EOF

  cat > "$LOCAL_RULES_DIR/project-specific.md" << 'EOF'
# Project-Specific Review Rules

## Custom Rules for This Project
Add your project-specific review rules here. Examples:

- **Framework-specific patterns**: Check for proper use of your chosen framework
- **Business logic**: Verify business rules are correctly implemented
- **Performance**: Look for potential performance issues specific to your domain
- **Dependencies**: Check for proper dependency management

## Team Conventions
- Add your team's coding conventions here
- Include any specific patterns or anti-patterns for your project
EOF

  # Create a .gitignore entry for .pash if it doesn't exist
  if [ ! -f ".gitignore" ] || ! grep -q "^\.pash/" ".gitignore"; then
    echo "" >> .gitignore
    echo "# PASH local configuration" >> .gitignore
    echo ".pash/" >> .gitignore
  fi

  echo "Local PASH rules initialized in $LOCAL_RULES_DIR"
  echo "You can customize the rules by editing the markdown files in that directory."
}

list_rules() {
  echo "Available review rules in this repository:"
  if [ -d "$LOCAL_RULES_DIR" ]; then
    local found_rules=false
    for rule_file in "$LOCAL_RULES_DIR"/*.md; do
      if [ -f "$rule_file" ]; then
        echo "  - $(basename "$rule_file")"
        found_rules=true
      fi
    done
    if [ "$found_rules" = false ]; then
      echo "  No rule files found in $LOCAL_RULES_DIR"
    fi
  else
    echo "No local rules found. Run 'pash init-rules' to create default rules."
  fi
}

add_rule() {
  local rule_name="$2"
  if [ -z "$rule_name" ]; then
    error "Please specify a rule name. Usage: pash add-rule <rule-name>"
  fi
  
  if [ ! -d "$LOCAL_RULES_DIR" ]; then
    echo "Local rules directory not found. Creating it..."
    mkdir -p "$LOCAL_RULES_DIR"
  fi
  
  local rule_file="$LOCAL_RULES_DIR/${rule_name}.md"
  if [ -f "$rule_file" ]; then
    error "Rule file $rule_file already exists."
  fi
  
  cat > "$rule_file" << EOF
# ${rule_name} Review Rules

## Description
Add a description of what this rule checks for.

## Rules
- Add your specific rules here
- Use bullet points for clarity
- Be specific about what to look for

## Examples
\`\`\`
// Good example
// Add examples of good code patterns

// Bad example  
// Add examples of patterns to avoid
\`\`\`
EOF

  echo "Created new rule file: $rule_file"
  echo "Edit this file to add your custom review rules."
}

# Function to check if a command exists.
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# --- Main Script ---
# Handle special commands
case "$1" in
  init)
    init
    exit 0
    ;;
  init-rules)
    init_rules
    exit 0
    ;;
  list-rules)
    list_rules
    exit 0
    ;;
  add-rule)
    add_rule "$@"
    exit 0
    ;;
  --version|-v)
    echo "PASH Code Review Framework v1.0.0"
    echo "AI-powered pre-push code review tool"
    exit 0
    ;;
  --help|-h)
    echo "PASH - AI-Powered Pre-Push Code Review"
    echo ""
    echo "Usage: pash [COMMAND|REVIEW_TYPE] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  init                 Initialize PASH with LiteLLM configuration"
    echo "  init-rules          Create default review rules for this repository"
    echo "  list-rules          List available review rules in this repository"
    echo "  add-rule <name>     Add a new custom review rule"
    echo ""
    echo "Review Types:"
    echo "  staged              Review staged changes"
    echo "  unstaged            Review unstaged changes"
    echo "  untracked           Review untracked files"
    echo "  all                 Review all changes (default)"
    echo ""
    echo "Options:"
    echo "  --rules=<files>     Use custom rule files (comma-separated)"
    echo "  --help, -h          Show this help message"
    echo "  --version, -v       Show version information"
    echo ""
    echo "Examples:"
    echo "  pash                Review all changes with auto-detected rules"
    echo "  pash staged         Review only staged changes"
    echo "  pash --rules=security.md,quality.md  # Use specific rule files"
    exit 0
    ;;
esac

# Check if Git is installed.
if ! command_exists git; then
  error "Git is not installed. Please install Git to use this script."
fi

# Check if the current directory is a Git repository.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  error "Not a Git repository. Please run this script from within a Git repository."
fi

# --- Parse Arguments ---
# Parse command line arguments for review type and custom rules
REVIEW_TYPE="all"
CUSTOM_RULES=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    staged|unstaged|untracked|all)
      REVIEW_TYPE="$1"
      shift
      ;;
    --rules)
      CUSTOM_RULES="$2"
      shift 2
      ;;
    --rules=*)
      CUSTOM_RULES="${1#*=}"
      shift
      ;;
    *)
      # If it's not a known argument, treat it as review type for backward compatibility
      if [[ "$1" =~ ^(staged|unstaged|untracked|all)$ ]]; then
        REVIEW_TYPE="$1"
      else
        error "Unknown argument: $1. Usage: pash [staged|unstaged|untracked|all] [--rules=file1.md,file2.md]"
      fi
      shift
      ;;
  esac
done

echo "Reviewing '$REVIEW_TYPE' changes..."

# --- Rule Selection Logic ---
# If no custom rules specified via command line, ask user interactively
if [ -z "$CUSTOM_RULES" ]; then
  echo ""
  read -p "Would you like to use custom review rules? (y/N): " use_custom_rules
  
  if [[ "$use_custom_rules" =~ ^[Yy]$ ]]; then
    # Ask for rule file paths
    read -p "Enter rule file paths (comma-separated, or press Enter for default): " rule_paths
    
    if [ -z "$rule_paths" ]; then
      # Check if local rules exist as default
      if [ -d "$LOCAL_RULES_DIR" ]; then
        LOCAL_RULE_FILES=$(find "$LOCAL_RULES_DIR" -name "*.md" -type f 2>/dev/null)
        
        if [ -n "$LOCAL_RULE_FILES" ]; then
          echo "Using local repository rules as default:"
          for rule_file in $LOCAL_RULE_FILES; do
            echo "  - $(basename "$rule_file")"
          done
          # Convert file paths to comma-separated list
          CUSTOM_RULES=$(echo "$LOCAL_RULE_FILES" | tr '\n' ',' | sed 's/,$//')
        else
          echo "No local rules found. Using default review prompts."
        fi
      else
        echo "No local rules directory found. Using default review prompts."
      fi
    else
      # Validate and use provided rule paths
      CUSTOM_RULES="$rule_paths"
      echo "Using custom rules: $CUSTOM_RULES"
      
      # Validate that the rule files exist
      IFS=',' read -ra RULE_FILES <<< "$CUSTOM_RULES"
      for rule_file in "${RULE_FILES[@]}"; do
        rule_file=$(echo "$rule_file" | xargs) # trim whitespace
        if [ ! -f "$rule_file" ]; then
          echo "Warning: Rule file not found: $rule_file"
        fi
      done
    fi
  else
    echo "Using default review prompts."
  fi
fi

if [ -n "$CUSTOM_RULES" ]; then
  echo "Custom rules: $CUSTOM_RULES"
fi

# Handle the edge case of a new repository with no commits yet.
if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
  error "This repository has no commits yet. Please make a commit before running a review."
fi

case "$REVIEW_TYPE" in
  staged)
    # Reviews changes that are staged for the next commit.
    DIFF=$(git diff --staged)
    ;;
  unstaged)
    # Reviews changes in the working directory that are not staged.
    DIFF=$(git diff)
    ;;
  untracked)
    # Reviews untracked files by showing their full content
    UNTRACKED_FILES=$(git ls-files --others --exclude-standard | grep -v '^\.pash_reviews/')
    if [ -z "$UNTRACKED_FILES" ]; then
      echo "No untracked files to review."
      exit 0
    fi
    DIFF=""
    for file in $UNTRACKED_FILES; do
      if [ -f "$file" ]; then
        DIFF="$DIFF
diff --git a/dev/null b/$file
new file mode 100644
index 0000000..$(git hash-object "$file" 2>/dev/null || echo "0000000")
--- /dev/null
+++ b/$file
$(sed 's/^/+/' "$file")"
      fi
    done
    ;;
  all)
    # Reviews all local changes: staged, unstaged, and untracked
    DIFF=""
    
    # Get staged changes
    STAGED_DIFF=$(git diff --staged)
    if [ -n "$STAGED_DIFF" ]; then
      DIFF="$STAGED_DIFF"
    fi
    
    # Get unstaged changes
    UNSTAGED_DIFF=$(git diff)
    if [ -n "$UNSTAGED_DIFF" ]; then
      if [ -n "$DIFF" ]; then
        DIFF="$DIFF

$UNSTAGED_DIFF"
      else
        DIFF="$UNSTAGED_DIFF"
      fi
    fi
    
    # Get untracked files (excluding review files)
    UNTRACKED_FILES=$(git ls-files --others --exclude-standard | grep -v '^\.pash_reviews/')
    if [ -n "$UNTRACKED_FILES" ]; then
      for file in $UNTRACKED_FILES; do
        if [ -f "$file" ]; then
          UNTRACKED_DIFF="
diff --git a/dev/null b/$file
new file mode 100644
index 0000000..$(git hash-object "$file" 2>/dev/null || echo "0000000")
--- /dev/null
+++ b/$file
$(sed 's/^/+/' "$file")"
          if [ -n "$DIFF" ]; then
            DIFF="$DIFF$UNTRACKED_DIFF"
          else
            DIFF="$UNTRACKED_DIFF"
          fi
        fi
      done
    fi
    ;;
  *)
    error "Invalid review type: '$REVIEW_TYPE'. Please use 'staged', 'unstaged', 'untracked', or 'all'."
    ;;
esac

# If there are no changes, exit.
if [ -z "$DIFF" ]; then
  echo "No changes to review."
  exit 0
fi

# --- File Limit Check ---
# Count the number of files in the diff.
FILE_COUNT=$(echo "$DIFF" | grep -c '^diff --git')

if [ "$FILE_COUNT" -gt "$MAX_FILES_TO_REVIEW" ]; then
  error "The number of changed files ($FILE_COUNT) exceeds the configured limit of $MAX_FILES_TO_REVIEW.
Please commit some changes or increase the limit in $CONFIG_FILE."
fi

# Check if the review module exists and is executable.
if [ ! -f "$REVIEW_MODULE" ]; then
  error "Review module not found: $REVIEW_MODULE"
fi

if [ ! -x "$REVIEW_MODULE" ]; then
  error "Review module is not executable: $REVIEW_MODULE"
fi

# Pass the diff to the review module and print the review.
echo "--- Code Review ---"
# Export custom rules as environment variable if provided
if [ -n "$CUSTOM_RULES" ]; then
  export PASH_CUSTOM_RULES="$CUSTOM_RULES"
fi
echo "$DIFF" | "$REVIEW_MODULE"
echo "-------------------"

exit 0
