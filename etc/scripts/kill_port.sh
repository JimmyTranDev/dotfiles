
#!/bin/zsh
source "$HOME/Programming/dotfiles/etc/scripts/common/utility.sh"

if [ -z "$1" ]; then
  echo "Usage: $0 <port>"
  exit 1
fi

PORT=$1

PID=$(lsof -ti tcp:$PORT)

if [ -z "$PID" ]; then
  echo "No process found on port $PORT"
else
  echo "Killing process $PID on port $PORT"
  kill -9 $PID
fi
