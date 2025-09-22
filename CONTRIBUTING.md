# Contributing to Home Lab Docker Swarm Setup

Thank you for your interest in contributing to this project! This guide will help you get started.

## Getting Started

1. Fork the repository
2. Clone your fork locally
3. Create a new branch for your feature/fix
4. Make your changes
5. Test your changes on the target platforms
6. Submit a pull request

## Development Environment

To test the setup scripts:

1. Have access to the target platforms (Arch Linux, Windows 11, macOS)
2. Docker installed (or use the installation scripts)
3. Network connectivity between test machines

## Code Style

### Shell Scripts
- Use `#!/bin/bash` for all shell scripts
- Include `set -e` for error handling
- Use consistent indentation (2 spaces)
- Add comments for complex operations
- Use colored output functions for user feedback

### PowerShell Scripts
- Use proper error handling with try/catch blocks
- Include parameter validation
- Use consistent indentation (4 spaces)
- Add help documentation for functions

## Testing

Before submitting changes:

1. Test installation scripts on clean systems
2. Verify firewall rules work correctly
3. Test swarm initialization and joining
4. Run health checks to ensure everything works
5. Update documentation if needed

## Documentation

- Update README.md for significant changes
- Add comments to complex scripts
- Document any new requirements or dependencies
- Include troubleshooting steps for new features

## Submitting Changes

1. Ensure your code follows the style guidelines
2. Test on multiple platforms if applicable
3. Update documentation
4. Submit a pull request with a clear description of changes

## Reporting Issues

When reporting issues, please include:

- Operating system and version
- Docker version
- Error messages or logs
- Steps to reproduce the issue
- Expected vs actual behavior

## Feature Requests

Feel free to open an issue for feature requests. Include:

- Description of the feature
- Use case or problem it solves
- Any implementation ideas

## Questions

If you have questions about contributing, feel free to open an issue with the "question" label.