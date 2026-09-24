<div align="center">

⚡ QUICKSERVE

Smart Local Service Request & Dispatch Platform

<p><strong>Book. Dispatch. Track. Complete.</strong><br>
A full-stack platform connecting customers, service agents, and administrators in real time.</p>

<p>
<img src="https://img.shields.io/badge/Flutter-3.47.5-02569B?style=for-the-badge&logo=flutter&logoColor=white">
<img src="https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white">
<img src="https://img.shields.io/badge/PostGIS-Spatial_Dispatch-336791?style=for-the-badge&logo=postgresql&logoColor=white">
<img src="https://img.shields.io/badge/Riverpod-State_Management-6C63FF?style=for-the-badge">
<img src="https://img.shields.io/badge/Tests-83%2F83-success?style=for-the-badge">
</p>

<p>
<a href="#-overview">Overview</a> •
<a href="#-features">Features</a> •
<a href="#-architecture">Architecture</a> •
<a href="#-setup">Setup</a> •
<a href="#-testing">Testing</a>
</p>

</div>

🖼️ Product Preview

Add your best screenshot as docs/assets/quickserve-preview.png.

<p align="center">
<img src="docs/assets/quickserve-preview.png" alt="QuickServe Preview" width="900">
</p>

<p align="center"><sub>Customer • Agent • Administrator workflows</sub></p>

🚀 Overview

QuickServe is a full-stack service request management platform for local services such as AC servicing, plumbing, electrical work, and cleaning.

Customers create requests, agents receive and manage assignments, and administrators monitor operations from a responsive dashboard.

Core Flow

CUSTOMER
   │
   │ Create Service Request
   ▼
SUPABASE
Auth + PostgreSQL + PostGIS + RLS + Realtime
   │
   ├──────────────► AGENT
   │                 Accept → Start → Complete
   │
   └──────────────► ADMIN
                     Monitor → Assign → Manage

🎯 SWASIQ Assignment Coverage

QuickServe covers the core SWASIQ technical assignment requirements:

Requirement

Implementation

Flutter Mobile Application

Flutter

Web Administration Portal

Flutter Web

Backend

Supabase

Authentication

Supabase Auth

Roles

Customer / Agent / Admin

Database

PostgreSQL

Geospatial Operations

PostGIS

Backend Authorization

PostgreSQL RLS

Realtime Updates

Supabase Realtime

Smart Dispatch

PostgreSQL RPC + PostGIS

Request History

Request Status History

Payment Recording

PostgreSQL

Testing

Flutter Unit / Widget / Integration validation

Documentation

Architecture / Security / Demo documentation

Version Control

Git + GitHub

✨ Features

<table>
<tr>
<td width="33%" valign="top">

👤 Customer

Registration / Login

Browse services

Create requests

Preferred date/time

Address & priority

Request tracking

Status history

Assigned-agent visibility

Active agent location

Payment tracking

Eligible cancellation

Profile

Password reset

</td>
<td width="33%" valign="top">

🛠️ Agent

Secure login

Agent profile

Online/offline status

10–20 km service radius

Job offers

Accept / reject

Offer countdown

Start service

Work notes

Complete service

Record payment

Active-job location

Foreground GPS

</td>
<td width="33%" valign="top">

🧑‍💼 Admin

Responsive dashboard

Customer management

Agent management

Request management

Manual assignment

Status management

Agent tracking

Payment records

Operational visibility

Request history

Dispatch management

</td>
</tr>
</table>

🔄 Request Lifecycle

┌──────────┐
│ PENDING  │
└────┬─────┘
     ▼
┌──────────────┐
│ DISPATCHING  │
└────┬─────────┘
     ▼
┌────────────┐
│  ASSIGNED  │
└────┬───────┘
     ▼
┌──────────────┐
│ IN_PROGRESS  │
└────┬─────────┘
     ▼
┌────────────┐
│ COMPLETED  │
└────────────┘

Eligible states ─────────► CANCELLED

🧠 Smart Dispatch

Dispatch is performed by the backend rather than trusting the client.

Agent eligibility

📍 Within configured service radius

🟢 Available

✅ Verified

🛠️ Eligible for the requested service

📡 Has current location

Candidate ordering

1. Lowest active workload
2. Shortest eligible distance
3. Deterministic agent ID tie-breaker

Spatial matching

Agent proximity is calculated with PostGIS using:

ST_DWithin(...)

Locations use:

geography(Point, 4326)

and are formatted as:

POINT(longitude latitude)

Concurrency protection

Find Candidates
      │
      ▼
FOR UPDATE SKIP LOCKED
      │
      ▼
Re-check Eligibility
      │
      ▼
Create 120-second Offer
      │
 ┌────┴─────┐
 ▼          ▼
ACCEPT   REJECT/EXPIRE
 │          │
 ▼          ▼
ASSIGNED   NEXT CANDIDATE

🗺️ Location Privacy

Role

Location Access

Customer

Assigned agent during active service

Agent

Own current location

Administrator

Operational agent visibility

Unrelated customer

❌ No access

Anonymous user

❌ No access

QuickServe uses foreground GPS for active service workflows and avoids unlimited location-history storage.

No background headless GPS service or fake production coordinates are used.

🏗️ Architecture

                 QUICK SERVE
                      │
        ┌─────────────┴─────────────┐
        │                           │
   Flutter Mobile              Flutter Web
    Android/iOS                Admin Portal
        │                           │
        └─────────────┬─────────────┘
                      │
               Riverpod + Router
                      │
                      ▼
               Supabase Client
                      │
       ┌──────────────┼──────────────┐
       │              │              │
    Supabase          RLS         Realtime
      Auth             │              │
       │               ▼              │
       │          PostgreSQL          │
       │               │              │
       │            PostGIS            │
       └───────────────┴──────────────┘
                      │
                Dispatch RPCs
                      │
                      ▼
               Agent Assignment

Technology Stack

Layer

Technology

Mobile

Flutter

Web Admin

Flutter Web

Language

Dart

State

Riverpod

Navigation

go_router

Backend

Supabase

Auth

Supabase Auth

Database

PostgreSQL

Spatial

PostGIS

Authorization

PostgreSQL RLS

Realtime

Supabase Realtime

Maps

flutter_map + OpenStreetMap

GPS

geolocator

Testing

Flutter test

Source Control

Git + GitHub

Web Hosting Target

Firebase Hosting

🗄️ Database

Core database entities include:

profiles
    │
    ├── service_requests
    │       │
    │       ├── service_assignments
    │       ├── request_status_history
    │       └── payments
    │
    ├── agent_profiles
    │       │
    │       └── agent_locations
    │
    └── authentication relationship

Main tables

profiles

service_requests

service_assignments

agent_profiles

agent_locations

payments

request_status_history

The database uses PostGIS spatial types and indexes for location-based dispatch.

Payment records are for operational recording and audit purposes; QuickServe does not implement a payment gateway.

🔐 Security

QuickServe uses a backend-authoritative security model.

Flutter
   │
   ▼
Supabase Auth
   │
   ▼
Authenticated Session
   │
   ▼
PostgreSQL RLS

Role model

PUBLIC SIGNUP
     │
     ▼
 CUSTOMER ONLY
     │
     ├──────► AGENT
     │        provisioned separately
     │
     └──────► ADMIN
              provisioned separately

The client cannot freely assign itself an agent or administrator role.

Protected database resources include:

profiles

service requests

service assignments

agent profiles

agent locations

request status history

payments

Security-sensitive helper functions use SECURITY DEFINER with a controlled search_path.

Security Checklist

Supabase Auth

Server-side role authorization

PostgreSQL RLS

Forced RLS

SECURITY DEFINER helpers

Controlled search_path

No service-role key in Flutter

Customer-only public signup

Separate agent/admin provisioning

Restricted location visibility

No fake production GPS

No unlimited location history

Secrets excluded from Git

Authorization tested against backend RLS

📱 Application Flows

Customer

Login / Register
       ↓
     Home
       ├── Services
       ├── Create Request
       └── My Requests
                ↓
          Request Details
                ↓
        Assignment / Location
                ↓
             Payment

Agent

Login
 ↓
Dashboard
 ├── Availability
 ├── Service Radius
 ├── Offers
 └── Active Job
          ↓
      Start Service
          ↓
       Complete
          ↓
    Record Payment

Admin

Admin Login
     ↓
Dashboard
 ├── Requests
 ├── Customers
 ├── Agents
 ├── Payments
 └── Request Details
       ├── Assign Agent
       ├── Update Status
       └── Track Agent

📂 Project Structure

quickserve/
├── android/
├── ios/
├── web/
├── lib/
│   ├── core/
│   ├── data/
│   ├── features/
│   │   ├── auth/
│   │   ├── customer/
│   │   ├── agent/
│   │   └── admin/
│   └── main.dart
├── supabase/
│   └── migrations/
├── test/
├── docs/
│   └── assets/
├── .env.example
├── .gitignore
├── pubspec.yaml
└── README.md

⚙️ Setup

1. Prerequisites

Install Flutter, Dart, Android Studio/Android SDK, Git, and create a Supabase project.

flutter --version
flutter doctor

2. Clone

git clone https://github.com/pranav122005/Quickserve.git
cd Quickserve

3. Dependencies

flutter pub get

4. Environment

Create .env from .env.example.

SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_public_anon_or_publishable_key

Never put a service_role key, database password, or other secret in the Flutter client.

5. Run Web

flutter run -d chrome --dart-define-from-file=.env

6. Run Android

flutter devices
flutter run --dart-define-from-file=.env

7. Build Android Release

flutter build apk --release --dart-define-from-file=.env

8. Build Web Release

flutter build web --release --dart-define-from-file=.env

🌐 Hosting

QuickServe Web is configured for Firebase Hosting.

Architecture:

Flutter Web
     ↓
Firebase Hosting
     ↓
Supabase
     ↓
PostgreSQL + PostGIS

Deploy after Firebase CLI configuration:

firebase deploy --only hosting

Detailed hosting instructions are maintained in:

docs/HOSTING.md

🧪 Testing

flutter analyze
flutter test

Current Verification

Check

Result

Static Analysis

PASS — 0 issues

Automated Tests

PASS — 83/83

Android Release Build

PASS

Flutter Web Build

PASS

Physical Android Validation

PASS

RLS Authorization Validation

PASS

Dispatch Concurrency Validation

PASS

Secret Hygiene

PASS

Recommended E2E Flow

Customer Registration
        ↓
Customer Login
        ↓
Create Request
        ↓
Dispatch
        ↓
Agent Offer
        ↓
Agent Accept
        ↓
Agent Start
        ↓
Agent Complete
        ↓
Payment Record
        ↓
Admin Verification

👥 Demo Accounts

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

These accounts are intended for demonstration and evaluation only.

📚 Documentation

Additional documentation is maintained under:

docs/

Recommended documentation includes:

docs/
├── ARCHITECTURE.md
├── SECURITY.md
├── DEMO_WALKTHROUGH.md
├── HOSTING.md
└── assets/

🛣️ Roadmap

Authentication

Role-based access

Customer workflow

Agent workflow

Admin portal

PostGIS dispatch

Realtime updates

Active-job location

Payment recording

RLS hardening

Android release build

Flutter Web production build

Production deployment

Push notifications

Advanced analytics

Extended CI/CD

📸 Recommended README Visuals

Create this folder:

docs/assets/

Add:

quickserve-preview.png
customer-dashboard.png
create-request.png
agent-dashboard.png
agent-offer.png
admin-dashboard.png
architecture.png

Then add sections like:

<h2 align="center">📱 Customer Experience</h2>

<p align="center">
  <img src="docs/assets/customer-dashboard.png" width="260">
  <img src="docs/assets/create-request.png" width="260">
  <img src="docs/assets/agent-offer.png" width="260">
</p>

For a wide admin screenshot:

<h2 align="center">🧑‍💼 Admin Operations</h2>

<p align="center">
  <img src="docs/assets/admin-dashboard.png" width="900">
</p>

🤝 Git Workflow

Feature
  ↓
Feature Branch
  ↓
Implementation
  ↓
flutter analyze
  ↓
flutter test
  ↓
Manual E2E
  ↓
Pull Request
  ↓
Review
  ↓
main

Example commits:

feat: add agent offer workflow
fix: resolve RLS recursion
fix: repair agent availability
test: add authorization coverage
docs: update deployment guide

📦 Submission

GitHub Repository:

https://github.com/pranav122005/Quickserve

The repository contains:

Flutter application source code

Flutter Web admin portal

Supabase integration

PostgreSQL database migrations

PostGIS dispatch logic

RLS security policies

Realtime functionality

Tests

Documentation

Environment configuration template

<div align="center">

⚡ QuickServe

Secure • Realtime • Location-Aware • Service Management

<p><sub>Customer • Agent • Administrator</sub></p>

</div>
