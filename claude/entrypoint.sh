#!/bin/bash

# Check if gh is authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "=========================================="
    echo "GitHub CLI is not authenticated."
    echo "Please authenticate to enable GitHub features"
    echo "like viewing workflows and managing issues."
    echo "=========================================="
    echo ""
    gh auth login
    echo ""
fi

# Run claude with all arguments
exec claude "$@"