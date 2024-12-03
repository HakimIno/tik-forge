const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

function build() {
    try {
        console.log('Building for ' + process.platform + '-' + process.arch + '...');

        // หำหนด paths ที่แน่นอน
        const projectRoot = path.resolve(__dirname, '..');
        const nodeApiHeadersDir = path.join(projectRoot, 'node_modules', 'node-api-headers', 'include');
        const nodeAddonApiDir = path.join(projectRoot, 'node_modules', 'node-addon-api');

        // ตรวจสอบว่าไฟล์ header มีอยู่จริง
        if (!fs.existsSync(path.join(nodeApiHeadersDir, 'node_api.h'))) {
            throw new Error('node_api.h not found in ' + nodeApiHeadersDir);
        }

        // สร้าง include paths
        const includePaths = [
            nodeApiHeadersDir,
            nodeAddonApiDir,
            path.join(nodeAddonApiDir, 'src'),
            path.join(nodeAddonApiDir, 'external-napi')
        ].map(p => `-I ${p}`).join(' ');

        console.log('Running zig build...');
        
        // เพิ่ม environment variables สำหรับ zig build
        const env = {
            ...process.env,
            ZIG_INCLUDE_PATHS: includePaths,
            NODE_INCLUDE_PATH: nodeApiHeadersDir
        };

        execSync('zig build', {
            stdio: 'inherit',
            env: env
        });

        // Copy built files
        const buildDir = path.join(projectRoot, 'build', 'Release');
        if (!fs.existsSync(buildDir)) {
            fs.mkdirSync(buildDir, { recursive: true });
        }

        const zigOutDir = path.join(projectRoot, 'zig-out', 'lib');
        const sourceFile = path.join(zigOutDir, `libtik-forge.node.${process.platform === 'darwin' ? 'dylib' : 'so'}`);
        const targetFile = path.join(buildDir, 'tik-forge.node');

        fs.copyFileSync(sourceFile, targetFile);
        console.log(`Copied ${sourceFile} to ${targetFile}`);
        console.log('Build completed successfully');

    } catch (error) {
        console.error('Build failed:', error);
        process.exit(1);
    }
}

build();