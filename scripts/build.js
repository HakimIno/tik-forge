const path = require('path');
const fs = require('fs');
const os = require('os');
const { execSync } = require('child_process');

async function build() {
    try {
        if (process.env.npm_config_global) {
            console.log('Installing globally - checking for prebuilt binary...');
            try {
                require('prebuild-install')();
                return;
            } catch (err) {
                console.log('No prebuilt binary found, falling back to build...');
            }
        }

        const platform = os.platform();
        const arch = os.arch();
        console.log(`Building for ${platform}-${arch}...`);

        // Run zig build
        console.log('Running zig build...');
        execSync('zig build', { stdio: 'inherit' });

        // Create necessary directories
        const buildDir = path.join(__dirname, '..', 'build', 'Release');
        if (!fs.existsSync(buildDir)) {
            fs.mkdirSync(buildDir, { recursive: true });
        }

        // Find the built library
        const zigOutDir = path.join(__dirname, '..', 'zig-out');
        const libName = platform === 'darwin' ? 'libtik-forge.node.dylib' : 'libtik-forge.node.so';
        
        // Search in possible locations
        const possiblePaths = [
            path.join(zigOutDir, 'lib', libName),
            path.join(zigOutDir, 'zig-out/lib', libName),
            path.join(zigOutDir, libName)
        ];

        let sourceFile;
        for (const p of possiblePaths) {
            if (fs.existsSync(p)) {
                sourceFile = p;
                break;
            }
        }

        if (!sourceFile) {
            console.error('Built library not found. Searched in:');
            possiblePaths.forEach(p => console.error(`- ${p}`));
            throw new Error('Library not found');
        }

        // Copy to build directory
        const targetFile = path.join(buildDir, 'tik-forge.node');
        fs.copyFileSync(sourceFile, targetFile);
        console.log(`Copied ${sourceFile} to ${targetFile}`);

        // Create symlink in zig-out/lib
        const libDir = path.join(zigOutDir, 'lib');
        if (!fs.existsSync(libDir)) {
            fs.mkdirSync(libDir, { recursive: true });
        }
        const symlinkTarget = path.join(libDir, libName);
        if (!fs.existsSync(symlinkTarget)) {
            fs.symlinkSync(sourceFile, symlinkTarget);
        }

        // Set executable permissions for Linux
        if (platform === 'linux') {
            try {
                execSync(`chmod +x "${targetFile}"`);
            } catch (err) {
                console.warn('Warning: Could not set executable permissions:', err);
            }
        }

        console.log('Build completed successfully');
    } catch (error) {
        console.error('Build failed:', error);
        process.exit(1);
    }
}

build().catch(console.error);