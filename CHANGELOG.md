# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Major refactoring to follow industry-standard directory structure
- Renamed executables to `ubuntu-iso` and `ubuntu-iso-generate`
- Simplified to single base configuration approach
- Moved from multiple profiles to base + examples structure
- Improved dependency management and validation

### Added
- `lib/` directory for shared functions
- `share/` directory for data files
- `tests/` directory for test scripts
- Professional documentation (LICENSE, CONTRIBUTING.md)
- Environment variable support via `.env` file

### Removed
- Removed `scripts/` directory (consolidated into `lib/`)
- Removed credential injection complexity
- Removed ISO building from GitHub Actions (storage optimization)

## [1.0.0] - 2024-01-29

### Added
- Initial release with 11 pre-built profiles
- Interactive autoinstall generator
- GitHub Actions CI/CD pipeline
- Validation system with Subiquity support
- Python fallback for restricted environments
- VM testing framework
- Ubuntu update checker