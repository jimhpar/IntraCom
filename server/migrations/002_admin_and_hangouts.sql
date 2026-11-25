-- IntraCom Migration 002: Admin & Advanced Hangout Architecture

-- 1. Users table updates
ALTER TABLE users ALTER COLUMN email DROP NOT NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_suspended BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT '';

-- Make initial admin user admin by default
UPDATE users SET is_admin = TRUE WHERE full_number = '+1-1111111' OR email = 'admin';

-- 2. Hangouts table updates
ALTER TABLE hangouts ADD COLUMN IF NOT EXISTS hub_type VARCHAR(20) DEFAULT 'public'; -- public, private
ALTER TABLE hangouts ADD COLUMN IF NOT EXISTS district_code INT DEFAULT 0;

-- 3. Public Hub Creation Requests Queue
CREATE TABLE IF NOT EXISTS hangout_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT DEFAULT '',
    district_code INT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected
    admin_note TEXT DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMP WITH TIME ZONE
);

-- 4. Hub-Specific User Bans
CREATE TABLE IF NOT EXISTS hangout_bans (
    hangout_id UUID NOT NULL REFERENCES hangouts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    banned_by UUID REFERENCES users(id),
    reason TEXT DEFAULT '',
    banned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(hangout_id, user_id)
);

-- 5. Hub Chat Messages (for real-time persistence & admin moderation)
CREATE TABLE IF NOT EXISTS hangout_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hangout_id UUID NOT NULL REFERENCES hangouts(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_hangout_messages_created ON hangout_messages(hangout_id, created_at ASC);
