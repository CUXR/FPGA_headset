#!/usr/bin/env bash

# This script is intended to be sourced:
#
#   source env/login.sh
#

# Get the location of this script when sourced from zsh
SCRIPT_PATH="${(%):-%N}"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)"
PROJ_BASE="$(cd -- "$SCRIPT_DIR/.." && pwd)"
export PROJ_BASE

# ================================ CONDA =================================
# Create or update the Conda environment defined by:
#
#   python/environment.yml
#
# Then activate the environment.
# ========================================================================

echo -e "\nSetting up Python environment..."

ENV_FILE="${PROJ_BASE}/python/environment.yml"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: Could not find '$ENV_FILE'." >&2
    return 1
fi

# Read the environment name from environment.yml
ENV_NAME="$(
    awk '
        /^[[:space:]]*name:[[:space:]]*/ {
            sub(/^[[:space:]]*name:[[:space:]]*/, "")
            gsub(/[[:space:]]+$/, "")
            print
            exit
        }
    ' "$ENV_FILE"
)"

if [[ -z "$ENV_NAME" ]]; then
    echo "Error: No 'name:' field found in '$ENV_FILE'." >&2
    return 1
fi

# Make sure Conda is available
if ! command -v conda >/dev/null 2>&1; then
    echo "Error: Conda is not available in the current shell." >&2
    echo "Initialize Conda first, then source this script again." >&2
    return 1
fi

# Create the environment if it does not exist.
# Otherwise, update it to match environment.yml.
if conda env list | awk '{print $1}' | grep -Fxq "$ENV_NAME"; then
    conda env update \
        --name "$ENV_NAME" \
        --file "$ENV_FILE" \
        --prune \
        --quiet >/dev/null 2>&1
else
    echo "Creating Conda environment '$ENV_NAME'..."
    conda env create \
        --file "$ENV_FILE" \
        --quiet >/dev/null 2>&1
fi

# Prevent Conda from modifying the shell prompt for this shell only.
export CONDA_CHANGEPS1=false

conda activate "$ENV_NAME" || {
    echo "Error: Failed to activate Conda environment '$ENV_NAME'." >&2
    return 1
}

# pyenv may have added its shims ahead of Conda's existing PATH entry. Conda
# then replaces that entry in place during activation, leaving pyenv's Python
# as the default. Explicitly put the activated environment first.
export PATH="${CONDA_PREFIX}/bin:${PATH}"
hash -r

echo "Activated Conda environment '$ENV_NAME'."


# ================================ PYTEST ================================
# Convenience command for running project Python tests.
#
# Example:
#
#   pytest
#   pytest verif/tests/test_transform.py
#   pytest -v
# ========================================================================

pytest() (
    if [[ -z "${PROJ_BASE:-}" ]]; then
        echo "Error: PROJ_BASE is not set." >&2
        return 1
    fi

    cd "$PROJ_BASE/python" || {
        echo "Error: Could not enter '$PROJ_BASE/python'." >&2
        return 1
    }

    "${CONDA_PREFIX}/bin/python" -m pytest "$@"
)

echo "'pytest' command created."


# ================================ CLEANUP ================================

unset SCRIPT_DIR
unset ENV_FILE
unset ENV_NAME

echo -e "\nProject environment ready."
