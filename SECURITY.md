# Security Policy

## Prototype Status

OpenClinic is a prototype and research codebase. It is not approved for production clinical use or deployment with real patient data.

## Reporting a Vulnerability

Do not open a public issue for security reports.

Use one of these private paths instead:

- GitHub private vulnerability reporting or security advisories for the repository, if enabled.
- Direct contact with the repository owner through GitHub.

When reporting an issue:

- Include reproduction steps, impact, and affected files or features.
- Redact all patient data, credentials, access tokens, and server details.
- Use synthetic or demo data only.

## In Scope

- Authentication and SMART on FHIR flows
- FHIR import and local persistence
- Local file storage for photos and exported documents
- Token handling, secrets handling, and transport security
- AI or RAG behavior that could expose sensitive local data

## Out of Scope

- General clinical correctness disagreements without a security impact
- Feature requests
- Unsupported deployment environments you have modified locally

## Supported Versions

- `main` only
