# CLAUDE.md - OpenSCAD App

This file provides guidance for AI assistants working on this codebase.

## Project Overview

OpenSCAD App is a native application for working with OpenSCAD files. OpenSCAD is a script-based 3D CAD modeler that uses its own description language.

## Development Guidelines

### Code Style

- Follow the established patterns in the codebase
- Use meaningful variable and function names
- Write self-documenting code with comments where necessary

### Commit Guidelines

- Use semantic commit messages
- Commit types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`
- Format: `type: short description`

### Before Committing

- Run linting and formatting if available
- Ensure tests pass
- Review changes for obvious issues

## OpenSCAD Reference

When working with OpenSCAD-related features:

- OpenSCAD uses `.scad` file extension
- The language supports modules, functions, and parametric design
- Common operations: `cube()`, `sphere()`, `cylinder()`, `union()`, `difference()`, `intersection()`
- Variables are assigned with `=` and are evaluated at compile time
- Use `$fn`, `$fa`, `$fs` for controlling mesh resolution

## Testing

- Write tests for new functionality
- Run existing tests to verify no regressions
- Cover edge cases in parametric designs

## Documentation

- Use Context7 for accurate documentation references
- Consult Apple Human Interface Guidelines for UI/UX decisions (if building native macOS/iOS app)
