#!/bin/bash

# install.sh - Installation and initialization script for the PASH Code Review Framework.

# --- Configuration ---
PASH_SCRIPT="pash_test.sh"
REVIEW_MODULE="review_module.sh"
CONFIG_FILE=".pash_config"
INSTALL_PATH="/usr/local/bin/pash"

# --- Helper Functions ---
error() {
  echo "Error: $1" >&2
  exit 1
}

# --- Installation Function ---
install() {
  echo "Installing PASH Code Review Framework..."

  # Check if the main script exists.
  if [ ! -f "$PASH_SCRIPT" ]; then
    error "Main script not found: $PASH_SCRIPT"
  fi

  # Make the scripts executable.
  chmod +x "$PASH_SCRIPT"
  chmod +x "$REVIEW_MODULE"

  # Create a symbolic link in the install path.
  if [ -L "$INSTALL_PATH" ]; then
    echo "Removing existing symbolic link..."
    sudo rm "$INSTALL_PATH"
  fi
  
  echo "Creating symbolic link at $INSTALL_PATH..."
  if sudo ln -s "$(pwd)/$PASH_SCRIPT" "$INSTALL_PATH"; then
    echo "Installation complete. You can now run 'pash' from anywhere."
    echo "Next, please run 'pash init' to configure the framework."
  else
    echo ""
    echo "---"
    echo "Warning: Failed to create symbolic link. This usually requires administrator privileges."
    echo "As an alternative, you can add the PASH directory to your shell's PATH."
    echo ""
    echo "Please add the following line to your shell configuration file (e.g., ~/.zshrc, ~/.bash_profile):"
    echo "  export PATH=\"\$PATH:$(pwd)\""
    echo ""
    echo "After adding the line, restart your terminal or run 'source ~/.zshrc' (or your respective config file)."
    echo "You will then be able to run 'pash_test.sh' as a command (e.g., 'pash_test.sh init')."
    echo "---"
  fi
}

# --- Main Script ---
if [ "$1" == "install" ]; then
  install
else
  echo "Usage: $0 install"
  exit 1
fi

exit 0
