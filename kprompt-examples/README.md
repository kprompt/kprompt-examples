# kprompt-examples Autonomous Ship Loop

This module implements an **autonomous ship loop** for kprompt/kprompt-examples that continuously ships real capabilities while respecting a monthly spend cap and applying survivor selection logic.

## Features

- **Monthly spend cap enforcement**: Stops shipping if the monthly spend exceeds a configured USD cap.
- **Survivor selection**: After each ship iteration, decides whether to continue shipping or stop based on survivor selection logic.
- **Configurable ship callback**: Integrate your shipping logic.
- **Configurable spend tracking**: Provide a function to get current spend.
- **Configurable survivor selector**: Provide a function to decide if the current iteration survives.
- **Safe stop/start**: Start with optional max iterations and ability to stop the loop.

## Usage
