-- ============================================
-- 博客系统文章表结构
-- 版本：1.0
-- 创建日期：2024
-- 说明：创建所有文章相关表
-- 修正：修复了视图中的 GROUP BY 问题
-- ============================================

BEGIN;

-- ============================================
-- 1. 创建文章主表
-- ============================================
CREATE TABLE IF NOT EXISTS posts
(
    -- 主键
    id                   SERIAL PRIMARY KEY,

    -- 基础信息
    title                VARCHAR(200)        NOT NULL,
    slug                 VARCHAR(250) UNIQUE NOT NULL,
    excerpt              TEXT,
    content              TEXT                NOT NULL,

    -- 作者和所有权
    author_id            INTEGER             NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    editor_id            INTEGER             REFERENCES users (id) ON DELETE SET NULL,

    -- 分类和标签（外键将在后续表中定义）
    category_id          INTEGER, -- 将在创建分类表后添加外键约束
    status               VARCHAR(20)              DEFAULT 'draft' CHECK (status IN
                                                                         ('draft', 'pending', 'published', 'private',
                                                                          'trash', 'scheduled')),

    -- 元信息
    is_featured          BOOLEAN                  DEFAULT FALSE,
    is_pinned            BOOLEAN                  DEFAULT FALSE,
    allow_comments       BOOLEAN                  DEFAULT TRUE,
    comment_count        INTEGER                  DEFAULT 0,
    view_count           INTEGER                  DEFAULT 0,
    like_count           INTEGER                  DEFAULT 0,
    share_count          INTEGER                  DEFAULT 0,
    reading_time_minutes INTEGER                  DEFAULT 0,

    -- SEO 优化
    meta_title           VARCHAR(200),
    meta_description     TEXT,
    meta_keywords        VARCHAR(500),
    canonical_url        VARCHAR(500),

    -- 媒体
    featured_image_url   VARCHAR(500),
    featured_image_alt   VARCHAR(200),

    -- 时间管理
    published_at         TIMESTAMP WITH TIME ZONE,
    scheduled_at         TIMESTAMP WITH TIME ZONE,
    created_at           TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at           TIMESTAMP WITH TIME ZONE,

    -- 版本控制
    version              INTEGER                  DEFAULT 1,
    parent_post_id       INTEGER             REFERENCES posts (id) ON DELETE SET NULL,

    -- 约束和索引
    CONSTRAINT posts_slug_format CHECK (slug ~* '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
    CONSTRAINT posts_scheduled_check CHECK (
        (status != 'scheduled' AND scheduled_at IS NULL) OR
        (status = 'scheduled' AND scheduled_at IS NOT NULL AND scheduled_at > created_at)
        ),
    CONSTRAINT posts_published_check CHECK (
        (status != 'published' AND published_at IS NULL) OR
        (status = 'published' AND published_at IS NOT NULL)
        )
);

-- ============================================
-- 2. 创建文章分类表
-- ============================================
CREATE TABLE IF NOT EXISTS categories
(
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100)        NOT NULL,
    slug        VARCHAR(120) UNIQUE NOT NULL,
    description TEXT,
    parent_id   INTEGER REFERENCES categories (id) ON DELETE CASCADE,
    sort_order  INTEGER                  DEFAULT 0,
    post_count  INTEGER                  DEFAULT 0,
    is_active   BOOLEAN                  DEFAULT TRUE,
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT categories_slug_format CHECK (slug ~* '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

-- 现在为文章表添加分类外键约束
ALTER TABLE posts
    ADD CONSTRAINT fk_posts_category
        FOREIGN KEY (category_id)
            REFERENCES categories (id)
            ON DELETE SET NULL;

-- ============================================
-- 3. 创建标签表
-- ============================================
CREATE TABLE IF NOT EXISTS tags
(
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(50)        NOT NULL,
    slug        VARCHAR(70) UNIQUE NOT NULL,
    description TEXT,
    post_count  INTEGER                  DEFAULT 0,
    is_active   BOOLEAN                  DEFAULT TRUE,
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT tags_slug_format CHECK (slug ~* '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

-- ============================================
-- 4. 创建文章-标签关联表
-- ============================================
CREATE TABLE IF NOT EXISTS post_tags
(
    post_id    INTEGER NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    tag_id     INTEGER NOT NULL REFERENCES tags (id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (post_id, tag_id)
);

-- ============================================
-- 5. 创建文章草稿/版本表
-- ============================================
CREATE TABLE IF NOT EXISTS post_revisions
(
    id              SERIAL PRIMARY KEY,
    post_id         INTEGER      NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    title           VARCHAR(200) NOT NULL,
    content         TEXT         NOT NULL,
    excerpt         TEXT,
    author_id       INTEGER      NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    reason          VARCHAR(200),
    revision_number INTEGER      NOT NULL,
    is_autosave     BOOLEAN                  DEFAULT FALSE,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- 6. 创建文章元数据表（用于扩展字段）
-- ============================================
CREATE TABLE IF NOT EXISTS post_meta
(
    id         SERIAL PRIMARY KEY,
    post_id    INTEGER      NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    meta_key   VARCHAR(100) NOT NULL,
    meta_value TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (post_id, meta_key)
);

-- ============================================
-- 7. 创建文章系列/系列表
-- ============================================
CREATE TABLE IF NOT EXISTS series
(
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(150)        NOT NULL,
    slug        VARCHAR(170) UNIQUE NOT NULL,
    description TEXT,
    author_id   INTEGER             NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    post_count  INTEGER                  DEFAULT 0,
    sort_order  INTEGER                  DEFAULT 0,
    is_active   BOOLEAN                  DEFAULT TRUE,
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT series_slug_format CHECK (slug ~* '^[a-z0-9]+(?:-[a-z0-9]+)*$')
);

CREATE TABLE IF NOT EXISTS post_series
(
    post_id        INTEGER NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    series_id      INTEGER NOT NULL REFERENCES series (id) ON DELETE CASCADE,
    episode_number INTEGER NOT NULL,
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (post_id, series_id),
    UNIQUE (series_id, episode_number)
);

-- ============================================
-- 8. 创建相关文章关联表
-- ============================================
CREATE TABLE IF NOT EXISTS related_posts
(
    post_id         INTEGER NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    related_post_id INTEGER NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
    relevance_score FLOAT                    DEFAULT 1.0,
    is_manual       BOOLEAN                  DEFAULT FALSE,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (post_id, related_post_id),
    CHECK (post_id != related_post_id)
);

-- ============================================
-- 9. 创建索引（优化查询性能）
-- ============================================

-- 文章表索引
CREATE INDEX IF NOT EXISTS idx_posts_author_id ON posts (author_id);
CREATE INDEX IF NOT EXISTS idx_posts_status ON posts (status);
CREATE INDEX IF NOT EXISTS idx_posts_category_id ON posts (category_id);
CREATE INDEX IF NOT EXISTS idx_posts_published_at ON posts (published_at);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON posts (created_at);
CREATE INDEX IF NOT EXISTS idx_posts_slug ON posts (slug);
CREATE INDEX IF NOT EXISTS idx_posts_featured ON posts (is_featured) WHERE is_featured = TRUE;
CREATE INDEX IF NOT EXISTS idx_posts_pinned ON posts (is_pinned) WHERE is_pinned = TRUE;

-- 复合索引
CREATE INDEX IF NOT EXISTS idx_posts_status_published ON posts (status, published_at);
CREATE INDEX IF NOT EXISTS idx_posts_author_status ON posts (author_id, status);
CREATE INDEX IF NOT EXISTS idx_posts_category_status ON posts (category_id, status);

-- 分类表索引
CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON categories (parent_id);
CREATE INDEX IF NOT EXISTS idx_categories_slug ON categories (slug);
CREATE INDEX IF NOT EXISTS idx_categories_active ON categories (is_active) WHERE is_active = TRUE;

-- 标签表索引
CREATE INDEX IF NOT EXISTS idx_tags_slug ON tags (slug);
CREATE INDEX IF NOT EXISTS idx_tags_active ON tags (is_active) WHERE is_active = TRUE;

-- 文章-标签关联表索引
CREATE INDEX IF NOT EXISTS idx_post_tags_tag_id ON post_tags (tag_id);
CREATE INDEX IF NOT EXISTS idx_post_tags_post_id ON post_tags (post_id);

-- 文章版本表索引
CREATE INDEX IF NOT EXISTS idx_post_revisions_post_id ON post_revisions (post_id);
CREATE INDEX IF NOT EXISTS idx_post_revisions_created_at ON post_revisions (created_at);
CREATE INDEX IF NOT EXISTS idx_post_revisions_author_id ON post_revisions (author_id);

-- 文章元数据表索引
CREATE INDEX IF NOT EXISTS idx_post_meta_post_id ON post_meta (post_id);
CREATE INDEX IF NOT EXISTS idx_post_meta_key ON post_meta (meta_key);

-- 系列表索引
CREATE INDEX IF NOT EXISTS idx_series_author_id ON series (author_id);
CREATE INDEX IF NOT EXISTS idx_series_slug ON series (slug);

-- 相关文章索引
CREATE INDEX IF NOT EXISTS idx_related_posts_related_id ON related_posts (related_post_id);

-- ============================================
-- 10. 创建函数
-- ============================================

-- 自动更新 updated_at 时间戳的函数（如果之前没有创建）
CREATE OR REPLACE FUNCTION update_updated_at_column()
    RETURNS TRIGGER AS
$$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 计算文章阅读时间的函数
CREATE OR REPLACE FUNCTION calculate_reading_time(content_text TEXT)
    RETURNS INTEGER AS
$$
DECLARE
    words_per_minute INTEGER := 200; -- 平均阅读速度
    word_count       INTEGER;
    reading_time     INTEGER;
BEGIN
    -- 估算字数（按空格分割）
    word_count := array_length(regexp_split_to_array(trim(content_text), '\s+'), 1);

    -- 计算阅读时间（分钟）
    reading_time := CEIL(word_count::FLOAT / words_per_minute);

    -- 确保至少1分钟
    RETURN GREATEST(reading_time, 1);
END;
$$ LANGUAGE plpgsql;

-- 生成唯一 slug 的函数
CREATE OR REPLACE FUNCTION generate_unique_slug(base_slug VARCHAR, table_name VARCHAR, id_column VARCHAR,
                                                id_value INTEGER DEFAULT NULL)
    RETURNS VARCHAR AS
$$
DECLARE
    slug          VARCHAR := lower(regexp_replace(base_slug, '[^a-zA-Z0-9]+', '-', 'g'));
    original_slug VARCHAR := slug;
    counter       INTEGER := 1;
    exists        BOOLEAN;
BEGIN
    -- 移除首尾的连字符
    slug := regexp_replace(slug, '^-|-$', '', 'g');

    -- 检查是否已存在
    EXECUTE format(
            'SELECT EXISTS(SELECT 1 FROM %I WHERE %I = $1 AND ($2::int IS NULL OR id != $2))',
            table_name, id_column
            ) INTO exists USING slug, id_value;

    -- 如果已存在，添加数字后缀
    WHILE exists
        LOOP
            slug := original_slug || '-' || counter;
            counter := counter + 1;

            EXECUTE format(
                    'SELECT EXISTS(SELECT 1 FROM %I WHERE %I = $1 AND ($2::int IS NULL OR id != $2))',
                    table_name, id_column
                    ) INTO exists USING slug, id_value;
        END LOOP;

    RETURN slug;
END;
$$ LANGUAGE plpgsql;

-- 更新文章统计的函数
CREATE OR REPLACE FUNCTION update_post_stats(
    p_post_id INTEGER,
    p_view_change INTEGER DEFAULT 0,
    p_like_change INTEGER DEFAULT 0,
    p_comment_change INTEGER DEFAULT 0,
    p_share_change INTEGER DEFAULT 0
)
    RETURNS VOID AS
$$
BEGIN
    UPDATE posts
    SET view_count    = GREATEST(0, view_count + p_view_change),
        like_count    = GREATEST(0, like_count + p_like_change),
        comment_count = GREATEST(0, comment_count + p_comment_change),
        share_count   = GREATEST(0, share_count + p_share_change),
        updated_at    = CURRENT_TIMESTAMP
    WHERE id = p_post_id;
END;
$$ LANGUAGE plpgsql;

-- 发布文章的函数
CREATE OR REPLACE FUNCTION publish_post(
    p_post_id INTEGER,
    p_publish_time TIMESTAMP WITH TIME ZONE DEFAULT NULL
)
    RETURNS VOID AS
$$
DECLARE
    v_publish_time TIMESTAMP WITH TIME ZONE;
BEGIN
    -- 确定发布时间
    IF p_publish_time IS NULL THEN
        v_publish_time := CURRENT_TIMESTAMP;
    ELSE
        v_publish_time := p_publish_time;
    END IF;

    -- 更新文章状态
    UPDATE posts
    SET status       = 'published',
        published_at = v_publish_time,
        scheduled_at = NULL,
        updated_at   = CURRENT_TIMESTAMP
    WHERE id = p_post_id;

    -- 更新作者的文章计数
    UPDATE user_statistics
    SET posts_count  = posts_count + 1,
        last_post_at = v_publish_time,
        updated_at   = CURRENT_TIMESTAMP
    WHERE user_id = (SELECT author_id FROM posts WHERE id = p_post_id);

    -- 更新分类的文章计数
    UPDATE categories
    SET post_count = post_count + 1,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = (SELECT category_id FROM posts WHERE id = p_post_id);

    -- 更新标签的文章计数
    UPDATE tags t
    SET post_count = post_count + 1
    FROM post_tags pt
    WHERE pt.post_id = p_post_id
      AND pt.tag_id = t.id;
END;
$$ LANGUAGE plpgsql;

-- 获取相关文章的函数
CREATE OR REPLACE FUNCTION get_related_posts(
    p_post_id INTEGER,
    p_limit INTEGER DEFAULT 5
)
    RETURNS TABLE
            (
                related_id              INTEGER,
                related_title           VARCHAR(200),
                related_slug            VARCHAR(250),
                related_excerpt         TEXT,
                related_author_id       INTEGER,
                related_published_at    TIMESTAMP WITH TIME ZONE,
                related_view_count      INTEGER,
                related_relevance_score FLOAT
            )
AS
$$
BEGIN
    RETURN QUERY
        SELECT p.id,
               p.title,
               p.slug,
               p.excerpt,
               p.author_id,
               p.published_at,
               p.view_count,
               rp.relevance_score
        FROM related_posts rp
                 JOIN posts p ON rp.related_post_id = p.id
        WHERE rp.post_id = p_post_id
          AND p.status = 'published'
        ORDER BY rp.relevance_score DESC, p.published_at DESC
        LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- 搜索文章的函数（修复参数名冲突问题）
CREATE OR REPLACE FUNCTION search_posts(
    p_search_query TEXT,
    p_category_id INTEGER DEFAULT NULL,
    p_author_id INTEGER DEFAULT NULL,
    p_tag_ids INTEGER[] DEFAULT NULL,
    p_status_filter VARCHAR DEFAULT 'published',
    p_limit_count INTEGER DEFAULT 20,
    p_offset_count INTEGER DEFAULT 0
)
    RETURNS TABLE
            (
                post_id           INTEGER,
                post_title        VARCHAR(200),
                post_slug         VARCHAR(250),
                post_excerpt      TEXT,
                post_author_id    INTEGER,
                post_category_id  INTEGER,
                post_published_at TIMESTAMP WITH TIME ZONE,
                post_view_count   INTEGER,
                post_relevance    FLOAT
            )
AS
$$
BEGIN
    RETURN QUERY
        SELECT p.id,
               p.title,
               p.slug,
               p.excerpt,
               p.author_id,
               p.category_id,
               p.published_at,
               p.view_count,
               ts_rank(
                       setweight(to_tsvector('simple', p.title), 'A') ||
                       setweight(to_tsvector('simple', coalesce(p.excerpt, '')), 'B') ||
                       setweight(to_tsvector('simple', p.content), 'C'),
                       plainto_tsquery('simple', p_search_query)
               ) as relevance
        FROM posts p
        WHERE (
            p_status_filter IS NULL OR p.status = p_status_filter
            )
          AND (
            p_category_id IS NULL OR p.category_id = p_category_id
            )
          AND (
            p_author_id IS NULL OR p.author_id = p_author_id
            )
          AND (
            p_tag_ids IS NULL OR EXISTS (SELECT 1
                                         FROM post_tags pt
                                         WHERE pt.post_id = p.id
                                           AND pt.tag_id = ANY (p_tag_ids))
            )
          AND (
            p_search_query IS NULL OR
            to_tsvector('simple', p.title || ' ' || coalesce(p.excerpt, '') || ' ' || p.content) @@
            plainto_tsquery('simple', p_search_query)
            )
        ORDER BY relevance DESC, p.published_at DESC
        LIMIT p_limit_count OFFSET p_offset_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 11. 创建触发器
-- ============================================

-- 文章表触发器
DROP TRIGGER IF EXISTS update_posts_updated_at ON posts;
CREATE TRIGGER update_posts_updated_at
    BEFORE UPDATE
    ON posts
    FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 分类表触发器
DROP TRIGGER IF EXISTS update_categories_updated_at ON categories;
CREATE TRIGGER update_categories_updated_at
    BEFORE UPDATE
    ON categories
    FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 标签表触发器
DROP TRIGGER IF EXISTS update_tags_updated_at ON tags;
CREATE TRIGGER update_tags_updated_at
    BEFORE UPDATE
    ON tags
    FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 文章元数据表触发器
DROP TRIGGER IF EXISTS update_post_meta_updated_at ON post_meta;
CREATE TRIGGER update_post_meta_updated_at
    BEFORE UPDATE
    ON post_meta
    FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 系列表触发器
DROP TRIGGER IF EXISTS update_series_updated_at ON series;
CREATE TRIGGER update_series_updated_at
    BEFORE UPDATE
    ON series
    FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 自动计算阅读时间的触发器
CREATE OR REPLACE FUNCTION update_post_reading_time()
    RETURNS TRIGGER AS
$$
BEGIN
    IF NEW.content IS NOT NULL AND (TG_OP = 'INSERT' OR OLD.content IS DISTINCT FROM NEW.content) THEN
        NEW.reading_time_minutes := calculate_reading_time(NEW.content);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_reading_time ON posts;
CREATE TRIGGER trigger_update_reading_time
    BEFORE INSERT OR UPDATE
    ON posts
    FOR EACH ROW
EXECUTE FUNCTION update_post_reading_time();

-- 文章状态变更触发器
CREATE OR REPLACE FUNCTION handle_post_status_change()
    RETURNS TRIGGER AS
$$
BEGIN
    -- 如果状态从草稿变为发布，设置发布时间
    IF OLD.status != 'published' AND NEW.status = 'published' AND NEW.published_at IS NULL THEN
        NEW.published_at := CURRENT_TIMESTAMP;
    END IF;

    -- 如果状态从发布变为其他状态，更新作者统计
    IF OLD.status = 'published' AND NEW.status != 'published' THEN
        UPDATE user_statistics
        SET posts_count = GREATEST(0, posts_count - 1)
        WHERE user_id = NEW.author_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_handle_post_status_change ON posts;
CREATE TRIGGER trigger_handle_post_status_change
    BEFORE UPDATE
    ON posts
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION handle_post_status_change();

-- ============================================
-- 12. 创建视图（修复 GROUP BY 问题）
-- ============================================

-- 已发布文章视图（使用 DISTINCT ON 替代 GROUP BY）
CREATE OR REPLACE VIEW v_published_posts AS
SELECT DISTINCT ON (p.id) p.id,
                          p.title,
                          p.slug,
                          p.excerpt,
                          p.content,
                          p.author_id,
                          u.username                as author_username,
                          u.display_name            as author_name,
                          u.avatar_url              as author_avatar,
                          p.category_id,
                          c.name                    as category_name,
                          c.slug                    as category_slug,
                          c.sort_order              as category_sort_order,
                          p.status,
                          p.view_count,
                          p.like_count,
                          p.comment_count,
                          p.is_featured,
                          p.is_pinned,
                          p.featured_image_url,
                          p.featured_image_alt,
                          p.published_at,
                          p.created_at,
                          p.updated_at,
                          p.reading_time_minutes,
                          (SELECT array_agg(DISTINCT t.id)
                           FROM post_tags pt
                                    JOIN tags t ON pt.tag_id = t.id
                           WHERE pt.post_id = p.id) as tag_ids,
                          (SELECT array_agg(DISTINCT t.name)
                           FROM post_tags pt
                                    JOIN tags t ON pt.tag_id = t.id
                           WHERE pt.post_id = p.id) as tag_names,
                          (SELECT array_agg(DISTINCT t.slug)
                           FROM post_tags pt
                                    JOIN tags t ON pt.tag_id = t.id
                           WHERE pt.post_id = p.id) as tag_slugs
FROM posts p
         JOIN users u ON p.author_id = u.id
         LEFT JOIN categories c ON p.category_id = c.id
WHERE p.status = 'published'
  AND p.published_at <= CURRENT_TIMESTAMP
  AND u.is_active = TRUE
  AND u.is_banned = FALSE
ORDER BY p.id, p.is_pinned DESC, p.published_at DESC;

-- 文章详情视图
CREATE OR REPLACE VIEW v_post_details AS
SELECT p.*,
       u.username                                                                                            as author_username,
       u.display_name                                                                                        as author_name,
       u.avatar_url                                                                                          as author_avatar,
       u.bio                                                                                                 as author_bio,
       u.website_url                                                                                         as author_website,
       c.name                                                                                                as category_name,
       c.slug                                                                                                as category_slug,
       c.description                                                                                         as category_description,
       c.sort_order                                                                                          as category_sort_order,
       (SELECT json_agg(json_build_object(
               'id', t.id,
               'name', t.name,
               'slug', t.slug
                        ))
        FROM post_tags pt
                 JOIN tags t ON pt.tag_id = t.id
        WHERE pt.post_id = p.id)                                                                             as tags,
       (SELECT json_agg(json_build_object(
               'id', s.id,
               'name', s.name,
               'slug', s.slug,
               'episode_number', ps.episode_number
                        ))
        FROM post_series ps
                 JOIN series s ON ps.series_id = s.id
        WHERE ps.post_id = p.id)                                                                             as series_info,
       (SELECT COUNT(*) FROM post_revisions pr WHERE pr.post_id = p.id)                                      as revision_count,
       (SELECT meta_value
        FROM post_meta pm
        WHERE pm.post_id = p.id
          AND pm.meta_key = 'estimated_read_time')                                                           as estimated_read_time
FROM posts p
         JOIN users u ON p.author_id = u.id
         LEFT JOIN categories c ON p.category_id = c.id;

-- 分类文章统计视图（修复 GROUP BY）
CREATE OR REPLACE VIEW v_category_stats AS
SELECT c.id,
       c.name,
       c.slug,
       c.description,
       c.parent_id,
       c.post_count,
       c.sort_order,
       c.is_active,
       c.created_at,
       COUNT(DISTINCT p.id)           as published_post_count,
       MAX(p.published_at)            as latest_post_date,
       MIN(p.published_at)            as oldest_post_date,
       COALESCE(AVG(p.view_count), 0) as avg_views,
       COALESCE(SUM(p.view_count), 0) as total_views
FROM categories c
         LEFT JOIN posts p ON c.id = p.category_id AND p.status = 'published'
GROUP BY c.id, c.name, c.slug, c.description, c.parent_id, c.post_count, c.sort_order, c.is_active, c.created_at
ORDER BY c.sort_order, c.name;

-- 作者文章统计视图（修复 GROUP BY）
CREATE OR REPLACE VIEW v_author_stats AS
SELECT u.id                                                           as author_id,
       u.username,
       u.display_name,
       u.avatar_url,
       COUNT(DISTINCT p.id)                                           as total_posts,
       COUNT(DISTINCT CASE WHEN p.status = 'published' THEN p.id END) as published_posts,
       COUNT(DISTINCT CASE WHEN p.status = 'draft' THEN p.id END)     as draft_posts,
       COALESCE(SUM(p.view_count), 0)                                 as total_views,
       COALESCE(AVG(p.view_count), 0)                                 as avg_views,
       COALESCE(SUM(p.like_count), 0)                                 as total_likes,
       COALESCE(SUM(p.comment_count), 0)                              as total_comments,
       MAX(p.published_at)                                            as latest_post_date,
       MIN(p.published_at)                                            as first_post_date
FROM users u
         LEFT JOIN posts p ON u.id = p.author_id
WHERE u.is_active = TRUE
  AND u.is_banned = FALSE
GROUP BY u.id, u.username, u.display_name, u.avatar_url
ORDER BY published_posts DESC;

-- 月度文章归档视图
CREATE OR REPLACE VIEW v_monthly_archive AS
SELECT DATE_TRUNC('month', p.published_at)       as month,
       COUNT(*)                                  as post_count,
       ARRAY_AGG(json_build_object(
                         'id', p.id,
                         'title', p.title,
                         'slug', p.slug,
                         'published_at', p.published_at
                 ) ORDER BY p.published_at DESC) as posts
FROM posts p
WHERE p.status = 'published'
  AND p.published_at IS NOT NULL
GROUP BY DATE_TRUNC('month', p.published_at)
ORDER BY month DESC;

-- ============================================
-- 13. 创建全文搜索配置
-- ============================================

-- 添加全文搜索列到文章表
ALTER TABLE posts
    ADD COLUMN IF NOT EXISTS search_vector tsvector;

-- 创建全文搜索索引
CREATE INDEX IF NOT EXISTS idx_posts_search_vector ON posts USING gin (search_vector);

-- 更新搜索向量的函数
CREATE OR REPLACE FUNCTION posts_search_vector_update()
    RETURNS TRIGGER AS
$$
BEGIN
    NEW.search_vector :=
            setweight(to_tsvector('simple', coalesce(NEW.title, '')), 'A') ||
            setweight(to_tsvector('simple', coalesce(NEW.excerpt, '')), 'B') ||
            setweight(to_tsvector('simple', NEW.content), 'C');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_posts_search_vector_update ON posts;
CREATE TRIGGER trigger_posts_search_vector_update
    BEFORE INSERT OR UPDATE
    ON posts
    FOR EACH ROW
EXECUTE FUNCTION posts_search_vector_update();

-- 初始更新已有文章的搜索向量
UPDATE posts
SET search_vector =
        setweight(to_tsvector('simple', title), 'A') ||
        setweight(to_tsvector('simple', coalesce(excerpt, '')), 'B') ||
        setweight(to_tsvector('simple', content), 'C');

-- ============================================
-- 14. 提交所有更改
-- ============================================
COMMIT;

-- ============================================
-- 完成信息
-- ============================================
DO
$$
    BEGIN
        RAISE NOTICE '============================================';
        RAISE NOTICE '文章表结构创建完成！';
        RAISE NOTICE '已创建以下表:';
        RAISE NOTICE '1. posts (文章主表)';
        RAISE NOTICE '2. categories (分类表)';
        RAISE NOTICE '3. tags (标签表)';
        RAISE NOTICE '4. post_tags (文章-标签关联表)';
        RAISE NOTICE '5. post_revisions (文章版本表)';
        RAISE NOTICE '6. post_meta (文章元数据表)';
        RAISE NOTICE '7. series (系列表)';
        RAISE NOTICE '8. post_series (文章系列关联表)';
        RAISE NOTICE '9. related_posts (相关文章表)';
        RAISE NOTICE '';
        RAISE NOTICE '已创建以下视图:';
        RAISE NOTICE '1. v_published_posts (已发布文章视图)';
        RAISE NOTICE '2. v_post_details (文章详情视图)';
        RAISE NOTICE '3. v_category_stats (分类统计视图)';
        RAISE NOTICE '4. v_author_stats (作者统计视图)';
        RAISE NOTICE '5. v_monthly_archive (月度归档视图)';
        RAISE NOTICE '';
        RAISE NOTICE '已启用全文搜索功能';
        RAISE NOTICE '';
        RAISE NOTICE '下一步:';
        RAISE NOTICE '1. 插入初始分类数据';
        RAISE NOTICE '2. 测试文章发布功能';
        RAISE NOTICE '============================================';
    END
$$;