const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const pkg = require('../package.json');

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

        // สร้าง release บน GitHub
        console.log(`Creating release v${pkg.version}...`);
        execSync(`gh release create v${pkg.version} --generate-notes`, { stdio: 'inherit' });

        // อัพโหลดไฟล์ prebuilt binaries
        const files = fs.readdirSync(prebuildsDir);
        for (const file of files) {
            const filePath = path.join(prebuildsDir, file);
            console.log(`Uploading ${file}...`);
            execSync(`gh release upload v${pkg.version} "${filePath}"`, { stdio: 'inherit' });
        }

        console.log('Successfully published prebuilds to GitHub Releases');
    } catch (error) {
        console.error('Failed to publish prebuilds:', error);
        process.exit(1);
    }
}

publishPrebuilds().catch(console.error); 