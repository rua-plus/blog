# Blog

## 数据库设计

Postgresql 18

| #   | Name       | Comment    |
| --- | ---------- | ---------- |
| 1   | categories | 文章分类表 |
| 2   | comments   | 文章评论表 |
| 3   | posts      | 文章表     |
| 4   | tags       | 文章标签表 |
| 5   | users      | 用户表     |
| 6   | media      | 媒体文件表 |

## 后端设计

### 基本功能

- 根据配置文件中提供的 Postgresql 连接方式连接数据库
- 打印详细请求信息到 std

### 用户

- JWT 认证
- 基于 Argon2 的密码 Hash

### Hash

- 使用Argon2id算法，最低配置要求为19 MiB内存、迭代次数为2、并行度为1。
- 若Argon2id不可用，则使用scrypt算法，其CPU/内存成本参数至少为2^17，最小块大小为8（1024字节），并行化参数为1。
- 对于使用bcrypt的遗留系统，工作因子应设为10或更高，且密码长度限制为72字节。
- 如需符合FIPS-140标准，则采用PBKDF2算法，工作因子不低于600,000，并设置内部哈希函数为HMAC-SHA-256。
- 可考虑使用密钥延伸值（pepper）以提供深度防御增强（但其本身不具备额外的安全特性）。

### 接口

- 统一的返回格式

基础响应格式：

```json
{
  "code": 200,
  "message": "success",
  "data": {},
  "timestamp": 1640995200000
}
```

成功：

```json
{
  "success": true,
  "code": 200,
  "message": "操作成功",
  "data": {
    // 业务数据
    "user": {
      "id": 1,
      "name": "张三"
    }
  },
  "timestamp": 1640995200000,
  "version": "v1.0.0"
}
```

错误：

```json
{
  "success": false,
  "code": 40001,
  "message": "参数验证失败",
  "errors": [
    {
      "field": "email",
      "message": "邮箱格式不正确"
    },
    {
      "field": "password",
      "message": "密码长度至少6位"
    }
  ],
  "timestamp": 1640995200000,
  "path": "/api/v1/users",
  "debug": "详细错误堆栈（仅开发环境）"
}
```

分页：

```json
{
  "success": true,
  "code": 200,
  "message": "查询成功",
  "data": {
    "list": [
      // 数据列表
    ],
    "pagination": {
      "page": 1,
      "pageSize": 20,
      "total": 150,
      "totalPages": 8
    }
  },
  "timestamp": 1640995200000
}
```

状态码：

```js
// 状态码定义
const StatusCode = {
  // HTTP状态码
  HTTP_OK: 200,
  HTTP_CREATED: 201,
  HTTP_BAD_REQUEST: 400,
  HTTP_UNAUTHORIZED: 401,
  HTTP_FORBIDDEN: 403,
  HTTP_NOT_FOUND: 404,
  HTTP_INTERNAL_ERROR: 500,

  // 业务成功状态码
  SUCCESS: 200,
  CREATED: 201,
  ACCEPTED: 202,

  // 业务错误状态码（4xxxx）
  BAD_REQUEST: 40000,
  VALIDATION_ERROR: 40001,
  PARAM_ERROR: 40002,

  // 认证授权错误（401xx）
  UNAUTHORIZED: 40100,
  TOKEN_EXPIRED: 40101,
  TOKEN_INVALID: 40102,

  // 权限错误（403xx）
  FORBIDDEN: 40300,
  ACCESS_DENIED: 40301,

  // 资源错误（404xx）
  NOT_FOUND: 40400,
  RESOURCE_NOT_FOUND: 40401,

  // 业务逻辑错误（409xx）
  CONFLICT: 40900,
  DUPLICATE_RESOURCE: 40901,

  // 系统错误（500xx）
  INTERNAL_ERROR: 50000,
  SERVICE_UNAVAILABLE: 50001,
  DATABASE_ERROR: 50002,

  // 第三方服务错误（502xx）
  THIRD_PARTY_ERROR: 50200,
  EXTERNAL_API_ERROR: 50201,
};
```
