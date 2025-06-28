# OpenCode.md

## Build/Test/Lint Commands
- **Build**: Not applicable, focused on environment setup.
- **Test**: Run individual tests through `nvim` or `uv` commands as configured.
- **Lint**: Use `brew lint` and `nvim stylua` for formatting and validation.

## Code Style Guidelines

### General Conventions
- Follow shell scripting best practices for `*.sh` files.
- Prefer readable and idiomatic shell constructs; avoid unnecessary complexity.

### Imports and Dependencies
- All dependencies or external tools used in `*.sh` scripts must be explicitly defined.
- Use relative paths where possible for referencing files in the repo.

### Formatting and Comments
- Indent with 2 spaces.
- Comment complex logic generously but avoid unnecessary inline comments.

### Naming
- Use snake_case for variables and file names. Use ALL_CAPS for constants.
- Functions should start with verbs (e.g., `load_config`, `save_state`).

### Error Handling
- Check return values for commands using `if` or `set -e`.
- Use `trap` for cleanup tasks in case of failures.

### Types
- Use meaningful variable names to imply type as shell scripts don't support native type enforcement.

### Misc
- Use `readonly` for constants to prevent reassignment.
- Build upon existing scripts where possible to maintain consistency.
