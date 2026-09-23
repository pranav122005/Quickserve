# QuickServe Hosting & Deployment Guide

This document provides instructions for hosting the **QuickServe Flutter Web** application using **Firebase Hosting**, connected to the **Supabase** backend engine.

---

## 1. Hosting Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Flutter Web Frontend                  │
│             (Served statically via Firebase)            │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                    Firebase Hosting                     │
│            (Global CDN / SPA / Static Delivery)          │
└────────────────────────────┬────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────┐
│                    Supabase Backend                     │
│    (Auth, PostgreSQL, PostGIS, RLS, Realtime WebSockets) │
└─────────────────────────────────────────────────────────┘
```

> **Important**: Firebase is used **strictly for static web hosting and CDN delivery**. All database logic, authentication, row-level security, PostGIS spatial algorithms, and realtime WebSockets are managed authoritatively by **Supabase**. No Firebase backend SDKs (`firebase_core`, `cloud_firestore`, `firebase_auth`) are installed or used in the application code.

---

## 2. Release Build Instructions

To prepare the production web bundle, run the following standard Flutter toolchain commands:

```bash
# 1. Clean previous build artifacts
flutter clean

# 2. Resolve project dependencies
flutter pub get

# 3. Run static analyzer (verify 0 issues)
flutter analyze

# 4. Execute unit & widget tests
flutter test

# 5. Compile release web bundle
flutter build web --release
```

The output bundle will be generated in `build/web/`.

---

## 3. Local Web Verification

Before deploying, verify the generated release build locally:

### Option A: Using Python built-in HTTP server
```bash
python -m http.server 8080 --directory build/web
```
Navigate to `http://localhost:8080` in your browser.

### Option B: Using Node `serve`
```bash
npx serve build/web
```

---

## 4. Firebase CLI Initialization

Ensure you have the Firebase CLI installed (`npm install -g firebase-tools`).

1. Log in to Firebase:
   ```bash
   firebase login
   ```

2. Initialize hosting in the project root directory:
   ```bash
   firebase init hosting
   ```

3. Select options as configured in `firebase.json`:
   - **Select Firebase Project**: Choose your active Firebase project (or create one in Firebase Console).
   - **Public directory**: Enter `build/web`.
   - **Configure as single-page app (SPA)**: Enter `Yes` (rewrites all paths to `/index.html`).
   - **Set up automatic builds/deploys with GitHub Actions?**: `No` (optional).
   - **File `build/web/index.html` already exists. Overwrite?**: **`NO`** (preserve Flutter's generated `index.html`).

---

## 5. Deployment Command

To deploy the compiled application to Firebase Hosting CDN:

```bash
firebase deploy --only hosting
```

---

## 6. Post-Deployment Verification Checklist

After deploying to Firebase Hosting, perform the following end-to-end checks:

- [ ] **Authentication**: Test user sign-in and new account registration for Customer, Agent, and Admin roles.
- [ ] **Routing & Deep Linking**: Refresh pages on sub-routes (e.g. `/agent`, `/customer`, `/admin`) to verify single-page app fallback rewrites to `/index.html` correctly without 404 errors.
- [ ] **Realtime Subscriptions**: Confirm Supabase WebSocket connections remain active on HTTPS/WSS.
- [ ] **Service Request Flow**: Test customer request creation, automatic agent dispatch, and agent offer acceptance.
- [ ] **Browser Console**: Ensure no CORS, CSP, or uncaught JavaScript exceptions occur in the browser developer tools console.
