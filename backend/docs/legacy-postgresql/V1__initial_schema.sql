CREATE TABLE app_users (
 id VARCHAR(36) PRIMARY KEY, email VARCHAR(254) UNIQUE, password_hash VARCHAR(100),
 name VARCHAR(80) NOT NULL, role VARCHAR(16) NOT NULL DEFAULT 'USER',
 platform VARCHAR(16) NOT NULL, created_at TIMESTAMP WITH TIME ZONE NOT NULL,
 prefs TEXT, community_joined_at TIMESTAMP WITH TIME ZONE
);
CREATE TABLE auth_sessions (
 id VARCHAR(36) PRIMARY KEY, user_id VARCHAR(36) NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
 refresh_hash VARCHAR(64) UNIQUE NOT NULL, expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
 revoked BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX idx_sessions_user ON auth_sessions(user_id);
CREATE TABLE articles (
 id VARCHAR(100) PRIMARY KEY, title VARCHAR(240) NOT NULL, body TEXT NOT NULL,
 category VARCHAR(30) NOT NULL, urgency VARCHAR(16) NOT NULL, confirmed BOOLEAN NOT NULL,
 first_in_brazil BOOLEAN NOT NULL, lead_minutes INTEGER,
 published_at TIMESTAMP WITH TIME ZONE NOT NULL, detected_at TIMESTAMP WITH TIME ZONE NOT NULL,
 trending_tag VARCHAR(80), payload TEXT NOT NULL
);
CREATE INDEX idx_articles_feed ON articles(confirmed, published_at DESC, id DESC);
CREATE INDEX idx_articles_topic ON articles(category, published_at DESC, id DESC);
CREATE TABLE article_entities (
 article_id VARCHAR(100) NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
 entity_id VARCHAR(100) NOT NULL, name VARCHAR(100) NOT NULL, entity_type VARCHAR(16) NOT NULL,
 PRIMARY KEY(article_id, entity_id)
);
CREATE INDEX idx_entity_lookup ON article_entities(entity_id, article_id);
CREATE TABLE saved_articles (
 user_id VARCHAR(36) NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
 article_id VARCHAR(100) NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
 saved_at TIMESTAMP WITH TIME ZONE NOT NULL, progress DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK(progress >= 0 AND progress <= 1),
 archived BOOLEAN NOT NULL DEFAULT FALSE, PRIMARY KEY(user_id, article_id)
);
CREATE TABLE following (
 user_id VARCHAR(36) NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
 entity_id VARCHAR(100) NOT NULL, PRIMARY KEY(user_id, entity_id)
);
CREATE TABLE alerts (
 id VARCHAR(36) PRIMARY KEY, user_id VARCHAR(36) NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
 article_id VARCHAR(100) REFERENCES articles(id) ON DELETE SET NULL,
 type VARCHAR(16) NOT NULL, category VARCHAR(30), title VARCHAR(240) NOT NULL,
 subtitle VARCHAR(300) NOT NULL, created_at TIMESTAMP WITH TIME ZONE NOT NULL, is_read BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE INDEX idx_alerts_user ON alerts(user_id, created_at DESC);
CREATE TABLE push_tokens (
 token VARCHAR(2048) PRIMARY KEY, user_id VARCHAR(36) NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
 platform VARCHAR(16) NOT NULL, updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);
CREATE TABLE live_events (
 id VARCHAR(100) PRIMARY KEY, payload TEXT NOT NULL
);
CREATE TABLE reading_activity (
 user_id VARCHAR(36) NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
 article_id VARCHAR(100) NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
 read_date DATE NOT NULL, PRIMARY KEY(user_id, article_id, read_date)
);
