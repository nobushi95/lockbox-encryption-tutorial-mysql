#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails.
rm -f /app/tmp/pids/server.pid

# Run db setup
bundle exec rails db:create db:migrate 2>/dev/null || bundle exec rails db:migrate

exec "$@"
