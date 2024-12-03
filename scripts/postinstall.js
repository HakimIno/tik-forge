const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

async function install() {
    try {
        const platform = process.platform;
        const arch = process.arch;
        const buildDir = path.join(__dirname, '..', 'build', 'Release');
        
        // สร้าง build directory ถ้ายังไม่มี
        if (!fs.existsSync(buildDir)) {
            fs.mkdirSync(buildDir, { recursive: true });
        }

        // ลองโหลด prebuild ก่อน
        const prebuildPath = path.join(__dirname, '..', 'prebuilds', `${platform}-${arch}`, 'node.napi.node');
        const targetPath = path.join(buildDir, 'tik-forge.node');

        if (fs.existsSync(prebuildPath)) {
            console.log('Using prebuilt binary');
            fs.copyFileSync(prebuildPath, targetPath);
            return;
        }

        // ถ้าไม่มี prebuild ให้ใช้ไฟล์ที่ build เอง
        console.log('No prebuilt binary found, using built binary');
        const zigOutDir = path.join(__dirname, '..', 'zig-out', 'lib');
        const sourceFile = path.join(zigOutDir, `libtik-forge.node.${platform === 'darwin' ? 'dylib' : 'so'}`);

        if (fs.existsSync(sourceFile)) {
            fs.copyFileSync(sourceFile, targetPath);
            return;
        }

        // ถ้าไม่มีทั้ง prebuild และ built binary ให้ build ใหม่
        console.log('No binary found, building from source...');
        execSync('node scripts/build.js', {
            stdio: 'inherit',
            cwd: path.join(__dirname, '..')
        });

    } catch (error) {
        console.error('Build failed:', error);
        process.exit(1);
    }
}

install().catch(error => {
    console.error('Installation failed:', error);
    process.exit(1);
}); 