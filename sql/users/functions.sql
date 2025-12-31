-- 自动更新 updated_at 时间戳
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为用户表创建触发器
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 为用户设置表创建触发器
CREATE TRIGGER update_user_settings_updated_at
    BEFORE UPDATE ON user_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE VIEW v_user_profiles AS
SELECT 
    u.id,
    u.username,
    u.email,
    u.display_name,
    u.bio,
    u.avatar_url,
    u.website_url,
    u.location,
    u.role,
    u.is_active,
    u.created_at,
    u.last_login_at,
    us.email_notifications,
    us.comment_notifications,
    ust.posts_count,
    ust.comments_count,
    ust.followers_count,
    ust.following_count
FROM users u
LEFT JOIN user_settings us ON u.id = us.user_id
LEFT JOIN user_statistics ust ON u.id = ust.user_id;

CREATE OR REPLACE FUNCTION create_user_with_defaults(
    p_username VARCHAR(50),
    p_email VARCHAR(255),
    p_password_hash VARCHAR(255)
)
RETURNS INTEGER AS $$
DECLARE
    new_user_id INTEGER;
BEGIN
    -- 插入用户
    INSERT INTO users (username, email, password_hash)
    VALUES (p_username, p_email, p_password_hash)
    RETURNING id INTO new_user_id;
    
    -- 初始化用户设置
    INSERT INTO user_settings (user_id) VALUES (new_user_id);
    
    -- 初始化用户统计
    INSERT INTO user_statistics (user_id) VALUES (new_user_id);
    
    RETURN new_user_id;
END;
$$ LANGUAGE plpgsql;