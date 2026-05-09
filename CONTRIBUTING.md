# Contributing to OpenClinic

OpenClinic is currently a prototype and product exploration repo. Small, focused improvements are more useful here than broad rewrites.

## Before You Start

- Open an issue or discussion before starting large changes.
- Keep one concern per pull request.
- Note the platform and Xcode version you used when validating changes.
- Never commit real patient data, screenshots with identifiable data, access tokens, or production credentials.

## What Good Contributions Look Like

- Apple-native changes that fit the current stack: SwiftUI, SwiftData, Core ML, and system frameworks.
- Local-first behavior by default.
- Clear provenance when data origin changes.
- Minimal dependency growth. If a new dependency is necessary, explain why in the PR.
- Public-facing docs that stay centered on OpenClinic and avoid internal planning material.

## Code Expectations

- Keep the app usable without external services whenever possible.
- For SMART or FHIR changes, document the auth assumptions, sandbox expectations, and what happens when live import is unavailable.
- For AI or RAG changes, explain retrieval, verification, and fallback behavior.
- Avoid mixing unrelated UI redesign, model changes, and interoperability work in one PR.

## Validation

- Include manual verification steps in the pull request description.
- If you changed platform-specific behavior, state which platform or device class you tested.
- If you could not run a build or a specific validation step, say so plainly.

## Pull Request Checklist

- The change is scoped and explained clearly.
- Public docs match the current code.
- No secrets or personal data are committed.
- New user-visible behavior is verified.
- Follow-up work is called out instead of being silently deferred.
