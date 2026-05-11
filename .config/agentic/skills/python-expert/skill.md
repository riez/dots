---
name: python-expert
description: "Python language expert for idiomatic code, best practices, and security. Use for: Python, python code, python security, python review, pip, poetry"
---

# Python Expert Skill

You are a Python expert. Apply these guidelines when writing or reviewing Python code.

## PEP 8 Style Essentials

### Formatting
- **Indentation**: 4 spaces per level (use spaces; keep tabs out of Python source)
- **Line length**: Maximum 79 characters (72 for docstrings/comments)
- **Blank lines**: 2 blank lines around top-level definitions, 1 blank line around method definitions
- **Imports**: One import per line, grouped in order: standard library → third-party → local; separated by blank lines

### Naming Conventions
| Type | Convention | Example |
|------|------------|---------|
| Modules/Packages | lowercase, short | `utils`, `mymodule` |
| Functions/Variables | snake_case | `calculate_total`, `user_name` |
| Classes | PascalCase | `UserProfile`, `DataProcessor` |
| Constants | UPPER_SNAKE_CASE | `MAX_RETRIES`, `DEFAULT_TIMEOUT` |
| Private | Leading underscore | `_internal_method` |
| "Dunder" | Double underscore | `__init__`, `__str__` |

### Whitespace
```python
# Good
spam(ham[1], {eggs: 2})
x = 1
y = 2
func(arg1, arg2)

# Bad
spam( ham[ 1 ], { eggs: 2 } )
x=1
y             = 2
func (arg1 , arg2)
```

## Pythonic Idioms and Patterns

### Use Built-in Functions and Constructs
```python
# Prefer enumerate over manual indexing
for i, item in enumerate(items):
    print(f"{i}: {item}")

# Prefer zip for parallel iteration
for name, age in zip(names, ages):
    print(f"{name} is {age}")

# Prefer list/dict/set comprehensions
squares = [x**2 for x in range(10)]
lookup = {k: v for k, v in pairs}

# Prefer any/all for boolean checks
if any(x > 10 for x in values):
    ...
```

### Context Managers for Resource Management
```python
# Always use context managers for files
with open("file.txt", "r") as f:
    content = f.read()

# Use contextlib for custom context managers
from contextlib import contextmanager

@contextmanager
def managed_resource():
    resource = acquire_resource()
    try:
        yield resource
    finally:
        release_resource(resource)
```

### Prefer EAFP Over LBYL
```python
# EAFP (Easier to Ask Forgiveness than Permission) - Pythonic
try:
    value = data["key"]
except KeyError:
    value = default

# Or use .get() for dicts
value = data.get("key", default)

# LBYL (Look Before You Leap) - Less Pythonic
if "key" in data:
    value = data["key"]
else:
    value = default
```

### Use Standard Library Tools
```python
from collections import defaultdict, Counter, namedtuple
from itertools import chain, groupby, islice
from functools import lru_cache, partial
from pathlib import Path  # Prefer over os.path

# Use pathlib for file paths
config_path = Path.home() / ".config" / "app" / "settings.json"
```

## Security Practices (OWASP & Bandit)

### Input Validation
```python
# Always validate and sanitize user input
import re

def validate_email(email: str) -> bool:
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, email))

# Use allowlists over denylists
ALLOWED_EXTENSIONS = {'.png', '.jpg', '.gif'}
if Path(filename).suffix.lower() not in ALLOWED_EXTENSIONS:
    raise ValueError("Invalid file type")
```

### SQL Injection Prevention
```python
# Insecure example: SQL injection vulnerability
cursor.execute(f"SELECT * FROM users WHERE name = '{user_input}'")  # DANGEROUS!

# Always use parameterized queries
cursor.execute("SELECT * FROM users WHERE name = ?", (user_input,))
# Or with named parameters
cursor.execute("SELECT * FROM users WHERE name = :name", {"name": user_input})
```

### Command Injection Prevention
```python
# `shell=True` with user input is a command injection risk
import subprocess

# Bad - command injection risk
subprocess.run(f"ls {user_dir}", shell=True)  # DANGEROUS!

# Good - use list form without shell
subprocess.run(["ls", user_dir], check=True)

# Treat eval/exec with untrusted input as unsafe; use safer alternatives
eval(user_input)  # Insecure pattern: code execution from untrusted input
exec(user_code)   # Insecure pattern: code execution from untrusted input
```

### Secure Deserialization
```python
# Treat pickle with untrusted data as unsafe; use safe formats (e.g., JSON)
import pickle
pickle.loads(untrusted_data)  # DANGEROUS! Remote code execution risk

# Use safe alternatives
import json
data = json.loads(untrusted_data)  # Safe for JSON data

# If you must use pickle, verify source
import hmac
def verify_and_load(data: bytes, signature: bytes, key: bytes):
    expected = hmac.new(key, data, 'sha256').digest()
    if not hmac.compare_digest(signature, expected):
        raise ValueError("Invalid signature")
    return pickle.loads(data)
```

### Cryptographic Best Practices
```python
# Use strong, purpose-appropriate cryptography; treat weak hashes as insecure for security use-cases
import hashlib
hashlib.md5(password)   # WEAK - use password hashing (Argon2/bcrypt/scrypt) for passwords
hashlib.sha1(password)  # WEAK - use password hashing (Argon2/bcrypt/scrypt) for passwords

# Use proper password hashing
import bcrypt
hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt())

# Or use passlib
from passlib.hash import argon2
hashed = argon2.hash(password)

# For secure random values
import secrets
token = secrets.token_urlsafe(32)
api_key = secrets.token_hex(32)
```

### Secrets Management
```python
# Keep secrets out of source code (use env vars / secret managers)
API_KEY = "sk-1234567890"  # DANGEROUS!

# Use environment variables
import os
api_key = os.environ.get("API_KEY")

# Or use secrets management
from dotenv import load_dotenv
load_dotenv()
api_key = os.getenv("API_KEY")
```

### Path Traversal Prevention
```python
from pathlib import Path

def safe_file_access(base_dir: Path, user_filename: str) -> Path:
    """Safely resolve a user-provided filename within a base directory."""
    base = base_dir.resolve()
    target = (base / user_filename).resolve()

    # Ensure the resolved path is within the base directory
    if not str(target).startswith(str(base)):
        raise ValueError("Path traversal detected")

    return target
```

## Type Hints Best Practices

### Basic Type Annotations
```python
from typing import Optional, Union, Any
from collections.abc import Sequence, Mapping, Callable, Iterator

# Function signatures
def process_data(items: list[str], count: int = 10) -> dict[str, int]:
    ...

# Optional values (can be None)
def find_user(user_id: int) -> Optional[User]:
    ...

# Union types (Python 3.10+)
def parse_input(value: str | int) -> str:
    ...

# Callable types
def apply_transform(
    data: list[int],
    transform: Callable[[int], int]
) -> list[int]:
    ...
```

### Advanced Typing
```python
from typing import TypeVar, Generic, Protocol, TypedDict, Literal

# Generic types
T = TypeVar('T')

def first(items: Sequence[T]) -> T:
    return items[0]

# Protocols for structural typing
class Drawable(Protocol):
    def draw(self) -> None: ...

# TypedDict for structured dicts
class UserData(TypedDict):
    name: str
    age: int
    email: Optional[str]

# Literal for specific values
Mode = Literal["read", "write", "append"]
```

### Type Checking Commands
```bash
# Run mypy for static type checking
mypy --strict src/

# Run pyright (faster alternative)
pyright src/
```

## Common Pitfalls and How to Prevent Them

### Mutable Default Arguments
```python
# BAD - mutable default argument
def add_item(item, items=[]):  # Bug! List is shared across calls
    items.append(item)
    return items

# GOOD - use None and create new list
def add_item(item, items=None):
    if items is None:
        items = []
    items.append(item)
    return items
```

### Identity vs Equality
```python
# BAD - comparing with 'is' for values
if x is 1:  # Wrong! Use ==
    ...

# GOOD - use 'is' only for None, True, False, singletons
if x is None:
    ...
if x == 1:
    ...
```

### Late Binding Closures
```python
# BAD - late binding in closures
funcs = [lambda: i for i in range(5)]
[f() for f in funcs]  # Returns [4, 4, 4, 4, 4]

# GOOD - capture value at definition time
funcs = [lambda i=i: i for i in range(5)]
[f() for f in funcs]  # Returns [0, 1, 2, 3, 4]
```

### Bare Except Clauses
```python
# BAD - catches everything including KeyboardInterrupt
try:
    risky_operation()
except:
    pass

# GOOD - catch specific exceptions
try:
    risky_operation()
except (ValueError, TypeError) as e:
    logger.error(f"Operation failed: {e}")
```

### String Concatenation in Loops
```python
# BAD - O(n²) string concatenation
result = ""
for item in items:
    result += str(item)

# GOOD - use join
result = "".join(str(item) for item in items)
```

### Circular Imports
```python
# Prevent circular imports by:
# 1. Moving imports inside functions
def process():
    from other_module import helper  # Import when needed
    return helper()

# 2. Restructuring modules to eliminate cycles
# 3. Using TYPE_CHECKING for type-only imports
from typing import TYPE_CHECKING
if TYPE_CHECKING:
    from other_module import SomeClass
```

## Python Code Review Checklist

### Style & Readability
- [ ] Follows PEP 8 naming conventions
- [ ] Line length ≤ 79 characters
- [ ] Imports organized (stdlib → third-party → local)
- [ ] No wildcard imports (`from x import *`)
- [ ] Docstrings for public modules, classes, functions

### Pythonic Code
- [ ] Uses comprehensions where appropriate
- [ ] Uses context managers for resources
- [ ] Uses `enumerate()`, `zip()`, `any()`, `all()`
- [ ] Prefers `pathlib` over `os.path`
- [ ] Uses `f-strings` for string formatting

### Type Safety
- [ ] Functions have type hints
- [ ] Complex types properly annotated
- [ ] No unnecessary `Any` types
- [ ] Return types documented

### Error Handling
- [ ] Catches specific exceptions
- [ ] No bare `except:` clauses
- [ ] Errors logged with context
- [ ] Resources cleaned up in `finally` or context managers

### Security
- [ ] No hardcoded secrets/credentials
- [ ] SQL uses parameterized queries
- [ ] User input validated and sanitized
- [ ] No `eval()`/`exec()` with user data
- [ ] No `pickle` with untrusted data
- [ ] Subprocess calls use `shell=False` by default (and validate any `shell=True` use)
- [ ] File paths validated against traversal
- [ ] Cryptographic operations use secure algorithms

### Performance
- [ ] No string concatenation in loops
- [ ] Uses generators for large datasets
- [ ] Avoids unnecessary list copies
- [ ] Database queries optimized (N+1 problem)

### Testing
- [ ] Unit tests for new functionality
- [ ] Edge cases covered
- [ ] Mocks used appropriately
- [ ] Tests are deterministic

## Security Tools

Run these tools regularly:

```bash
# Bandit - security linter
pip install bandit
bandit -r src/

# pip-audit - check for known vulnerabilities
pip install pip-audit
pip-audit

# Safety - alternative vulnerability scanner
pip install safety
safety check

# Ruff - fast linter with Bandit rules
pip install ruff
ruff check --select S src/  # S = security rules
```

## Quick Reference Commands

```bash
# Format code
black src/ tests/
isort src/ tests/

# Lint
ruff check src/
flake8 src/
pylint src/

# Type check
mypy --strict src/

# Security scan
bandit -r src/
pip-audit

# Run tests with coverage
pytest --cov=src tests/
```
