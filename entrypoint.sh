#!/usr/bin/env bash

set -eo pipefail
[[ -n "${DEBUG}" ]] && set -x
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

# Setup and rotate log files once every 30 seconds to keep file size to a minimum
rm -f /fastly.log && touch /fastly.log
(set +e; while true; do sleep 30 && logrotate -s /logrotate.status /logrotate.conf; done) &

# Run vector to receive input
vector --config /vector.toml >> /fastly.log &

if [ -z "$CREDENTIAL" ]; then
        exec ttyd -R -- tail -F /fastly.log
else
        exec ttyd -R -c "$CREDENTIAL" -- tail -F /fastly.log
fi
