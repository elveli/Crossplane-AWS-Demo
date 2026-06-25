# Development Guide

This guide helps you set up your development environment and understand the project structure.

## Prerequisites

- Node.js 18+ (20+ recommended)
- npm 9+
- Git
- Docker (optional, for containerized development)
- AWS CLI (for Terraform/Crossplane deployment)
- kubectl (for Kubernetes operations)

## Quick Start

### 1. Clone and Setup

```bash
git clone https://github.com/yourusername/Crossplane-AWS-Demo.git
cd Crossplane-AWS-Demo

npm install
```

### 2. Environment Configuration

```bash
# Copy example env file
cp .env.example .env.local

# Edit with your values
nano .env.local
```

Required environment variables:
- `GEMINI_API_KEY`: Your Google Gemini API key
- `APP_URL`: (optional) Application URL for OAuth/redirects

### 3. Start Development Server

```bash
# Start with Vite (fast HMR)
npm run dev

# Open http://localhost:5173
```

### 4. Run Type Checking

```bash
# TypeScript type checking
npm run lint

# Continuous type checking
npx tsc --watch
```

### 5. Build for Production

```bash
npm run build

# Preview production build locally
npm run preview
```

---

## Project Structure

```
Crossplane-AWS-Demo/
│
├── src/                                # React frontend source
│   ├── App.tsx                        # Main component with file viewer
│   ├── main.tsx                       # React entry point
│   └── index.css                      # Tailwind CSS styles
│
├── terraform/                         # Infrastructure as Code
│   ├── main.tf                        # EKS cluster & VPC
│   ├── providers.tf                   # Terraform provider config
│   ├── variables.tf                   # Variable definitions
│   ├── outputs.tf                     # Output values
│   ├── crossplane.tf                  # Crossplane Helm install
│   └── backend.tf                     # Remote state (S3)
│
├── crossplane-manifests/              # Kubernetes resources
│   ├── 1-providers.yaml              # AWS provider installation
│   ├── 2-providerconfig.yaml         # AWS credentials
│   ├── 3-s3-bucket.yaml              # S3 resource
│   ├── 4-rds-instance.yaml           # RDS resource
│   ├── 5-iam-role.yaml               # IAM resource
│   └── 6-dynamodb-table.yaml         # DynamoDB resource
│
├── .github/
│   └── workflows/
│       └── ci-cd.yml                 # GitHub Actions pipeline
│
├── docs/                              # Documentation
│   ├── DEPLOYMENT.md                 # Deployment guide
│   └── DEVELOPMENT.md                # This file
│
├── Dockerfile                         # Production image
├── Dockerfile.dev                     # Development image
├── docker-compose.yml                 # Docker Compose config
├── tsconfig.json                      # TypeScript config (strict mode)
├── vite.config.ts                     # Vite build config
├── package.json                       # Dependencies
└── README.md                          # Main documentation
```

---

## Architecture

### Frontend (React + Vite)

```
┌─────────────────────────────────────┐
│         React App (App.tsx)         │
│  - File tree viewer (sidebar)       │
│  - Search/filter functionality      │
│  - Syntax highlighting              │
│  - Error boundary                   │
└─────────────────────────────────────┘
         ↓
┌─────────────────────────────────────┐
│    Vite (Dev) / Serve (Prod)       │
│    TypeScript compilation           │
│    CSS/Tailwind processing          │
└─────────────────────────────────────┘
```

### Infrastructure

```
┌──────────────────────────────┐
│    Terraform                 │
│  - AWS VPC                   │
│  - EKS Cluster               │
│  - Helm for Crossplane       │
└──────────────────────────────┘
         ↓
┌──────────────────────────────┐
│    EKS Cluster               │
│  - Crossplane Control Plane  │
│  - AWS Providers             │
└──────────────────────────────┘
         ↓
┌──────────────────────────────┐
│    Crossplane Manifests      │
│  - S3, RDS, IAM, DynamoDB   │
└──────────────────────────────┘
```

---

## Code Conventions

### TypeScript

- **Strict mode**: All TypeScript configs use strict type checking
- **No implicit any**: Explicit types required
- **No unused variables**: Compiler enforces cleanup

```typescript
// ✅ Good
interface FileNode {
  name: string;
  path: string;
  type: 'file' | 'folder';
}

const loadFile = async (path: string): Promise<FileNode> => {
  // implementation
};

// ❌ Bad
const loadFile = async (path: string) => {
  // missing return type
};
```

### React Components

- Use functional components with hooks
- Props should have explicit types
- Use error boundaries for error handling

```typescript
// ✅ Good
interface AppProps {
  title: string;
  onLoad?: (data: unknown) => void;
}

const MyComponent: React.FC<AppProps> = ({ title, onLoad }) => {
  // implementation
};

// ❌ Bad
const MyComponent = ({ title, onLoad }) => {
  // no types on props
};
```

### Styling

- Use Tailwind CSS utility classes
- Create reusable components for complex styles
- Use `cn()` utility for class composition

```typescript
// ✅ Good
className={cn(
  'px-4 py-2 rounded text-sm',
  isActive && 'bg-blue-500 text-white',
  disabled && 'opacity-50 cursor-not-allowed'
)}

// ❌ Bad
className={'px-4 py-2 rounded text-sm' + (isActive ? ' bg-blue-500' : '')}
```

### File Naming

- Components: PascalCase (`MyComponent.tsx`)
- Utilities: camelCase (`fileHelpers.ts`)
- Types/Interfaces: PascalCase (`FileNode.ts`)

---

## Common Development Tasks

### Add a New File Type to Viewer

Edit `src/App.tsx` and add to file loading:

```typescript
const docFilesRaw = import.meta.glob('../docs/*.md', { 
  query: '?raw', 
  import: 'default' 
});

// In loadFiles():
const docChildren: FileNode[] = [];
for (const path in docFilesRaw) {
  const content = await docFilesRaw[path]();
  const name = path.split('/').pop() || '';
  docChildren.push({
    name,
    path: `/docs/${name}`,
    content: content as string,
    type: 'file',
    language: 'markdown',
  });
}

tree.push({
  name: 'docs',
  path: '/docs',
  type: 'folder',
  isOpen: false,
  children: docChildren,
});
```

### Add Environment Variable

1. Add to `.env.example`:
```bash
NEW_VAR=example_value
```

2. Update `vite.config.ts`:
```typescript
define: {
  'process.env.NEW_VAR': JSON.stringify(env.NEW_VAR),
}
```

3. Use in code:
```typescript
const value = process.env.NEW_VAR;
```

### Modify Terraform

1. Edit files in `terraform/` directory
2. Validate:
```bash
cd terraform
terraform validate
terraform plan
```

3. Create PR for review
4. Apply via GitHub Actions or manually:
```bash
terraform apply
```

### Add Crossplane Resource

1. Create manifest in `crossplane-manifests/`:
```yaml
apiVersion: s3.aws.upbound.io/v1beta1
kind: Bucket
metadata:
  name: my-bucket
spec:
  forProvider:
    region: us-east-1
  providerConfigRef:
    name: default
```

2. Test locally:
```bash
kubectl apply --dry-run=client -f crossplane-manifests/my-resource.yaml
```

3. Apply to cluster:
```bash
kubectl apply -f crossplane-manifests/my-resource.yaml
```

---

## Testing

### TypeScript Type Checking

```bash
npm run lint
```

### Build Verification

```bash
npm run build
```

### Manual Testing

```bash
# Start dev server
npm run dev

# Test different browsers/devices
# Check file loading
# Test search functionality
# Verify error boundary works
```

---

## Debugging

### Browser DevTools

```javascript
// View file tree state
console.log('fileTree:', fileTree);

// Check selected file
console.log('selectedFile:', selectedFile);
```

### TypeScript Errors

```bash
# Get detailed type errors
npx tsc --noEmit

# Watch mode for continuous checking
npx tsc --watch --noEmit
```

### React DevTools

- Install React DevTools browser extension
- Inspect component tree and props
- Check state values

---

## Performance Tips

### Build Optimization

```bash
# Analyze bundle size
npm run build -- --analyze

# Use esbuild for faster builds (already configured in vite.config.ts)
```

### Development Experience

- Use VS Code with TypeScript extension
- Enable "Format on Save" for consistent styling
- Use Vite's dev server for fast HMR

---

## Common Issues

### Module not found error

```
Error: Cannot find module '../terraform/*'
```

**Solution**: Ensure Vite's glob patterns match your file structure. Update `vite.config.ts` if you reorganize files.

### TypeScript errors after npm install

```bash
# Clear cache and reinstall
rm -rf node_modules package-lock.json
npm install
```

### Port 3000/5173 already in use

```bash
# Use different port
npm run dev -- --port 5174
```

### Environment variable undefined

```bash
# Ensure .env.local exists and has the variable
# Variables must start with VITE_ for Vite to include them
cat .env.local | grep VITE_
```

---

## VS Code Extensions (Recommended)

- **TypeScript Vue Plugin** - Better TypeScript support
- **Tailwind CSS IntelliSense** - Tailwind autocomplete
- **Prettier** - Code formatting
- **ESLint** - Code linting
- **React DevTools** - React debugging

---

## Getting Help

1. Check existing issues on GitHub
2. Review the main README.md for architecture overview
3. Read CLAUDE.MD for code analysis and recommendations
4. Check deployment guide for production issues
5. Ask in GitHub Discussions or open an issue

---

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for contribution guidelines.
