---
name: go-expert
description: "Go language expert for idiomatic code, best practices, and security. Use for: Go, golang, go code, go security, go review"
---

# Go Expert Skill

Expert guidance for writing idiomatic, secure, and high-quality Go code. Reference this when writing, reviewing, or debugging Go code.

## Code Style & Idioms

### Formatting
- **Always run `gofmt`** - Non-negotiable. Use `goimports` for automatic import management
- Use tabs for indentation (gofmt default)
- No line length limit, but break semantically (by logic, not character count)
- Write control structures without parentheses (`if`, `for`, `switch`)

### Naming Conventions

#### General Rules
- Use **MixedCaps** or **mixedCaps**; keep underscores out of identifiers
- Short names for local variables with limited scope (`c` not `lineCount`, `i` not `sliceIndex`)
- Longer, descriptive names for globals and exports
- Package names: lowercase, single-word, no underscores or mixedCaps

#### Initialisms
- Keep initialisms consistently cased: `URL` or `url` (consistent across the codebase)
- Examples: `ServeHTTP`, `xmlHTTPRequest`, `appID` (not `appId`)

#### Specific Naming Patterns
```go
// Receiver names: 1-2 letter abbreviation, NOT "this", "self", "me"
func (c *Client) Do() {}  // Good
func (this *Client) Do() {} // Bad

// Getters: no "Get" prefix
func (u *User) Name() string {} // Good
func (u *User) GetName() string {} // Bad - only setters use "Set"

// Interfaces: method name + "-er" suffix
type Reader interface { Read() }
type Stringer interface { String() string }

// Error variables
var ErrNotFound = errors.New("not found") // Exported
var errInternal = errors.New("internal")  // Unexported
```

#### Package Names
- Prefer descriptive package names; skip `util`, `common`, `misc`, `api`, `types`, `interfaces`
- Use non-stuttering names: `chubby.File` instead of `chubby.ChubbyFile`

### Comments & Documentation
- Doc comments are complete sentences starting with the name being declared
- End with a period
```go
// Request represents a request to run a command.
type Request struct {}

// Encode writes the JSON encoding of req to w.
func Encode(w io.Writer, req *Request) error {}
```

### Error Handling

#### Error Flow
```go
// GOOD: Handle error first, keep happy path unindented
if err != nil {
    return err
}
// normal code continues

// BAD: Nesting the happy path
if err != nil {
    // error handling
} else {
    // normal code - now nested
}
```

#### Error Strings
- Lowercase (unless proper noun/acronym)
- No punctuation at end
- Designed for composition: `fmt.Errorf("reading config: %w", err)`

#### Handle Errors Explicitly
```go
// BAD
result, _ := SomeFunction()

// GOOD
result, err := SomeFunction()
if err != nil {
    return fmt.Errorf("some function: %w", err)
}
```

### Slices & Maps

```go
// Prefer nil slice declaration
var t []string    // Good: nil slice
t := []string{}   // Use only when JSON encoding needs [] (otherwise prefer nil slices)

// Check for nil/empty uniformly
if len(slice) == 0 {} // Works for both nil and empty
```

### Context
- Always first parameter: `func F(ctx context.Context, ...) {}`
- Keep `context.Context` local to the call chain; store only for interface compliance
- Use `context.TODO()` during refactoring, `context.Background()` only at top level

### Interfaces
- Define interfaces in the **consumer** package, not the producer
- Return concrete types from functions
- Define interfaces when they are needed by a consumer
- Test with real implementations where feasible; introduce interfaces for genuine abstraction boundaries

```go
// GOOD: Interface in consumer
package consumer
type Thinger interface { Thing() bool }

// Producer returns concrete type
package producer
type Thinger struct{}
func NewThinger() *Thinger { return &Thinger{} }
```

### Concurrency

#### Goroutine Lifetimes
- Make goroutine exit conditions clear
- Prefer synchronous functions; let callers add concurrency
- Document when/why goroutines exit

#### sync.WaitGroup
```go
// GOOD: Add before goroutine
wg.Add(1)
go func() {
    defer wg.Done()
    // work
}()

// BAD: Add inside goroutine (race condition)
go func() {
    wg.Add(1)  // Race!
    defer wg.Done()
}()
```

### Receiver Type Guidelines
Use pointer receiver when:
- Method mutates receiver
- Receiver contains `sync.Mutex` or similar
- Receiver is large struct/array
- Any element is pointer to mutable data
- When in doubt

Use value receiver when:
- Receiver is map, func, or chan
- Receiver is small immutable struct (like `time.Time`)
- Receiver is basic type (int, string)

Use consistent receiver types on the same type.

## Security Best Practices

### Cryptographic Randomness
```go
// BAD: math/rand is not cryptographically secure
import "math/rand"
key := rand.Int()

// GOOD: Use crypto/rand
import "crypto/rand"
key := rand.Text()  // For text keys
// Or for bytes:
buf := make([]byte, 32)
rand.Read(buf)
```

### Input Validation
- Validate all external input before use
- Use allowlists over denylists
- Sanitize data for its destination context (SQL, HTML, shell)

### SQL Injection Prevention
```go
// BAD: String concatenation
query := "SELECT * FROM users WHERE id = " + userInput

// GOOD: Parameterized queries
db.Query("SELECT * FROM users WHERE id = ?", userInput)
```

### Path Traversal Prevention
```go
// Validate file paths
func SafePath(base, userInput string) (string, error) {
    cleaned := filepath.Clean(userInput)
    fullPath := filepath.Join(base, cleaned)
    if !strings.HasPrefix(fullPath, filepath.Clean(base)+string(os.PathSeparator)) {
        return "", errors.New("path traversal detected")
    }
    return fullPath, nil
}
```

### HTTP Security
```go
// Set timeouts on HTTP server
srv := &http.Server{
    ReadTimeout:  5 * time.Second,
    WriteTimeout: 10 * time.Second,
    IdleTimeout:  120 * time.Second,
}

// Use buffered channels for signal handling
sigChan := make(chan os.Signal, 1) // Buffered!
signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
```

### Secrets Management
- Keep secrets out of source code
- Use environment variables or secret managers
- Keep sensitive data out of logs
- Clear sensitive data from memory when done

### Vulnerability Scanning
```bash
# Install and run govulncheck
go install golang.org/x/vuln/cmd/govulncheck@latest
govulncheck ./...

# Keep dependencies updated
go get -u ./...
go mod tidy
```

## Tooling Recommendations

### Essential Tools
| Tool | Purpose | Usage |
|------|---------|-------|
| `gofmt` | Format code | `gofmt -w .` |
| `goimports` | Format + manage imports | `goimports -w .` |
| `go vet` | Find suspicious constructs | `go vet ./...` |
| `staticcheck` | Advanced static analysis | `staticcheck ./...` |
| `govulncheck` | Security vulnerabilities | `govulncheck ./...` |

### Staticcheck Key Checks
- **SA1**: Standard library misuse
- **SA2**: Concurrency issues (WaitGroup races, empty critical sections)
- **SA4**: Dead code detection
- **SA5**: Correctness (nil map assignment, infinite recursion)
- **SA6**: Performance issues
- **ST1**: Style violations

### Testing Tools
```bash
# Run tests with race detector
go test -race ./...

# Run tests with coverage
go test -cover ./...

# Fuzz testing (Go 1.18+)
go test -fuzz=FuzzMyFunc ./...
```

## Common Pitfalls

### Common Mistakes and How to Prevent Them

1. **Loop variable capture in goroutines**
```go
// BAD (before Go 1.22)
for _, v := range values {
    go func() {
        fmt.Println(v) // All goroutines see last value
    }()
}

// GOOD
for _, v := range values {
    v := v // Shadow variable
    go func() {
        fmt.Println(v)
    }()
}
```

2. **Nil map assignment**
```go
// BAD: Panic
var m map[string]int
m["key"] = 1

// GOOD
m := make(map[string]int)
m["key"] = 1
```

3. **Defer in loops**
```go
// BAD: Resources held until function ends
for _, f := range files {
    file, _ := os.Open(f)
    defer file.Close() // Doesn't close until function returns!
}

// GOOD: Wrap in function or close explicitly
for _, f := range files {
    func() {
        file, _ := os.Open(f)
        defer file.Close()
        // process
    }()
}
```

4. **time.Tick leak** (pre-Go 1.23)
```go
// BAD: time.Tick leaks because the ticker is not stopped
for range time.Tick(time.Second) {}

// GOOD
ticker := time.NewTicker(time.Second)
defer ticker.Stop()
for range ticker.C {}
```

5. **Using `==` for time comparison**
```go
// BAD: May fail due to monotonic clock
if t1 == t2 {}

// GOOD
if t1.Equal(t2) {}
```

6. **Modifying slice during iteration**
```go
// BAD: Undefined behavior
for i, v := range slice {
    if condition(v) {
        slice = append(slice[:i], slice[i+1:]...)
    }
}
```

7. **Struct copying with mutex**
```go
// BAD: Copies mutex
type Config struct {
    mu sync.Mutex
    data string
}
c2 := c1 // Copies the mutex!

// GOOD: Use pointer receivers; keep types with mutexes non-copyable
```

## Code Review Checklist

### Before Approving Go Code, Verify:

**Correctness**
- [ ] All errors handled (no `_` for errors)
- [ ] No data races (run with `-race`)
- [ ] Goroutine lifetimes documented/clear
- [ ] Context passed correctly (first param)
- [ ] No nil pointer dereferences

**Security**
- [ ] No hardcoded secrets
- [ ] Input validated before use
- [ ] SQL uses parameterized queries
- [ ] File paths sanitized
- [ ] Using crypto/rand for security-sensitive randomness

**Style**
- [ ] Code formatted with gofmt
- [ ] Naming follows conventions
- [ ] Doc comments for exported items
- [ ] Error strings lowercase, no punctuation
- [ ] Imports organized (std lib first)

**Performance**
- [ ] No regexp.Match in loops (use Compile)
- [ ] Appropriate use of pointers vs values
- [ ] sync.Pool for frequent allocations
- [ ] Pre-allocate slices when size known

**Testing**
- [ ] Tests cover critical paths
- [ ] Test failures are descriptive: `got X, want Y`
- [ ] Table-driven tests where appropriate
- [ ] Fuzz tests for parsing functions

### Quick Commands for Review
```bash
# Run all checks
gofmt -d .
go vet ./...
staticcheck ./...
go test -race ./...
govulncheck ./...
```

## References

- [Effective Go](https://go.dev/doc/effective_go)
- [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments)
- [Go Security Best Practices](https://go.dev/doc/security/best-practices)
- [OWASP Go-SCP](https://owasp.org/www-project-go-secure-coding-practices-guide/)
- [Staticcheck Docs](https://staticcheck.dev/docs/)
- [Google Go Style Guide](https://google.github.io/styleguide/go/decisions)
