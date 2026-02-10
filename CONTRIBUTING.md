# Contributing Guide

## Branching Strategy

This project follows **GitFlow** for branch management:

### Main Branches
- `main` - Production-ready code, tagged releases
- `develop` - Integration branch for ongoing development

### Supporting Branches
- `feature/*` - New features or enhancements
- `bugfix/*` - Non-critical bug fixes
- `hotfix/*` - Critical production fixes
- `release/*` - Release preparation

## Workflow

### Starting New Work

```bash
# Update develop branch
git checkout develop
git pull origin develop

# Create feature branch
git checkout -b feature/your-feature-name
```

### Committing Changes

Use conventional commit messages:

```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks
- `perf`: Performance improvements

**Example:**
```bash
git commit -m "feat: add customer segmentation query

Implement RFM analysis query for customer segmentation.
Includes recency, frequency, and monetary value calculations.

Closes #42"
```

### Merging to Develop

```bash
# Ensure your branch is up to date
git checkout develop
git pull origin develop
git checkout feature/your-feature-name
git rebase develop

# Merge to develop
git checkout develop
git merge --no-ff feature/your-feature-name
git push origin develop

# Delete feature branch
git branch -d feature/your-feature-name
```

### Creating a Release

```bash
# Create release branch from develop
git checkout -b release/v1.0.0 develop

# Bump version, update CHANGELOG
# Test thoroughly

# Merge to main
git checkout main
git merge --no-ff release/v1.0.0
git tag -a v1.0.0 -m "Release version 1.0.0"

# Merge back to develop
git checkout develop
git merge --no-ff release/v1.0.0

# Push everything
git push origin main develop --tags
git branch -d release/v1.0.0
```

### Hotfixes

```bash
# Create hotfix from main
git checkout -b hotfix/critical-bug main

# Fix the issue, commit
git commit -m "fix: resolve data duplication in fact table"

# Merge to main
git checkout main
git merge --no-ff hotfix/critical-bug
git tag -a v1.0.1 -m "Hotfix version 1.0.1"

# Merge to develop
git checkout develop
git merge --no-ff hotfix/critical-bug

# Push and cleanup
git push origin main develop --tags
git branch -d hotfix/critical-bug
```

## Code Review Guidelines

- All changes require review before merging to `develop`
- Ensure tests pass
- Update documentation as needed
- Keep commits atomic and well-described
- Rebase feature branches to keep history clean

## Testing Requirements

Before submitting:
- Run `dbt test` for data quality checks
- Run `terraform validate` for infrastructure changes
- Verify queries return expected results
- Check for PII or sensitive data in commits
