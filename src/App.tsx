import React, { useState, useEffect } from 'react';
import ReactMarkdown from 'react-markdown';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { vscDarkPlus } from 'react-syntax-highlighter/dist/esm/styles/prism';
import {
  Folder,
  File,
  ChevronRight,
  ChevronDown,
  BookOpen,
  Code,
  Search,
  Copy,
  AlertCircle,
  X,
} from 'lucide-react';
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

// Error Boundary Component
interface ErrorBoundaryProps {
  children: React.ReactNode;
}

interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
}

class ErrorBoundary extends React.Component<ErrorBoundaryProps, ErrorBoundaryState> {
  constructor(props: ErrorBoundaryProps) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('Error caught by boundary:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-slate-950 flex items-center justify-center p-4">
          <div className="bg-slate-900 border border-red-900 rounded-lg p-6 max-w-md">
            <div className="flex items-center gap-3 mb-4">
              <AlertCircle className="text-red-500" size={24} />
              <h2 className="text-lg font-semibold text-red-400">Something went wrong</h2>
            </div>
            <p className="text-slate-300 text-sm mb-4">
              {this.state.error?.message || 'An unexpected error occurred'}
            </p>
            <button
              onClick={() => window.location.reload()}
              className="w-full px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded text-sm font-medium transition-colors"
            >
              Reload Page
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}

// Load files dynamically using Vite's import.meta.glob
const tfFilesRaw = import.meta.glob('../terraform/*', { query: '?raw', import: 'default' });
const cpFilesRaw = import.meta.glob('../crossplane-manifests/*', {
  query: '?raw',
  import: 'default',
});
const readmeRaw = import.meta.glob('../README.md', { query: '?raw', import: 'default' });

type FileNode = {
  name: string;
  path: string;
  content: string;
  type: 'file';
  language: string;
};

type FolderNode = {
  name: string;
  path: string;
  type: 'folder';
  children: (FileNode | FolderNode)[];
  isOpen: boolean;
};

function AppContent() {
  const [fileTree, setFileTree] = useState<(FileNode | FolderNode)[]>([]);
  const [selectedFile, setSelectedFile] = useState<FileNode | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [copyFeedback, setCopyFeedback] = useState(false);

  useEffect(() => {
    const loadFiles = async () => {
      try {
        setError(null);
        const tree: (FileNode | FolderNode)[] = [];

        // Load README
        const readmeModule = await readmeRaw['../README.md']();
        const readmeNode: FileNode = {
          name: 'README.md',
          path: '/README.md',
          content: readmeModule as string,
          type: 'file',
          language: 'markdown',
        };
        tree.push(readmeNode);
        setSelectedFile(readmeNode);

        // Load Terraform files
        const tfChildren: FileNode[] = [];
        for (const path in tfFilesRaw) {
          try {
            const content = await tfFilesRaw[path]();
            const name = path.split('/').pop() || '';
            tfChildren.push({
              name,
              path: `/terraform/${name}`,
              content: content as string,
              type: 'file',
              language: 'hcl',
            });
          } catch (err) {
            console.warn(`Failed to load terraform file: ${path}`, err);
          }
        }
        tree.push({
          name: 'terraform',
          path: '/terraform',
          type: 'folder',
          isOpen: true,
          children: tfChildren.sort((a, b) => a.name.localeCompare(b.name)),
        });

        // Load Crossplane files
        const cpChildren: FileNode[] = [];
        for (const path in cpFilesRaw) {
          try {
            const content = await cpFilesRaw[path]();
            const name = path.split('/').pop() || '';
            cpChildren.push({
              name,
              path: `/crossplane-manifests/${name}`,
              content: content as string,
              type: 'file',
              language: 'yaml',
            });
          } catch (err) {
            console.warn(`Failed to load crossplane file: ${path}`, err);
          }
        }
        tree.push({
          name: 'crossplane-manifests',
          path: '/crossplane-manifests',
          type: 'folder',
          isOpen: true,
          children: cpChildren.sort((a, b) => a.name.localeCompare(b.name)),
        });

        setFileTree(tree);
      } catch (err) {
        const errorMessage = err instanceof Error ? err.message : 'Failed to load files';
        setError(errorMessage);
        console.error('Error loading files:', err);
      } finally {
        setIsLoading(false);
      }
    };

    loadFiles();
  }, []);

  const toggleFolder = (folderPath: string) => {
    const newTree = [...fileTree];
    const toggleNode = (nodes: (FileNode | FolderNode)[]) => {
      for (const node of nodes) {
        if (node.type === 'folder') {
          if (node.path === folderPath) {
            node.isOpen = !node.isOpen;
            return true;
          }
          if (toggleNode(node.children)) return true;
        }
      }
      return false;
    };
    toggleNode(newTree);
    setFileTree(newTree);
  };

  const searchFiles = (
    nodes: (FileNode | FolderNode)[],
    query: string
  ): (FileNode | FolderNode)[] => {
    if (!query.trim()) return nodes;

    return nodes
      .map((node) => {
        if (node.type === 'folder') {
          const filteredChildren = searchFiles(node.children, query);
          if (filteredChildren.length > 0) {
            return { ...node, children: filteredChildren, isOpen: true };
          }
          return null;
        }

        if (node.name.toLowerCase().includes(query.toLowerCase())) {
          return node;
        }
        return null;
      })
      .filter((node): node is FileNode | FolderNode => node !== null);
  };

  const filteredTree = searchFiles(fileTree, searchQuery);

  const renderTree = (nodes: (FileNode | FolderNode)[], level = 0) => {
    return nodes.map((node) => {
      if (node.type === 'folder') {
        return (
          <div key={node.path}>
            <div
              className={cn(
                'flex items-center py-1.5 px-2 cursor-pointer hover:bg-slate-800 text-slate-300 transition-colors',
                level > 0 && 'ml-4'
              )}
              onClick={() => toggleFolder(node.path)}
            >
              {node.isOpen ? (
                <ChevronDown size={16} className="mr-1" />
              ) : (
                <ChevronRight size={16} className="mr-1" />
              )}
              <Folder size={16} className="mr-2 text-blue-400" />
              <span className="text-sm font-medium">{node.name}</span>
            </div>
            {node.isOpen && renderTree(node.children, level + 1)}
          </div>
        );
      }

      const isSelected = selectedFile?.path === node.path;
      return (
        <div
          key={node.path}
          className={cn(
            'flex items-center py-1.5 px-2 cursor-pointer transition-colors',
            level > 0 && 'ml-8',
            isSelected
              ? 'bg-blue-900/50 text-blue-200 border-r-2 border-blue-400'
              : 'hover:bg-slate-800 text-slate-400'
          )}
          onClick={() => setSelectedFile(node)}
        >
          <File size={14} className="mr-2 opacity-70" />
          <span className="text-sm truncate">{node.name}</span>
        </div>
      );
    });
  };

  const handleCopyToClipboard = async () => {
    if (!selectedFile) return;
    try {
      await navigator.clipboard.writeText(selectedFile.content);
      setCopyFeedback(true);
      setTimeout(() => setCopyFeedback(false), 2000);
    } catch (err) {
      console.error('Failed to copy to clipboard:', err);
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-slate-950 flex items-center justify-center text-slate-400">
        <div className="flex flex-col items-center gap-4">
          <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-blue-500"></div>
          <p>Loading workspace...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-slate-950 flex items-center justify-center p-4">
        <div className="bg-slate-900 border border-red-900 rounded-lg p-6 max-w-md">
          <div className="flex items-center gap-3 mb-4">
            <AlertCircle className="text-red-500" size={24} />
            <h2 className="text-lg font-semibold text-red-400">Failed to load files</h2>
          </div>
          <p className="text-slate-300 text-sm mb-4">{error}</p>
          <button
            onClick={() => window.location.reload()}
            className="w-full px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded text-sm font-medium transition-colors"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex h-screen bg-slate-950 text-slate-200 font-sans overflow-hidden">
      {/* Sidebar */}
      <div className="w-64 flex-shrink-0 bg-slate-900 border-r border-slate-800 flex flex-col">
        <div className="p-4 border-b border-slate-800 flex items-center gap-2">
          <BookOpen size={18} className="text-blue-400" />
          <h1 className="font-semibold text-sm tracking-wide uppercase text-slate-300">
            Crossplane Demo
          </h1>
        </div>

        {/* Search Bar */}
        <div className="p-3 border-b border-slate-800">
          <div className="relative">
            <Search size={16} className="absolute left-2 top-2.5 text-slate-500" />
            <input
              type="text"
              placeholder="Search files..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="w-full pl-8 pr-3 py-2 bg-slate-800 border border-slate-700 rounded text-sm text-slate-200 placeholder-slate-500 focus:outline-none focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
            />
            {searchQuery && (
              <button
                onClick={() => setSearchQuery('')}
                className="absolute right-2 top-2.5 text-slate-500 hover:text-slate-300"
              >
                <X size={16} />
              </button>
            )}
          </div>
        </div>

        {/* File Tree */}
        <div className="flex-1 overflow-y-auto py-2">{renderTree(filteredTree)}</div>
      </div>

      {/* Main Content */}
      <div className="flex-1 flex flex-col min-w-0 bg-slate-950">
        {/* Header */}
        <div className="flex items-center justify-between bg-slate-900 border-b border-slate-800 px-4 py-3">
          <div className="flex items-center gap-2">
            <File size={16} className="opacity-70" />
            <span className="text-sm font-medium">{selectedFile?.name || 'Select a file'}</span>
          </div>
          {selectedFile && (
            <button
              onClick={handleCopyToClipboard}
              className="flex items-center gap-2 px-3 py-1.5 text-sm bg-slate-800 hover:bg-slate-700 rounded transition-colors"
              title="Copy to clipboard"
            >
              <Copy size={14} />
              {copyFeedback ? 'Copied!' : 'Copy'}
            </button>
          )}
        </div>

        {/* Content Area */}
        <div className="flex-1 overflow-auto">
          {selectedFile ? (
            selectedFile.language === 'markdown' ? (
              <div className="max-w-4xl mx-auto p-8 prose prose-invert prose-blue text-slate-300">
                <ReactMarkdown
                  components={{
                    h1: ({ _node, ...props }: any) => (
                      <h1 className="text-3xl font-bold mt-6 mb-4" {...props} />
                    ),
                    h2: ({ _node, ...props }: any) => (
                      <h2 className="text-2xl font-bold mt-5 mb-3" {...props} />
                    ),
                    h3: ({ _node, ...props }: any) => (
                      <h3 className="text-xl font-bold mt-4 mb-2" {...props} />
                    ),
                    code: ({ _node, inline, ...props }: any) =>
                      inline ? (
                        <code
                          className="bg-slate-800 px-2 py-1 rounded text-blue-300 font-mono text-sm"
                          {...props}
                        />
                      ) : (
                        <code
                          className="block bg-slate-800 p-4 rounded overflow-x-auto font-mono text-sm"
                          {...props}
                        />
                      ),
                  }}
                >
                  {selectedFile.content}
                </ReactMarkdown>
              </div>
            ) : (
              <SyntaxHighlighter
                language={selectedFile.language}
                style={vscDarkPlus}
                customStyle={{
                  margin: 0,
                  padding: '1.5rem',
                  background: 'transparent',
                  fontSize: '14px',
                  lineHeight: '1.5',
                }}
                showLineNumbers={true}
                wrapLines={true}
              >
                {selectedFile.content}
              </SyntaxHighlighter>
            )
          ) : (
            <div className="flex h-full items-center justify-center text-slate-500 flex-col gap-4">
              <Code size={48} className="opacity-20" />
              <p>Select a file to view its contents</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default function App() {
  return (
    <ErrorBoundary>
      <AppContent />
    </ErrorBoundary>
  );
}
