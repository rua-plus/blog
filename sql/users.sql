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

-- ============================================
-- 表注释
-- ============================================

-- 用户表注释
COMMENT ON TABLE users IS '存储用户基本信息的核心表，包含身份验证和基础资料';

-- 用户社交链接表注释
COMMENT ON TABLE user_social_links IS '存储用户在各个社交平台的链接信息';

-- 用户设置表注释
COMMENT ON TABLE user_settings IS '存储用户的个性化设置和偏好配置';

-- 用户安全令牌表注释
COMMENT ON TABLE user_security_tokens IS '存储密码重置、邮箱验证等安全相关的令牌';

-- 用户统计表注释
COMMENT ON TABLE user_statistics IS '存储用户的活跃度统计和内容计数数据';

-- 用户关注关系表注释
COMMENT ON TABLE user_follows IS '存储用户之间的关注关系（粉丝系统）';

-- ============================================
-- 视图注释
-- ============================================

COMMENT ON VIEW v_user_profiles IS '用户完整资料视图，整合用户主表、设置和统计信息';
COMMENT ON VIEW v_user_social_links IS '用户社交链接视图，包含用户基本信息';
COMMENT ON VIEW v_active_users IS '活跃用户视图，用于展示高活跃度用户';

-- ============================================
-- 函数注释
-- ============================================

COMMENT ON FUNCTION update_updated_at_column() IS '自动更新updated_at字段的触发器函数';
COMMENT ON FUNCTION create_user_with_defaults(VARCHAR, VARCHAR, VARCHAR) IS '创建用户并初始化相关记录的封装函数';
COMMENT ON FUNCTION update_last_login(INTEGER) IS '更新用户最后登录时间的函数';
COMMENT ON FUNCTION update_user_stats(INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER) IS '更新用户统计数据的函数';

-- ============================================
-- 用户表列注释
-- ============================================

-- 主键和身份信息
COMMENT ON COLUMN users.id IS '用户唯一标识符，自增主键';
COMMENT ON COLUMN users.username IS '用户名，用于登录和显示，唯一且不可重复';
COMMENT ON COLUMN users.email IS '用户邮箱地址，用于登录和通知，唯一且不可重复';
COMMENT ON COLUMN users.password_hash IS '密码的哈希值，存储加密后的密码';
COMMENT ON COLUMN users.email_verified IS '邮箱是否已验证，未验证邮箱用户功能受限';

-- 用户资料
COMMENT ON COLUMN users.display_name IS '用户显示名称，可自由设置，不同于用户名';
COMMENT ON COLUMN users.bio IS '用户个人简介，支持富文本';
COMMENT ON COLUMN users.avatar_url IS '用户头像URL地址，存储外部链接或相对路径';
COMMENT ON COLUMN users.website_url IS '用户个人网站或博客地址';
COMMENT ON COLUMN users.location IS '用户所在地理位置';

-- 状态管理
COMMENT ON COLUMN users.is_active IS '账户是否激活，false表示账户被停用';
COMMENT ON COLUMN users.is_banned IS '账户是否被封禁，true表示用户因违规被封';
COMMENT ON COLUMN users.role IS '用户角色：admin-管理员, editor-编辑, author-作者, user-普通用户, subscriber-订阅者';

-- 时间戳
COMMENT ON COLUMN users.created_at IS '账户创建时间，自动设置';
COMMENT ON COLUMN users.updated_at IS '账户最后更新时间，通过触发器自动更新';
COMMENT ON COLUMN users.last_login_at IS '用户最后登录时间';
COMMENT ON COLUMN users.email_verified_at IS '邮箱验证通过的时间';

-- ============================================
-- 用户社交链接表列注释
-- ============================================

COMMENT ON COLUMN user_social_links.id IS '社交链接唯一标识符，自增主键';
COMMENT ON COLUMN user_social_links.user_id IS '外键，关联到users表的用户ID';
COMMENT ON COLUMN user_social_links.platform IS '社交平台名称，如github、twitter、weibo等';
COMMENT ON COLUMN user_social_links.url IS '社交平台个人主页的完整URL';
COMMENT ON COLUMN user_social_links.display_order IS '显示顺序，数值小的排在前面';
COMMENT ON COLUMN user_social_links.created_at IS '记录创建时间';

-- ============================================
-- 用户设置表列注释
-- ============================================

COMMENT ON COLUMN user_settings.user_id IS '外键，关联到users表的用户ID，也是主键';
COMMENT ON COLUMN user_settings.email_notifications IS '是否接收邮件通知，true为接收';
COMMENT ON COLUMN user_settings.comment_notifications IS '是否接收评论通知，true为接收';
COMMENT ON COLUMN user_settings.newsletter_subscribed IS '是否订阅新闻简报，true为订阅';
COMMENT ON COLUMN user_settings.show_email_public IS '是否公开显示邮箱地址';
COMMENT ON COLUMN user_settings.show_location_public IS '是否公开显示地理位置';
COMMENT ON COLUMN user_settings.posts_per_page IS '每页显示的文章数量，用于分页设置';
COMMENT ON COLUMN user_settings.preferred_theme IS '偏好主题：light-浅色, dark-深色, auto-自动';
COMMENT ON COLUMN user_settings.timezone IS '用户设置的时区，影响时间显示';
COMMENT ON COLUMN user_settings.updated_at IS '设置最后更新时间，通过触发器自动更新';

-- ============================================
-- 用户安全令牌表列注释
-- ============================================

COMMENT ON COLUMN user_security_tokens.id IS '令牌唯一标识符，自增主键';
COMMENT ON COLUMN user_security_tokens.user_id IS '外键，关联到users表的用户ID';
COMMENT ON COLUMN user_security_tokens.token_type IS '令牌类型：password_reset-密码重置, email_verify-邮箱验证, remember_me-记住登录';
COMMENT ON COLUMN user_security_tokens.token_hash IS '令牌的哈希值，存储加密后的令牌';
COMMENT ON COLUMN user_security_tokens.expires_at IS '令牌过期时间，过期后无效';
COMMENT ON COLUMN user_security_tokens.used IS '令牌是否已使用，使用后不能重复使用';
COMMENT ON COLUMN user_security_tokens.created_at IS '令牌创建时间';

-- ============================================
-- 用户统计表列注释
-- ============================================

COMMENT ON COLUMN user_statistics.user_id IS '外键，关联到users表的用户ID，也是主键';
COMMENT ON COLUMN user_statistics.posts_count IS '用户发布的文章总数';
COMMENT ON COLUMN user_statistics.comments_count IS '用户发表的评论总数';
COMMENT ON COLUMN user_statistics.likes_count IS '用户收到的点赞总数';
COMMENT ON COLUMN user_statistics.followers_count IS '用户的粉丝总数（关注者数量）';
COMMENT ON COLUMN user_statistics.following_count IS '用户关注的其他用户总数';
COMMENT ON COLUMN user_statistics.last_post_at IS '用户最后发布文章的时间';
COMMENT ON COLUMN user_statistics.last_comment_at IS '用户最后发表评论的时间';
COMMENT ON COLUMN user_statistics.last_login_at IS '用户最后登录时间（与users表同步）';
COMMENT ON COLUMN user_statistics.updated_at IS '统计数据最后更新时间，通过触发器自动更新';

-- ============================================
-- 用户关注关系表列注释
-- ============================================

COMMENT ON COLUMN user_follows.follower_id IS '关注者用户ID，外键关联users表';
COMMENT ON COLUMN user_follows.following_id IS '被关注者用户ID，外键关联users表';
COMMENT ON COLUMN user_follows.created_at IS '关注关系建立时间';

-- ============================================
-- 索引注释
-- ============================================

COMMENT ON INDEX idx_users_username IS '用户名字段索引，加速用户名查询';
COMMENT ON INDEX idx_users_email IS '邮箱字段索引，加速邮箱查询';
COMMENT ON INDEX idx_users_role IS '角色字段索引，加速按角色筛选';
COMMENT ON INDEX idx_users_created_at IS '创建时间索引，加速按时间范围查询';

COMMENT ON INDEX idx_social_links_user IS '用户社交链接的用户ID索引，加速按用户查询';

COMMENT ON INDEX idx_security_tokens_user IS '安全令牌的用户ID索引，加速按用户查询';
COMMENT ON INDEX idx_security_tokens_expires IS '令牌过期时间索引，加速清理过期令牌';
COMMENT ON INDEX idx_security_tokens_type IS '令牌类型索引，加速按类型查询';

COMMENT ON INDEX idx_follows_follower IS '关注者ID索引，加速查询用户的关注列表';
COMMENT ON INDEX idx_follows_following IS '被关注者ID索引，加速查询用户的粉丝列表';

-- ============================================
-- 触发器注释
-- ============================================

COMMENT ON TRIGGER update_users_updated_at ON users IS '在更新users表记录时自动更新updated_at字段';
COMMENT ON TRIGGER update_user_settings_updated_at ON user_settings IS '在更新user_settings表记录时自动更新updated_at字段';
COMMENT ON TRIGGER update_user_statistics_updated_at ON user_statistics IS '在更新user_statistics表记录时自动更新updated_at字段';

-- ============================================
-- 约束注释
-- ============================================

COMMENT ON CONSTRAINT valid_email ON users IS '邮箱格式验证约束，确保邮箱格式正确';
COMMENT ON CONSTRAINT valid_username ON users IS '用户名格式验证约束，只允许字母、数字和下划线';
COMMENT ON CONSTRAINT user_follows_pkey ON user_follows IS '主键约束，确保关注关系唯一';
COMMENT ON CONSTRAINT user_follows_check ON user_follows IS '检查约束，防止用户关注自己';

-- ============================================
-- 完成信息
-- ============================================
DO
$$
    BEGIN
        RAISE NOTICE '============================================';
        RAISE NOTICE '所有表和列注释已成功添加！';
        RAISE NOTICE '现在可以使用以下命令查看表注释：';
        RAISE NOTICE '-- 查看表注释：\dt+ users';
        RAISE NOTICE '-- 查看列注释：\d+ users';
        RAISE NOTICE '-- 查看所有表：\dt+';
        RAISE NOTICE '============================================';
    END
$$;