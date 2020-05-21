#!/bin/bash

set -e

if [[ ! -z "$SKIP_DEBUGGER" ]]; then
    echo "Skipping debugger because SKIP_DEBUGGER enviroment variable is set"
    exit
fi

# Install tmate on macOS or Ubuntu
echo Setting up tmate...
if [ -x "$(command -v apt-get)" ]; then
    curl -fsSL git.io/tmate.sh | bash
elif [ -x "$(command -v brew)" ]; then
    brew install tmate
else
    exit 1
fi

# Generate ssh key if needed
[ -e ~/.ssh/id_rsa ] || ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -N ""

# Run deamonized tmate
echo Running tmate...
tmate -S /tmp/tmate.sock new-session -d
tmate -S /tmp/tmate.sock wait tmate-ready

# Print connection info
DISPLAY=1
while [ $DISPLAY -le 3 ]; do
    echo ________________________________________________________________________________
    echo To connect to this session copy-n-paste the following into a terminal or browser:
    tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}'
    tmate -S /tmp/tmate.sock display -p '#{tmate_web}'
    [ ! -f /tmp/keepalive ] && echo -e "After connecting you can run 'touch /tmp/keepalive' to disable the 30m timeout"
    DISPLAY=$(($DISPLAY + 1))
    sleep 30
done

if [[ ! -z "$SLACK_WEBHOOK_URL" ]]; then
    MSG=$(tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}')
    curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"\`$MSG\`\"}" $SLACK_WEBHOOK_URL
fi

# Wait for connection to close or timeout in 15 min
timeout=$((30 * 60))
while [ -S /tmp/tmate.sock ]; do
    sleep 1
    timeout=$(($timeout - 1))

    if [ ! -f /tmp/keepalive ]; then
        if ((timeout < 0)); then
            echo Waiting on tmate connection timed out!
            sudo init 0
        fi
    fi
done
