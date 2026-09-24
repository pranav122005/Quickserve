<p align="center">
  <img src="docs/assets/quickserve-hero.png" alt="QuickServe Application Showcase" width="90%">
</p>

# ⚡ QuickServe

### A simple, reliable way to request, assign, track, and complete local services.

**Customer → Request → Smart Dispatch → Agent → Completion**

QuickServe is a full-stack service management platform built with Flutter and Supabase. Customers create service requests, field service agents manage and complete jobs, and administrators maintain operational control through a web portal.

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.47.5-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.13.4-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase">
  <img src="https://img.shields.io/badge/PostgreSQL-Database-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL">
  <img src="https://img.shields.io/badge/PostGIS-Spatial-336791?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostGIS">
  <img src="https://img.shields.io/badge/Riverpod-State-6C63FF?style=for-the-badge" alt="Riverpod">
  <img src="https://img.shields.io/badge/Firebase_Hosting-Web-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase Hosting">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Web-111827?style=for-the-badge" alt="Platforms">
</p>

---

## 📌 Table of Contents

- [Overview](#-overview)
- [SWASIQ Assignment](#-swasiq-assignment)
- [Why QuickServe?](#-why-quickserve)
- [How It Works](#-how-it-works)
- [Features](#-features)
- [Request Lifecycle](#-request-lifecycle)
- [Smart Dispatch](#-smart-dispatch)
- [Real-Time Location & Privacy](#-real-time-location--privacy)
- [Architecture](#-architecture)
- [Technology Stack](#-technology-stack)
- [Database](#-database)
- [Security](#-security)
- [Authentication & Authorization](#-authentication--authorization)
- [Screens / Visuals](#-screens--visuals)
- [Hosting](#-hosting)
- [Getting Started](#-getting-started)
- [Testing](#-testing)
- [Demo Credentials](#-demo-credentials)
- [Documentation](#-documentation)
- [Project Structure](#-project-structure)
- [Future Improvements](#-future-improvements)
- [Brand & License](#-brand--license)

---

## ✦ Overview

QuickServe is an end-to-end **service request and dispatch platform** for everyday local services.

The platform connects customers with service agents through a structured request lifecycle while providing administrators with operational visibility and control.

Supported service categories:

- ❄️ **AC Servicing**
- 🔧 **Plumbing**
- ⚡ **Electrical**
- 🧹 **Cleaning**

The platform provides:

- Customer registration and authentication
- Service request creation
- Preferred date and time selection
- Address and geographic location capture
- Priority selection
- Backend-based agent dispatch
- Time-limited service offers
- Agent acceptance and job execution
- Request status tracking
- Realtime updates
- Authorized agent location tracking
- Payment recording
- Administrative request management
- Role-based authorization
- Database-level security using RLS

> **Key Principle:** *The application handles the experience. The backend remains the authority.*

Authentication, authorization, dispatch, assignment, and critical state transitions are enforced by Supabase/PostgreSQL rather than relying solely on client-side state.

---

# ✦ SWASIQ Assignment

QuickServe was developed as part of the **SWASIQ Technical Assignment for the Founding Engineering Internship selection process**.

The implementation covers the required full-stack service request workflow with:

| Requirement | QuickServe Implementation |
|---|---|
| Mobile application | Flutter Android |
| Web administration portal | Flutter Web |
| Backend | Supabase |
| Database | PostgreSQL |
| Spatial database | PostGIS |
| Authentication | Supabase Auth |
| Roles | Customer / Service Agent / Administrator |
| Authorization | PostgreSQL RLS + protected RPCs |
| Services | AC Servicing / Plumbing / Electrical / Cleaning |
| Service requests | Create, view, update, track and cancel eligible requests |
| Request lifecycle | Pending → Dispatching → Assigned → In Progress → Completed |
| Agent assignment | Automated dispatch + Admin manual assignment |
| Agent availability | Available / Offline |
| Agent radius | 10–20 km, default 15 km |
| Offer response window | Approximately 120 seconds |
| Realtime | Supabase Realtime |
| Location | Device GPS + PostGIS |
| Payment | Operational payment recording |
| Status history | Request status history |
| Error handling | Centralized application error handling |
| Testing | Automated Flutter tests + physical-device E2E testing |
| Documentation | Architecture, database, security, demo and hosting documentation |
| Version control | GitHub |

### Final Verification

The final implementation was validated with:

```text
flutter analyze
→ No issues found

flutter test
→ 83 / 83 tests passed

Android Release Build
→ Successfully generated

Physical Device
→ Motorola Edge 70 Fusion
→ Android 16

Repository
→ Clean working tree
→ origin/main synchronized