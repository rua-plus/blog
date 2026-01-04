-- 创建用户表（包含所有字段）
CREATE TABLE users (
    id SERIAL PRIMARY KEY,                       -- 主键，自增长
    username VARCHAR(50) UNIQUE NOT NULL,        -- 用户名，唯一且不能为空
    email VARCHAR(100) UNIQUE NOT NULL,          -- 邮箱，唯一且不能为空
    password_hash VARCHAR(255) NOT NULL,         -- 密码哈希值
    avatar_url TEXT,                             -- 用户头像URL地址
    bio TEXT,                                    -- 用户个人简介
    last_login TIMESTAMP,                        -- 最后登录时间
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- 创建时间
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- 更新时间
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
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at);

-- 创建更新时间自动更新的触发器函数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 创建触发器
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
