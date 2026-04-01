# MedMod Wow Roadmap

## Purpose

This document reframes MedMod from a strong UI prototype into a plausible provider-grade mobile EHR pitch.

The core question is not whether the app looks better than current vendor apps. It does.

The real question is whether it demonstrates the things an EHR company would need to believe:

- it can plug into a real interoperability stack
- it reduces clinician friction instead of adding more data burden
- it closes the loop on actual work, not just chart viewing
- it handles trust, provenance, and enterprise mobile constraints

## What MedMod Already Proves

The current repo already proves several things well:

- A modern mobile EHR shell can feel cleaner and more readable than many incumbent products.
- Daily scheduling can be reframed around clinician workflow instead of raw appointment data.
- A patient chart can be organized around the questions clinicians actually ask.
- Local AI can summarize, search, and synthesize the chart in ways that feel useful at the point of care.
- Lesion and anatomy workflows are more visual and intuitive than most generic EHR mobile interfaces.

Concrete strengths already visible in the codebase:

- Main shell and tab architecture: `MedMod/Views/EHRMainShellView.swift`
- Agenda and workflow-oriented day view: `MedMod/Views/SubViews.swift`
- Patient chart navigation and alerts: `MedMod/Views/PatientDashboardView.swift`
- Local chart intelligence and panel queries: `MedMod/AI/ClinicalIntelligenceService.swift`
- Photo and lesion tracking surfaces: `MedMod/Views/ClinicalPhotoView.swift`, `MedMod/Views/LesionTrackingView.swift`, `MedMod/Views/AnatomicalRealityView.swift`

## The Biggest Gaps

If the goal is to impress an EHR company, the missing pieces are mostly not visual.

### 1. Interoperability credibility

Right now the app behaves like an advanced local prototype.

What an EHR vendor will ask immediately:

- How does this authenticate into a production EHR?
- How does it receive patient context?
- What standards does it speak?
- Which resources can it read and write?
- How do you keep source-of-truth data and local state aligned?

Without a SMART on FHIR story, this looks like a beautiful sidecar app instead of a platform-ready product.

### 2. Closed-loop workflow

The most persuasive demo is not “look at the chart.”

It is:

- open schedule
- enter patient context
- review pre-visit summary
- capture exam data/photos
- draft note
- reconcile meds and history
- place or prepare follow-up actions
- generate patient instructions
- sign or route

That is the moment where a buyer sees time saved, not just design quality.

### 3. Provenance and reconciliation

Every clinically meaningful datum needs an answer to:

- where did this come from?
- when was it refreshed?
- what is authoritative?
- is this patient-generated, imported, or directly from the EHR?

This app currently has local truth and mock truth, but not source-aware truth.

### 4. Enterprise mobile reality

Provider mobile software lives in a world of:

- shared devices
- rapid re-authentication
- session timeout
- lost devices
- device management
- role-based access
- auditability

The workflow literature is clear that mobile device efficiency matters, but usability competes directly with security and authentication burden.

### 5. Learnability and UX guidance

The app is visually strong, but a production EHR mobile product must make three things obvious everywhere:

- who is this?
- what matters now?
- what should I do next?

The best enterprise apps quietly guide action without feeling tutorial-heavy.

## HealthKit: What It Can And Cannot Do

This matters because it changes the entire integration strategy.

### What HealthKit can do

HealthKit can read health data that belongs to the device owner after explicit authorization.

`HKHealthStore` is the access point for HealthKit data and requires authorization to read types. `HKClinicalRecord` represents a clinical record stored on the user's device and exposes an underlying FHIR resource payload originating from the user's healthcare institution.

That means HealthKit can be useful for:

- patient-authorized, device-local data access
- patient-facing apps
- patient-contributed summaries or imported records on the patient's device
- selective patient-mediated sharing workflows

### What HealthKit cannot realistically do here

HealthKit is not the right mechanism for a provider app to request arbitrary patient data from outside the device owner's local health store.

In plain terms:

- a provider cannot just ask for Gunnar's Apple Health data from the provider's device
- a provider app cannot use HealthKit as a general EHR network retrieval layer
- HealthKit is not a substitute for provider interoperability infrastructure

That is why removing HealthKit as the central provider data source was the correct architectural decision for this repo.

## What A Provider App Actually Needs

For a credible provider-facing product, the data strategy should be:

### A. SMART on FHIR for EHR-connected provider workflows

SMART App Launch is the most important interoperability box to check.

It provides:

- launch context from the EHR
- OAuth-based authorization
- patient/user scoped access
- support for user-facing apps and backend services
- standards-based FHIR resource access

### B. FHIR resource model for core chart content

The app should clearly map to real-world resource types such as:

- Patient
- Appointment / Schedule / Slot
- Encounter
- Practitioner / PractitionerRole
- Condition
- AllergyIntolerance
- MedicationRequest
- Observation
- DiagnosticReport
- DocumentReference
- Procedure
- ServiceRequest

### C. Controlled PGHD intake instead of raw data dumping

Patient-generated health data should not just appear as a firehose in the provider chart.

The literature suggests the integration problem is not capture alone. It is delivery, review preferences, workflow fit, and resource burden.

So the design target should be:

- exception-based review
- triage first, chart second
- clear provenance
- explicit clinician acceptance or dismissal

## Evidence That Supports This Direction

### SMART / interoperability

The SMART App Launch implementation guide defines discovery, OAuth-based authorization, user-facing launch patterns, backend service authorization, scopes, and patient launch context. That is the standard language EHR vendors expect for app integration.

### PGHD integration evidence

Tiase et al., "Patient-generated health data and electronic health record integration: a scoping review" (JAMIA Open, 2020), found that PGHD integration was still early and highlighted recurring problems around resource requirements, delivery into the EHR, and review workflow preferences.

This is important: the opportunity is not just to ingest more data, but to make it reviewable without burdening clinicians.

### Mobile clinician workflow evidence

Gellert et al., "A Survey of Clinicians in US Healthcare Delivery Organizations on Mobile Device Use in Care Delivery" (2025), found that mobile workflows can improve efficiency and are frequently used to access the EHR, but security, authentication, and mobile fleet complexity remain major adoption constraints.

That means enterprise mobile flow is part of the product value proposition, not an implementation detail.

## What Would Actually Wow A Company Like ModMed

The strongest pitch is not “I redesigned your app.”

It is:

"I built a faster, more intuitive mobile specialty workflow on top of the standards your ecosystem already depends on."

For this repo, the most convincing single workflow is dermatology mobile care:

1. Open agenda.
2. Enter a patient directly from today's workflow.
3. See a pre-visit AI brief with source-aware facts.
4. Review recent lesions, prior images, meds, and risk flags.
5. Capture new photo or anatomy findings.
6. Generate a note draft from structured exam context.
7. Reconcile medications and follow-up plan.
8. Produce patient instructions.
9. Sign or send downstream.

That tells a buyer:

- this improves throughput
- this reduces chart review burden
- this can sit in or around existing infrastructure
- this is not just a mockup

## Recommended Product Direction

### North star

Build MedMod as a specialty mobile workflow layer that sits on top of real interoperability standards, with local intelligence accelerating chart review and documentation.

### Positioning

MedMod should be framed as:

- a provider-first mobile chart and workflow client
- optimized for specialty clinics
- intelligence-assisted but not AI-led
- source-aware and standards-based
- designed to reduce clicks, navigation friction, and review burden

Not as:

- a replacement for the entire enterprise EHR on day one
- a generic patient data viewer
- a HealthKit-based provider aggregator

## Concrete Build Roadmap

### Phase 1: Make the current app production-credible

Goal: preserve the current wow factor, but add trust and workflow discipline.

Build:

- provenance badges on chart facts and AI output
- explicit "source of truth" labels on meds, appointments, records, and photos
- note status model: draft, reviewed, signed
- action lane on patient pages: note, med, follow-up, instructions
- audit-friendly event logging for major chart actions

Suggested repo areas:

- `MedMod/Models/`
- `MedMod/Views/PatientDashboardView.swift`
- `MedMod/Views/ClinicIntelligenceView.swift`
- `MedMod/AI/ClinicalIntelligenceService.swift`

### Phase 2: Add interoperability skeleton

Goal: show exactly how this plugs into a real EHR.

Build:

- SMART on FHIR auth service
- launch context model
- provider/user/patient session objects
- FHIR client abstraction
- first-pass resource adapters into local models

Suggested new structure:

- `MedMod/Interop/SMART/`
- `MedMod/Interop/FHIR/`
- `MedMod/Interop/Adapters/`

Core deliverables:

- SMART configuration discovery
- authorization code flow
- token storage / refresh handling
- patient context handoff into existing views
- local cache sync into SwiftData

### Phase 3: Replace mock data with synced demo pathways

Goal: keep the app demoable while proving real-world resource mapping.

Build:

- sample FHIR bundles for dermatology patients
- importer that populates local models from FHIR JSON
- source provenance on every imported object
- resync and reconciliation UI

This avoids needing a live EHR during every demo while still demonstrating real standards.

### Phase 4: PGHD done the right way

Goal: let patient-originated data contribute to clinician workflow without adding noise.

Build:

- PGHD inbox / triage queue
- clinician review states: new, reviewed, accepted, dismissed
- threshold-based highlighting for only actionable items
- patient-contributed images or symptom questionnaires with source badges

Important rule:

PGHD should be exception-driven and reviewable, not continuously dumped into the chart timeline.

### Phase 5: Enterprise mobile features

Goal: address real buyer objections.

Build:

- shared-device login flow
- re-auth shortcut for role reentry
- configurable idle timeout
- local wipe / remote wipe hooks
- audit trail view
- lightweight role-aware access gates

## Proposed Demo Script For A Buyer

If this were shown to ModMed or a similar company, the script should be tightly staged.

### Demo story

- Start in Agenda.
- Show a realistic clinic day with clear next action.
- Tap into a patient chart from the active workflow.
- Show how quickly the chart can be understood.
- Use intelligence to answer a high-value clinical question.
- Show lesion/photo tracking and anatomy context.
- Draft a note or follow-up plan.
- Generate patient instructions.
- Show where real FHIR integration would plug in.

### Key message

"This is not trying to rebuild the whole EHR. It is the mobile workflow layer clinicians actually want to use."

## The Highest-Leverage Next Step In This Repo

If only one thing gets built next, it should be a SMART on FHIR skeleton plus source-aware local caching.

That single move changes the pitch from:

- beautiful prototype

to:

- credible provider platform strategy

## Immediate Implementation Candidates

In practical order:

1. Add source/provenance fields to local chart models.
2. Add a source badge component to agenda, patient chart, and intelligence outputs.
3. Introduce `SMARTSession` and `FHIRClient` scaffolding.
4. Build import adapters for Patient, Appointment, Condition, MedicationRequest, Observation, and DocumentReference.
5. Add a clinician action lane on patient charts that completes a note/follow-up workflow.
6. Add a PGHD inbox rather than reviving HealthKit as a provider data source.

## Final Recommendation

Do not move backward toward HealthKit-centered provider access.

Move forward with:

- SMART on FHIR
- source-aware charting
- closed-loop specialty workflows
- exception-based PGHD review
- enterprise mobile trust features

That is the path most likely to make a serious EHR company see this as more than a polished concept.
