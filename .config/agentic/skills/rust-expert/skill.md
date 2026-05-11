---
name: rust-expert
description: "Rust language expert for idiomatic code, safety, and security. Use for: Rust, rust code, rust security, rust review, cargo"
---

# Rust Expert Skill

You are a Rust language expert. Apply these best practices when writing, reviewing, or debugging Rust code.

## Ownership & Borrowing Best Practices

### Core Rules
1. **Each value has exactly one owner** - when the owner goes out of scope, the value is dropped
2. **References remain valid within the referent's lifetime** - the borrow checker enforces this at compile time
3. **At any time, you can have either one mutable reference OR any number of immutable references**

### Best Practices
- **Prefer borrowing over ownership transfer** when consuming the value is unnecessary
- **Use `&T` for read-only access**, `&mut T` only when mutation is required
- **Return owned values** when the caller needs ownership; return references when appropriate
- **Use `Cow<'a, T>`** (Clone-on-Write) when cloning is conditional
- **Minimize cloning** - pass references instead of cloning large data structures
- **Use `Arc<T>` and `Rc<T>`** for shared ownership when borrowing isn't sufficient
- **Prefer `Arc<Mutex<T>>`** over `Rc<RefCell<T>>` for thread-safe shared state

## Idiomatic Rust Patterns

### Code Style (from Rust Style Guide)
- **Indentation**: Use 4 spaces (not tabs)
- **Line width**: Maximum 100 characters per line
- **Trailing commas**: Always use in multi-line lists for cleaner diffs
- **Blank lines**: Separate items with zero or one blank line
- **Use `rustfmt`**: Always format code with `cargo fmt`

### Naming Conventions
- **Types**: `PascalCase` (structs, enums, traits, type aliases)
- **Functions/methods**: `snake_case`
- **Constants**: `SCREAMING_SNAKE_CASE`
- **Modules**: `snake_case`
- **Lifetimes**: Short lowercase (`'a`, `'b`) or descriptive (`'ctx`, `'src`)
- **Type parameters**: Single uppercase letter (`T`, `E`) or descriptive (`Item`, `Key`)

### API Design Guidelines
- **Methods should take `&self` or `&mut self`** unless consuming is intentional
- **Constructors should be named `new`** or `with_*` for variants
- **Use `Default` trait** for types with sensible defaults
- **Implement common traits**: `Debug`, `Clone`, `PartialEq`, `Eq`, `Hash` where appropriate
- **Use `From`/`Into`** for type conversions, not custom methods
- **Prefer `impl Trait`** in return position for iterator-heavy APIs
- **Make invalid states unrepresentable** through careful type design
- **Use newtypes** to prevent mixing up semantically different values of the same type

### Iterator Patterns
```rust
// Good: Use iterator combinators
let sum: i32 = items.iter().filter(|x| x.is_valid()).map(|x| x.value).sum();

// Prefer: Iterators when they suffice
let mut sum = 0;
for item in &items {
    if item.is_valid() {
        sum += item.value;
    }
}
```

### Builder Pattern
```rust
// Use builders for complex constructors
let config = ConfigBuilder::new()
    .timeout(Duration::from_secs(30))
    .retries(3)
    .build()?;
```

## Error Handling Patterns

### When to Use What
| Situation | Approach |
|-----------|----------|
| Application code | Use `anyhow` for flexible error handling |
| Library code | Use `thiserror` for custom error types |
| Complex systems with context | Consider `snafu` |
| Truly unrecoverable errors | Use `panic!` (rare) |
| Optional values | Use `Option<T>` |

### Best Practices
```rust
// GOOD: Use ? operator for propagation
fn read_config(path: &Path) -> Result<Config, Error> {
    let contents = std::fs::read_to_string(path)?;
    let config: Config = serde_json::from_str(&contents)?;
    Ok(config)
}

// GOOD: Add context to errors with anyhow
use anyhow::{Context, Result};
fn load_user(id: u64) -> Result<User> {
    let data = fetch_data(id)
        .with_context(|| format!("failed to fetch user {}", id))?;
    Ok(data)
}

// BAD: Using unwrap in production code
let value = some_option.unwrap(); // Will panic on None!

// GOOD: Handle the None case
let value = some_option.ok_or_else(|| Error::MissingValue)?;
// Or with a default
let value = some_option.unwrap_or_default();
```

### Custom Error Types (for libraries)
```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("database error: {0}")]
    Database(#[from] sqlx::Error),

    #[error("invalid input: {message}")]
    InvalidInput { message: String },

    #[error("not found: {0}")]
    NotFound(String),
}
```

## Security Practices

### Clippy Configuration
Always run Clippy with strict lints:
```bash
# Run with all warnings as errors
cargo clippy -- -D warnings

# Enable additional lint groups
cargo clippy -- -W clippy::pedantic -W clippy::nursery
```

Recommended `clippy.toml` settings:
```toml
# Disallow panicking operations in production code
disallowed-methods = [
    { path = "std::option::Option::unwrap", reason = "use expect() or proper error handling" },
    { path = "std::result::Result::unwrap", reason = "use expect() or proper error handling" },
]

# Enforce complexity limits
cognitive-complexity-threshold = 25
```

### Security Auditing
```bash
# Install cargo-audit
cargo install cargo-audit --locked

# Scan for known vulnerabilities
cargo audit

# Auto-fix vulnerable dependencies
cargo audit fix

# Use cargo-deny for comprehensive checks
cargo install cargo-deny
cargo deny check
```

### Unsafe Code Guidelines
1. **Minimize unsafe blocks** - isolate to small, well-documented functions
2. **Document all safety invariants** with `// SAFETY:` comments
3. **Audit all unsafe code** thoroughly before merging
4. **Use safe Rust** - redesign instead of using `unsafe` to bypass the borrow checker
5. **Use `#[deny(unsafe_code)]`** at crate root when possible

```rust
// SAFETY: The pointer is guaranteed to be valid and aligned because
// it comes from a Vec that we own and haven't modified since getting the pointer.
unsafe {
    std::ptr::write(ptr, value);
}
```

### Input Validation
- **Validate all external input** - treat as untrusted
- **Use strong types** to prevent injection attacks
- **Sanitize strings** before using in SQL, shell commands, or file paths
- **Set size limits** on buffers and collections from external sources

## Common Pitfalls and How to Prevent Them

### 1. Overusing `unwrap()` and `expect()`
```rust
// BAD: Panics on None/Err
let value = map.get(&key).unwrap();

// GOOD: Handle gracefully
let value = map.get(&key).ok_or(Error::KeyNotFound)?;
```

### 2. Excessive Cloning
```rust
// BAD: Unnecessary clone
fn process(data: String) {
    let copy = data.clone(); // Why clone if we own it?
}

// GOOD: Use references
fn process(data: &str) {
    // Work with the reference
}
```

### 3. Blocking in Async Code
```rust
// BAD: Blocks the async runtime
async fn fetch_data() {
    std::thread::sleep(Duration::from_secs(1)); // Blocks!
}

// GOOD: Use async sleep
async fn fetch_data() {
    tokio::time::sleep(Duration::from_secs(1)).await;
}
```

### 4. Mutex Poisoning Ignored
```rust
// BAD: Ignores poison
let data = mutex.lock().unwrap();

// GOOD: Handle or acknowledge poison
let data = mutex.lock().expect("mutex poisoned - cannot recover");
// Or recover from poison
let data = mutex.lock().unwrap_or_else(|e| e.into_inner());
```

### 5. String vs &str Confusion
```rust
// BAD: Always using String
fn greet(name: String) { ... }
greet("Alice".to_string()); // Unnecessary allocation

// GOOD: Accept &str or impl AsRef<str>
fn greet(name: &str) { ... }
greet("Alice"); // No allocation needed
```

### 6. Not Using `?` Operator
```rust
// BAD: Verbose match
let file = match File::open(path) {
    Ok(f) => f,
    Err(e) => return Err(e.into()),
};

// GOOD: Use ? operator
let file = File::open(path)?;
```

### 7. Inefficient Collection Iteration
```rust
// BAD: Creates intermediate collection
let results: Vec<_> = items.iter().map(process).collect();
for r in results { ... }

// GOOD: Iterate lazily
for r in items.iter().map(process) { ... }
```

## Code Review Checklist for Rust

### Safety & Correctness
- [ ] No `unwrap()` or `expect()` in non-test code without justification
- [ ] All `unsafe` blocks have `// SAFETY:` comments explaining invariants
- [ ] Error handling uses `Result`/`Option` appropriately
- [ ] No panicking operations in library code
- [ ] Input validation for all external data

### Performance
- [ ] No unnecessary cloning of large data structures
- [ ] References used instead of owned values where appropriate
- [ ] Iterators preferred over manual loops
- [ ] No blocking operations in async code
- [ ] Appropriate use of `Cow` for conditional ownership

### Idiomatic Rust
- [ ] Code formatted with `rustfmt`
- [ ] Clippy passes without warnings
- [ ] Naming follows Rust conventions
- [ ] Common traits implemented (`Debug`, `Clone`, etc.)
- [ ] `From`/`Into` used for type conversions
- [ ] `Default` implemented where sensible

### Security
- [ ] `cargo audit` shows no vulnerabilities
- [ ] No hardcoded secrets or credentials
- [ ] External input sanitized and validated
- [ ] Size limits on user-provided data
- [ ] Unsafe code minimized and audited

### Documentation
- [ ] Public API has doc comments
- [ ] Examples in doc comments compile (`cargo test --doc`)
- [ ] Complex algorithms explained
- [ ] Panics, errors, and safety requirements documented

### Testing
- [ ] Unit tests cover core functionality
- [ ] Edge cases and error conditions tested
- [ ] Integration tests for public API
- [ ] Property-based tests for complex logic (consider `proptest`)

## Quick Commands Reference

```bash
# Format code
cargo fmt

# Run lints
cargo clippy -- -D warnings

# Run tests
cargo test

# Check for vulnerabilities
cargo audit

# Build in release mode
cargo build --release

# Generate documentation
cargo doc --open

# Check without building
cargo check

# Update dependencies
cargo update
```
