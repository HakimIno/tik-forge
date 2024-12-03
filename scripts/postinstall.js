const os = require('os');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

async function install() {
    try {
        // ตรวจสอบว่าใช้ bun หรือไม่
        const isBun = process.versions.bun != null;

        // ตรวจสอบว่ามี prebuild binary หรือไม่
        const platform = os.platform();
        const arch = os.arch();
        const prebuildPath = path.join(__dirname, '..', 'prebuilds', `${platform}-${arch}`);
        const buildPath = path.join(__dirname, '..', 'build', 'Release');
        
        // สร้างโฟลเดอร์ถ้ายังไม่มี
        if (!fs.existsSync(buildPath)) {
            fs.mkdirSync(buildPath, { recursive: true });
        }

        if (fs.existsSync(prebuildPath)) {
            console.log('Using prebuilt binary');
            // คัดลอก prebuild binary ไปยัง build/Release
            const prebuildFile = path.join(prebuildPath, 'node.napi.node');
            const targetFile = path.join(buildPath, 'tik-forge.node');
            fs.copyFileSync(prebuildFile, targetFile);
            console.log(`Copied ${prebuildFile} to ${targetFile}`);
            return;
        }

        // ถ้าไม่มี prebuild ให้ build เอง
        console.log('No prebuilt binary found, building from source...');
        
        // ติดตั้ง Zig ถ้าจำเป็น
        try {
            execSync('zig version');
        } catch (e) {
            console.log('Zig not found, installing...');
            if (platform === 'darwin') {
                execSync('brew install zig');
            } else if (platform === 'linux') {
                console.log('Please install Zig manually on Linux');
                process.exit(1);
            } else if (platform === 'win32') {
                console.log('Please install Zig manually on Windows');
                process.exit(1);
            }
        }

        // Build
        if (isBun) {
            // ถ้าใช้ bun ให้ build ด้วย node scripts/build.js
            console.log('Building with Bun...');
            require('./build.js');
        } else {
            // ถ้าใช้ npm ให้ build ตามปกติ
            console.log('Building with npm...');
            execSync('npm run build', { stdio: 'inherit' });
        }

        console.log('Build completed successfully');
        
    } catch (error) {
        console.error('Build failed:', error);
        process.exit(1);
    }
}

install().catch(console.error); 