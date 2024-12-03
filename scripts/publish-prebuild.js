const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

async function publishPrebuilds() {
    try {
        // สร้างโฟลเดอร์ prebuilds ถ้ายังไม่มี
        const prebuildsDir = path.join(__dirname, '..', 'prebuilds');
        if (!fs.existsSync(prebuildsDir)) {
            fs.mkdirSync(prebuildsDir, { recursive: true });
        }

        // รัน prebuildify
        console.log('Running prebuildify...');
        execSync('prebuildify --napi --strip -t 18.0.0 -t 20.0.0', {
            stdio: 'inherit'
        });

        // ตรวจสอบว่ามีไฟล์ใน prebuilds หรือไม่
        const files = fs.readdirSync(prebuildsDir);
        if (files.length === 0) {
            throw new Error('No prebuilt binaries were generated');
        }

        console.log('Copying prebuilt binaries to node-pre-gyp location...');
        const prebuildFile = path.join(prebuildsDir, 'darwin-x64', 'node.napi.node');
        const targetFile = path.join(prebuildsDir, 'darwin-x64', 'tik-forge.node');
        if (fs.existsSync(prebuildFile)) {
            fs.copyFileSync(prebuildFile, targetFile);
        }

        // Package prebuilds
        console.log('Packaging prebuilds...');
        execSync('npx node-pre-gyp package', {
            stdio: 'inherit'
        });

        // Publish to GitHub releases
        if (!process.env.GITHUB_TOKEN) {
            throw new Error('GITHUB_TOKEN environment variable is not set');
        }

        console.log('Publishing prebuilds to GitHub releases...');
        // Get current branch name
        const currentBranch = execSync('git rev-parse --abbrev-ref HEAD', { 
            stdio: 'pipe' 
        }).toString().trim();

        execSync('npx node-pre-gyp-github publish', {
            stdio: 'inherit',
            env: {
                ...process.env,
                NODE_PRE_GYP_GITHUB_TOKEN: process.env.GITHUB_TOKEN,
                NODE_PRE_GYP_GITHUB_TARGET_COMMITISH: currentBranch
            }
        });

        console.log('Prebuilds published successfully');
    } catch (error) {
        console.error('Failed to publish prebuilds:', error);
        process.exit(1);
    }
}

publishPrebuilds().catch(console.error); 