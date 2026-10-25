# TASK007: Refresh stale default models

## Background

Over time, the default models used by the provider can become stale due to updates in dependencies, improvements in model definitions, or bug fixes. This task ensures that the default models are refreshed regularly to maintain hygiene and correctness.

## Goal

Implement capability P-007 to refresh stale default models automatically or on demand, ensuring the provider uses up-to-date model definitions.

## Acceptance Criteria

- The provider detects when default models are stale (e.g., based on a version or timestamp).
- The provider refreshes the default models accordingly.
- Tests validate that stale models are detected and refreshed.
- Documentation or CHANGELOG is updated to reflect this new capability.

## Notes

- This is a **good first issue** for community contributors.
- Keep the blast radius small; avoid large refactors or unrelated changes.
- Follow the architecture guidelines for capability P-007.

---
<!-- coppergate-scout architectureId=P-007 -->
