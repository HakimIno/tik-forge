const path = require('path');

try {
    const addonPath = path.resolve(__dirname, 'build/Release/tik-forge.node');
    console.log('Loading addon from:', addonPath);
    module.exports = require(addonPath);
} catch (err) {
    console.error('Failed to load tik-forge native addon:', err);
    throw err;
}