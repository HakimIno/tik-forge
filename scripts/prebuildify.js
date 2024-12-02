const { execSync } = require('child_process');

const PLATFORMS = [
    { name: 'darwin', arch: ['x64', 'arm64'] },
    { name: 'linux', arch: ['x64', 'arm64'] },
    { name: 'win32', arch: ['x64'] }
];

async function main() {
    try {
        // Build the Zig library first
        console.log('Building Zig library...');
        execSync('zig build', { stdio: 'inherit' });

        // Run prebuildify for each platform and architecture
        console.log('Running prebuildify for all platforms...');
        for (const platform of PLATFORMS) {
            for (const arch of platform.arch) {
                console.log(`Building for ${platform.name}-${arch}...`);
                execSync(`prebuildify --napi --platform=${platform.name} --arch=${arch}`, {
                    stdio: 'inherit'
                });
            }
        }

        console.log('Prebuild completed successfully for all platforms');
    } catch (e) {
        console.error('Prebuild failed:', e.message);
        process.exit(1);
    }
}

main(); 