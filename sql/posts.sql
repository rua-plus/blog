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
