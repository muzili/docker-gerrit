#!/bin/bash
# Starts up the Phabricator stack within the container.

# Stop on error
#set -e

GERRIT_HOME=/data/gerrit2
LOG_DIR=/var/log

if [[ -e /first_run ]]; then
  source /scripts/first_run.sh
else
  source /scripts/normal_run.sh
fi

pre_start_action
post_start_action

exec supervisord
