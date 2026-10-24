# Autonomous Ship Loop for kprompt-examples

This package implements an autonomous shipping loop that keeps the `kprompt-examples` repository shipping real capabilities under a configurable monthly spend cap. It also supports survivor selection to retain the best shipped results for subsequent iterations.

## Features

- **Monthly Spend Cap Enforcement:** Ensures total spend on shipped items does not exceed a configured monthly budget.
- **Periodic Ship Attempts:** Ships new capabilities at a configurable interval.
- **Survivor Selection:** Keeps a configurable number of "survivor" shipped results based on a custom selection function.
- **Automatic History Pruning:** Removes shipped results older than 30 days from spend calculations.
- **Graceful Start/Stop:** Supports starting and stopping the autonomous loop cleanly.

## Usage
