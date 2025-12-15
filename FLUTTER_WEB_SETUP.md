# Flutter Web Setup for Supabase

## CORS Issue Fix

If you're getting "Failed to fetch" or "ClientException" errors when trying to login/register on Flutter Web, you need to configure CORS on your Supabase project.

### Steps to Fix CORS on Supabase

1. **Go to your Supabase Dashboard**
   - Navigate to: <https://supabase.com/dashboard>

2. **Select your project** (the one with URL: `https://isqzlkxwpotvjkymirvn.supabase.co`)

3. **Disable Email Confirmation (for development)**
   - Go to **Authentication** → **Settings** → **Email Auth**
   - Turn OFF "Confirm email" (this allows instant login without email verification)
   - Click **Save**

4. **Configure Allowed URLs**
   - In **Authentication** → **URL Configuration**
   - Add these to **Redirect URLs**:

     ```text
     http://localhost:50601
     http://localhost:50601/*
     http://localhost:*
     ```

   - Add to **Site URL**: `http://localhost:50601`

5. **Alternative: Run on Chrome with CORS disabled (Development Only)**

   If you still have issues, you can run Flutter Web with CORS disabled:

   ```bash
   flutter run -d chrome --web-browser-flag "--disable-web-security"
   ```

   ⚠️ **WARNING**: Only use this for development! Never deploy with security disabled.

6. **Or: Use Flutter on a different platform**

   CORS issues only affect Flutter Web. You can also run on:

   ```bash
   flutter run -d windows    # If on Windows
   flutter run -d macos      # If on macOS
   flutter run               # Will show available devices
   ```

## Verify Your .env Configuration

Make sure your `.env` file has the correct Supabase credentials:

```env
SUPABASE_URL=https://isqzlkxwpotvjkymirvn.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlzcXpsa3h3cG90dmpreW1pcnZuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyODI4NjcsImV4cCI6MjA3ODg1ODg2N30.X94ifDA-wrWh74QutmAx8nYXU_irwsna8rmAjeH1l6Y
```

## Test Login

After fixing CORS, try logging in with:

- Email: <sample@gmail.com>
- Password: Password1

If the account doesn't exist yet, create it through the register screen first.
