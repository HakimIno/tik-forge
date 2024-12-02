const path = require('path');
const docGenerator = require(path.resolve(__dirname, 'build/Release/tik-forge.node'));
const fs = require('fs').promises;
const ExcelJS = require('exceljs');

// ย้ายข้อมูลตัวอย่างมาไว้ด้านนอก
const sampleProducts = [
    'เสื้อยืดคอกลม', 'กางเกงยีนส์', 'รองเท้าผ้าใบ', 
    'กระเป๋าสะพาย', 'นาฬิกา'
];
const sampleCategories = ['เสื้อผ้า', 'รองเท้า', 'กระเป๋า'];

async function generateHTML(startPage, endPage) {
    let html = `
        <html>
        <head>
            <meta charset="UTF-8">
            <style>
                @font-face {
                    font-family: 'THSarabunNew';
                    src: local('THSarabunNew');
                }
                body {
                    font-family: 'THSarabunNew', sans-serif;
                    font-size: 12pt;
                }
                table { 
                    width: 100%; 
                    border-collapse: collapse; 
                }
                th, td { 
                    border: 1px solid black; 
                    padding: 4px; 
                    text-align: left;
                }
                th { background-color: #f2f2f2; }
                @page { 
                    size: A4 landscape; 
                    margin: 0.5cm; 
                }
            </style>
        </head>
        <body>
    `;

    for (let page = startPage; page <= endPage; page++) {
        html += `
            <h2>รายการสินค้า - หน้า ${page}</h2>
            <table>
                <tr>
                    <th>รหัส</th>
                    <th>สินค้า</th>
                    <th>ราคา</th>
                    <th>คงเหลือ</th>
                    <th>หมวดหมู่</th>
                </tr>
        `;

        for (let i = 1; i <= 20; i++) {
            const itemId = (page - 1) * 20 + i;
            const randomProduct = sampleProducts[Math.floor(Math.random() * sampleProducts.length)];
            const randomCategory = sampleCategories[Math.floor(Math.random() * sampleCategories.length)];
            
            html += `
                <tr>
                    <td>P${String(itemId).padStart(5, '0')}</td>
                    <td>${randomProduct}</td>
                    <td>${(Math.random() * 1000).toFixed(2)}</td>
                    <td>${Math.floor(Math.random() * 100)}</td>
                    <td>${randomCategory}</td>
                </tr>
            `;
        }

        html += `</table><div style="page-break-after: always;"></div>`;
    }

    html += `</body></html>`;
    return html;
}

async function generateLargeReport() {
    const TOTAL_PAGES = 500;
    const BATCH_SIZE = 100;
    const workbook = new ExcelJS.Workbook();
    let allHtml = '';

    console.log(`เริ่มสร้างรายงาน ${TOTAL_PAGES} หน้า...`);
    console.log(`แบ่งการทำงานเป็น ${Math.ceil(TOTAL_PAGES/BATCH_SIZE)} batch (${BATCH_SIZE} หน้าต่อ batch)`);

    for (let start = 1; start <= TOTAL_PAGES; start += BATCH_SIZE) {
        const end = Math.min(start + BATCH_SIZE - 1, TOTAL_PAGES);
        console.log(`\nกำลังสร้าง batch ${Math.ceil(start/BATCH_SIZE)}/${Math.ceil(TOTAL_PAGES/BATCH_SIZE)} (หน้า ${start}-${end})`);
        
        // สร้าง HTML
        console.time('HTML Generation');
        const html = await generateHTML(start, end);
        allHtml += html;
        console.timeEnd('HTML Generation');

        // สร้าง Excel sheets
        console.time('Excel Sheets');
        for (let page = start; page <= end; page++) {
            const worksheet = workbook.addWorksheet(`หน้า ${page}`);
            
            worksheet.columns = [
                { header: 'รหัส', width: 10 },
                { header: 'สินค้า', width: 20 },
                { header: 'ราคา', width: 10 },
                { header: 'คงเหลือ', width: 10 },
                { header: 'หมวดหมู่', width: 15 }
            ];

            // จัด style header
            worksheet.getRow(1).font = { bold: true };
            worksheet.getRow(1).fill = {
                type: 'pattern',
                pattern: 'solid',
                fgColor: { argb: 'FFE0E0E0' }
            };

            // เพิ่มข้อมูล 20 แถวต่อหน้า
            for (let i = 1; i <= 20; i++) {
                const itemId = (page - 1) * 20 + i;
                worksheet.addRow([
                    `P${String(itemId).padStart(5, '0')}`,
                    sampleProducts[Math.floor(Math.random() * sampleProducts.length)],
                    (Math.random() * 1000).toFixed(2),
                    Math.floor(Math.random() * 100),
                    sampleCategories[Math.floor(Math.random() * sampleCategories.length)]
                ]);
            }

            // เพิ่ม border
            worksheet.eachRow((row) => {
                row.eachCell((cell) => {
                    cell.border = {
                        top: { style: 'thin' },
                        left: { style: 'thin' },
                        bottom: { style: 'thin' },
                        right: { style: 'thin' }
                    };
                });
            });
        }
        console.timeEnd('Excel Sheets');
    }

    return { html: allHtml, workbook };
}

async function ensureOutputDir() {
    const outputDir = path.join(process.cwd(), 'output');
    try {
        await fs.mkdir(outputDir, { recursive: true });
    } catch (error) {
        if (error.code !== 'EEXIST') throw error;
    }
    return outputDir;
}

async function runTests() {
    try {
        const outputDir = await ensureOutputDir();
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const pdfPath = path.join(outputDir, `report_${timestamp}.pdf`);
        const excelPath = path.join(outputDir, `report_${timestamp}.xlsx`);

        console.log('Initializing generator...');
        docGenerator.init();

        console.time('Total Generation');
        const { html, workbook } = await generateLargeReport();

        // สร้าง PDF
        console.log('\nกำลังสร้างไฟล์ PDF...');
        console.time('PDF Generation');
        const pdfBuffer = await docGenerator.generatePDF(html);
        await fs.writeFile(pdfPath, pdfBuffer);
        console.timeEnd('PDF Generation');

        // สร้าง Excel
        console.log('\nกำลังบันทึกไฟล์ Excel...');
        console.time('Excel Save');
        await workbook.xlsx.writeFile(excelPath);
        console.timeEnd('Excel Save');

        // แสดงผลลัพธ์
        const pdfStats = await fs.stat(pdfPath);
        const excelStats = await fs.stat(excelPath);
        console.timeEnd('Total Generation');

        console.log('\nสรุป:');
        console.log(`1. ไฟล์ PDF: ${pdfPath} (${(pdfStats.size / 1024 / 1024).toFixed(2)} MB)`);
        console.log(`2. ไฟล์ Excel: ${excelPath} (${(excelStats.size / 1024 / 1024).toFixed(2)} MB)`);
        console.log(`\nไฟล์ทั้งหมดถูกบันทึกไว้ในโฟลเดอร์: ${outputDir}`);

    } catch (error) {
        console.error('Test failed:', error);
        process.exit(1);
    }
}

runTests().catch(console.error);