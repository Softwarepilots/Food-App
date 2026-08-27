# Garuda — Architecture Rules

This repo is three independently-deployed apps, each a **modular monolith**:

| App | Path | Stack |
|---|---|---|
| Backend API | `backend/` | Django + DRF, single Postgres (Supabase) |
| Customer app | `mobile/` | Flutter |
| Restaurant partner app | `restaurant_app/` | Flutter |

All three ship as one deployable unit each. None of them are split into
services. **Do not change that** without the user explicitly asking for it.

## Hard rules — do not do these without explicit user approval

- Do not propose or scaffold splitting `backend/` into multiple services,
  separate deployables, or separate processes (no new Dockerfiles per
  domain, no API gateway, no service mesh).
- Do not add a second database, a message broker (Kafka/RabbitMQ/etc.), or
  an inter-service RPC layer (gRPC, internal HTTP calls) for communication
  between `apps/*`. Cross-domain communication inside the backend happens
  via direct Python calls (imports) or Django signals — see below.
- Do not create a new top-level backend project/folder for a new domain.
  A new domain is a new Django app under `backend/apps/`.
- Do not suggest microservices as the default answer to a scaling
  question. If genuine scaling pressure comes up (e.g. payments/delivery
  load), flag it as a discussion point — don't implement a split.

## Backend module conventions (`backend/apps/*`)

Existing domains: `common`, `accounts`, `restaurants`, `menu`, `cart`,
`orders`, `payments`, `delivery`, `notifications`.

- Each app owns its own `models.py`, `serializers.py`, `views.py`,
  `urls.py`, `services.py`, `signals.py`, `migrations/`, `tests/`.
- Business logic goes in `services.py`, not in views. Views/serializers
  stay thin.
- **Dependency direction:** `apps/common` must never import from another
  `apps/*` module. Every other app may import `apps.common` freely.
  Domain apps may import directly from other domain apps' `models.py` /
  `services.py` when there's a real data dependency (this already happens,
  e.g. `orders/services.py` imports `apps.menu`, `apps.payments`,
  `apps.restaurants`) — that's normal here, not a violation.
- Use Django signals (`signals.py`) for reactive side effects across apps
  (e.g. `delivery/signals.py` reacting to `apps.orders.models.Order`
  saves) rather than tight coupling in view code.
- A new domain = a new app under `backend/apps/`, registered in
  `LOCAL_APPS` (`backend/config/settings/base.py`), wired under
  `api_v1_patterns` in `backend/config/urls.py`. Do not bolt unrelated
  concerns onto an existing app to avoid creating a new one — keep
  boundaries by domain.
- One `DATABASES["default"]` for everything. Do not introduce per-app
  databases or read replicas as a default suggestion.

## Frontend module conventions (`mobile/lib`, `restaurant_app/lib`)

- Feature-modular: each domain lives under `lib/features/<name>/` with
  its own `data/`, `domain/`, `presentation/` layers.
- Shared infra (networking, theming, router, common widgets) lives in
  `lib/core/` only — it must not depend on any `features/*` module.
- A new feature = a new folder under `lib/features/`, not code added
  into an unrelated existing feature.

## When in doubt

If a request implies breaking a rule above (new service, new DB, new
broker, cross-repo RPC), say so explicitly and ask before proceeding,
rather than silently implementing it or silently refusing.
