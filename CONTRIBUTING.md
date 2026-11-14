# Contributing to nocterm_markdown_plus

Thank you for your interest in contributing! This document explains how to
set up the project, run the checks, and submit changes.

## Code of Conduct

By participating in this project you agree to uphold a respectful,
collaborative environment. Be kind, be constructive, and assume good faith.

## Reporting bugs

Before filing a new issue, please search existing issues to avoid
duplicates. A good bug report includes:

- A short summary and the affected version (`pubspec.yaml` `version:`)
- Steps to reproduce (minimal snippet preferred)
- Expected vs. actual behavior
- Terminal/OS and Nocterm version (`nocterm` in `pubspec.yaml`)

## Suggesting features

Open an issue describing the use case and the proposed API. For anything
touching the public API or architecture, please discuss first — this package
follows the rules in [`AGENTS.md`](AGENTS.md).

## Development setup

```bash
git clone https://github.com/AmidVoshakul/nocterm_markdown_plus.git
cd nocterm_markdown_plus
dart pub get
```

Requirements: Dart SDK `^3.13.4` (see `pubspec.yaml` `environment`).

## Running checks

```bash
dart format .            # format
dart analyze             # static analysis
dart test               # all tests
dart run tool/contrast_audit.dart  # every theme AA
```

For coverage:

```bash
dart test --coverage=coverage
dart run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info \
  --packages=.dart_tool/package_config.json --report-on=lib
```

The core + layout line coverage must stay **≥ 80%** (see `AGENTS.md`).

## Pull requests

1. Fork the repo and create a branch from `main`.
2. Keep changes focused — one concern per PR.
3. Update `CHANGELOG.md` and bump `pubspec.yaml` `version:` together.
4. Make sure all checks pass before submitting.

---

Created by [Amid Voshakul 🌠](https://github.com/AmidVoshakul)
