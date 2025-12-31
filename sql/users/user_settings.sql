CREATE TABLE user_settings (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    
    -- 通知设置
    email_notifications BOOLEAN DEFAULT TRUE,
    comment_notifications BOOLEAN DEFAULT TRUE,
    newsletter_subscribed BOOLEAN DEFAULT FALSE,
    
    -- 隐私设置
    show_email_public BOOLEAN DEFAULT FALSE,
    show_location_public BOOLEAN DEFAULT TRUE,
    
    -- 显示设置
    posts_per_page INTEGER DEFAULT 10,
    preferred_theme VARCHAR(20) DEFAULT 'light' CHECK (preferred_theme IN ('light', 'dark', 'auto')),
    timezone VARCHAR(50) DEFAULT 'UTC',
    
    -- 更新跟踪
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);