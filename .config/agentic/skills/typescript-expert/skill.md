---
name: typescript-expert
description: "TypeScript/JavaScript expert for idiomatic code, type safety, and security. Use for: TypeScript, JavaScript, ts, js, node, npm, pnpm, frontend, backend"
---

# TypeScript/JavaScript Expert

You are an expert TypeScript/JavaScript developer. Apply these best practices when writing or reviewing code.

## Type System Best Practices

### Enable Strict Mode
Always use strict TypeScript configuration:
```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "noImplicitReturns": true,
    "noUncheckedIndexedAccess": true
  }
}
```

### Prefer Explicit Types Over `any`
- Use `unknown`, generics, or proper unions; reserve `any` for short-lived JavaScript migration work
- Use `unknown` when type is uncertain, then narrow with type guards
- Use generics for flexible, type-safe code
- Prefer union types (`string | number`) over `any`

### Prefer Explicit Types
```typescript
// ✅ Good: Explicit parameter and return types
function calculateTotal(items: Item[]): number {
  return items.reduce((sum, item) => sum + item.price, 0);
}

// ❌ Bad: Implicit any
function calculateTotal(items) {
  return items.reduce((sum, item) => sum + item.price, 0);
}
```

### Use Type Guards for Narrowing
```typescript
// ✅ Good: Type guard for safe narrowing
function isUser(value: unknown): value is User {
  return typeof value === 'object' && value !== null && 'id' in value;
}

if (isUser(data)) {
  console.log(data.id); // TypeScript knows data is User
}
```

### Primitive Types
- Use `string`, `number`, `boolean` (lowercase)
- Use `string`, `number`, `boolean`, and `object` instead of wrapper types (`String`, `Number`, `Boolean`, `Object`)

## Idiomatic TypeScript Patterns (Google Style Guide)

### Variable Declarations
- Always use `const` by default, `let` only when reassignment is needed
- Use `const`/`let` instead of `var`
- One variable per declaration

### Imports & Exports
```typescript
// ✅ Good: Named exports (preferred)
export class UserService { }
export function fetchUser(id: string): Promise<User> { }

// ❌ Bad: Default exports (prefer named exports)
export default class UserService { }

// ✅ Good: Type-only imports when only using as type
import type { User } from './types';
import { UserService } from './services';
```

### Use Modules, Not Namespaces
- Use ES modules (`import`/`export`) instead of `namespace`
- Use ES module imports instead of `require()`
- Use ES6 module imports/exports

### Arrays
```typescript
// ✅ Good: Array literal syntax
const items: number[] = [1, 2, 3];
const empty: string[] = [];

// ❌ Bad: Array constructor
const items = new Array(3); // Confusing behavior
```

### Object Iteration
```typescript
// ✅ Good: Safe object iteration
for (const key of Object.keys(obj)) { }
for (const [key, value] of Object.entries(obj)) { }

// ❌ Bad: Unfiltered for-in (includes prototype properties)
for (const key in obj) { }
```

### Prefer Interfaces Over Type Aliases
```typescript
// ✅ Good: Interface for object shapes
interface User {
  id: string;
  name: string;
}

// Use type for unions, intersections, mapped types
type Status = 'active' | 'inactive';
type UserWithRole = User & { role: string };
```

### Nullish Values
- Use `undefined` over `null` when possible
- Use optional chaining: `user?.address?.city`
- Use nullish coalescing: `value ?? defaultValue`

### Control Flow
- Always use braces for control structures
- No fall-through in switch (use `break` or `return`)

## Security Practices

### XSS Prevention (OWASP)
```typescript
// ❌ DANGEROUS: innerHTML with untrusted data is an XSS risk
element.innerHTML = userInput; // XSS vulnerability!

// ✅ Safe: Use textContent for text
element.textContent = userInput;

// ✅ Safe: Use DOMPurify for HTML
import DOMPurify from 'dompurify';
element.innerHTML = DOMPurify.sanitize(userInput);
```

### Framework-Specific XSS
```typescript
// ❌ React: dangerouslySetInnerHTML is an XSS risk; prefer safe rendering
<div dangerouslySetInnerHTML={{ __html: userInput }} />

// ✅ React: Let React handle escaping
<div>{userInput}</div>

// If HTML is required, sanitize first
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userInput) }} />
```

### Input Validation
```typescript
// ✅ Good: Validate and sanitize all user input
import { z } from 'zod';

const UserSchema = z.object({
  email: z.string().email(),
  age: z.number().min(0).max(150),
  name: z.string().min(1).max(100),
});

function createUser(input: unknown) {
  const validated = UserSchema.parse(input); // Throws on invalid
  // Use validated data safely
}
```

### SQL Injection Prevention
```typescript
// ❌ DANGEROUS: String concatenation
const query = `SELECT * FROM users WHERE id = '${userId}'`;

// ✅ Safe: Parameterized queries
const result = await db.query(
  'SELECT * FROM users WHERE id = $1',
  [userId]
);

// ✅ Safe: ORM with type safety
const user = await prisma.user.findUnique({ where: { id: userId } });
```

### Command Injection Prevention
```typescript
// ❌ DANGEROUS: Passing user input to shell
import { exec } from 'child_process';
exec(`ls ${userInput}`); // Command injection!

// ✅ Safe: Use execFile with arguments array
import { execFile } from 'child_process';
execFile('ls', [userInput]); // Arguments are escaped

// ✅ Best: Prefer native Node APIs when possible
import { readdir } from 'fs/promises';
const files = await readdir(userInput);
```

### Path Traversal Prevention
```typescript
import path from 'path';

// ❌ DANGEROUS: Direct path concatenation
const filePath = `./uploads/${userFilename}`;

// ✅ Safe: Validate path is within allowed directory
const uploadsDir = path.resolve('./uploads');
const requestedPath = path.resolve(uploadsDir, userFilename);

if (!requestedPath.startsWith(uploadsDir)) {
  throw new Error('Path traversal attempt detected');
}
```

### Secrets Management
```typescript
// ❌ DANGEROUS: Hardcoded secrets
const API_KEY = 'sk-1234567890abcdef';

// ✅ Safe: Environment variables
const API_KEY = process.env.API_KEY;
if (!API_KEY) throw new Error('API_KEY not configured');

// ❌ DANGEROUS: Logging sensitive data
console.log('User logged in:', { password: user.password });

// ✅ Safe: Exclude sensitive fields
console.log('User logged in:', { id: user.id, email: user.email });
```

## Node.js Security

### Dependency Security
```bash
# Audit dependencies for known vulnerabilities
npm audit
pnpm audit

# Fix automatically where possible
npm audit fix

# Update outdated packages
npm outdated
npm update
```

### Content Security Policy
```typescript
// Express.js with Helmet
import helmet from 'helmet';

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));
```

### Cookie Security
```typescript
// ✅ Secure cookie configuration
res.cookie('session', token, {
  httpOnly: true,    // Prevents XSS access
  secure: true,      // HTTPS only
  sameSite: 'strict', // CSRF protection
  maxAge: 3600000,   // 1 hour
});
```

### Rate Limiting
```typescript
import rateLimit from 'express-rate-limit';

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per window
  message: 'Too many requests',
});

app.use('/api/', limiter);
```

### HTTPS and TLS
```typescript
// Always use HTTPS in production
import https from 'https';
import fs from 'fs';

const options = {
  key: fs.readFileSync('private-key.pem'),
  cert: fs.readFileSync('certificate.pem'),
};

https.createServer(options, app).listen(443);
```

## Common Pitfalls and How to Prevent Them

### Type Pitfalls
```typescript
// ❌ Pitfall: Type assertion without validation
const user = data as User; // Might not be a User!

// ✅ Safe: Validate before asserting
if (isUser(data)) {
  const user = data; // TypeScript knows it's User
}

// ❌ Pitfall: Non-null assertion abuse
const value = maybeNull!.property; // Runtime error if null

// ✅ Safe: Handle null explicitly
const value = maybeNull?.property ?? defaultValue;
```

### Async/Promise Pitfalls
```typescript
// ❌ Pitfall: Unhandled promise rejection
async function fetchData() {
  const response = await fetch(url); // Can throw!
}

// ✅ Safe: Proper error handling
async function fetchData() {
  try {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    return await response.json();
  } catch (error) {
    logger.error('Fetch failed:', error);
    throw error;
  }
}

// ❌ Pitfall: Floating promises
someAsyncFunction(); // No await, no .catch()

// ✅ Safe: Always handle promises
await someAsyncFunction();
// or
someAsyncFunction().catch(handleError);
```

### Object Pitfalls
```typescript
// ❌ Pitfall: Mutating shared state
function processItems(items: Item[]) {
  items.sort(); // Mutates original array!
}

// ✅ Safe: Create new array
function processItems(items: Item[]) {
  return [...items].sort();
}

// ❌ Pitfall: Shallow copy surprises
const copy = { ...original };
copy.nested.value = 'changed'; // Also changes original!

// ✅ Safe: Deep clone when needed
const copy = structuredClone(original);
```

### Equality Pitfalls
```typescript
// ❌ Pitfall: Loose equality
if (value == null) { } // Matches both null and undefined
if (value == 0) { }    // Matches 0, '', false

// ✅ Safe: Strict equality
if (value === null || value === undefined) { }
if (value === 0) { }

// Exception: == null is acceptable for null/undefined check
if (value == null) { } // OK when checking for both null/undefined
```

### Security Pitfalls
```typescript
// ❌ Pitfall: eval and Function constructor
eval(userCode);                    // Remote code execution!
new Function(userCode);            // Same risk
setTimeout(userCode, 1000);        // When string is passed

// ❌ Pitfall: Regex DoS (ReDoS)
const emailRegex = /^([a-zA-Z0-9_\.-]+)@([\da-zA-Z\.-]+)\.([a-zA-Z\.]{2,6})$/;
// Vulnerable to catastrophic backtracking

// ✅ Safe: Use well-tested validation libraries
import { isEmail } from 'validator';
if (isEmail(input)) { }
```

## Code Review Checklist

### Type Safety
- [ ] No `any` types (or documented justification)
- [ ] Strict mode enabled in tsconfig.json
- [ ] Proper null/undefined handling
- [ ] Type guards used for narrowing unknown types
- [ ] No type assertions without prior validation

### Security
- [ ] User input validated and sanitized
- [ ] No SQL/command injection vulnerabilities
- [ ] XSS prevention (no innerHTML with untrusted data)
- [ ] Secrets not hardcoded or logged
- [ ] HTTPS used for sensitive operations
- [ ] Proper authentication/authorization checks
- [ ] Rate limiting on public endpoints
- [ ] Secure cookie flags set (httpOnly, secure, sameSite)

### Error Handling
- [ ] All async operations have error handling
- [ ] Errors logged with appropriate detail (no sensitive data)
- [ ] User-facing errors keep internals private
- [ ] Promise rejections handled

### Code Quality
- [ ] Named exports used (no default exports)
- [ ] Const by default, let only when needed
- [ ] No var declarations
- [ ] Consistent naming conventions (camelCase)
- [ ] Single responsibility functions
- [ ] No magic numbers/strings (use constants)

### Dependencies
- [ ] npm/pnpm audit passes
- [ ] No outdated packages with known vulnerabilities
- [ ] Minimal dependencies (keep bloat out)
- [ ] Lock file committed

## ESLint Security Rules

Enable these ESLint plugins for security:
```json
{
  "plugins": ["@typescript-eslint", "security"],
  "extends": [
    "plugin:@typescript-eslint/recommended",
    "plugin:@typescript-eslint/recommended-requiring-type-checking",
    "plugin:security/recommended"
  ],
  "rules": {
    "@typescript-eslint/no-explicit-any": "error",
    "@typescript-eslint/no-unsafe-assignment": "error",
    "@typescript-eslint/no-unsafe-call": "error",
    "@typescript-eslint/no-unsafe-member-access": "error",
    "@typescript-eslint/no-unsafe-return": "error",
    "security/detect-eval-with-expression": "error",
    "security/detect-non-literal-fs-filename": "warn",
    "security/detect-object-injection": "warn",
    "security/detect-possible-timing-attacks": "warn",
    "security/detect-unsafe-regex": "error"
  }
}
```
