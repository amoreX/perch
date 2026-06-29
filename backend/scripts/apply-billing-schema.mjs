import 'dotenv/config';
import { readFile } from 'node:fs/promises';
import { Client } from 'pg';

const connectionString =
  process.env.DATABASE_URL ||
  process.env.POSTGRES_URL ||
  process.env.SUPABASE_DB_URL;

if (!connectionString) {
  console.error(
    'Missing DATABASE_URL, POSTGRES_URL, or SUPABASE_DB_URL. Add the Supabase Postgres connection string and rerun this script.',
  );
  process.exit(1);
}

const sql = await readFile(new URL('../sql/001_billing_entitlements.sql', import.meta.url), 'utf8');
const client = new Client({
  connectionString,
  ssl: connectionString.includes('localhost') ? false : { rejectUnauthorized: false },
});

try {
  await client.connect();
  await client.query(sql);
  console.log('Billing entitlement schema applied.');
} finally {
  await client.end();
}
