-- ============================================
-- 博客系统用户表结构
-- 版本：1.0
-- 创建日期：2024
-- 说明：首次安装时运行此文件创建所有用户相关表
-- ============================================

-- 关闭事务自动提交，确保所有表要么全部创建成功，要么全部失败
BEGIN;

-- ============================================
-- 1. 创建基本用户表
-- ============================================
CREATE TABLE IF NOT EXISTS users
(
    -- 主键和身份信息
    id                SERIAL PRIMARY KEY,
    username          VARCHAR(50) UNIQUE  NOT NULL,
    email             VARCHAR(255) UNIQUE NOT NULL,
    password_hash     VARCHAR(255)        NOT NULL,
    email_verified    BOOLEAN                  DEFAULT FALSE,

    -- 用户资料
    display_name      VARCHAR(100),
    bio               TEXT,
    avatar_url        VARCHAR(500),
    website_url       VARCHAR(500),
    location          VARCHAR(100),

    -- 状态管理
    is_active         BOOLEAN                  DEFAULT TRUE,
    is_banned         BOOLEAN                  DEFAULT FALSE,
    role              VARCHAR(20)              DEFAULT 'user' CHECK (role IN ('admin', 'editor', 'author', 'user', 'subscriber')),

    -- 时间戳
    created_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login_at     TIMESTAMP WITH TIME ZONE,
    email_verified_at TIMESTAMP WITH TIME ZONE,

    -- 约束
    CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT valid_username CHECK (username ~* '^[a-zA-Z0-9_]{3,50}$')
);

-- ============================================
-- 2. 创建用户社交链接表
-- ============================================
CREATE TABLE IF NOT EXISTS user_social_links
(
    id            SERIAL PRIMARY KEY,
    user_id       INTEGER REFERENCES users (id) ON DELETE CASCADE,
    platform      VARCHAR(50)  NOT NULL,
    url           VARCHAR(500) NOT NULL,
    display_order INTEGER                  DEFAULT 0,
    created_at    TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (user_id, platform)
);

-- ============================================
-- 3. 创建用户设置表
-- ============================================
CREATE TABLE IF NOT EXISTS user_settings
(
    user_id               INTEGER PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,

    -- 通知设置
    email_notifications   BOOLEAN                  DEFAULT TRUE,
    comment_notifications BOOLEAN                  DEFAULT TRUE,
    newsletter_subscribed BOOLEAN                  DEFAULT FALSE,

    -- 隐私设置
    show_email_public     BOOLEAN                  DEFAULT FALSE,
    show_location_public  BOOLEAN                  DEFAULT TRUE,

    -- 显示设置
    posts_per_page        INTEGER                  DEFAULT 10,
    preferred_theme       VARCHAR(20)              DEFAULT 'light' CHECK (preferred_theme IN ('light', 'dark', 'auto')),
    timezone              VARCHAR(50)              DEFAULT 'UTC',

    -- 更新跟踪
    updated_at            TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 4. 创建用户密码重置和验证表
-- ============================================
CREATE TABLE IF NOT EXISTS user_security_tokens
(
    id         SERIAL PRIMARY KEY,
    user_id    INTEGER REFERENCES users (id) ON DELETE CASCADE,
    token_type VARCHAR(20)              NOT NULL CHECK (token_type IN ('password_reset', 'email_verify', 'remember_me')),
    token_hash VARCHAR(255)             NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used       BOOLEAN                  DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 5. 创建用户统计表
-- ============================================
CREATE TABLE IF NOT EXISTS user_statistics
(
    user_id         INTEGER PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    posts_count     INTEGER                  DEFAULT 0,
    comments_count  INTEGER                  DEFAULT 0,
    likes_count     INTEGER                  DEFAULT 0,
    followers_count INTEGER                  DEFAULT 0,
    following_count INTEGER                  DEFAULT 0,

    -- 活跃度统计
    last_post_at    TIMESTAMP WITH TIME ZONE,
    last_comment_at TIMESTAMP WITH TIME ZONE,
    last_login_at   TIMESTAMP WITH TIME ZONE,

    -- 更新跟踪
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 6. 创建用户关注关系表
-- ============================================
CREATE TABLE IF NOT EXISTS user_follows
(
    follower_id  INTEGER REFERENCES users (id) ON DELETE CASCADE,
    following_id INTEGER REFERENCES users (id) ON DELETE CASCADE,
    created_at   TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (follower_id, following_id),
    CHECK (follower_id != following_id)
);

-- ============================================
-- 7. 创建索引（优化查询性能）
-- ============================================

-- 用户表索引
CREATE INDEX IF NOT EXISTS idx_users_username ON users (username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users (role);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users (created_at);

-- 社交链接表索引
CREATE INDEX IF NOT EXISTS idx_social_links_user ON user_social_links (user_id);

-- 安全令牌表索引
CREATE INDEX IF NOT EXISTS idx_security_tokens_user ON user_security_tokens (user_id);
CREATE INDEX IF NOT EXISTS idx_security_tokens_expires ON user_security_tokens (expires_at);
CREATE INDEX IF NOT EXISTS idx_security_tokens_type ON user_security_tokens (token_type);

-- 关注关系表索引
CREATE INDEX IF NOT EXISTS idx_follows_follower ON user_follows (follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON user_follows (following_id);

-- ============================================
-- 8. 创建函数
-- ============================================

-- 自动更新 updated_at 时间戳的函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
    RETURNS TRIGGER AS
$$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 创建用户时初始化相关表的函数
CREATE OR REPLACE FUNCTION create_user_with_defaults(
    p_username VARCHAR(50),
    p_email VARCHAR(255),
    p_password_hash VARCHAR(255)
)
    RETURNS INTEGER AS
$$
DECLARE
    new_user_id INTEGER;
BEGIN
    -- 验证输入
    IF p_username IS NULL OR p_email IS NULL OR p_password_hash IS NULL THEN
        RAISE EXCEPTION '用户名、邮箱和密码哈希不能为空';
    END IF;

    -- 验证用户名格式
    IF NOT (p_username ~* '^[a-zA-Z0-9_]{3,50}$') THEN
        RAISE EXCEPTION '用户名格式无效，只能包含字母、数字和下划线，长度3-50位';
    END IF;

    -- 验证邮箱格式
    IF NOT (p_email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') THEN
        RAISE EXCEPTION '邮箱格式无效';
    END IF;

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

-- 更新用户最后登录时间的函数
CREATE OR REPLACE FUNCTION update_last_login(p_user_id INTEGER)
    RETURNS VOID AS
$$
BEGIN
    -- 更新用户表的最后登录时间
    UPDATE users
    SET last_login_at = CURRENT_TIMESTAMP
    WHERE id = p_user_id;

    -- 更新统计表的最后登录时间
    UPDATE user_statistics
    SET last_login_at = CURRENT_TIMESTAMP,
        updated_at    = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- 更新用户统计的函数
CREATE OR REPLACE FUNCTION update_user_stats(
    p_user_id INTEGER,
    p_posts_change INTEGER DEFAULT 0,
    p_comments_change INTEGER DEFAULT 0,
    p_likes_change INTEGER DEFAULT 0,
    p_followers_change INTEGER DEFAULT 0,
    p_following_change INTEGER DEFAULT 0
)
    RETURNS VOID AS
$$
BEGIN
    UPDATE user_statistics
    SET posts_count     = GREATEST(0, posts_count + p_posts_change),
        comments_count  = GREATEST(0, comments_count + p_comments_change),
        likes_count     = GREATEST(0, likes_count + p_likes_change),
        followers_count = GREATEST(0, followers_count + p_followers_change),
        following_count = GREATEST(0, following_count + p_following_change),
        updated_at      = CURRENT_TIMESTAMP
    WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 9. 创建触发器
-- ============================================

-- 为用户表创建触发器（自动更新 updated_at）
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE
    ON users
    FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 为用户设置表创建触发器
DROP TRIGGER IF EXISTS update_user_settings_updated_at ON user_settings;
CREATE TRIGGER update_user_settings_updated_at
    BEFORE UPDATE
    ON user_settings
    FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 为用户统计表创建触发器
DROP TRIGGER IF EXISTS update_user_statistics_updated_at ON user_statistics;
CREATE TRIGGER update_user_statistics_updated_at
    BEFORE UPDATE
    ON user_statistics
    FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 10. 创建视图
-- ============================================

-- 用户信息视图
CREATE OR REPLACE VIEW v_user_profiles AS
SELECT u.id,
       u.username,
       u.email,
       u.display_name,
       u.bio,
       u.avatar_url,
       u.website_url,
       u.location,
       u.role,
       u.is_active,
       u.is_banned,
       u.email_verified,
       u.created_at,
       u.updated_at,
       u.last_login_at,
       u.email_verified_at,
       us.email_notifications,
       us.comment_notifications,
       us.newsletter_subscribed,
       us.show_email_public,
       us.show_location_public,
       us.posts_per_page,
       us.preferred_theme,
       us.timezone,
       ust.posts_count,
       ust.comments_count,
       ust.likes_count,
       ust.followers_count,
       ust.following_count,
       ust.last_post_at,
       ust.last_comment_at
FROM users u
         LEFT JOIN user_settings us ON u.id = us.user_id
         LEFT JOIN user_statistics ust ON u.id = ust.user_id
WHERE u.is_active = TRUE;

-- 用户社交链接视图
CREATE OR REPLACE VIEW v_user_social_links AS
SELECT usl.*,
       u.username,
       u.display_name
FROM user_social_links usl
         JOIN users u ON usl.user_id = u.id
ORDER BY usl.user_id, usl.display_order;

-- 活跃用户视图
CREATE OR REPLACE VIEW v_active_users AS
SELECT u.id,
       u.username,
       u.display_name,
       u.avatar_url,
       u.role,
       u.created_at,
       u.last_login_at,
       ust.posts_count,
       ust.comments_count,
       ust.followers_count,
       CASE
           WHEN u.last_login_at > CURRENT_TIMESTAMP - INTERVAL '7 days' THEN 'high'
           WHEN u.last_login_at > CURRENT_TIMESTAMP - INTERVAL '30 days' THEN 'medium'
           ELSE 'low'
           END as activity_level
FROM users u
         LEFT JOIN user_statistics ust ON u.id = ust.user_id
WHERE u.is_active = TRUE
  AND u.is_banned = FALSE
ORDER BY ust.posts_count DESC, ust.comments_count DESC;

-- ============================================
-- 11. 创建默认管理员用户（可选）
-- 注意：在实际生产环境中，建议通过应用注册，这里仅为演示
-- ============================================
-- 如果您需要创建默认管理员，请取消注释下面的代码，并设置您的密码哈希
/*
DO $$
DECLARE
    admin_id INTEGER;
BEGIN
    -- 创建管理员用户（密码为 'admin123' 的bcrypt哈希，请在生产环境中更改）
    SELECT create_user_with_defaults(
        'admin',
        'admin@example.com',
        '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW'
    ) INTO admin_id;

    -- 更新为管理员角色并验证邮箱
    UPDATE users
    SET role = 'admin',
        email_verified = TRUE,
        email_verified_at = CURRENT_TIMESTAMP,
        display_name = '系统管理员'
    WHERE id = admin_id;

    RAISE NOTICE '已创建默认管理员账户: admin (密码: admin123) - 请立即更改密码！';
END $$;
*/

-- ============================================
-- 12. 提交所有更改
-- ============================================
COMMIT;

-- ============================================
-- 完成信息
-- ============================================
DO
$$
    BEGIN
        RAISE NOTICE '============================================';
        RAISE NOTICE '用户表结构创建完成！';
        RAISE NOTICE '已创建以下表:';
        RAISE NOTICE '1. users (用户主表)';
        RAISE NOTICE '2. user_social_links (用户社交链接表)';
        RAISE NOTICE '3. user_settings (用户设置表)';
        RAISE NOTICE '4. user_security_tokens (用户安全令牌表)';
        RAISE NOTICE '5. user_statistics (用户统计表)';
        RAISE NOTICE '6. user_follows (用户关注关系表)';
        RAISE NOTICE '';
        RAISE NOTICE '已创建以下视图:';
        RAISE NOTICE '1. v_user_profiles (用户资料视图)';
        RAISE NOTICE '2. v_user_social_links (用户社交链接视图)';
        RAISE NOTICE '3. v_active_users (活跃用户视图)';
        RAISE NOTICE '';
        RAISE NOTICE '下一步:';
        RAISE NOTICE '1. 运行应用创建第一个用户';
        RAISE NOTICE '2. 或取消注释文件中的默认管理员创建代码';
        RAISE NOTICE '============================================';
    END
$$;
