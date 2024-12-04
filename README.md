# TikForge

A high-performance document generator for Node.js that supports PDF and Excel output formats. Built with Zig for maximum performance and reliability.

## Installation

```bash
yarn add tik-forge
# or
bun add tik-forge
```

## System Requirements

- Node.js >= 14.0.0
- wkhtmltopdf (for PDF generation)
- node-xlsx (for Excel generation)

### Platform Support
- Linux (x64, ARM64)
- macOS (Intel x64, Apple Silicon)
- Windows (x64)

## Basic Usage

```javascript
const tikForge = require('tik-forge');

// Initialize the generator (required before use)
tikForge.init();

// Generate PDF
async function generatePDF() {
  try {
    const htmlContent = '<h1>Hello World</h1>';
    const pdfBuffer = await tikForge.generatePDF(htmlContent);
    // pdfBuffer is a Buffer containing the PDF data
  } catch (error) {
    console.error('PDF generation failed:', error);
  }
}

// Generate Excel
async function generateExcel() {
  try {
    const htmlTable = `
      <table>
        <tr><th>Name</th><th>Age</th></tr>
        <tr><td>John</td><td>30</td></tr>
      </table>
    `;
    const excelBuffer = await tikForge.generateExcel(htmlTable);
    // excelBuffer is a Buffer containing the Excel data
  } catch (error) {
    console.error('Excel generation failed:', error);
  }
}

// Clean up when done
process.on('exit', () => {
  tikForge.cleanup();
});
```

## API Reference

### init()
Initializes the document generator. Must be called before using other functions.

### generatePDF(htmlContent: string): Promise<Buffer>
Generates a PDF document from HTML content.

### generateExcel(htmlContent: string): Promise<Buffer>
Generates an Excel document from HTML content.

### cleanup()
Cleans up resources. Should be called when the generator is no longer needed.

## Configuration

The generator uses these default settings:
- Maximum concurrent jobs: 4
- Buffer size: 50MB
- Operation timeout: 10 minutes

## License

MIT