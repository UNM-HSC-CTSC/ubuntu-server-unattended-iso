# Contributing to Ubuntu Server Unattended ISO Builder

Thank you for your interest in contributing to this project! We welcome contributions of all kinds.

## How to Contribute

### Reporting Issues

1. Check if the issue already exists in [GitHub Issues](https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso/issues)
2. Create a new issue with:
   - Clear description of the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (OS, Python version, etc.)

### Suggesting Features

1. Check [existing issues](https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso/issues) and [discussions](https://github.com/UNM-HSC-CTSC/ubuntu-server-unattended-iso/discussions)
2. Open a discussion or issue describing:
   - The feature you'd like to see
   - Use cases for the feature
   - How it fits with the project goals

### Code Contributions

1. **Fork the repository**
   ```bash
   gh repo fork UNM-HSC-CTSC/ubuntu-server-unattended-iso
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow the existing code style
   - Add tests for new functionality
   - Update documentation as needed

4. **Test your changes**
   ```bash
   ./test.sh
   ```

5. **Commit with descriptive messages**
   ```bash
   git commit -m "Add feature: description of what you added"
   ```

6. **Push and create a pull request**
   ```bash
   git push origin feature/your-feature-name
   gh pr create
   ```

## Development Guidelines

### Code Style

- Use 4 spaces for indentation in shell scripts
- Follow shellcheck recommendations
- Add comments for complex logic
- Use meaningful variable names

### Testing

- All new features should include tests
- Run `./test.sh` before submitting PR
- Ensure CI passes on your PR

### Documentation

- Update README.md for user-facing changes
- Add inline comments for complex code
- Update CLAUDE.md for architectural changes

## Project Structure

- `bin/` - User-facing executables
- `lib/` - Shared library functions
- `share/` - Data files and examples
- `tests/` - Test scripts
- `.github/` - GitHub Actions workflows

## Questions?

Feel free to open a discussion if you have questions about contributing.