⚡ QuickServe

<p align="center">
  <img src="docs/assets/quickserve-hero.png" alt="QuickServe" width="850" />
</p>

<p align="center">
  <strong>Service Request Management Platform</strong><br/>
  Flutter • Supabase • PostgreSQL • PostGIS • Realtime
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.47.5-02569B?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.13.4-0175C2?logo=dart" alt="Dart" />
  <img src="https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase" alt="Supabase" />
  <img src="https://img.shields.io/badge/PostgreSQL-PostGIS-336791?logo=postgresql" alt="PostgreSQL" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Web-34A853" alt="Platforms" />
</p>

📌 Overview

QuickServe is a full-stack service request management application designed for customers, service agents, and administrators.

Customers can create and track service requests, agents can receive and manage nearby jobs, and administrators can manage operations through a responsive web portal.

The application uses Supabase Auth, PostgreSQL, PostGIS, Row Level Security (RLS), Realtime, and Flutter to provide a shared backend for the customer mobile experience and admin/agent web experience.

✨ Why QuickServe?

Problem

QuickServe Solution

Customers need to request services easily

Guided service-request creation

Requests need operational assignment

Location-aware PostGIS dispatch

Agents need nearby work

Radius-based offer system

Customers need status visibility

Realtime request updates

Admins need operational control

Web dashboard and assignment tools

Sensitive data needs protection

Supabase Auth + PostgreSQL RLS

👥 User Roles

Customer 👤

Service Agent 🛠️

Administrator 🖥️

Register / login

Login

Login

Browse services

Set service radius

Dashboard

Create requests

Online / offline

Manage requests

Track requests

Receive offers

Assign agents

View assigned agent

Accept / reject

Manage customers

Cancel eligible requests

Start / complete jobs

Manage agents

Track payment record

Record payment

View operational activity

🔄 Request Lifecycle

┌─────────┐     ┌────────────┐     ┌──────────┐
│ PENDING │ ──▶ │ DISPATCHING│ ──▶ │ ASSIGNED │
└─────────┘     └────────────┘     └────┬─────┘
                                         │
                                         ▼
                                  ┌─────────────┐
                                  │ IN_PROGRESS │
                                  └──────┬──────┘
                                         │
                                         ▼
                                  ┌───────────┐
                                  │ COMPLETED │
                                  └───────────┘

                 └──── eligible requests ────▶ CANCELLED

Each important transition is stored in the request status history so the operational flow remains traceable.

🧭 How It Works

1. Customer creates a request

The customer selects a service, enters the required details, preferred time, address, and priority.

A unique request ID is generated in the format:

REQ-2026-000123

2. Backend finds eligible agents

The backend evaluates:

Current agent location

Configured service radius

Online availability

Verification status

Current workload

Operational capability

PostGIS performs the geographic filtering.

3. Agent receives an offer

The selected agent receives a time-limited offer. The current implementation uses a 120-second offer window.

If the offer is rejected or expires, the backend can continue dispatching to another eligible candidate.

4. Agent accepts and starts the job

After acceptance, the request becomes assigned. When work starts, the request moves to IN_PROGRESS.

5. Customer receives live progress

Supabase Realtime updates the relevant request state without requiring the customer to repeatedly refresh the application.

6. Job completion and payment record

The agent completes the request and records the payment information. The current payment implementation is payment recording/audit, not an online payment gateway.

🏗️ Architecture

High-Level Architecture

flowchart TB
    C[Customer<br/>Flutter Android] --> A[Supabase Auth]
    G[Agent<br/>Flutter Web / Android] --> A
    AD[Administrator<br/>Flutter Web] --> A

    C --> API[Supabase Backend]
    G --> API
    AD --> API

    API --> DB[(PostgreSQL)]
    DB --> GIS[(PostGIS)]
    API --> RT[Supabase Realtime]

    RT --> C
    RT --> G
    RT --> AD

Architecture in simple terms

Flutter clients → communicate with → Supabase → which securely manages → database, authentication, authorization, dispatch and realtime updates.

The clients do not directly implement privileged database operations. Authorization is enforced by the backend/database layer.

🧩 Main Components

Component

Responsibility

Flutter

Customer, agent and admin interfaces

Riverpod

Application state management

go_router

Navigation and protected routes

Supabase Auth

Login, registration, sessions and password reset

PostgreSQL

Core application data

PostGIS

Location and radius-based dispatch

RLS

Database-level authorization

Supabase Realtime

Live request/assignment updates

flutter_map + OSM

Map visualization

geolocator

Foreground device location

🗄️ Database Model

erDiagram
    PROFILES ||--o| AGENT_PROFILES : has
    PROFILES ||--o{ SERVICE_REQUESTS : creates
    SERVICE_REQUESTS ||--o{ SERVICE_ASSIGNMENTS : receives
    SERVICE_REQUESTS ||--o{ REQUEST_STATUS_HISTORY : tracks
    SERVICE_REQUESTS ||--o{ PAYMENTS : records
    PROFILES ||--o{ AGENT_LOCATIONS : reports

    PROFILES {
        uuid id PK
        user_role role
    }

    SERVICE_REQUESTS {
        uuid id PK
        text request_id
        uuid customer_id FK
        text status
        text priority
    }

    SERVICE_ASSIGNMENTS {
        uuid id PK
        uuid request_id FK
        uuid agent_id FK
        text status
    }

    REQUEST_STATUS_HISTORY {
        uuid id PK
        uuid request_id FK
        text status
        timestamp created_at
    }

    PAYMENTS {
        uuid id PK
        uuid request_id FK
        numeric amount
    }

Core data areas

Profiles — application users and their roles.

Agent Profiles — agent-specific operational configuration.

Service Requests — customer service requests and lifecycle state.

Service Assignments — agent offers and assignments.

Agent Locations — current operational location.

Request Status History — lifecycle history.

Payments — payment records associated with completed work.

The project uses an equivalent operational activity/history model rather than a separate audit_logs table.

📍 Smart Dispatch

QuickServe performs dispatch on the backend rather than trusting the Flutter client.

New Request
    │
    ▼
Find available agents
    │
    ▼
Apply service-radius filter
    │
    ▼
Verify eligibility
    │
    ▼
Rank candidates
    │
    ▼
Reserve candidate atomically
    │
    ▼
Create 120-sec offer
    │
    ├── Accept ──▶ Assignment
    │
    └── Reject/Expire ──▶ Next candidate

Candidate ranking

The implemented hybrid ordering considers:

Lower workload

Shorter distance

Stable agent_id tie-breaker

Database locking with FOR UPDATE SKIP LOCKED helps prevent two concurrent dispatch operations from reserving the same agent incorrectly.

📍 Location & Privacy

QuickServe deliberately limits location exposure.

Customer

Customer location access to the active agent becomes available only after an authorized assignment state is reached.

Agent

The current implementation uses foreground GPS tracking for active jobs.

Admin

Administrators can access operational agent location information required for dispatch and management.

Privacy principles

Current operational location is used instead of unlimited GPS history.

Location visibility depends on authorization and request state.

Terminal requests no longer expose active-job location.

No fake GPS coordinates are used as a production fallback.

No background/headless GPS service is required by the current implementation.

🔐 Security

QuickServe treats the database as a security boundary rather than relying only on UI restrictions.

User
 │
 ▼
Supabase Auth
 │
 ▼
Authenticated Session
 │
 ▼
PostgreSQL RLS
 │
 ├── Customer → Own requests
 │
 ├── Agent    → Assigned work
 │
 └── Admin    → Authorized operational data
 │
 ▼
Database Operation

Security controls

Supabase Authentication

Backend/database role authorization

PostgreSQL Row Level Security

Forced RLS on protected tables

SECURITY DEFINER helper functions where required

Controlled function search_path

Authenticated-only grants for protected operations

No service-role key in the Flutter client

Customer-only public registration

Agent/admin accounts provisioned separately

Secrets excluded from Git

Sensitive information excluded from operational logs

For detailed controls, see docs/SECURITY.md.

For the full architecture, see docs/ARCHITECTURE.md.

📱 Application Experience

Customer

Login
  ↓
Home
  ↓
Services
  ↓
Create Request
  ↓
My Requests
  ↓
Request Details
  ↓
Live Status / Agent Location

Agent

Login
  ↓
Agent Home
  ↓
Offers
  ↓
Accept
  ↓
Active Job
  ↓
Start Work
  ↓
Complete
  ↓
Payment Record

Administrator

Login
  ↓
Dashboard
  ↓
Requests
  ├── Search / Filter
  ├── View Details
  ├── Assign Agent
  └── Update Status
       ↓
Customers / Agents / Activity

🛠️ Technology Stack

Layer

Technology

Mobile / Web UI

Flutter

Language

Dart

State Management

Riverpod

Routing

go_router

Backend

Supabase

Authentication

Supabase Auth

Database

PostgreSQL

Spatial Database

PostGIS

Realtime

Supabase Realtime

Maps

flutter_map + OpenStreetMap

Location

geolocator

Source Control

Git + GitHub

Web Hosting

Firebase Hosting configuration

⚙️ Setup

Prerequisites

Install Flutter, Dart, Android Studio/Android SDK and Git.

flutter --version
flutter doctor

Clone

git clone https://github.com/pranav122005/Quickserve.git
cd Quickserve

Install dependencies

flutter pub get

Environment

Create .env from .env.example:

SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_public_anon_or_publishable_key

Never place a service_role key, database password, or other secret in the Flutter client.

Run Web

flutter run -d chrome

Run Android

flutter devices
flutter run

🧪 Testing & Quality

flutter analyze
flutter test

Current project baseline:

Flutter Analyze : 0 issues
Flutter Tests   : 83 / 83 passing

End-to-end workflow

Customer Login
      ↓
Create Request
      ↓
Backend Dispatch
      ↓
Agent Offer
      ↓
Agent Accept
      ↓
Start Job
      ↓
Complete Job
      ↓
Record Payment
      ↓
Admin Verification

The project also includes authorization, dispatch concurrency, location privacy, authentication/session and regression coverage.

🚀 Release & Hosting

The project includes:

Android release build

Flutter Web build

Firebase Hosting configuration

Supabase production backend configuration

Environment-based configuration

A live public URL is not listed here because deployment status should be verified from the current hosting environment rather than assumed from configuration.

👤 Demo Accounts

Role

Email

Password

Customer

customer@quickserve.com

QuickServe@123

Agent

agent@quickserve.com

QuickServe@123

Admin

admin@quickserve.com

QuickServe@123

These credentials are intended for demonstration/testing. Replace them before public production use.

📚 Documentation

Document

Purpose

docs/ARCHITECTURE.md

System architecture, data flow and design decisions

docs/SECURITY.md

Authentication, RLS, authorization and privacy controls

📂 Project Structure

Quickserve/
├── android/
├── lib/
│   ├── core/
│   ├── features/
│   ├── routing/
│   └── main.dart
├── supabase/
│   └── migrations/
├── test/
├── docs/
│   ├── assets/
│   ├── ARCHITECTURE.md
│   └── SECURITY.md
├── .env.example
├── .gitignore
├── firebase.json
├── pubspec.yaml
└── README.md

🏁 Implementation Status

Area

Status

Authentication

✅

Customer workflow

✅

Agent workflow

✅

Admin portal

✅

RBAC / RLS

✅

PostGIS dispatch

✅

Realtime updates

✅

Active-job location

✅

Payment recording

✅

Password reset

✅

Testing

✅

Android release build

✅

Web build

✅

Production public deployment

⏳

Push notifications

Future

Advanced analytics

Future

📄 License

This project was developed as a technical assignment for SWASIQ.

© 2026 QuickServe. All rights reserved
