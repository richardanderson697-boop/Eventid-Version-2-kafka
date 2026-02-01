-- Events database schema
-- Immutable audit log of all platform events

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- For full-text search

-- Events table (immutable append-only log)
CREATE TABLE events (
    id BIGSERIAL PRIMARY KEY,
    event_id UUID UNIQUE NOT NULL,
    event_version INTEGER NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    platform VARCHAR(50) NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    correlation_id VARCHAR(255),
    user_id VARCHAR(255),
    event_data JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes for fast queries
CREATE INDEX idx_events_event_id ON events(event_id);
CREATE INDEX idx_events_platform ON events(platform);
CREATE INDEX idx_events_event_type ON events(event_type);
CREATE INDEX idx_events_timestamp ON events(timestamp DESC);
CREATE INDEX idx_events_correlation_id ON events(correlation_id) WHERE correlation_id IS NOT NULL;
CREATE INDEX idx_events_user_id ON events(user_id) WHERE user_id IS NOT NULL;

-- JSONB indexes for querying event data
CREATE INDEX idx_events_data_framework ON events USING GIN ((event_data->'jurisdiction'->>'framework'));
CREATE INDEX idx_events_data_region ON events USING GIN ((event_data->'jurisdiction'->>'region'));
CREATE INDEX idx_events_data_severity ON events USING GIN ((event_data->'risk_context'->>'change_severity'));

-- Full-text search on event data
CREATE INDEX idx_events_data_text ON events USING GIN (to_tsvector('english', event_data::text));

-- Audit trigger to prevent updates/deletes (immutability)
CREATE OR REPLACE FUNCTION prevent_event_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Events are immutable and cannot be modified or deleted';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_event_update
    BEFORE UPDATE ON events
    FOR EACH ROW
    EXECUTE FUNCTION prevent_event_modification();

CREATE TRIGGER prevent_event_delete
    BEFORE DELETE ON events
    FOR EACH ROW
    EXECUTE FUNCTION prevent_event_modification();

-- Event statistics view
CREATE VIEW event_statistics AS
SELECT
    platform,
    event_type,
    DATE(timestamp) as event_date,
    COUNT(*) as event_count,
    COUNT(DISTINCT correlation_id) FILTER (WHERE correlation_id IS NOT NULL) as workflow_count
FROM events
GROUP BY platform, event_type, DATE(timestamp);

-- Recent events view (last 7 days)
CREATE VIEW recent_events AS
SELECT
    event_id,
    event_type,
    platform,
    timestamp,
    correlation_id,
    event_data->>'workspace_id' as workspace_id,
    event_data->'jurisdiction'->>'framework' as framework,
    event_data->'risk_context'->>'change_severity' as severity
FROM events
WHERE timestamp >= NOW() - INTERVAL '7 days'
ORDER BY timestamp DESC;

-- Comments
COMMENT ON TABLE events IS 'Immutable append-only log of all platform events';
COMMENT ON COLUMN events.event_id IS 'UUIDv7 time-ordered event identifier';
COMMENT ON COLUMN events.event_data IS 'Complete event payload in JSONB format';
COMMENT ON COLUMN events.correlation_id IS 'Links related events in workflows';