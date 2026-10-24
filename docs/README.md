# Provider Tasks and Model Management

## Refresh Stale Default Models (P-007)

To maintain hygiene and ensure that default models used by the provider are always up-to-date, the system now automatically refreshes stale default models.

### What is a stale default model?

A default model is considered stale if it has not been refreshed or updated within a configured time window (e.g., 24 hours). Stale models may cause outdated or inconsistent behavior.

### How does the refresh work?

- On provider initialization or at scheduled intervals, the system checks the age of default models.
- If a model is detected as stale, it triggers a refresh operation to update the model data.
- This process is automatic and transparent to the user.

### Benefits

- Ensures the provider uses the latest model data.
- Improves reliability and hygiene of the system.
- Reduces manual intervention for model updates.

### Configuration

The stale threshold and refresh intervals can be configured in the provider settings.

---

For more details, see the [provider-tasks/TASK007.md](./provider-tasks/TASK007.md) for the original task description.
