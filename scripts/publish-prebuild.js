const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const pkg = require('../package.json');
const glob = require('glob');

async function publishPrebuilds() {
    try {
        // ตรวจสอบว่ามี GITHUB_TOKEN
        if (!process.env.GITHUB_TOKEN) {
            throw new Error('GITHUB_TOKEN environment variable is required');
        }

        // ตรวจสอบว่ามีโฟลเดอร์ prebuilds
        const prebuildsDir = path.join(__dirname, '..', 'prebuilds');
        if (!fs.existsSync(prebuildsDir)) {
            throw new Error('Prebuilds directory not found. Run npm run prebuild first.');
        }

        // สร้าง release บน GitHub หรือใช้ release ที่มีอยู่แล้ว
        console.log(`Creating or updating release v${pkg.version}...`);
        try {
            execSync(`gh release create v${pkg.version} --generate-notes`, { stdio: 'inherit' });
        } catch (error) {
            // ถ้า release มีอยู่แล้ว ให้ดำเนินการต่อ
            console.log('Release already exists, continuing with upload...');
        }

        // อัพโหลดไฟล์
        const platformName = `${process.platform}-${process.arch}`;
        const prebuildPath = path.join(__dirname, '..', 'prebuilds', platformName, 'node.napi.node');

        if (!fs.existsSync(prebuildPath)) {
            throw new Error(`Prebuild file not found at: ${prebuildPath}`);
        }

        console.log(`Uploading ${prebuildPath}...`);
        execSync(`gh release upload v${pkg.version} "${prebuildPath}" --clobber`, { stdio: 'inherit' });

        console.log('Successfully published prebuilds to GitHub Releases');
    } catch (error) {
        console.error('Failed to publish prebuilds:', error);
        process.exit(1);
    }
}

publishPrebuilds().catch(console.error); 