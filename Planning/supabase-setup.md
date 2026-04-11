# Supabase Auth Setup (Milestone 0.5)

Manual steps to configure Supabase for LangBrew.

## 1. Create Supabase Project

1. Go to https://supabase.com/dashboard → New Project
2. Name: `langbrew`
3. Region: pick closest to your users
4. Generate a strong database password (used for the Postgres connection string)
5. Wait for project to provision

## 2. Get JWT Keys

1. Go to Project Settings → API → JWT Settings
2. Copy the **JWT Secret** → `SUPABASE_JWT_SECRET`
3. Copy the **JWK** (public key JSON) → `SUPABASE_JWT_JWK`
   - Supabase uses ES256 signing; the backend needs the public JWK to verify tokens
4. Add both to backend env vars and `.env` for local dev

## 3. Enable Auth Providers

### Apple Sign-In
1. Go to Authentication → Providers → Apple
2. Enable it
3. Add your Apple Services ID, Team ID, Key ID, and private key
4. These come from Apple Developer Console → Certificates, Identifiers & Profiles → Keys

### Google Sign-In
1. Go to Authentication → Providers → Google
2. Enable it
3. Add your Google Client ID and Client Secret
4. These come from Google Cloud Console → APIs & Services → Credentials → OAuth 2.0 Client IDs

### Email/Password
1. Go to Authentication → Providers → Email
2. Enable email sign-up
3. Enable "Confirm email" for verification
4. Customize email templates if desired

## 4. Configure Redirect URLs

1. Go to Authentication → URL Configuration
2. Add redirect URL for iOS: `langbrew://auth-callback`
3. Add localhost for dev: `http://localhost:3000/auth/callback`

## 5. Get Supabase URL & Anon Key (for iOS)

1. Go to Project Settings → API
2. Copy:
   - **Project URL** → used as `SUPABASE_URL` in iOS app
   - **anon/public key** → used as `SUPABASE_ANON_KEY` in iOS app

## 6. iOS Configuration

Add to the iOS project's configuration (e.g., Info.plist or a config file):
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=eyJ...your-anon-key
```

## 7. Verify

1. Create a test user from Supabase Dashboard → Authentication → Users → Add User
2. Use the Supabase client to sign in and confirm a JWT is issued
3. Decode the JWT at jwt.io — verify `sub` contains the user UUID and `aud` is "authenticated"
4. Test the JWT against your backend's `GET /v1/health` (once auth middleware is deployed)

## Notes

- Free tier: 50K MAUs, project pauses after 7 days of inactivity
- For production: upgrade to Supabase Pro ($25/mo) to prevent auto-pause
- Supabase provides both auth AND the database — all app data lives in Supabase Postgres
- Supabase is only used for authentication (JWT issuance + token refresh)
