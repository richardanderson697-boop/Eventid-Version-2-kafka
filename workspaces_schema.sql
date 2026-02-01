-- Workspaces database schema
-- Configuration for compliance workspaces and platform integrations

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Workspaces table
CREATE TABLE workspaces (
    id BIGSERIAL PRIMARY KEY,
    workspace_id VARCHAR(255) UNIQUE NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    name VARCHAR(500) NOT NULL,
    frameworks JSONB NOT NULL DEFAULT '[]',
    jurisdiction VARCHAR(50) NOT NULL,
    modules JSONB NOT NULL DEFAULT '[]',
    github_repo VARCHAR(500),
    active BOOLEAN NOT NULL DEFAULT true,
    settings JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_workspaces_workspace_id ON workspaces(workspace_id);
CREATE INDEX idx_workspaces_user_id ON workspaces(user_id);
CREATE INDEX idx_workspaces_active ON workspaces(active) WHERE active = true;
CREATE INDEX idx_workspaces_frameworks ON workspaces USING GIN (frameworks);
CREATE INDEX idx_workspaces_jurisdiction ON workspaces(jurisdiction);

-- Platform integrations table
CREATE TABLE platform_integrations (
    id BIGSERIAL PRIMARY KEY,
    workspace_id VARCHAR(255) NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
    platform VARCHAR(50) NOT NULL, -- 'scraper', 'code', 'scan', 'review'
    enabled BOOLEAN NOT NULL DEFAULT true,
    configuration JSONB DEFAULT '{}',
    last_sync TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(workspace_id, platform)
);

CREATE INDEX idx_integrations_workspace ON platform_integrations(workspace_id);
CREATE INDEX idx_integrations_platform ON platform_integrations(platform);
CREATE INDEX idx_integrations_enabled ON platform_integrations(enabled) WHERE enabled = true;

-- Event subscriptions (which event types each workspace subscribes to)
CREATE TABLE event_subscriptions (
    id BIGSERIAL PRIMARY KEY,
    workspace_id VARCHAR(255) NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL,
    platform VARCHAR(50) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT true,
    filters JSONB DEFAULT '{}', -- Additional filtering criteria
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(workspace_id, event_type, platform)
);

CREATE INDEX idx_subscriptions_workspace ON event_subscriptions(workspace_id);
CREATE INDEX idx_subscriptions_event_type ON event_subscriptions(event_type);
CREATE INDEX idx_subscriptions_enabled ON event_subscriptions(enabled) WHERE enabled = true;

-- Automation rules (workspace-specific automation logic)
CREATE TABLE automation_rules (
    id BIGSERIAL PRIMARY KEY,
    workspace_id VARCHAR(255) NOT NULL REFERENCES workspaces(workspace_id) ON DELETE CASCADE,
    rule_name VARCHAR(255) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    conditions JSONB NOT NULL, -- Matching conditions
    actions JSONB NOT NULL, -- Actions to execute
    enabled BOOLEAN NOT NULL DEFAULT true,
    priority INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_rules_workspace ON automation_rules(workspace_id);
CREATE INDEX idx_rules_event_type ON automation_rules(event_type);
CREATE INDEX idx_rules_enabled ON automation_rules(enabled) WHERE enabled = true;
CREATE INDEX idx_rules_priority ON automation_rules(priority DESC);

-- Workflow history (tracks automated workflows)
CREATE TABLE workflow_history (
    id BIGSERIAL PRIMARY KEY,
    workflow_id VARCHAR(255) UNIQUE NOT NULL,
    workspace_id VARCHAR(255) REFERENCES workspaces(workspace_id),
    workflow_type VARCHAR(100) NOT NULL,
    trigger_event_id VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL, -- 'started', 'in_progress', 'completed', 'failed'
    steps JSONB NOT NULL DEFAULT '[]',
    result JSONB,
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_workflow_workflow_id ON workflow_history(workflow_id);
CREATE INDEX idx_workflow_workspace ON workflow_history(workspace_id);
CREATE INDEX idx_workflow_status ON workflow_history(status);
CREATE INDEX idx_workflow_started ON workflow_history(started_at DESC);
CREATE INDEX idx_workflow_trigger ON workflow_history(trigger_event_id);

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_workspaces_updated_at
    BEFORE UPDATE ON workspaces
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_integrations_updated_at
    BEFORE UPDATE ON platform_integrations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_rules_updated_at
    BEFORE UPDATE ON automation_rules
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Sample data for testing
INSERT INTO workspaces (workspace_id, user_id, name, frameworks, jurisdiction, modules, github_repo, active) VALUES
('ws_healthcare_app', 'user_123', 'Healthcare Application', '["HIPAA", "SOC2"]', 'US', '["DATABASE", "API", "AUTHENTICATION", "ENCRYPTION"]', 'yourorg/healthcare-app', true),
('ws_fintech_platform', 'user_456', 'FinTech Platform', '["PCI_DSS", "SOC2"]', 'US', '["PAYMENT_PROCESSING", "DATABASE", "API", "ENCRYPTION"]', 'yourorg/fintech-platform', true),
('ws_saas_product', 'user_789', 'SaaS Product', '["GDPR", "ISO27001"]', 'EU', '["DATABASE", "USER_INTERFACE", "API", "DATA_STORAGE"]', 'yourorg/saas-product', true);

-- Views
CREATE VIEW active_workspaces_summary AS
SELECT
    w.workspace_id,
    w.name,
    w.user_id,
    w.frameworks,
    w.jurisdiction,
    jsonb_array_length(w.modules) as module_count,
    w.github_repo,
    COUNT(DISTINCT pi.platform) FILTER (WHERE pi.enabled = true) as active_integrations,
    COUNT(DISTINCT es.event_type) FILTER (WHERE es.enabled = true) as active_subscriptions
FROM workspaces w
LEFT JOIN platform_integrations pi ON w.workspace_id = pi.workspace_id
LEFT JOIN event_subscriptions es ON w.workspace_id = es.workspace_id
WHERE w.active = true
GROUP BY w.workspace_id, w.name, w.user_id, w.frameworks, w.jurisdiction, w.modules, w.github_repo;

-- Comments
COMMENT ON TABLE workspaces IS 'Compliance workspace configurations';
COMMENT ON TABLE platform_integrations IS 'Platform integration settings per workspace';
COMMENT ON TABLE event_subscriptions IS 'Event type subscriptions per workspace';
COMMENT ON TABLE automation_rules IS 'Custom automation rules per workspace';
COMMENT ON TABLE workflow_history IS 'History of executed workflows';