-- 创建用户表（包含所有字段）
CREATE TABLE users
(
    id            SERIAL PRIMARY KEY,                  -- 主键，自增长
    username      VARCHAR(50) UNIQUE  NOT NULL,        -- 用户名，唯一且不能为空
    email         VARCHAR(100) UNIQUE NOT NULL,        -- 邮箱，唯一且不能为空
    password_hash VARCHAR(255)        NOT NULL,        -- 密码哈希值
    avatar_url    TEXT,                                -- 用户头像URL地址
    bio           TEXT,                                -- 用户个人简介
    last_login    TIMESTAMP,                           -- 最后登录时间
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- 创建时间
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- 更新时间
);
-- 添加表注释
COMMENT ON TABLE users IS '用户表';
-- 添加字段注释
COMMENT ON COLUMN users.id IS '用户ID，主键';
COMMENT ON COLUMN users.username IS '用户名，唯一标识';
COMMENT ON COLUMN users.email IS '用户邮箱，用于登录和通知';
COMMENT ON COLUMN users.password_hash IS '密码哈希值（不存储明文密码）';
COMMENT ON COLUMN users.avatar_url IS '用户头像URL地址，存储头像图片的网络链接';
COMMENT ON COLUMN users.bio IS '用户个人简介或描述信息';
COMMENT ON COLUMN users.last_login IS '用户最后登录时间，用于记录用户活跃度';
COMMENT ON COLUMN users.created_at IS '用户创建时间';
COMMENT ON COLUMN users.updated_at IS '用户信息更新时间';
-- 创建索引以优化查询性能
CREATE INDEX idx_users_username ON users (username);
CREATE INDEX idx_users_email ON users (email);
CREATE INDEX idx_users_created_at ON users (created_at);
-- 创建更新时间自动更新的触发器函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
    RETURNS TRIGGER AS
$$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';
-- 创建触发器
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE
    ON users
    FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


-- 创建文章表
CREATE TABLE posts
(
    id           SERIAL PRIMARY KEY,                    -- 文章ID，主键
    title        VARCHAR(200)        NOT NULL,          -- 文章标题
    slug         VARCHAR(200) UNIQUE NOT NULL,          -- URL友好标识，唯一
    content      TEXT                NOT NULL,          -- 文章内容
    excerpt      TEXT,                                  -- 文章摘要
    author_id    INTEGER             NOT NULL,          -- 作者ID，外键关联用户表
    status       VARCHAR(20) DEFAULT 'draft',           -- 文章状态：draft, published, archived
    published_at TIMESTAMP,                             -- 发布时间（如果已发布）
    created_at   TIMESTAMP   DEFAULT CURRENT_TIMESTAMP, -- 创建时间
    updated_at   TIMESTAMP   DEFAULT CURRENT_TIMESTAMP, -- 更新时间

    -- 外键约束
    CONSTRAINT fk_posts_author
        FOREIGN KEY (author_id)
            REFERENCES users (id)
            ON DELETE CASCADE
);
-- 添加注释
COMMENT ON TABLE posts IS '文章表';
COMMENT ON COLUMN posts.id IS '文章ID，主键';
COMMENT ON COLUMN posts.title IS '文章标题';
COMMENT ON COLUMN posts.slug IS 'URL友好标识，用于生成文章URL，必须唯一';
COMMENT ON COLUMN posts.content IS '文章完整内容';
COMMENT ON COLUMN posts.excerpt IS '文章摘要，可空';
COMMENT ON COLUMN posts.author_id IS '作者ID，关联users表的id';
COMMENT ON COLUMN posts.status IS '文章状态：draft(草稿)、published(已发布)、archived(归档)';
COMMENT ON COLUMN posts.published_at IS '文章发布时间，只有当status=published时有值';
COMMENT ON COLUMN posts.created_at IS '文章创建时间';
COMMENT ON COLUMN posts.updated_at IS '文章最后更新时间';
-- 创建索引以优化查询性能
CREATE INDEX idx_posts_author_id ON posts (author_id);
CREATE INDEX idx_posts_status ON posts (status);
CREATE INDEX idx_posts_published_at ON posts (published_at);
CREATE INDEX idx_posts_created_at ON posts (created_at);
CREATE INDEX idx_posts_slug ON posts (slug);
-- 创建复合索引，用于常见的查询模式
CREATE INDEX idx_posts_status_published_at ON posts (status, published_at);
CREATE INDEX idx_posts_author_status ON posts (author_id, status);
-- 创建更新时间自动更新的触发器
CREATE TRIGGER update_posts_updated_at
    BEFORE UPDATE
    ON posts
    FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
-- 确保 published_at 只在文章发布时才有值
ALTER TABLE posts
    ADD CONSTRAINT check_published_at
        CHECK (
            (status = 'published' AND published_at IS NOT NULL) OR
            (status != 'published' AND published_at IS NULL)
            );


-- 创建分类表
CREATE TABLE categories
(
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(50)        NOT NULL,
    slug        VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    parent_id   INTEGER, -- 父分类ID，用于多级分类

    CONSTRAINT fk_categories_parent
        FOREIGN KEY (parent_id)
            REFERENCES categories (id)
            ON DELETE CASCADE
);
COMMENT ON TABLE categories IS '文章分类表';
COMMENT ON COLUMN categories.name IS '分类名称';
COMMENT ON COLUMN categories.slug IS 'URL友好标识';
COMMENT ON COLUMN categories.description IS '分类描述';
COMMENT ON COLUMN categories.parent_id IS '父分类ID，支持多级分类';


-- 创建评论表
CREATE TABLE comments
(
    id           SERIAL PRIMARY KEY,            -- 评论ID
    post_id      INTEGER NOT NULL,              -- 文章ID
    user_id      INTEGER,                       -- 用户ID（匿名评论可为空）
    parent_id    INTEGER,                       -- 父评论ID（用于回复）
    author_name  VARCHAR(100),                  -- 作者姓名（匿名评论用）
    author_email VARCHAR(100),                  -- 作者邮箱（匿名评论用）
    content      TEXT    NOT NULL,              -- 评论内容
    status       VARCHAR(20) DEFAULT 'pending', -- 状态：pending, approved, spam
    created_at   TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,

    -- 外键约束
    CONSTRAINT fk_comments_post
        FOREIGN KEY (post_id)
            REFERENCES posts (id)
            ON DELETE CASCADE,

    CONSTRAINT fk_comments_user
        FOREIGN KEY (user_id)
            REFERENCES users (id)
            ON DELETE SET NULL,

    CONSTRAINT fk_comments_parent
        FOREIGN KEY (parent_id)
            REFERENCES comments (id)
            ON DELETE CASCADE
);
COMMENT ON TABLE comments IS '文章评论表';
COMMENT ON COLUMN comments.id IS '评论ID';
COMMENT ON COLUMN comments.post_id IS '关联的文章ID';
COMMENT ON COLUMN comments.user_id IS '评论用户ID，匿名评论为空';
COMMENT ON COLUMN comments.parent_id IS '父评论ID，用于嵌套回复';
COMMENT ON COLUMN comments.author_name IS '评论者姓名（匿名评论时使用）';
COMMENT ON COLUMN comments.author_email IS '评论者邮箱（匿名评论时使用）';
COMMENT ON COLUMN comments.content IS '评论内容';
COMMENT ON COLUMN comments.status IS '评论状态：pending(待审核)、approved(已批准)、spam(垃圾评论)';


-- 创建标签表
CREATE TABLE tags
(
    id   SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    slug VARCHAR(50) UNIQUE NOT NULL
);
COMMENT ON TABLE tags IS '文章标签表';
COMMENT ON COLUMN tags.name IS '标签名称';
COMMENT ON COLUMN tags.slug IS 'URL友好标识';
