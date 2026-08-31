# Garuda — Architecture Rules

**Project status: incomplete, actively being built.** This is not a finished
product — several backend apps are schema-only or partially wired (e.g.
`payments` has no REST API yet, `cart` is currently unused, `notifications`
has no push-delivery mechanism, `dashboard` has no test suite). That an app
is unfinished is never a reason to skip the rules below when adding to it —
new code lands inside the same modular-monolith boundaries as everything
else, not as a shortcut "for now."

## Core Architecture Decision

**This project uses a modular monolith architecture.** Keep the backend as
a modular monolith unless the project owner explicitly requests an
architectural change. Do not interpret "modular" as "microservices."

The architecture should prioritize:

- Clear business/domain module boundaries
- Simple deployment
- Maintainability
- Testability
- Independent ownership of domain logic
- Future ability to extract a module into a service if genuinely required
- Avoiding premature distributed-system complexity

This is the single most important rule in this file and applies to **every**
app in the repo — the Django backend and all four Flutter apps — current and
future code, complete or not.

```text
┌──────────────────────────────────────────┐
│              MOBILE LAYER                │
│                                          │
│ Customer     Feature-based modular       │
│ Restaurant   Feature-based modular       │
│ Driver       Feature-based modular       │
│ Admin        Feature-based modular       │
└───────────────────┬──────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────┐
│          DJANGO MODULAR MONOLITH         │
│                                          │
│ Accounts                                 │
│ Restaurants                              │
│ Menu                                     │
│ Cart                                     │
│ Orders                                   │
│ Payments                                 │
│ Delivery                                 │
│ Notifications                            │
│ Dashboard                                │
└───────────────────┬──────────────────────┘
                    │
                    ▼
             ┌───────────────┐
             │  PostgreSQL   │
             │    Shared     │
             └───────────────┘
```

This repo is five independently-deployed apps, each a **modular monolith**:

| App | Path | Stack |
|---|---|---|
| Backend API | `backend/` | Django + DRF, single Postgres (Supabase) |
| Customer app | `mobile/` | Flutter |
| Restaurant partner app | `restaurant_app/` | Flutter |
| Delivery partner app | `delivery_app/` | Flutter |
| Admin app | `admin_app/` | Flutter |

All five ship as one deployable unit each. None of them are split into
services. **Do not change that** without the project owner explicitly
asking for it.

---

## Backend Architecture

The backend is a **Django modular monolith**. All backend business domains
live inside the same Django application/deployment:

```text
backend/
└── apps/
    ├── accounts/
    ├── restaurants/
    ├── menu/
    ├── cart/
    ├── orders/
    ├── payments/
    ├── delivery/
    ├── notifications/
    └── dashboard/
```

(`common` also exists under `apps/` but is shared infra, not a domain — see
"Module conventions" below.) The exact domain list may evolve as the product
evolves, but new functionality should normally be added to the appropriate
existing domain module rather than creating a separate service. A new
domain = a new app under `backend/apps/`, registered in `LOCAL_APPS`
(`backend/config/settings/base.py`) and wired under `api_v1_patterns`
(`backend/config/urls.py`) — don't bolt unrelated concerns onto an existing
app to avoid creating a new one.

### Deployment rule

The backend must remain:

```text
ONE Django application
ONE deployable backend
ONE logical application
ONE shared PostgreSQL database
```

Do not introduce, without the project owner explicitly requesting it:

- Microservices, Kubernetes, service discovery
- Inter-service HTTP APIs or gRPC between internal modules
- Separate backend deployments or separate Dockerfiles per domain
- An API gateway or service mesh
- Separate databases per module, or read replicas as a default suggestion
- A message broker (Kafka/RabbitMQ/etc.) for communication between
  `apps/*` — cross-domain communication inside the backend happens via
  direct Python calls (service functions) or Django signals, see below
- Distributed transactions, CQRS, or event sourcing

Do not suggest microservices as the default answer to a scaling question.
If genuine scaling pressure comes up (e.g. payments/delivery load), flag it
as a discussion point — don't implement a split.

### Module conventions (`backend/apps/*`)

- Each domain app owns `models.py`, `urls.py`, `migrations/`, `tests/` at
  minimum, plus whichever of `serializers.py`/`views.py`/`services.py`/
  `signals.py` it actually needs — **not every app has all of these yet,
  and that's expected given the project is incomplete**, e.g. `cart` and
  `payments` have no `serializers.py`/`views.py` (no REST API exposed),
  `notifications` has no `signals.py` of its own, `dashboard` has no
  `tests/` yet. When you build out one of these, add the missing files
  following the same domain-boundary rules as the finished apps — don't
  invent a different pattern because the app started out thin. `common` is
  shared infra, not a domain, and only has `models.py`/`exceptions.py`/
  `pagination.py`/`response.py`/`validators.py`/`geo.py`/`storage.py` — it
  never gets a `views.py`/`urls.py` of its own, and it must never import
  from another `apps/*` module (every other app may import `apps.common`
  freely).
- Business logic goes in `services.py`, not in views. Views/serializers
  stay thin.
- Use Django signals (`signals.py`) for reactive side effects across apps
  (e.g. `delivery/signals.py` reacting to `apps.orders.models.Order`
  saves) rather than tight coupling in view code.

---

## Module Ownership

Each module must own its own business logic and domain responsibilities:

```text
accounts/        User/authentication responsibilities
restaurants/     Restaurant business responsibilities
menu/            Menu/Food responsibilities
cart/            Cart responsibilities (currently unused by the order flow)
orders/          Order lifecycle and order business rules
payments/        Payment business rules
delivery/        Delivery and driver-assignment business rules
notifications/   Notification business rules
dashboard/       Read-only cross-domain reporting (no owned domain data)
```

A module should expose a small, intentional public interface to other
modules. Other modules should not depend on another module's internal
implementation details.

---

## Cross-Module Communication

Prefer:

```text
Module A
   ↓
Public service/interface
   ↓
Module B
```

**The rule in practice — reading vs. writing:**

- **Reading** another app's models directly (FK lookups, filters,
  aggregates) is fine. This is normal ORM usage in a single-DB modular
  monolith — don't wrap a trivial read in a service call just to have one.
  Example: `orders/services.py` reading `apps.restaurants.models.Restaurant`
  or `apps.menu.models.Food`.
- **Creating or mutating** another app's model from outside the app that
  owns it must go through a function in that app's `services.py` instead
  of touching the model directly.

Bad:

```python
from payments.models import Payment
# ...then creating/mutating Payment rows directly from Orders
```

Prefer:

```python
payment_service.create_payment(...)
```

or an equivalent domain-level interface appropriate to the existing
codebase. This pattern is already implemented — follow these as the
template for any new cross-app write:

| Function | Owning app | Called by |
|---|---|---|
| `apps.notifications.services.create_notification(...)` | `notifications` | `orders`, `restaurants`, `menu` signals |
| `apps.payments.services.create_payment_for_order(...)` | `payments` | `orders.services.place_order` |
| `apps.restaurants.services.update_rating_stats(...)` | `restaurants` | `orders.signals` |
| `apps.orders.services.assign_delivery_partner(...)` | `orders` | `apps.delivery.services` |
| `apps.orders.services.update_order_status(...)` | `orders` | `apps.delivery.services` |
| `apps.orders.services.set_payment_status(...)` | `orders` | `apps.payments.signals` |

For workflows that naturally benefit from asynchronous processing, a
domain event via Django signals is fine (e.g. `menu/signals.py` reacting to
a new `orders.OrderItem` to decrement its own stock, or
`orders/signals.py` creating a notification when an order's status
changes) — that's the correct pattern, not a boundary violation, as long as
the signal handler only mutates models its own app owns (or calls another
app's public interface for anything it doesn't own).

However, do NOT introduce abstraction layers merely for architectural
purity — see "Avoid Over-Engineering" below.

---

## Database Architecture

Use the existing shared PostgreSQL database. Do NOT create a separate
database for every module. Each module should have logical ownership of
its domain data:

```text
Orders       → owns orders/order_items
Payments     → owns payments/refunds
Delivery     → owns deliveries/driver assignments
Restaurants  → owns restaurants
```

Avoid unnecessary cross-module database manipulation. If another module
needs to change data it doesn't own, prefer using that owning module's
public interface (see "Cross-Module Communication"); reading another
module's data directly is fine (see above).

Database schema changes must preserve existing functionality unless the
task explicitly requires a schema change.

---

## Avoid Over-Engineering

The project is intentionally a modular monolith. Do NOT automatically
introduce:

- Repository interfaces everywhere, or for trivial CRUD
- Abstract factories
- Generic service layers
- Excessive dependency injection
- Event buses or message brokers
- Distributed transactions, CQRS, or event sourcing
- Kubernetes or microservices

Use these only when there is a concrete requirement. Simple code is
preferred when it provides the same architectural boundary.

---

## Mobile Architecture

The project contains four independent Flutter applications, each its own
modular monolith:

| App | Path |
|---|---|
| Customer app | `mobile/` |
| Restaurant partner app | `restaurant_app/` |
| Delivery partner app | `delivery_app/` |
| Admin app | `admin_app/` |

Each mobile application uses **feature-based modular architecture**:

```text
lib/
├── core/
└── features/
    ├── auth/
    ├── restaurants/
    ├── menu/
    ├── cart/
    ├── orders/
    └── profile/
```

(Adapt the feature list to what the app actually needs — e.g. `delivery_app`
has `delivery`/`orders`/`profile` rather than `restaurants`/`menu`/`cart`.)

Each feature should contain its own relevant UI, state management, models,
data access, and feature-specific business logic (including `domain/` once
a feature grows real business rules — don't force it for a thin CRUD
screen). Keep genuinely shared infrastructure (networking, theming,
storage, error handling, common widgets) inside `core/`. Do NOT put
unrelated business logic into `core/`.

The one accepted exception is `lib/core/router/` (e.g. `app_router.dart`,
`main_shell.dart`), which legitimately imports screens/providers from
`features/*` to wire routes and shell navigation — that's composition-root
wiring, not a boundary violation. No other file under `lib/core/` may
import from `lib/features/`.

A new feature = a new folder under `lib/features/`, not code added into an
unrelated existing feature.

All four apps currently duplicate the entire `lib/core/` layer file-for-file
rather than sharing a package — when fixing something in `core/network`,
`core/storage`, or `core/error`, remember to check whether the same fix is
needed in the other three apps.

---

## Mobile/Backend Boundary

Mobile applications communicate with the backend through APIs only:

```text
Customer App
Restaurant App
Driver App
Admin App
        │
        ▼
     Backend API
        │
        ▼
 Modular Monolith
        │
        ▼
   PostgreSQL
```

Mobile applications must not depend on Django's internal module
implementation. The API is the boundary between mobile and backend.

---

## Scaling Strategy

The initial infrastructure may run on a single VPS. The intended scaling
path is:

```text
Single VPS
    ↓
Optimize bottlenecks
    ↓
Horizontal scaling of backend
    ↓
Multiple backend instances
    ↓
Identify specific bottleneck
    ↓
Only if necessary, extract that module
```

The modular monolith should be designed so the backend can eventually run
multiple instances behind a load balancer. Avoid local state that prevents
horizontal scaling.

---

## Future Module Extraction

Do not extract modules into microservices prematurely. If a specific
module eventually becomes a genuine scaling or organizational bottleneck,
it may be extracted:

```text
CURRENT

Modular Monolith
├── Accounts
├── Restaurants
├── Menu
├── Orders
├── Payments
└── Delivery
```

Potential future evolution:

```text
Main Modular Monolith          Delivery Service
├── Accounts
├── Restaurants          +
├── Menu
├── Orders
└── Payments
```

This is an **optional future evolution**, not the current architecture.
When designing module boundaries, make extraction possible without
designing the entire system as distributed from day one.

---

## Development Rules

Before implementing a new feature:

1. Identify which domain owns the feature.
2. Put the business logic inside that domain module.
3. Check existing module boundaries.
4. Reuse existing domain services/interfaces.
5. Avoid creating a new module unless the domain responsibility is
   genuinely distinct.
6. Avoid cross-module internal dependencies (writes go through the owning
   module's `services.py`; reads are fine directly).
7. Preserve API contracts unless the task explicitly requires changing
   them.
8. Preserve existing business behavior.
9. Add or update tests for the affected module.
10. Do not introduce microservice infrastructure.

## Refactoring Rules

When modifying existing code:

- Prefer incremental refactoring.
- Do not rewrite working functionality unnecessarily.
- Do not change architecture merely for stylistic reasons.
- Strengthen existing module boundaries where practical.
- Move business logic toward the module that owns it.
- Remove unnecessary circular dependencies.
- Keep public module interfaces small.
- Avoid creating layers that have no practical value.

## Testing

Tests should follow the modular structure. Each module should have
appropriate unit tests, integration tests, and API tests. Test important
module interactions through their public interfaces. The goal is to ensure
modules can evolve independently while remaining inside the same
deployment.

---

## When in doubt

If a request implies breaking a rule above (new service, new DB, new
broker, cross-repo RPC, Kubernetes, microservices), say so explicitly and
ask before proceeding, rather than silently implementing it or silently
refusing.

## Final principle

**Start simple. Keep modules strongly separated inside one application.
Scale the monolith horizontally first. Extract only the specific module
that proves it needs independent scaling or deployment.**
