# AGENTS.md

This file provides guidance for agentic coding assistants working in this repository.

## Build/Lint/Test Commands

This project is currently in architecture design phase. No build, lint, or test commands are available yet.

When implementing the backend, ensure to:
- Set up TypeScript configuration (tsconfig.json)
- Configure ESLint for code quality
- Add testing framework (Jest or Vitest)
- Include scripts in package.json for common operations

## Code Style Guidelines

### TypeScript & Types

- Use strict TypeScript with `strict: true` in tsconfig.json
- Export enums with `export const enum` for better tree-shaking (see interface.ts:2)
- Define interfaces for all data structures
- Use generic types for reusable components (e.g., `SuccessResponse<T>`, `PaginationResponse<T>`)
- Type all function parameters and return types explicitly

### Naming Conventions

- **Enums**: PascalCase with descriptive names (e.g., `StatusCode`, `HTTP_OK`)
- **Interfaces**: PascalCase, descriptive names (e.g., `BaseResponse`, `SuccessResponse`)
- **Variables**: camelCaseCase
- **Constants**: UPPER_SNAKE_CASE for enum values (e.g., `VALIDATION_ERROR`, `TOKEN_EXPIRED`)
- **Database tables**: lowercase, plural (e.g., `users`, `posts`, `categories`)
- **Database columns**: snake_case (e.g., `password_hash`, `created_at`)

### Imports

- Use ES6 import syntax
- Group imports in this order: 1) External libraries, 2) Internal modules, 3) Relative imports
- Use named exports for enums and interfaces
- Avoid default exports unless necessary

### Error Handling

- Use the 5-digit status code system defined in `StatusCode` enum
- **2xxxx**: Success codes
- **400xx**: Client errors (validation, bad requests)
- **401xx**: Authentication errors (unauthorized, token issues)
- **403xx**: Authorization errors (forbidden, access denied)
- **404xx**: Resource errors (not found)
- **409xx**: Business logic errors (conflicts, duplicates)
- **500xx**: System errors (internal, database)
- **502xx**: Third-party service errors

Return error responses in the format:
```typescript
{
  success: false,
  code: StatusCode.VALIDATION_ERROR,
  message: "error message",
  errors: [{ field: "fieldName", message: "error details" }],
  timestamp: Date.now(),
  path: "/api/v1/endpoint"
}
```

### Response Format

All API responses must follow the unified format defined in `interface.ts`:

**Success Response:**
```typescript
{
  success: true,
  code: StatusCode.SUCCESS,
  message: "操作成功",
  data: { /* business data */ },
  timestamp: number,
  requestId: string,
  version?: string
}
```

**Pagination Response:**
```typescript
{
  success: true,
  code: StatusCode.SUCCESS,
  message: "查询成功",
  data: {
    list: T[],
    pagination: {
      page: number,
      pageSize: number,
      total: number,
      totalPages: number
    }
  },
  timestamp: number,
  requestId: string
}
```

### Security Requirements

- **Password Hashing**: Use Argon2id algorithm (19 MiB memory, 2 iterations, parallelism 1)
- **Fallback Hashing**: If Argon2id unavailable, use scrypt (CPU/memory cost 2^17, block size 8, parallelism 1)
- **Legacy Systems**: For bcrypt, use work factor 10+ and limit password to 72 bytes
- **FIPS Compliance**: Use PBKDF2 with 600,000+ iterations and HMAC-SHA-256
- **Authentication**: Use JWT (JSON Web Token) for user authentication
- **Never**: Store plaintext passwords or log sensitive data

### Database Conventions

- Use PostgreSQL 18
- All tables have `id` (SERIAL PRIMARY KEY), `created_at`, and `updated_at` columns
- Use `update_updated_at_column()` trigger for automatic timestamp updates
- Add comments for all tables and columns
- Create indexes on frequently queried columns
- Use foreign key constraints with appropriate ON DELETE behavior:
  - `CASCADE`: Delete dependent records
  - `SET NULL`: Set foreign key to NULL
- Use CHECK constraints for data validation (e.g., published_at validation)

### API Design

- Print detailed request information to stdout for debugging
- Use RESTful API design principles
- Include `requestId` in all responses for request tracing
- Include `timestamp` in all responses
- Support versioning (e.g., `/api/v1/`)
- Return appropriate HTTP status codes alongside business status codes

### Code Comments

- Add comments for complex logic
- Document public APIs and interfaces
- Keep comments concise and relevant
- Prefer self-documenting code over excessive comments

### File Organization

- `interface.ts`: TypeScript interface definitions and status codes
- `sql/init.sql`: Database schema and initialization
- Follow module-based structure for backend implementation
- Separate concerns: models, controllers, services, middleware
