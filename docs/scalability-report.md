# Delivero Scalability Review

## Executive Summary

Delivero already has a good foundation for a growing Flutter product:

- Flutter + Riverpod is a solid choice for cross-platform scale.
- `go_router` keeps top-level navigation centralized.
- Firebase Auth + Firestore allow fast iteration for early-stage delivery workflows.
- The app already separates major domains such as auth, owner, delivery, onboarding, and core services.

The main scalability risk is that domain state, Firestore access, derived business logic, and UI orchestration are still too tightly coupled. As the app grows to more users, factories, routes, drivers, and orders, this will make changes slower, testing harder, and performance tuning more expensive.

## What Is Working Well

### 1. Clear Feature Grouping

The `lib/features/` structure is easy to understand and already grouped by product areas like:

- `auth`
- `owner`
- `delivery`
- `onboarding`
- `startup`

This is a good base for scaling the team and codebase.

### 2. Good App-Level Composition

The app startup flow is straightforward:

- Firebase initializes in `lib/main.dart`
- app startup and auth bootstrapping run early
- routing is centralized in `lib/app/router.dart`

This is a good pattern for maintainability.

### 3. Shared Design System Direction

The presence of `core/theme/` and shared widgets like `DeliveroButton`, `DeliveroAuthScaffold`, `DeliveroEmptyState`, and sliver/header helpers is a strong sign. This helps UI consistency as more screens are added.

### 4. Real Product Thinking Already Exists

The app is not just CRUD. It already includes:

- onboarding
- owner and delivery roles
- driver auto-linking
- reporting
- local notifications
- push notification integration

That means the next phase should focus less on adding random screens and more on stabilizing architecture for growth.

## Main Scalability Risks

### 1. `app/providers.dart` Is Becoming a Monolith

`lib/app/providers.dart` currently holds:

- global providers
- multiple domain notifiers
- Firestore subscription setup
- filtering and normalization logic
- local notification diffing logic
- CRUD write methods

This file is doing too much. It will become harder to reason about ownership, side effects, and regression risk.

### 2. Firestore Access Is Too Close to UI State

Most write operations are called directly from notifiers, for example:

- add/update/delete orders
- customers
- food items
- routes
- drivers

This works now, but over time it causes:

- duplicated query logic
- hard-to-test business rules
- weak control over validation and permissions
- difficulty adding retries, caching, pagination, and telemetry

### 3. Business Rules Are Mixed Into Presentation-Oriented State

Examples include:

- route derivation and driver normalization inside the orders notifier
- notification diffing inside UI-facing state
- onboarding completion and role linking inside auth state management

These rules should eventually move into dedicated services or domain use cases.

### 4. Reporting Is Computed Entirely on the Client

`lib/app/reports_provider.dart` aggregates metrics by iterating over all loaded orders in memory. This is okay for small datasets, but it will degrade when:

- order history grows
- multiple months of data are loaded
- charts and filters become more advanced

For larger customers, reports should not depend on loading the full orders collection into the app.

### 5. Limited Automated Test Coverage

The test suite currently contains only a smoke widget test in `test/widget_test.dart`.

This is the biggest delivery risk once more features are added. The current app has enough business logic that regressions will become frequent without:

- notifier tests
- auth flow tests
- router redirect tests
- model serialization tests
- service/repository tests

### 6. Firestore Query Strategy Will Hit Scale Limits

Some reads are filtered after snapshot load, especially in orders logic. This can become expensive as data grows because:

- more documents are streamed than needed
- filtering happens on the client
- index planning becomes reactive instead of intentional

For scale, queries should be purpose-built around tenant, role, and status filters.

### 7. Tenant Boundaries Need Stronger Enforcement

The app is mostly factory-based already, which is good, but scale requires stricter multi-tenant discipline:

- every collection should consistently include `factoryId`
- every read path should query by `factoryId`
- every write path should validate tenant ownership
- Firestore security rules should mirror app assumptions

If this is not tightened early, data leakage risk increases later.

## Highest-Impact Improvements

### Priority 1: Introduce a Repository Layer

Create repositories per domain:

- `OrdersRepository`
- `CustomersRepository`
- `DriversRepository`
- `RoutesRepository`
- `FoodItemsRepository`
- `UsersRepository`

Each repository should own:

- Firestore collection paths
- query construction
- serialization mapping
- paging and filtering
- write operations
- transactional or batch updates

Then let Riverpod notifiers focus on screen state and user actions, not database wiring.

Expected benefit:

- easier testing
- smaller providers
- reusable query logic
- simpler migration to Cloud Functions or other backends later

### Priority 2: Split `app/providers.dart` by Domain

Move notifiers into feature or domain-specific files, for example:

- `features/orders/orders_provider.dart`
- `features/customers/customers_provider.dart`
- `features/routes/routes_provider.dart`
- `features/drivers/drivers_provider.dart`

Expected benefit:

- clearer ownership
- fewer merge conflicts
- safer refactors
- easier onboarding for new developers

### Priority 3: Add a Proper Domain/Use-Case Layer for Critical Flows

Important flows that deserve dedicated use cases:

- send OTP
- verify OTP
- auto-link driver
- create owner profile
- create order
- assign route/driver
- complete onboarding

Expected benefit:

- business rules stop leaking into widgets and generic notifiers
- easier testing of real app behavior
- clearer support for future role expansion

### Priority 4: Strengthen Testing Before More Feature Growth

Add tests in this order:

1. model serialization tests
2. router redirect tests
3. auth notifier tests
4. orders notifier tests
5. repository tests using fake or mocked Firestore boundaries

Target first:

- sign-in and onboarding redirects
- driver auto-link behavior
- order status transitions
- report calculations
- route assignment logic

### Priority 5: Move Heavy Analytics to Precomputed Data

For reports, introduce one of these approaches:

- daily aggregate documents in Firestore
- Cloud Functions to update summary collections
- scheduled rollups for revenue, top products, and customer metrics

This avoids scanning all orders on every client session.

## Recommended Scalable Features

These are the best next features if the goal is to make Delivero production-ready for more customers and higher usage.

### 1. Role and Permission Expansion

Add more granular roles beyond owner and delivery:

- admin
- manager
- dispatcher
- finance
- read-only auditor

Why it matters:

- real businesses rarely operate with only two roles
- permissions become essential once staff count increases
- this unlocks team workflows without sharing one owner account

### 2. Real Dispatch Board

Build a dispatch-focused planning experience with:

- route capacity overview
- unassigned orders queue
- drag-to-assign driver/route
- delivery priority flags
- ETA and delay indicators

Why it matters:

- this improves operational scale far more than more dashboard widgets
- it directly reduces coordination overhead for factories handling many deliveries

### 3. Order History With Server-Side Filters and Pagination

Introduce:

- date range filters
- status filters
- customer filters
- pagination or cursor-based loading
- archived orders view

Why it matters:

- order volume grows quickly
- loading everything into memory will not scale
- better historical access improves operations and finance review

### 4. Audit Trail and Activity Log

Track who changed:

- order status
- payment status
- route assignment
- driver assignment
- customer data

Why it matters:

- helps support, debugging, compliance, and dispute resolution
- becomes essential for multi-user teams

### 5. Offline-First Delivery Workflow

For delivery staff, add:

- cached assigned orders
- offline status update queue
- sync recovery on reconnect
- last-sync indicator

Why it matters:

- delivery apps often operate in weak network areas
- this is a real-world scalability feature, not just technical polish

### 6. Subscription and Plan Enforcement

The model already hints at plan support. Expand it with:

- factory plan limits
- driver/user caps
- order/month usage tracking
- premium reporting
- billing event hooks

Why it matters:

- this is required if Delivero becomes a SaaS product
- plan enforcement should be built before enterprise growth

### 7. Operational Notifications Engine

Move from simple push alerts to event-driven notifications:

- order assigned to driver
- payment overdue
- route overloaded
- missed delivery SLA
- onboarding incomplete

Why it matters:

- better proactive operations
- easier automation and customer retention

## Suggested Architecture Direction

### Near-Term Target Structure

Recommended evolution:

- `core/`
  - app services, theme, utilities, shared widgets
- `data/`
  - dto/model mapping
  - firestore data sources
  - repositories
- `domain/`
  - entities
  - repository contracts
  - use cases
- `features/`
  - screen-specific presentation
  - Riverpod controllers
  - local UI state

You do not need a massive clean-architecture rewrite immediately. A gradual migration is better:

1. move Firestore code into repositories
2. keep models temporarily
3. extract critical use cases
4. add tests around those boundaries
5. refactor feature-by-feature

## Performance Recommendations

### Short Term

- avoid streaming broad collections when filtered queries can be used
- reduce client-side filtering of orders
- avoid recomputing heavy report datasets on every rebuild
- add loading and error states around all async domains consistently

### Medium Term

- add pagination to orders and customers
- add memoized selectors for derived values
- precompute dashboard/report metrics
- instrument slow screens and long Firestore operations

## Security and Reliability Recommendations

- review Firestore security rules against every collection used by the app
- ensure tenant isolation is enforced server-side, not only in app code
- add validation for order totals, payment updates, and assignment changes
- centralize error logging and crash reporting
- add analytics for onboarding drop-off, OTP failure, and order completion funnel

## Product Opportunities

These features align well with the current product direction:

- customer reorder templates
- recurring order schedules
- proof-of-delivery photos/signatures
- invoice and receipt history
- route performance reports
- driver earnings and payout summaries
- warehouse or stock awareness for food items

## 90-Day Improvement Plan

### Phase 1: Stabilize Foundation

- split `app/providers.dart`
- introduce repositories
- add core tests
- tighten Firestore query boundaries
- document data ownership per collection

### Phase 2: Improve Operational Scale

- server-side order filtering and pagination
- dispatch board basics
- audit logs
- delivery offline sync groundwork

### Phase 3: Prepare for Business Scale

- role-based permissions
- precomputed analytics
- subscription enforcement
- advanced notifications and SLA monitoring

## Final Recommendation

Do not start with a full rewrite. The app is already far enough along that the best path is structured extraction:

- keep the current feature UI
- move Firestore logic into repositories
- isolate business rules into use cases
- add tests around auth, routing, orders, and reporting
- then add operational features that directly improve scale

If you do only three things next, do these:

1. split `app/providers.dart`
2. add repositories for Firestore access
3. add targeted tests for auth, router, and orders

These changes will make every future feature cheaper, safer, and faster to ship.
