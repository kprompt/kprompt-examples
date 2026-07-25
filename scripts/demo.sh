#!/usr/bin/env bash
# Back-compat wrapper — prefer `make walkthrough`.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/walkthrough.sh"
