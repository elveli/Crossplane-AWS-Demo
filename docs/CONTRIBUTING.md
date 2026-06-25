# Contributing to Crossplane AWS Demo

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

- Be respectful and inclusive
- No harassment, discrimination, or hate speech
- Assume good faith in discussions
- Focus on ideas, not people

## How to Contribute

### Reporting Bugs

1. **Check existing issues** to avoid duplicates
2. **Use the bug report template**:
```markdown
## Description
Clear description of the issue

## Steps to Reproduce
1. 
2. 
3. 

## Expected Behavior
What should happen

## Actual Behavior
What actually happened

## Environment
- OS: macOS/Linux/Windows
- Node version: 20.x
- npm version: 9.x
- Docker version (if applicable): 24.x

## Logs/Error Messages
```
Include any relevant error messages or logs
```
```

3. **Be specific**: Include versions, reproduction steps, and error messages

### Suggesting Enhancements

1. **Check existing discussions** to avoid duplicates
2. **Describe the enhancement**:
   - What problem does it solve?
   - How would it work?
   - What are the benefits?
3. **Provide examples** if applicable

### Pull Requests

#### Before You Start

1. Fork the repository
2. Create a feature branch:
```bash
git checkout -b feature/your-feature-name
```

3. Set up development environment:
```bash
npm install
npm run lint
```

#### Development Workflow

```bash
# Create feature branch
git checkout -b feature/add-dark-mode

# Make your changes
# Keep commits atomic and focused

# Run type checking
npm run lint

# Build to verify
npm run build

# Commit with meaningful messages
git commit -m "feat: add dark mode toggle to file viewer"
```

#### Commit Message Guidelines

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` A new feature (triggers minor version bump)
- `fix:` A bug fix (triggers patch version bump)
- `docs:` Documentation changes
- `style:` Code style changes (formatting, missing semicolons, etc.)
- `refactor:` Code refactoring without feature/bug changes
- `perf:` Performance improvements
- `test:` Adding or updating tests
- `ci:` CI/CD configuration changes
- `chore:` Dependency updates, build config changes

Examples:
```bash
git commit -m "feat: add search functionality to file tree"
git commit -m "fix: handle error boundary in App component"
git commit -m "docs: update deployment guide with K8s examples"
git commit -m "refactor: extract file loading logic to custom hook"
git commit -m "perf: implement virtual scrolling for large file trees"
```

#### Push and Create PR

```bash
# Push to your fork
git push origin feature/add-dark-mode

# Create Pull Request on GitHub
# Use the PR template (auto-filled)
```

#### PR Checklist

Before submitting a PR, ensure:

- [ ] Changes follow the code style and conventions
- [ ] TypeScript types are correct (`npm run lint`)
- [ ] No console errors or warnings
- [ ] Build succeeds (`npm run build`)
- [ ] Commits have meaningful messages
- [ ] PR description explains what and why
- [ ] Related issues are referenced
- [ ] Screenshots/videos for UI changes
- [ ] No breaking changes (or documented clearly)

#### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Related Issue
Fixes #123

## Changes Made
- Change 1
- Change 2
- Change 3

## Testing
How to test these changes:
1. Step 1
2. Step 2

## Screenshots
(if applicable)

## Checklist
- [ ] My code follows the code style
- [ ] I have performed a self-review
- [ ] TypeScript compilation passes
- [ ] Build succeeds
```

---

## Areas for Contribution

### 🐛 Bug Fixes
- Check [Issues](https://github.com/issues) for `bug` label
- Fix and submit PR with test cases

### ✨ Features
See [CLAUDE.MD](../CLAUDE.MD) for suggested improvements:

**High Priority:**
- [ ] Add search/filter in file tree
- [ ] Add copy-to-clipboard for code blocks
- [ ] Implement error boundaries
- [ ] Add TypeScript strict mode

**Medium Priority:**
- [ ] Extract file loading to custom hook
- [ ] Add E2E tests with Playwright
- [ ] Implement virtual scrolling
- [ ] Add keyboard shortcuts (Cmd/Ctrl+K)

**Low Priority:**
- [ ] Dark mode toggle
- [ ] Theme persistence
- [ ] Line numbers in code view
- [ ] Diff view for configurations

### 📚 Documentation
- Improve existing docs
- Add examples and tutorials
- Create architecture diagrams
- Document best practices

### 🔒 Security
- Report security vulnerabilities privately to maintainers
- Do not open public issues for security vulnerabilities
- See [SECURITY.md](./SECURITY.md) (if exists)

### 🚀 DevOps
- Improve GitHub Actions workflows
- Enhance Docker configurations
- Add CI/CD improvements
- Performance optimizations

---

## Development Standards

### TypeScript

```typescript
// ✅ Good
interface FileNode {
  name: string;
  path: string;
  content: string;
}

const processFile = (file: FileNode): string => {
  return file.content.trim();
};

// ❌ Bad - Missing types
const processFile = (file) => {
  return file.content.trim();
};
```

### React Components

```typescript
// ✅ Good - Explicit types and error handling
interface ButtonProps {
  onClick: () => void;
  label: string;
  disabled?: boolean;
}

const Button: React.FC<ButtonProps> = ({ onClick, label, disabled }) => {
  return (
    <button onClick={onClick} disabled={disabled}>
      {label}
    </button>
  );
};

// ❌ Bad - No types
const Button = (props) => {
  return <button onClick={props.onClick}>{props.label}</button>;
};
```

### Styling

```typescript
// ✅ Good - Using Tailwind with cn() utility
className={cn(
  'px-4 py-2 rounded',
  isActive && 'bg-blue-500',
  disabled && 'opacity-50'
)}

// ❌ Bad - String concatenation
className={'px-4 py-2' + (isActive ? ' bg-blue-500' : '')}
```

### Error Handling

```typescript
// ✅ Good - Try-catch with error boundary
try {
  const data = await loadFile(path);
  setData(data);
} catch (error) {
  console.error('Failed to load:', error);
  setError('File loading failed');
}

// ❌ Bad - Ignoring errors
const data = await loadFile(path);
setData(data);
```

---

## Testing

### Manual Testing Checklist

Before submitting:
- [ ] Feature works as intended
- [ ] No console errors
- [ ] TypeScript compilation passes
- [ ] Build succeeds
- [ ] Tested in Chrome, Firefox, Safari
- [ ] Responsive on mobile

### Performance Testing

```bash
# Check bundle size
npm run build
du -sh dist/

# Check for unused dependencies
npm audit
npm ls --depth=0
```

---

## Code Review Process

1. **Automated checks**:
   - TypeScript compilation
   - Build verification
   - Security scanning (Trivy, TruffleHog)

2. **Manual review**:
   - Code quality and style
   - Architecture and design
   - Performance implications
   - Documentation

3. **Feedback**:
   - Constructive comments
   - Request changes if needed
   - Approve when ready

4. **Merge**:
   - Squash commits if needed
   - Delete branch after merge
   - Close related issues

---

## Project Management

### Issue Labels

- `bug` - Something isn't working
- `enhancement` - New feature request
- `documentation` - Documentation improvements
- `good first issue` - Good for beginners
- `help wanted` - Need community help
- `performance` - Performance improvements
- `security` - Security-related
- `breaking` - Breaking change

### Milestones

Check [Milestones](https://github.com/milestones) for planned releases and priorities.

### Discussions

Use [GitHub Discussions](https://github.com/discussions) for:
- Questions and help
- Feature ideas
- General discussion
- Announcements

---

## Resources

### Documentation
- [README.md](../README.md) - Project overview
- [CLAUDE.MD](../CLAUDE.MD) - Code analysis
- [docs/DEPLOYMENT.md](./DEPLOYMENT.md) - Deployment guide
- [docs/DEVELOPMENT.md](./DEVELOPMENT.md) - Development guide

### Technologies
- [React](https://react.dev/) - UI framework
- [TypeScript](https://www.typescriptlang.org/) - Language
- [Tailwind CSS](https://tailwindcss.com/) - Styling
- [Vite](https://vitejs.dev/) - Build tool
- [Terraform](https://www.terraform.io/) - IaC
- [Crossplane](https://crossplane.io/) - Infrastructure provisioning
- [Kubernetes](https://kubernetes.io/) - Orchestration

### External Resources
- [Crossplane Documentation](https://docs.crossplane.io/)
- [AWS Provider Docs](https://marketplace.upbound.io/providers/upbound/provider-aws)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/best-practices/)

---

## Recognition

Contributors will be:
- Listed in `CONTRIBUTORS.md` (when created)
- Thanked in release notes
- Featured in monthly updates

---

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

## Questions?

- Check existing documentation
- Open a GitHub Discussion
- Comment on related issues
- Email maintainers

Thank you for contributing! 🎉
