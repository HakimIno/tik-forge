const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

// ตรวจสอบ platform และ architecture
const platform = os.platform();
const arch = os.arch();
const isLinux = platform === 'linux';
const isMac = platform === 'darwin';
const isArm64 = arch === 'arm64';

// กำหนดค่า library prefix และ extension ตาม platform
const libPrefix = isMac ? 'lib' : '';
const libExtension = isMac ? '.dylib' : (isLinux ? '.so' : '.dll');

// กำหนดค่าตาม platform
const target = `${platform}-${arch}`;
let buildTarget;

if (isMac && isArm64) {
    buildTarget = 'aarch64-macos';
} else if (isMac) {
    buildTarget = 'x86_64-macos';
} else if (isLinux && isArm64) {
    buildTarget = 'aarch64-linux';
} else if (isLinux) {
    buildTarget = 'x86_64-linux';
}

console.log(`Building for ${target} (${buildTarget})...`);

// สร้างโฟลเดอร์ที่จำเป็น
const dirs = [
    path.join(__dirname, '..', 'zig-out', 'lib'),
    path.join(__dirname, '..', 'build', 'Release')
];

for (const dir of dirs) {
    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
    }
    console.log(`Directory exists: ${dir}`);
}

// Build
console.log(`Running zig build for ${buildTarget}...`);
execSync(`zig build -Dtarget=${buildTarget}`, {
    stdio: 'inherit',
});

// แสดงรายการไฟล์ใน zig-out
console.log('\nFiles in zig-out:');
execSync('ls -R zig-out/', { stdio: 'inherit' });

// ตรวจสอบและ copy ไฟล์
const sourceFile = path.join(
    __dirname, 
    '..', 
    'zig-out', 
    'zig-out', 
    'lib', 
    `${libPrefix}tik-forge.node${libExtension}`
);

if (!fs.existsSync(sourceFile)) {
    throw new Error(`Library not found at ${sourceFile}`);
}

console.log(`Found library at: ${sourceFile}`);

// กำหนด paths สำหรับ copy
const releaseFile = path.join(__dirname, '..', 'build', 'Release', 'tik-forge.node');

// Copy ไฟล์ไปยัง Release directory
try {
    fs.copyFileSync(sourceFile, releaseFile);
    console.log(`Copied to: ${releaseFile}`);
    
    // Set permissions
    fs.chmodSync(releaseFile, 0o755);
    console.log(`Successfully created and set permissions: ${releaseFile}`);
    
    // แสดงรายการไฟล์ใน Release directory
    console.log('\nFiles in build/Release:');
    execSync('ls -la build/Release/', { stdio: 'inherit' });

    // ตรวจสอบว่าไฟล์สามารถโหลดได้
    try {
        require(releaseFile);
        console.log('Successfully loaded the module');
    } catch (loadError) {
        console.error('Failed to load module:', loadError);
    }
} catch (copyError) {
    console.error('Copy error details:', copyError);
    throw new Error(`Failed to copy file: ${copyError.message}`);
}

console.log(`Built successfully for ${target}`);