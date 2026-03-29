# Delivero: Flutter Migration Implementation Steps

This document outlines the specific implementation steps for migrating the Delivero React Native app to Flutter, based on the [FLUTTER_MIGRATION.md](file:///Users/pickcel/Jaseem/GitWorks/delivero/docs/FLUTTER_MIGRATION.md) plan.

## Phase 1: Foundation & Infrastructure (Current)

### 1.1 Project Setup
- [x] Clean project and recreate from scratch (`flutter create .`)
- [x] Update `pubspec.yaml` with core dependencies:
    - `flutter_riverpod` (State Management)
    - `go_router` (Navigation)
    - `shared_preferences` (Local persistence)
    - `intl` (Date formatting)
    - `google_fonts` (Typography)
    - `fl_chart` (Charts)
    - `flutter_svg` (SVG Support)
    - `uuid` (ID Generation)
    - `url_launcher` (Phone/Email support)
- [x] Create folder structure:
    - `lib/app/` (Router, Providers)
    - `lib/core/theme/`, `lib/core/widgets/`, `lib/core/utils/`
    - `lib/data/models/`, `lib/data/repositories/`
    - `lib/features/auth/`, `lib/features/startup/`, `lib/features/owner/`, `lib/features/delivery/`
- [x] Import assets from React Native project.

### 1.2 Design System (Parity with RN `constants/theme.ts`)
- [x] Implement `AppColors`:
    - Primary: `#FF6B00`
    - Secondary: `#1A1A2E`
    - Accent: `#FFD60A`
- [x] Implement `AppTheme` with `ThemeData`.

### 1.3 Routing & Navigation
- [x] Implement `AppRouter` using `go_router`.
- [x] Define initial routes: `/intro`, `/login`, `/owner`, `/delivery`.
- [x] Implement role-based redirection logic.

## Phase 2: Core Domain Models

### 2.1 Models (Port from RN `services/firebase/schema.ts` and Stores)
- [x] `User` model (Auth, Roles)
- [x] `DeliveryRoute` model
- [x] `Customer` model
- [x] `Order` model
- [x] `FoodItem` model
- [x] `Driver` and `Factory` models

## Phase 3: Authentication & Onboarding

### 3.1 App Startup
- [x] Implement `AppStartupNotifier` to handle initial flags (onboarding seen, etc.).
- [x] Port `AppIntroScreen` (Enhanced multi-page version).

### 3.2 Authentication
- [x] Implement `AuthNotifier` with hardcoded users parity (`lib/users.ts`).
- [x] Create `LoginScreen` with validation.

## Phase 4: Feature Implementation (Upcoming)

### 4.1 Owner Module
- [x] Owner dashboard with metrics and charts (`fl_chart`).
- [x] Customer management (List, Add, Edit, Details).
- [x] Route management (List, Add, Edit, Driver assignment).
- [x] Order management (List, Create, Status/Payment updates).
- [x] Food item management (List, Add, Edit).
- [x] Advanced reports and analytics (Date range, Customer breakdown).

## Phase 5: Delivery Module Implementation

### 5.1 Driver Experience
- [x] Delivery dashboard with overview and financial summary.
- [x] Order status list with filtering (Active/Delivered).
- [x] Delivery confirmation logic.
- [x] Settings and profile management (Unified).
