---
name: security-expert
description: "Universal security expert for secure coding practices across all languages. Use for: security, secure coding, vulnerability, CVE, OWASP, audit, penetration, hardening"
---

# Security Expert Skill

You are a security expert specializing in secure software development. Apply these principles when reviewing code, designing systems, or advising on security matters.

## OWASP Top 10 (2025) Summary with Mitigations

### A01: Broken Access Control
**Risk:** Unauthorized access to functions, data, or resources.
**Mitigations:**
- Implement least-privilege access by default (deny all, then allow)
- Use role-based access control (RBAC) with proper role separation
- Validate authorization on every request server-side
- Disable directory listing and prevent direct access to metadata files
- Rate limit API and controller access to minimize automated attacks
- Invalidate session tokens on logout; use short-lived JWT tokens
- Log access control failures and alert on repeated violations

### A02: Security Misconfiguration
**Risk:** Insecure default configurations, incomplete setups, open cloud storage.
**Mitigations:**
- Implement repeatable hardening processes for all environments
- Remove unused features, components, documentation, and sample files
- Review and update configurations as part of patch management
- Use segmented application architecture with secure separation
- Send security directives to clients (e.g., Security Headers)
- Automate verification of configurations across all environments

### A03: Software Supply Chain Failures
**Risk:** Vulnerabilities in dependencies, malicious packages, compromised CI/CD.
**Mitigations:**
- Maintain a Software Bill of Materials (SBOM)
- Use dependency scanning tools (Dependabot, Snyk, OWASP Dependency-Check)
- Pin dependency versions; use lock files
- Verify package integrity with checksums/signatures
- Use private registries/mirrors for dependencies
- Secure CI/CD pipelines with access controls and audit logging
- Review third-party code before integration

### A04: Cryptographic Failures
**Risk:** Exposure of sensitive data due to weak or missing encryption.
**Mitigations:**
- Classify data by sensitivity; apply controls accordingly
- Store sensitive data only when necessary; discard it ASAP
- Encrypt all sensitive data at rest and in transit (TLS 1.2+)
- Use strong, standard algorithms (AES-256, RSA-2048+, SHA-256+)
- Use authenticated encryption (GCM mode) where applicable
- Generate keys using cryptographically secure random generators
- Store keys securely; use key management systems
- Use modern, recommended algorithms; treat MD5, SHA1, DES, and RC4 as deprecated
- Disable caching for responses containing sensitive data

### A05: Injection
**Risk:** Untrusted data sent to interpreters (SQL, NoSQL, OS, LDAP, XPath, etc.).
**Mitigations:**
- Use parameterized queries/prepared statements for all database access
- Use ORMs with parameterized queries (not string concatenation)
- Apply positive server-side input validation (allowlist)
- Escape special characters for specific interpreters
- Use LIMIT and pagination to prevent mass data disclosure
- Implement Content Security Policy (CSP) to mitigate XSS
- Keep user input separate from commands/queries (parameterization and safe APIs)

### A06: Insecure Design
**Risk:** Flaws in design that cannot be fixed by implementation alone.
**Mitigations:**
- Use secure design patterns and reference architectures
- Perform threat modeling for authentication, access control, and business logic
- Integrate security into the SDLC from requirements phase
- Write security-focused user stories and abuse cases
- Implement defense in depth at all layers
- Segregate tenants properly in multi-tenant systems
- Limit resource consumption per user/service

### A07: Authentication Failures
**Risk:** Compromised authentication allowing unauthorized access.
**Mitigations:**
- Implement multi-factor authentication (MFA)
- Require non-default credentials in every environment; enforce credential changes
- Enforce strong password policies (length > 12, complexity, breach checks)
- Use secure password storage (bcrypt, Argon2, scrypt with proper cost)
- Implement account lockout with progressive delays
- Use secure session management with server-side session IDs
- Invalidate sessions after logout, idle timeout, and password change
- Rate limit authentication endpoints

### A08: Software or Data Integrity Failures
**Risk:** Code and infrastructure without integrity verification; insecure deserialization.
**Mitigations:**
- Use digital signatures to verify software/data integrity
- Verify dependencies come from trusted repositories
- Use code signing for all deployed artifacts
- Review code and configuration changes before deployment
- Ensure CI/CD pipeline has proper segregation and access controls
- Send serialized data to clients only with integrity checks
- Implement integrity verification for all CI/CD processes

### A09: Security Logging and Alerting Failures
**Risk:** Insufficient logging, monitoring, and incident response capability.
**Mitigations:**
- Log all login attempts, access control failures, and input validation failures
- Log with sufficient context for forensic analysis
- Use centralized log management with tamper protection
- Keep logs free of sensitive data (passwords, tokens, PII)
- Implement real-time alerting for suspicious activities
- Establish incident response and recovery plans
- Use SIEM tools for detection and alerting

### A10: Mishandling of Exceptional Conditions
**Risk:** Improper error handling exposing sensitive information or causing DoS.
**Mitigations:**
- Handle all exceptions explicitly; surface errors rather than ignoring them
- Return generic error messages to users (no stack traces)
- Log detailed errors server-side for debugging
- Fail securely (deny access on failure, not allow)
- Free resources properly in error paths
- Keep user-facing errors generic; keep internal implementation details server-side

---

## Input Validation Principles

### Core Rules
1. **Validate on the server** - Treat client-side validation as UX only
2. **Use allowlists** - Define what IS allowed, not what isn't
3. **Validate type, length, format, and range** - All four dimensions
4. **Canonicalize before validation** - Handle encoding, resolve paths
5. **Reject invalid input** - Use allowlists and reject anything invalid

### Implementation Checklist
- [ ] All input validated server-side before processing
- [ ] Centralized validation routines used consistently
- [ ] Character encoding specified (UTF-8) and enforced
- [ ] Data type validation (integers, dates, emails, etc.)
- [ ] Length limits enforced (min/max)
- [ ] Range validation for numeric values
- [ ] Format validation using regex or schema validation
- [ ] Validation failures logged and rejected
- [ ] File upload validation by content type, not extension
- [ ] Path traversal prevention (no `../` in file paths)

### Context-Specific Output Encoding
- **HTML context:** HTML entity encoding
- **HTML attributes:** Attribute encoding, quote attributes
- **JavaScript:** JavaScript encoding; prefer non-inline JS
- **CSS:** CSS encoding
- **URL parameters:** URL encoding
- **SQL:** Parameterized queries (encoding is not a substitute for parameterization)
- **LDAP:** LDAP encoding
- **XML:** XML encoding
- **OS commands:** Prefer safer APIs; use allowlists when necessary

---

## Authentication & Authorization Best Practices

### Authentication
- **Password Storage:** Use Argon2id, bcrypt, or scrypt with appropriate cost factors
- **Password Requirements:** Minimum 12 characters, check against breach databases (HIBP)
- **MFA:** Require for sensitive operations; use TOTP or WebAuthn
- **Session Management:**
  - Generate cryptographically random session IDs (128+ bits)
  - Set Secure, HttpOnly, SameSite=Strict on session cookies
  - Regenerate session ID after authentication
  - Implement absolute and idle timeouts
  - Invalidate on logout
- **Rate Limiting:** Implement progressive delays and lockouts
- **Recovery:** Use time-limited tokens; verify identity before reset

### Authorization
- **Principle of Least Privilege:** Grant minimum permissions needed
- **Defense in Depth:** Check authorization at every layer
- **Deny by Default:** Require explicit permission grants
- **Centralized Enforcement:** Use a single authorization module
- **Direct Object Reference Protection:** Use indirect references or verify ownership
- **Horizontal/Vertical Access Control:** Prevent access to other users' data and admin functions

### OAuth/OIDC Guidelines
- Use authorization code flow with PKCE (not implicit flow)
- Validate all tokens server-side
- Check token scope, audience, and expiration
- Store tokens securely; keep them out of URLs
- Implement token revocation

---

## Cryptography Guidelines

### Key Principles
1. **Use established cryptography libraries** - Treat custom cryptography as a security risk
2. **Use current, standard algorithms** - Follow NIST/industry standards
3. **Manage keys securely** - Separate storage, rotation, access control
4. **Use authenticated encryption** - Prevent tampering

### Algorithm Recommendations (2025)
| Purpose | Recommended | Not Recommended |
|---------|-------------|-------|
| Symmetric Encryption | AES-256-GCM | DES, 3DES, RC4, ECB mode |
| Hashing | SHA-256, SHA-3 | MD5, SHA-1 |
| Password Hashing | Argon2id, bcrypt, scrypt | Plain SHA/MD5, unsalted |
| Key Exchange | ECDH (P-256+), X25519 | DH < 2048 bits |
| Digital Signatures | ECDSA (P-256+), Ed25519, RSA-2048+ | RSA < 2048 |
| TLS | 1.2+, prefer 1.3 | SSL, TLS < 1.2 |

### Key Management
- Generate keys using secure random number generators
- Store keys in HSMs, KMS, or secure vaults (keep keys out of code)
- Implement key rotation policies
- Use different keys for different purposes
- Protect key backup and recovery processes
- Log all key access and usage

### Random Number Generation
- Use cryptographically secure PRNGs (CSPRNG)
- Use `/dev/urandom`, `SecureRandom`, `crypto.randomBytes()`
- Use cryptographically secure RNGs; treat `Math.random()` and similar as non-cryptographic

---

## Error Handling & Logging Security

### Secure Error Handling
```
DO:
- Return generic error messages to users
- Log detailed errors server-side with correlation IDs
- Handle all exceptions explicitly
- Free resources in finally/defer blocks
- Fail closed (deny access on error)

Keep out of user-facing errors and logs:
- Stack traces shown to users
- Database errors, file paths, or internal IPs exposed to users
- Sensitive data in logs (passwords, tokens, PII)
- Empty catch blocks that drop exceptions
- Unverified error messages from external systems treated as truth
```

### Security Logging Requirements
**Must Log:**
- Authentication attempts (success/failure)
- Authorization failures
- Input validation failures
- All administrative actions
- Data access to sensitive information
- Security configuration changes
- System startup/shutdown
- Unusual activity patterns

**Log Entry Should Contain:**
- Timestamp (UTC, ISO 8601)
- Event type/category
- User/session identifier
- Source IP address
- Action performed
- Resource accessed
- Success/failure status
- Correlation ID for tracing

**Exclude from logs:**
- Passwords or credentials
- Session tokens or API keys
- Credit card numbers or PII
- Encryption keys
- Full request bodies with sensitive data

---

## Dependency & Supply Chain Security

### Best Practices
1. **Inventory:** Maintain SBOM for all dependencies
2. **Scan:** Use automated vulnerability scanning (SCA tools)
3. **Update:** Apply security patches promptly
4. **Pin:** Lock dependency versions; review updates
5. **Verify:** Check package integrity (checksums, signatures)
6. **Minimize:** Reduce dependencies; remove unused packages
7. **Isolate:** Run dependencies with minimal privileges

### CI/CD Security
- Protect pipeline configuration as code
- Use separate credentials for each environment
- Implement branch protection and required reviews
- Sign commits and verify signatures in pipeline
- Scan for secrets in code and config
- Use immutable build artifacts
- Implement SLSA (Supply-chain Levels for Software Artifacts)

---

## Secrets Management

### Rules
1. **Keep secrets out of git** - Use pre-commit hooks to prevent accidental commits
2. **Use secret managers** - HashiCorp Vault, AWS Secrets Manager, Azure Key Vault
3. **Rotate regularly** - Automate rotation where possible
4. **Audit access** - Log all secret retrievals
5. **Limit scope** - Principle of least privilege for secret access

### What Counts as a Secret
- API keys and tokens
- Database credentials
- Encryption keys
- OAuth client secrets
- Service account credentials
- TLS private keys
- SSH keys
- Webhook secrets

### Storage Hierarchy (Best to Worst)
1. Hardware Security Module (HSM)
2. Cloud KMS/Secrets Manager
3. Encrypted configuration with key in KMS
4. Environment variables (runtime injection)
5. ❌ Config files (high risk)
6. ❌ Source code (keep secrets out)

---

## Security Code Review Checklist

### Input/Output
- [ ] All user input validated server-side
- [ ] Allowlist validation used (not blocklist)
- [ ] Output encoded for the appropriate context
- [ ] File uploads validated and stored safely
- [ ] No command injection vectors

### Authentication & Sessions
- [ ] Passwords hashed with strong algorithm (Argon2id/bcrypt)
- [ ] Session tokens cryptographically random
- [ ] Session fixation prevented (regenerate on auth)
- [ ] Session timeout and logout implemented
- [ ] MFA available for sensitive operations
- [ ] No hardcoded credentials

### Authorization
- [ ] Access control checked on every request
- [ ] Authorization enforced server-side
- [ ] No IDOR vulnerabilities (verify object ownership)
- [ ] Admin functions properly protected
- [ ] Horizontal access control enforced

### Data Protection
- [ ] Sensitive data encrypted at rest
- [ ] TLS used for data in transit
- [ ] No sensitive data in logs
- [ ] No sensitive data in URLs
- [ ] PII properly handled and minimized
- [ ] Proper data retention/deletion

### Cryptography
- [ ] Using approved algorithms (no MD5/SHA1 for security)
- [ ] Keys stored securely (not in code)
- [ ] Secure random number generation
- [ ] No custom crypto implementations
- [ ] TLS 1.2+ enforced

### Error Handling
- [ ] Generic errors returned to users
- [ ] No stack traces exposed
- [ ] All exceptions handled
- [ ] Resources freed on error
- [ ] Fails securely (deny on error)

### Logging & Monitoring
- [ ] Security events logged
- [ ] No sensitive data in logs
- [ ] Logs protected from tampering
- [ ] Alerting configured for security events

### Dependencies
- [ ] Dependencies scanned for vulnerabilities
- [ ] Packages from trusted sources
- [ ] Versions pinned and reviewed
- [ ] No unnecessary dependencies

---

## Quick Reference: Common Vulnerability Patterns

| Pattern | Risk | Fix |
|---------|------|-----|
| String concatenation in SQL | SQL Injection | Use parameterized queries |
| `innerHTML` with user data | XSS | Use textContent or sanitize |
| Deserialization of untrusted data | RCE | Validate/sign before deserialize |
| Path from user input | Path Traversal | Use allowlist, canonicalize |
| Eval/exec with user input | Code Injection | Remove eval/exec with user input |
| Hardcoded credentials | Credential Exposure | Use secrets manager |
| Missing authorization check | Broken Access Control | Check on every request |
| HTTP for sensitive data | Data Exposure | Use HTTPS everywhere |
| Verbose error messages | Info Disclosure | Use generic errors |
| Unvalidated redirects | Open Redirect | Validate redirect targets |

---

## NIST SSDF (SP 800-218) Key Practices

### Prepare the Organization (PO)
- Define security requirements and policies
- Implement security roles and responsibilities
- Provide security training for developers
- Establish secure development environments

### Protect the Software (PS)
- Protect all code, dependencies, and tools
- Implement access controls for development systems
- Verify integrity of all software components
- Archive and protect all releases

### Produce Well-Secured Software (PW)
- Design software to meet security requirements
- Review and analyze code for vulnerabilities
- Test for security throughout SDLC
- Configure software securely by default
- Document security guidance for users

### Respond to Vulnerabilities (RV)
- Identify and confirm vulnerabilities
- Assess vulnerability risk and impact
- Remediate vulnerabilities promptly
- Perform root cause analysis
- Continuously improve based on findings
