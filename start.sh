#!/bin/bash
# WWT Music Club — Start Server (Background)
# Runs the Node.js server in the background and logs output

cd /var/www/wwtmc

# Create log directory if it doesn't exist
mkdir -p logs

# Get current timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="logs/wwtmc-$TIMESTAMP.log"

# Check if already running
if pgrep -f "node server.js" > /dev/null; then
  echo "⚠️  Server is already running"
  echo "View logs: tail -f logs/wwtmc-latest.log"
  echo "Stop: pkill -f 'node server.js'"
  exit 0
fi

# Run in background with nohup
nohup node server.js > "$LOG_FILE" 2>&1 &

# Create a symlink to latest log
ln -sf "$LOG_FILE" logs/wwtmc-latest.log

echo "✅ Server started in background"
echo "📝 Logs: $LOG_FILE"
echo "📊 View logs: tail -f logs/wwtmc-latest.log"
echo "🛑 Stop server: pkill -f 'node server.js'"
echo "🌐 Access: http://localhost:3000"
