const { execSync } = require('child_process');
const os = require('os');
const path = require('path');
const fs = require('fs');

console.log('Building Zig library...');

// Get platform-specific library extension
const platform = os.platform();
const libExt = platform === 'win32' ? 'dll' : platform === 'darwin' ? 'dylib' : 'so';

// Build Zig library first
try {
  execSync('zig build', { stdio: 'inherit' });
  
  // Verify that the library was built
  const libPath = path.join(
    __dirname,
    '..',
    'zig-out',
    'lib',
    platform === 'win32' 
      ? 'tik-forge.dll'
      : `libtik-forge.${libExt}`
  );
  
  if (!fs.existsSync(libPath)) {
    throw new Error(`Library file not found at ${libPath}`);
  }
  
  console.log(`Library built successfully at ${libPath}`);
} catch (error) {
  console.error('Zig build failed:', error);
  process.exit(1);
}

console.log('Building node addon...');
try {
  // Create build directory if it doesn't exist
  if (!fs.existsSync('build')) {
    fs.mkdirSync('build');
  }
  if (!fs.existsSync('build/Release')) {
    fs.mkdirSync('build/Release', { recursive: true });
  }
  
  execSync('node-gyp rebuild', { stdio: 'inherit' });
  
  // Verify that the node addon was built
  const addonPath = path.join(
    __dirname,
    '..',
    'build',
    'Release',
    'tik-forge.node'
  );
  
  if (!fs.existsSync(addonPath)) {
    throw new Error(`Node addon not found at ${addonPath}`);
  }
  
  console.log(`Node addon built successfully at ${addonPath}`);
} catch (error) {
  console.error('node-gyp build failed:', error);
  process.exit(1);
}

console.log('Build completed successfully');