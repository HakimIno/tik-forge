const os = require('os');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

async function install() {
    try {
        // ตรวจสอบว่ามี prebuild binary หรือไม่
        const platform = os.platform();
        const arch = os.arch();
        const prebuildPath = path.join(__dirname, '..', 'prebuilds', `${platform}-${arch}`);
        
        if (fs.existsSync(prebuildPath)) {
            console.log('Using prebuilt binary');
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
                // Add Linux-specific Zig installation
                console.log('Please install Zig manually on Linux');
            }
        }

        // Build
        execSync('npm run build', { stdio: 'inherit' });
        console.log('Build completed successfully');
        
    } catch (error) {
        console.error('Build failed:', error);
        process.exit(1);
    }
}

install().catch(console.error); 