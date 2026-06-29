# TODO

## Apply Billing Entitlement Columns

The trial/BYOK code is implemented, but the live Supabase database still needs the billing columns on `danotch_user_profiles`.

Missing columns:

- `trial_started_at`
- `trial_ends_at`
- `lifetime_purchased_at`
- `billing_status`
- `dodo_customer_id`
- `dodo_payment_id`

To apply them, add the Supabase Postgres connection string to `backend/.env` as one of:

```bash
SUPABASE_DB_URL=...
# or
DATABASE_URL=...
```

Then run:

```bash
cd backend
npm run db:billing
```

The SQL that gets applied lives at:

```text
backend/sql/001_billing_entitlements.sql
```

Until this is done, new signup will fail because the backend now writes trial fields during account creation.
