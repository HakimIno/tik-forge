const { init, generatePDF } = require('./index.js');

// ทดสอบ init
init();

// ทดสอบ generatePDF
const html = '<h1>Hello, World!</h1>';
const pdfBuffer = generatePDF(html);

console.log("pdfBuffer", pdfBuffer);
