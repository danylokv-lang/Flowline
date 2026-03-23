-- Flowline D1 Database Schema
-- Apply with: wrangler d1 execute flowline-db --file=schema.sql

-- ── Users ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id              TEXT    PRIMARY KEY,            -- UUID
  email           TEXT    UNIQUE NOT NULL,
  password_hash   TEXT,                           -- NULL for Apple Sign In users
  apple_id        TEXT    UNIQUE,                 -- NULL for email users
  name            TEXT    NOT NULL,
  is_pro          INTEGER NOT NULL DEFAULT 0,
  pro_expires_at  INTEGER,                        -- Unix timestamp, NULL = lifetime
  created_at      INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL
);

-- ── User Profiles ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS profiles (
  user_id        TEXT    PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  wake_time      TEXT    NOT NULL DEFAULT '07:00',
  sleep_time     TEXT    NOT NULL DEFAULT '23:00',
  work_start     TEXT,                            -- NULL if no fixed hours
  work_end       TEXT,
  has_work_hours INTEGER NOT NULL DEFAULT 0,
  bio            TEXT    NOT NULL DEFAULT '',
  updated_at     INTEGER NOT NULL
);

-- ── Calendar Days ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS calendar_days (
  id         TEXT    PRIMARY KEY,                 -- UUID
  user_id    TEXT    NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date       TEXT    NOT NULL,                    -- yyyy-MM-dd
  ai_notes   TEXT,
  updated_at INTEGER NOT NULL,
  UNIQUE(user_id, date)                           -- one row per user per day
);

-- ── Schedule Blocks ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS schedule_blocks (
  id         TEXT    PRIMARY KEY,                 -- UUID
  day_id     TEXT    NOT NULL REFERENCES calendar_days(id) ON DELETE CASCADE,
  user_id    TEXT    NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title      TEXT    NOT NULL,
  category   TEXT    NOT NULL,                    -- work | study | health | personal
  start_time TEXT    NOT NULL,                    -- HH:mm
  end_time   TEXT    NOT NULL,                    -- HH:mm
  created_at INTEGER NOT NULL
);

-- ── Chat Messages ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS chat_messages (
  id           TEXT    PRIMARY KEY,                  -- stable UUID generated on-device
  user_id      TEXT    NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_id   TEXT    NOT NULL,                     -- groups messages into one conversation
  session_date TEXT    NOT NULL,                     -- yyyy-MM-dd of the session
  role         TEXT    NOT NULL,                     -- "user" | "assistant"
  content      TEXT    NOT NULL,
  timestamp    INTEGER NOT NULL                      -- Unix timestamp (seconds)
);

-- ── Password Reset Tokens ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS password_reset_tokens (
  token       TEXT    PRIMARY KEY,
  user_id     TEXT    NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at  INTEGER NOT NULL,                   -- Unix timestamp (1 hour TTL)
  used        INTEGER NOT NULL DEFAULT 0          -- 0 = unused, 1 = already used
);

-- ── Indexes ────────────────────────────────────────────────────────────────
-- Fast week queries: "give me all days for user X between date A and B"
CREATE INDEX IF NOT EXISTS idx_calendar_user_date ON calendar_days(user_id, date);

-- Fast block loading for a day
CREATE INDEX IF NOT EXISTS idx_blocks_day ON schedule_blocks(day_id);

-- Fast "delete all blocks for user" on account deletion
CREATE INDEX IF NOT EXISTS idx_blocks_user ON schedule_blocks(user_id);

-- Fast chat history queries: "give me all messages for user X since timestamp T"
CREATE INDEX IF NOT EXISTS idx_chat_user_ts ON chat_messages(user_id, timestamp);
