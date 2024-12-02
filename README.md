# TikForge

A high-performance PDF and Excel generator library for Node.js

## Installation

```bash
npm install tik-forge
```

```bash
yarn add tik-forge
```

```bash
bun add tik-forge
```

## Requirements

- Node.js >= 14.0.0
- Python (for node-gyp)
- C++ build tools
- wkhtmltopdf (for PDF generation)
- ssconvert (for Excel conversion)

## System Requirements

### Supported Operating Systems
- Windows (x64)
- macOS (Intel x64 & Apple Silicon ARM64)
- Linux (x64 & ARM64)

### Prerequisites
- Node.js >= 14.0.0
- Zig compiler
- Python (for node-gyp)
- C/C++ build tools:
  - Windows: Visual Studio Build Tools
  - macOS: Xcode Command Line Tools
  - Linux: GCC and development tools

### Supported Apple Silicon Macs
- M1
- M2
- M3
- Future Apple Silicon chips

## Usage

```javascript
const tikForge = require('tik-forge');

async function generateDocuments() {
  try {
    await tikForge.generateFiles({
      template: '<h1>{{title}}</h1>',
      data: {
        title: 'Hello World'
      },
      output: {
        path: './output',
        format: 'file',
        pdf: {
          filename: 'output.pdf'
        },
        excel: {
          filename: 'output.xlsx'
        }
      }
    });
  } catch (error) {
    console.error('Generation failed:', error);
  }
}
```

## Configuration

Environment variables:
- `TEMP_DIR`: Directory for temporary files
- `MAX_CONCURRENT_OPS`: Maximum concurrent operations
- `CACHE_SIZE`: Cache size in bytes
- `TIMEOUT_MS`: Operation timeout in milliseconds

## API Reference

### generateFiles(options)

Generates PDF and Excel files from templates.

Options:
- `template`: HTML template string
- `data`: Data to inject into template
- `output`: Output configuration
  - `path`: Output directory
  - `format`: 'file' | 'base64' | 'buffer'
  - `pdf`: PDF generation options
  - `excel`: Excel generation options

Returns: Promise<void>

zig build -freference-trace   