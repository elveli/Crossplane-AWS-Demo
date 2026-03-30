import React, { useState, useEffect } from 'react';
import ReactMarkdown from 'react-markdown';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { vscDarkPlus } from 'react-syntax-highlighter/dist/esm/styles/prism';
import { Folder, File, ChevronRight, ChevronDown, BookOpen, Code, Terminal } from 'lucide-react';
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

// Load files dynamically using Vite's import.meta.glob
const tfFilesRaw = import.meta.glob('../terraform/*', { query: '?raw', import: 'default' });
const cpFilesRaw = import.meta.glob('../crossplane-manifests/*', { query: '?raw', import: 'default' });
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

export default function App() {
  const [fileTree, setFileTree] = useState<(FileNode | FolderNode)[]>([]);
  const [selectedFile, setSelectedFile] = useState<FileNode | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const loadFiles = async () => {
      try {
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
          const content = await tfFilesRaw[path]();
          const name = path.split('/').pop() || '';
          tfChildren.push({
            name,
            path: `/terraform/${name}`,
            content: content as string,
            type: 'file',
            language: 'hcl',
          });
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
          const content = await cpFilesRaw[path]();
          const name = path.split('/').pop() || '';
          cpChildren.push({
            name,
            path: `/crossplane-manifests/${name}`,
            content: content as string,
            type: 'file',
            language: 'yaml',
          });
        }
        tree.push({
          name: 'crossplane-manifests',
          path: '/crossplane-manifests',
          type: 'folder',
          isOpen: true,
          children: cpChildren.sort((a, b) => a.name.localeCompare(b.name)),
        });

        setFileTree(tree);
      } catch (error) {
        console.error("Error loading files:", error);
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

  const renderTree = (nodes: (FileNode | FolderNode)[], level = 0) => {
    return nodes.map((node) => {
      if (node.type === 'folder') {
        return (
          <div key={node.path}>
            <div
              className={cn(
                "flex items-center py-1.5 px-2 cursor-pointer hover:bg-slate-800 text-slate-300 transition-colors",
                level > 0 && "ml-4"
              )}
              onClick={() => toggleFolder(node.path)}
            >
              {node.isOpen ? <ChevronDown size={16} className="mr-1" /> : <ChevronRight size={16} className="mr-1" />}
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
            "flex items-center py-1.5 px-2 cursor-pointer transition-colors",
            level > 0 && "ml-8",
            isSelected ? "bg-blue-900/50 text-blue-200 border-r-2 border-blue-400" : "hover:bg-slate-800 text-slate-400"
          )}
          onClick={() => setSelectedFile(node)}
        >
          <File size={14} className="mr-2 opacity-70" />
          <span className="text-sm truncate">{node.name}</span>
        </div>
      );
    });
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-slate-950 flex items-center justify-center text-slate-400">
        Loading workspace...
      </div>
    );
  }

  return (
    <div className="flex h-screen bg-slate-950 text-slate-200 font-sans overflow-hidden">
      {/* Sidebar */}
      <div className="w-64 flex-shrink-0 bg-slate-900 border-r border-slate-800 flex flex-col">
        <div className="p-4 border-b border-slate-800 flex items-center gap-2">
          <BookOpen size={18} className="text-blue-400" />
          <h1 className="font-semibold text-sm tracking-wide uppercase text-slate-300">Crossplane Demo</h1>
        </div>
        <div className="flex-1 overflow-y-auto py-2">
          {renderTree(fileTree)}
        </div>
      </div>

      {/* Main Content */}
      <div className="flex-1 flex flex-col min-w-0 bg-slate-950">
        {/* Tabs */}
        <div className="flex bg-slate-900 border-b border-slate-800">
          {selectedFile && (
            <div className="px-4 py-2 bg-slate-950 border-t-2 border-blue-500 text-sm flex items-center gap-2 text-slate-200">
              <File size={14} className="opacity-70" />
              {selectedFile.name}
            </div>
          )}
        </div>

        {/* Editor/Viewer Area */}
        <div className="flex-1 overflow-auto relative">
          {selectedFile ? (
            selectedFile.language === 'markdown' ? (
              <div className="max-w-4xl mx-auto p-8 prose prose-invert prose-blue">
                <ReactMarkdown>{selectedFile.content}</ReactMarkdown>
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
