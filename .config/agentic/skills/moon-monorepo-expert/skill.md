---
name: moon-monorepo-expert
description: "Moon monorepo expert for task orchestration, toolchain management, and cross-language consistency. Use for: Moon, monorepo, workspace, task runner, toolchain"
---

# Moon Monorepo Expert

Expert guidance for Moon-based monorepo development, covering project structure, task orchestration, toolchain management, and security best practices.

## 1. Project Structure Best Practices

### Workspace Configuration

```yaml
# .moon/workspace.yml
$schema: 'https://moonrepo.dev/schemas/workspace.json'

# Version control configuration
vcs:
  manager: 'git'
  defaultBranch: 'main'
  syncHooks: true

# Project discovery - prefer globs for scalability
projects:
  - 'apps/*'
  - 'packages/*'
  - 'libs/*'

# Code ownership integration
codeowners:
  syncOnRun: true
  globalPaths:
    '/.moon/**/*': ['@platform-team']
```

### Project Organization

```
monorepo/
├── .moon/
│   ├── workspace.yml      # Workspace configuration
│   ├── toolchains.yml     # Tool version management
│   ├── tasks.yml          # Global inherited tasks
│   └── tasks/
│       ├── node.yml       # Node.js specific tasks
│       ├── rust.yml       # Rust specific tasks
│       └── python.yml     # Python specific tasks
├── apps/                  # Applications
│   ├── web/
│   │   └── moon.yml       # Project-specific config
│   └── api/
│       └── moon.yml
├── packages/              # Shared packages
│   └── ui/
│       └── moon.yml
├── libs/                  # Shared libraries
│   └── utils/
│       └── moon.yml
├── .editorconfig          # Cross-editor consistency
└── .gitguardian.yml       # Secrets scanning config
```

### Project Configuration (moon.yml)

```yaml
# apps/web/moon.yml
$schema: 'https://moonrepo.dev/schemas/project.json'

# Project metadata
language: 'typescript'
type: 'application'
stack: 'frontend'

# Explicit dependencies
dependsOn:
  - id: 'ui'
    scope: 'production'
  - id: 'utils'
    scope: 'production'

# Ownership for accountability
owners:
  paths:
    '*': ['@frontend-team']
    'src/auth/**': ['@security-team']

# Project-specific tags for filtering
tags:
  - 'frontend'
  - 'customer-facing'
```

## 2. Task Configuration Patterns

### Task Inheritance Model

```yaml
# .moon/tasks.yml - Global tasks inherited by all projects
$schema: 'https://moonrepo.dev/schemas/tasks.json'

fileGroups:
  sources:
    - 'src/**/*'
  tests:
    - 'tests/**/*'
    - '**/*.test.*'
  configs:
    - '*.config.*'
    - 'tsconfig.json'
```

### Language-Specific Task Inheritance

```yaml
# .moon/tasks/node.yml
$schema: 'https://moonrepo.dev/schemas/tasks.json'

# Only inherit for Node.js projects
language: 'javascript'

tasks:
  lint:
    command: 'eslint'
    args:
      - '--ext'
      - '.js,.ts,.tsx'
      - '@group(sources)'
    inputs:
      - '@group(sources)'
      - '@group(configs)'

  typecheck:
    command: 'tsc'
    args: ['--noEmit']
    inputs:
      - '@group(sources)'
      - 'tsconfig.json'

  test:
    command: 'vitest'
    args: ['run']
    inputs:
      - '@group(sources)'
      - '@group(tests)'
    deps:
      - '~:typecheck'

  build:
    command: 'vite'
    args: ['build']
    inputs:
      - '@group(sources)'
      - '@group(configs)'
    outputs:
      - 'dist'
    deps:
      - '^:build'  # Build dependencies first
```

### Task Types and Modes

```yaml
tasks:
  # Build task - generates artifacts
  build:
    command: 'npm run build'
    type: 'build'
    outputs:
      - 'dist'

  # Run task - executes processes
  serve:
    command: 'npm run dev'
    type: 'run'
    local: true        # Only runs locally, not in CI
    persistent: true   # Long-running process

  # Test task - validation
  test:
    command: 'npm test'
    type: 'test'
    options:
      retryCount: 2    # Retry flaky tests

  # Internal task - not directly invoked
  codegen:
    command: 'graphql-codegen'
    type: 'build'
    options:
      internal: true   # Hidden from direct invocation

  # Interactive task - requires user input
  release:
    command: 'npm run release'
    options:
      interactive: true
      runInCI: false
```

### Caching Strategy

```yaml
tasks:
  build:
    command: 'webpack build'
    inputs:
      - '@group(sources)'
      - 'webpack.config.js'
      - 'package.json'
    outputs:
      - 'dist'
    options:
      cache: true           # Enable caching (default)
      outputStyle: 'hash'   # Use content hashing

  # Disable cache for non-deterministic tasks
  e2e:
    command: 'playwright test'
    options:
      cache: false
```

## 3. Toolchain Management

### Toolchain Configuration

```yaml
# .moon/toolchains.yml
$schema: 'https://moonrepo.dev/schemas/toolchain.json'

# Node.js toolchain
node:
  version: '20.10.0'
  packageManager: 'pnpm'
  pnpm:
    version: '8.15.0'

# Rust toolchain
rust:
  version: '1.75.0'
  components:
    - 'clippy'
    - 'rustfmt'

# Go toolchain
go:
  version: '1.21.5'

# Python toolchain (proto integration)
python:
  version: '3.12.0'
```

### Benefits

- **Version Consistency**: Same tool versions across all developer machines and CI
- **Automatic Installation**: Tools downloaded and configured on first run
- **Dependency Hashing**: Package lock changes trigger reinstallation
- **No Manual Setup**: New team members get correct versions automatically

## 4. Cross-Language Consistency Rules

### EditorConfig for Style Consistency

```ini
# .editorconfig
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

[*.md]
trim_trailing_whitespace = false

[*.{py,rs}]
indent_size = 4

[Makefile]
indent_style = tab
```

### Unified Linting Strategy

```yaml
# .moon/tasks.yml
fileGroups:
  lintable:
    - 'src/**/*.{js,ts,tsx}'
    - 'src/**/*.py'
    - 'src/**/*.rs'

tasks:
  lint:
    command: 'echo'
    args: ['Lint not configured for this language']

# .moon/tasks/node.yml
tasks:
  lint:
    command: 'eslint'
    args: ['@group(sources)']

# .moon/tasks/python.yml
tasks:
  lint:
    command: 'ruff'
    args: ['check', '@group(sources)']

# .moon/tasks/rust.yml
tasks:
  lint:
    command: 'cargo'
    args: ['clippy', '--', '-D', 'warnings']
```

### TypeScript Project References (for JS/TS monorepos)

```json
// Root tsconfig.json
{
  "files": [],
  "references": [
    { "path": "apps/web" },
    { "path": "packages/ui" },
    { "path": "libs/utils" }
  ]
}

// packages/ui/tsconfig.json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "composite": true,
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"],
  "references": [
    { "path": "../utils" }
  ]
}
```

## 5. Supply Chain Security Practices

### SLSA Framework Compliance

**Build Provenance (SLSA Level 2+)**:

```yaml
# CI workflow generating provenance
name: Build with Provenance

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write  # Required for provenance
    steps:
      - uses: actions/checkout@v4
      - uses: moonrepo/setup-toolchain@v1

      - name: Build
        run: moon ci :build

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          format: cyclonedx-json
          output-file: sbom.json

      - name: Attest provenance
        uses: actions/attest-build-provenance@v1
        with:
          subject-path: 'dist/*'
```

### Dependency Scanning with OWASP

```yaml
# .github/workflows/security.yml
name: Security Scan

on:
  pull_request:
  schedule:
    - cron: '0 0 * * *'  # Daily scan

jobs:
  dependency-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: OWASP Dependency Check
        uses: dependency-check/Dependency-Check_Action@main
        with:
          project: 'monorepo'
          path: '.'
          format: 'ALL'

      - name: Upload report
        uses: actions/upload-artifact@v4
        with:
          name: dependency-check-report
          path: reports/
```

### Software Bill of Materials (SBOM)

```yaml
# Generate SBOM for each release
tasks:
  sbom:
    command: 'cyclonedx-npm'
    args:
      - '--output-file'
      - 'sbom.json'
    options:
      runInCI: true
```

### Dependency Update Strategy

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: 'npm'
    directory: '/'
    schedule:
      interval: 'weekly'
    groups:
      dev-dependencies:
        patterns:
          - '*'
        exclude-patterns:
          - 'react*'
          - 'typescript'
    open-pull-requests-limit: 10

  - package-ecosystem: 'cargo'
    directory: '/'
    schedule:
      interval: 'weekly'
```

## 6. Secrets Management

### GitGuardian Integration

```yaml
# .gitguardian.yml
version: 2

secret:
  # Paths to ignore
  ignored-paths:
    - '**/*.test.*'
    - '**/fixtures/**'
    - '**/__mocks__/**'

  # Custom patterns
  ignored-matches:
    - name: 'test-api-key'
      match: 'test_api_key_*'
```

### Pre-commit Secrets Scanning

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitguardian/ggshield
    rev: v1.24.0
    hooks:
      - id: ggshield
        language_version: python3
        stages: [commit]
```

### Moon Task for Secrets Scanning

```yaml
# .moon/tasks.yml
tasks:
  secrets-scan:
    command: 'ggshield'
    args:
      - 'secret'
      - 'scan'
      - 'path'
      - '.'
      - '--recursive'
    options:
      runInCI: true
      cache: false
```

### Secrets Management Best Practices

1. **Keep secrets out of source code** - Use environment variables or secret managers
2. **Use `.env.example`** - Document required variables without actual values
3. **Rotate secrets regularly** - Automate rotation where possible
4. **Audit access** - Review who has access to secrets quarterly
5. **Use short-lived credentials** - Prefer dynamic secrets over static ones

```yaml
# .moon/workspace.yml
# Environment variable passthrough for tasks
runner:
  inheritColorsForPipedTasks: true

# Define required env vars (values injected at runtime)
env:
  DATABASE_URL: null  # Must be provided
  API_KEY: null       # Must be provided
```

## 7. Code Review Checklist for Monorepo Changes

### Pre-Review Automation

```yaml
# CI tasks to run before review
tasks:
  pr-check:
    command: 'moon'
    args:
      - 'ci'
      - '--base'
      - 'origin/main'
    deps:
      - ':lint'
      - ':typecheck'
      - ':test'
      - ':secrets-scan'
```

### Review Checklist

#### Project Structure
- [ ] New projects have correct `moon.yml` configuration
- [ ] Project `language`, `type`, and `stack` are properly set
- [ ] Dependencies are explicitly declared in `dependsOn`
- [ ] Ownership is defined for accountability
- [ ] Tags are applied for filtering and organization

#### Task Configuration
- [ ] Task `inputs` accurately reflect all dependencies
- [ ] Task `outputs` are defined for cacheable tasks
- [ ] `deps` correctly specify task dependencies
- [ ] `runInCI` is appropriate for each task type
- [ ] Sensitive tasks have `cache: false` if needed

#### Cross-Project Impact
- [ ] Changes keep dependent projects working (`moon query projects --affected`)
- [ ] Shared packages have appropriate versioning strategy
- [ ] Breaking changes are documented
- [ ] Migration path provided for deprecations

#### Security
- [ ] No secrets or credentials in code
- [ ] Dependencies scanned for vulnerabilities
- [ ] New dependencies are from trusted sources
- [ ] API keys use environment variables
- [ ] Sensitive data handling follows security guidelines

#### Performance
- [ ] Build outputs are properly cached
- [ ] Large dependencies are tree-shaken where possible
- [ ] Circular dependencies are avoided
- [ ] Shared code is appropriately factored

### CI Configuration

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Required for affected detection

      - uses: moonrepo/setup-toolchain@v1
        with:
          auto-install: true

      - name: Run CI
        run: moon ci

      - name: Upload artifacts
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: moon-logs
          path: .moon/cache/states/
```

## Quick Commands Reference

```bash
# Run task across all projects
moon run :build

# Run task in specific project
moon run web:build

# Run all tasks for affected projects
moon ci

# Query affected projects
moon query projects --affected

# View project graph
moon project-graph

# View task dependencies
moon task-graph web:build

# Sync workspace (install deps, etc.)
moon sync

# Check all projects
moon check --all
```

## Common Patterns

### Affected-Only CI

```bash
# Only run tasks for projects affected by changes
moon ci --base origin/main

# Run specific tasks for affected projects
moon run :test --affected
```

### Parallel Execution

```yaml
tasks:
  test-all:
    command: 'moon'
    args:
      - 'run'
      - ':test'
      - '--concurrency'
      - '4'
```

### Project Filtering

```bash
# Run for tagged projects
moon run '#frontend:build'

# Run for project type
moon run ':test' --query 'projectType=application'
```
