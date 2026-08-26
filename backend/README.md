# Food Delivery Platform — Backend

Django REST API backend. Clean architecture: `models -> repositories -> services -> serializers -> views`.
See `apps/` for the domain apps and `config/` for project-wide configuration.

## Local setup

1. Create and activate a virtual environment (from this `backend/` folder):

   ```
   python -m venv .venv
   .venv\Scripts\activate      # Windows
   source .venv/bin/activate   # macOS/Linux
   ```

2. Install dependencies:

   ```
   pip install -r requirements/dev.txt
   ```

3. Copy `.env.example` to `.env` and fill in real values (Supabase `DATABASE_URL`, `SECRET_KEY`, etc.):

   ```
   copy .env.example .env    # Windows
   cp .env.example .env      # macOS/Linux
   ```

4. Verify the project loads:

   ```
   python manage.py check
   ```

5. Run the dev server:

   ```
   python manage.py runserver
   ```

`manage.py` defaults to `config.settings.dev`. Production entrypoints (`wsgi.py`/`asgi.py`) default to `config.settings.prod`. Override either with the `DJANGO_SETTINGS_MODULE` env var.

## Project layout

- `config/` — settings (`base`/`dev`/`staging`/`prod`), root URLconf, WSGI/ASGI entrypoints.
- `apps/common/` — shared infrastructure: pagination, standard response envelope, global exception handler. No domain models.
- `apps/{accounts,restaurants,menu,cart,orders,payments,delivery,notifications}/` — one Django app per domain. Currently scaffolded with no models — models land in later modules.
- `requirements/` — split `base` / `dev` / `prod` dependency sets.
- `logs/`, `media/`, `static/` — runtime output directories (git-ignored except `.gitkeep`).
