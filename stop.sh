#!/bin/bash
# WWT Music Club — Stop Server

if pkill -f "node server.js"; then
  echo "✅ Server stopped"
else
  echo "⚠️  Server is not running"
  exit 1
fi
