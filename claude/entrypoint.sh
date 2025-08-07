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

# Check if Perplexity API key is set for MCP server
if [ -z "$PERPLEXITY_API_KEY" ]; then
    echo "=========================================="
    echo "NOTICE: Perplexity MCP Server"
    echo "The Perplexity web search MCP server requires an API key."
    echo "To enable it, set the PERPLEXITY_API_KEY environment variable:"
    echo "  export PERPLEXITY_API_KEY=your-api-key"
    echo "Get your API key at: https://www.perplexity.ai/settings/api"
    echo ""
    echo "Context7 and Sequential Thinking MCP servers are ready to use!"
    echo "=========================================="
    echo ""
fi

# Run claude with all arguments
exec claude "$@"