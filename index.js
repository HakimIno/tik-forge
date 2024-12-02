const path = require('path');
const modulePath = path.join(__dirname, 'build', 'Release', 'tik-forge.node');
const addon = require(modulePath);

module.exports = {
    init: addon.init,
    generatePDF: addon.generatePDF,
};