# PASH - AI-Powered Pre-Push Code Review

PASH is a command-line framework that uses AI to review your code for potential issues before you push it to a remote repository. It is designed to be a simple yet powerful tool to help you catch bugs, security vulnerabilities, and exposed secrets early in the development process.

The framework leverages LiteLLM to connect to a wide variety of language models, giving you the flexibility to choose the AI that best suits your needs.

## Features

- **AI-Powered Reviews**: Get intelligent feedback on your code changes.
- **Multiple Review Scopes**: Review staged, unstaged, committed, or all local changes.
- **Configurable**: Easily configure your AI provider, model, and other settings.
- **File Limit**: Prevent accidental reviews of large changesets with a configurable file limit.
- **Shell Compatible**: Works seamlessly in any standard shell environment.

## Prerequisites

Before you begin, ensure you have the following tools installed on your system:

- **Git**: For version control.
- **curl**: For making API requests.
- **jq**: For parsing JSON responses.

You can typically install these on macOS using Homebrew:
```bash
brew install git curl jq
```
Or on Debian/Ubuntu-based systems:
```bash
sudo apt-get update && sudo apt-get install -y git curl jq
```

## Installation with Homebrew (Recommended)

If you are on macOS or Linux, the easiest way to install PASH is with [Homebrew](https://brew.sh/).

1.  **Tap the Repository**
    First, you need to "tap" the PASH formula repository. This tells Homebrew where to find the installation formula.
    ```bash
    brew tap gyash1512/pash
    ```

2.  **Install PASH**
    Now, you can install PASH with a single command:
    ```bash
    brew install pash
    ```
    Homebrew will handle all the dependencies and place the `pash` command in your PATH.

## Alternative Installation (Manual)

If you are not using Homebrew, you can install the framework manually.

1.  **Clone the Repository**
    First, clone this repository to your local machine:
    ```bash
    git clone https://github.com/gyash1512/PASH.git
    cd PASH
    ```

2.  **Run the Installation Script**
    Next, run the installation script. This will make the necessary scripts executable and attempt to create a symbolic link in `/usr/local/bin`.
    ```bash
    ./install.sh install
    ```
    *Note: You may be prompted for your administrator password. If the symbolic link fails, the script will provide instructions on how to add the PASH directory to your PATH manually.*

## Configuration

After installation, you need to initialize the framework to configure your AI provider.

1.  **Run the Initialization Command**
    ```bash
    pash init
    ```

2.  **Enter Your Credentials**
    You will be prompted to enter the following information:
    - **LiteLLM API URL**: The full URL of your LiteLLM service (e.g., `http://localhost:4000`).
    - **LiteLLM API Key**: Your API key for the LiteLLM service.
    - **Model Name**: The name of the model you want to use (e.g., `gpt-4`, `claude-3-opus`).

Your configuration will be saved to a `.pash_config` file in the PASH directory.

## Usage

You can run PASH from within any Git repository on your machine.

-   **Review All Local Changes**
    To review all committed, staged, and unstaged changes since your last push:
    ```bash
    pash all
    ```
    Or simply:
    ```bash
    pash
    ```

-   **Review Staged Changes**
    To review only the changes that are staged for the next commit:
    ```bash
    pash staged
    ```

-   **Review Unstaged Changes**
    To review changes in your working directory that have not been staged:
    ```bash
    pash unstaged
    ```

-   **Review the Last Commit**
    To review the changes from your most recent commit:
    ```bash
    pash committed
    ```

Now, you can commit this updated `README.md` and push it to your GitHub repository. Others will then have clear instructions on how to install and use your PASH framework.
