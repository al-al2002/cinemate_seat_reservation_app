-- =============================================
-- CINEMA BOOKING SYSTEM - DATABASE MIGRATION
-- Extends existing schema with payment features
-- =============================================

-- 1. CREATE PAYMENT METHODS TABLE
CREATE TABLE IF NOT EXISTS public.payment_methods (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL, -- 'GCash', 'Maya', 'Cash'
  type TEXT NOT NULL, -- 'online', 'cash'
  qr_code_url TEXT, -- URL to QR code image
  mobile_number TEXT, -- Mobile number for payment
  account_name TEXT, -- Account holder name
  instructions TEXT, -- Payment instructions
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. UPDATE TICKETS TABLE
-- Add payment tracking columns
ALTER TABLE public.tickets
  ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'failed', 'expired')),
  ADD COLUMN IF NOT EXISTS reserved_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '15 minutes'),
  ADD COLUMN IF NOT EXISTS payment_method_id UUID REFERENCES public.payment_methods(id),
  ADD COLUMN IF NOT EXISTS confirmed_by UUID REFERENCES public.users(id),
  ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMP WITH TIME ZONE;

-- 3. UPDATE SEATS TABLE
-- Add reservation expiry tracking
ALTER TABLE public.seats
  ADD COLUMN IF NOT EXISTS reservation_expires_at TIMESTAMP WITH TIME ZONE;

-- 4. UPDATE MOVIES TABLE
-- Add status for upcoming/now showing/ended
ALTER TABLE public.movies
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'now_showing', 'ended'));

-- 5. UPDATE SHOWTIMES TABLE
-- Add status for started/available
ALTER TABLE public.showtimes
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'available' CHECK (status IN ('available', 'started', 'ended'));

-- 6. UPDATE RESERVATIONS TABLE
-- Add payment reference and expiry
ALTER TABLE public.reservations
  ADD COLUMN IF NOT EXISTS payment_method_id UUID REFERENCES public.payment_methods(id);

-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================
CREATE INDEX IF NOT EXISTS idx_tickets_payment_status ON public.tickets(payment_status);
CREATE INDEX IF NOT EXISTS idx_tickets_expires_at ON public.tickets(expires_at);
CREATE INDEX IF NOT EXISTS idx_seats_reservation_expires ON public.seats(reservation_expires_at);
CREATE INDEX IF NOT EXISTS idx_movies_status ON public.movies(status);
CREATE INDEX IF NOT EXISTS idx_movies_release_date ON public.movies(release_date);
CREATE INDEX IF NOT EXISTS idx_showtimes_status ON public.showtimes(status);
CREATE INDEX IF NOT EXISTS idx_payment_history_status ON public.payment_history(status);

-- =============================================
-- FUNCTION: Generate unique reference number
-- =============================================
DROP FUNCTION IF EXISTS generate_reference_number();
CREATE FUNCTION generate_reference_number()
RETURNS TEXT AS $$
DECLARE
  ref_number TEXT;
  ref_exists BOOLEAN;
BEGIN
  LOOP
    -- Generate format: REF-YYYYMMDD-XXXXXX
    ref_number := 'REF-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' ||
                  UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 6));

    -- Check if reference number already exists
    SELECT EXISTS(
      SELECT 1 FROM public.tickets WHERE payment_reference = ref_number
    ) INTO ref_exists;

    -- Exit loop if unique
    EXIT WHEN NOT ref_exists;
  END LOOP;

  RETURN ref_number;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- FUNCTION: Generate unique ticket number
-- =============================================
DROP FUNCTION IF EXISTS generate_ticket_number();
CREATE FUNCTION generate_ticket_number()
RETURNS TEXT AS $$
DECLARE
  ticket_num TEXT;
  ticket_exists BOOLEAN;
BEGIN
  LOOP
    -- Generate format: TKT-YYYYMMDD-XXXXXX
    ticket_num := 'TKT-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' ||
                  UPPER(SUBSTRING(MD5(RANDOM()::TEXT) FROM 1 FOR 6));

    -- Check if ticket number already exists
    SELECT EXISTS(
      SELECT 1 FROM public.tickets WHERE ticket_number = ticket_num
    ) INTO ticket_exists;

    -- Exit loop if unique
    EXIT WHEN NOT ticket_exists;
  END LOOP;

  RETURN ticket_num;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- FUNCTION: Auto-release expired seat reservations
-- =============================================
DROP FUNCTION IF EXISTS release_expired_seats();
CREATE FUNCTION release_expired_seats()
RETURNS TABLE(released_count INTEGER) AS $$
DECLARE
  released_count INTEGER;
BEGIN
  -- Update expired tickets to 'expired' status
  UPDATE public.tickets
  SET
    payment_status = 'expired',
    status = 'cancelled'
  WHERE
    payment_status = 'pending'
    AND expires_at < NOW();

  GET DIAGNOSTICS released_count = ROW_COUNT;

  -- Release seats that were reserved but payment expired
  UPDATE public.seats
  SET
    status = 'available',
    user_id = NULL,
    reserved_at = NULL,
    reservation_expires_at = NULL
  WHERE
    status = 'reserved'
    AND reservation_expires_at < NOW();

  -- Also update reservations to cancelled
  UPDATE public.reservations
  SET status = 'cancelled'
  WHERE
    status = 'pending'
    AND expires_at < NOW();

  RETURN QUERY SELECT released_count;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- FUNCTION: Update movie status based on release date
-- =============================================
DROP FUNCTION IF EXISTS update_movie_status();
CREATE FUNCTION update_movie_status()
RETURNS TABLE(updated_count INTEGER) AS $$
DECLARE
  updated_count INTEGER := 0;
BEGIN
  -- Move to 'now_showing' if release date is today or past
  UPDATE public.movies
  SET status = 'now_showing'
  WHERE
    status = 'upcoming'
    AND release_date <= CURRENT_DATE;

  GET DIAGNOSTICS updated_count = ROW_COUNT;

  -- Mark movie as 'ended' if all showtimes have passed
  UPDATE public.movies m
  SET status = 'ended'
  WHERE
    status = 'now_showing'
    AND NOT EXISTS (
      SELECT 1
      FROM public.showtimes s
      WHERE s.movie_id = m.id
      AND s.showtime > NOW()
    );

  RETURN QUERY SELECT updated_count;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- FUNCTION: Update showtime status
-- =============================================
DROP FUNCTION IF EXISTS update_showtime_status();
CREATE FUNCTION update_showtime_status()
RETURNS TABLE(updated_count INTEGER) AS $$
DECLARE
  updated_count INTEGER := 0;
BEGIN
  -- Mark showtimes as 'started' when showtime has passed
  UPDATE public.showtimes s
  SET status = 'started'
  WHERE
    status = 'available'
    AND showtime <= NOW();

  GET DIAGNOSTICS updated_count = ROW_COUNT;

  -- Mark as 'ended' after movie duration (if duration exists in movies table)
  UPDATE public.showtimes s
  SET status = 'ended'
  FROM public.movies m
  WHERE
    s.movie_id = m.id
    AND s.status = 'started'
    AND (s.showtime + (m.duration_minutes || ' minutes')::INTERVAL) < NOW();

  RETURN QUERY SELECT updated_count;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- TRIGGER: Auto-update movie updated_at
-- =============================================
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;
CREATE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS update_movies_updated_at ON public.movies;
CREATE TRIGGER update_movies_updated_at
  BEFORE UPDATE ON public.movies
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;
CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- TRIGGER: Auto-create user profile on signup
-- =============================================
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
CREATE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, full_name, password, role, created_at, updated_at)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    'auth_managed', -- Placeholder since auth.users manages passwords
    'user',
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();

-- =============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =============================================

-- Enable RLS on payment_methods table
ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;

-- Everyone can view active payment methods
CREATE POLICY "Public can view active payment methods"
  ON public.payment_methods FOR SELECT
  USING (is_active = true);

-- Only admins can modify payment methods
CREATE POLICY "Only admins can modify payment methods"
  ON public.payment_methods FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
      AND users.role = 'admin'
    )
  );

-- =============================================
-- SEED DATA: Payment Methods
-- =============================================
INSERT INTO public.payment_methods (name, type, qr_code_url, mobile_number, account_name, instructions, is_active) VALUES
  ('GCash', 'online', NULL, '09123456789', 'Cinema Booking', 'Scan the QR code or send payment to the mobile number. Use your ticket reference number as the payment message.', true),
  ('Maya', 'online', NULL, '09987654321', 'Cinema Booking', 'Scan the QR code or send payment to the mobile number. Use your ticket reference number as the payment message.', true),
  ('Cash', 'cash', NULL, NULL, NULL, 'Pay at the cinema counter before the movie starts. Show your ticket reference number.', true)
ON CONFLICT DO NOTHING;

-- =============================================
-- HELPER VIEWS
-- =============================================

-- View for pending payments (Admin Dashboard)
CREATE OR REPLACE VIEW pending_payments_view AS
SELECT
  t.id as ticket_id,
  t.payment_reference,
  t.ticket_number,
  t.total_amount,
  t.seat_ids,
  t.payment_status,
  t.expires_at,
  t.created_at,
  u.id as user_id,
  u.email as user_email,
  u.full_name as user_name,
  u.phone_number,
  m.id as movie_id,
  m.title as movie_title,
  s.id as showtime_id,
  s.showtime,
  s.cinema_hall,
  pm.name as payment_method_name,
  pm.type as payment_method_type
FROM public.tickets t
JOIN public.users u ON t.user_id = u.id
JOIN public.showtimes s ON t.showtime_id = s.id
JOIN public.movies m ON s.movie_id = m.id
LEFT JOIN public.payment_methods pm ON t.payment_method_id = pm.id
WHERE t.payment_status = 'pending'
  AND t.expires_at > NOW()
ORDER BY t.created_at DESC;

-- View for expired reservations (for cleanup monitoring)
CREATE OR REPLACE VIEW expired_reservations_view AS
SELECT
  t.id as ticket_id,
  t.payment_reference,
  t.ticket_number,
  t.user_id,
  t.seat_ids,
  t.expires_at,
  t.total_amount,
  s.showtime,
  s.cinema_hall,
  m.title as movie_title
FROM public.tickets t
JOIN public.showtimes s ON t.showtime_id = s.id
JOIN public.movies m ON s.movie_id = m.id
WHERE
  t.payment_status = 'pending'
  AND t.expires_at < NOW();

-- View for upcoming and now showing movies
CREATE OR REPLACE VIEW active_movies_view AS
SELECT
  m.*,
  COUNT(DISTINCT s.id) as showtime_count,
  MIN(s.showtime) as next_showtime
FROM public.movies m
LEFT JOIN public.showtimes s ON s.movie_id = m.id AND s.showtime > NOW()
WHERE m.status IN ('upcoming', 'now_showing')
  AND m.is_active = true
GROUP BY m.id
ORDER BY m.release_date ASC;

-- =============================================
-- NOTES FOR IMPLEMENTATION
-- =============================================
/*
1. Run this migration in your Supabase SQL Editor
2. Upload QR code images to Supabase Storage and update payment_methods table
3. Set up cron job or Edge Function to call release_expired_seats() every minute
4. Set up cron job to call update_movie_status() every hour
5. Set up cron job to call update_showtime_status() every 5 minutes
6. Configure Realtime subscriptions for admin dashboard
7. Update your Flutter app to use these new columns and functions

IMPORTANT: Test the functions manually first:
- SELECT release_expired_seats();
- SELECT update_movie_status();
- SELECT update_showtime_status();
*/
