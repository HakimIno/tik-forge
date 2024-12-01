const { generateFiles } = require('./your-lib-name');
const fs = require('fs');

// สร้างข้อมูลทดสอบ
function generateTestData(rowCount) {
    const rows = [];
    for (let i = 0; i < rowCount; i++) {
        rows.push({
            fields: [
                { key: "id", value: { string: `P${String(i+1).padStart(4, '0')}` } },
                { key: "name", value: { string: `Product ${i+1}` } },
                { key: "price", value: { number: Math.random() * 1000 } },
                { key: "stock", value: { integer: Math.floor(Math.random() * 1000) } },
                { key: "category", value: { string: `Category ${Math.floor(i/100)}` } },
                { key: "available", value: { boolean: Math.random() > 0.5 } }
            ]
        });
    }
    return rows;
}

// ฟังก์ชันวัดการใช้หน่วยความจำ
function formatMemoryUsage(bytes) {
    return `${Math.round(bytes / 1024 / 1024 * 100) / 100} MB`;
}

async function runBenchmark() {
    const testCases = [100, 1000, 10000];
    const template = fs.readFileSync('./template.html', 'utf8');

    console.log('Starting benchmark...\n');
    
    for (const rowCount of testCases) {
        console.log(`Testing with ${rowCount} rows:`);
        
        // วัดการใช้หน่วยความจำก่อนเริ่ม
        const beforeMemory = process.memoryUsage();
        
        // จับเวลา
        const startTime = process.hrtime();
        
        const options = {
            template,
            data: {
                rows: generateTestData(rowCount),
                metadata: {
                    title: `Benchmark Report - ${rowCount} rows`,
                    date: new Date().toISOString()
                }
            },
            output: {
                path: './benchmark_output',
                format: 'file',
                pdfOptions: {
                    filename: `benchmark_${rowCount}.pdf`,
                },
                excelFilename: `benchmark_${rowCount}.xlsx`
            }
        };

        try {
            await generateFiles(options);
            
            // คำนวณเวลาที่ใช้
            const [seconds, nanoseconds] = process.hrtime(startTime);
            const totalTime = seconds + nanoseconds / 1e9;
            
            // วัดการใช้หน่วยความจำหลังเสร็จ
            const afterMemory = process.memoryUsage();
            
            console.log(`✓ Time taken: ${totalTime.toFixed(3)} seconds`);
            console.log('Memory usage:');
            console.log(`  - Heap used: ${formatMemoryUsage(afterMemory.heapUsed - beforeMemory.heapUsed)}`);
            console.log(`  - RSS delta: ${formatMemoryUsage(afterMemory.rss - beforeMemory.rss)}`);
            
            // ตรวจสอบขนาดไฟล์
            const pdfSize = fs.statSync(`./benchmark_output/benchmark_${rowCount}.pdf`).size;
            const excelSize = fs.statSync(`./benchmark_output/benchmark_${rowCount}.xlsx`).size;
            console.log(`Output file sizes:`);
            console.log(`  - PDF: ${formatMemoryUsage(pdfSize)}`);
            console.log(`  - Excel: ${formatMemoryUsage(excelSize)}`);
            
        } catch (error) {
            console.error(`✗ Error with ${rowCount} rows:`, error);
        }
        
        console.log('\n' + '-'.repeat(50) + '\n');
    }
}

// สร้าง template.html สำหรับทดสอบ
const testTemplate = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8"/>
    <style>
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 4px; border: 1px solid #ddd; font-size: 10px; }
        th { background-color: #f4f4f4; }
        .metadata { margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="metadata">
        {{#if metadata.title}}<h1>{{metadata.title}}</h1>{{/if}}
        {{#if metadata.date}}<p>Date: {{metadata.date}}</p>{{/if}}
    </div>
    <table>
        <thead>
            <tr>
                {{#each data.[0].fields}}
                    <th>{{this.key}}</th>
                {{/each}}
            </tr>
        </thead>
        <tbody>
            {{#each data}}
                <tr>
                    {{#each this.fields}}
                        <td>
                            {{#if (eq this.value.type "number")}}
                                {{format_number this.value.value}}
                            {{else if (eq this.value.type "boolean")}}
                                {{#if this.value.value}}Yes{{else}}No{{/if}}
                            {{else}}
                                {{this.value.value}}
                            {{/if}}
                        </td>
                    {{/each}}
                </tr>
            {{/each}}
        </tbody>
    </table>
</body>
</html>
`;

fs.writeFileSync('./template.html', testTemplate);

// รัน benchmark
runBenchmark().catch(console.error);
