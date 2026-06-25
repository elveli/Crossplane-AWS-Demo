/// <reference types="vite/client" />

declare module 'react-markdown' {
  import React = require('react');
  interface ReactMarkdownProps {
    children?: string;
    [key: string]: unknown;
  }
  const ReactMarkdown: React.FC<ReactMarkdownProps>;
  export default ReactMarkdown;
}

declare module 'react-syntax-highlighter' {
  import React = require('react');
  interface SyntaxHighlighterProps {
    language?: string;
    style?: Record<string, unknown>;
    children?: string;
    [key: string]: unknown;
  }
  export const Prism: React.FC<SyntaxHighlighterProps>;
}
