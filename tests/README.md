# Writhdeck Test Suite

This directory contains regression tests to ensure code quality and prevent bugs.

## Running Tests

From the project root, run:

```bash
make test              # Run all tests
make test-i18n        # Test translations only
make test-syntax      # Test Tcl syntax only
make test-gui         # Test GUI build only
make test-cli         # Test CLI build only
make test-langs       # Test different language combinations
```

## Test Files

### test-i18n.tcl
Validates the i18n translation system:
- Checks that all language files have complete translations
- Verifies no duplicate or extra keys exist
- Ensures format strings (%s, %d) are consistent across languages
- Detects missing translations that would cause runtime errors

**Example output:**
```
✓ en: 122 keys (complete)
✓ fr: 122 keys (complete)
✓ All format strings are consistent
```

### test-syntax.tcl
Checks Tcl syntax in all source files:
- Parses each .tcl file for syntax errors
- Uses `info complete` to detect incomplete or invalid Tcl
- Catches errors early before runtime

**Coverage:**
- src/*.tcl (main source modules)
- src/i18n/*.tcl (translation files)

## What Tests Catch

✅ Missing or incomplete translations in any language
✅ Format string mismatches (e.g., wrong number of %s)
✅ Tcl syntax errors
✅ Build failures with different language combinations
✅ GUI/CLI mode loading failures
✅ Broken polyglot sh/Tcl bootstrap

## Adding New Tests

1. Create a new test file in this directory (e.g., `test-feature.tcl`)
2. Add a corresponding target in the Makefile
3. Add the target to the `test:` target dependencies

Example:
```makefile
test-feature:
	@echo "Testing feature..."
	@tclsh tests/test-feature.tcl
```

## CI/CD Integration

These tests are designed to run in continuous integration:
- Fast execution (completes in seconds)
- Non-interactive (no user input required)
- Clear pass/fail output
- Exit code 0 on success, non-zero on failure

## Troubleshooting

**"ERROR: No language files found"**
- Make sure you're running tests from the project root
- Check that src/i18n/ directory exists

**"Syntax error in src/file.tcl"**
- Review the file for incomplete braces, brackets, or quotes
- Use a Tcl linter or editor with syntax checking

**Test timeout or hang**
- Check for infinite loops in source files
- Ensure no interactive commands in tested files
