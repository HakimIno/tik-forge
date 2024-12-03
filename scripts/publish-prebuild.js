const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');

async function publishPrebuilds() {
    try {
        const packageJson = require('../package.json');
        const version = packageJson.version;
        const tagName = `v${version}`;

        // Create tag
        console.log('Creating git tag...');
        try {
            execSync('git fetch --all --tags');
            execSync(`git tag -d ${tagName} 2>/dev/null || true`);
            execSync(`git push origin :refs/tags/${tagName} 2>/dev/null || true`);
            execSync(`git tag -a ${tagName} -m "Release ${tagName}"`);
            execSync(`git push origin ${tagName}`);
        } catch (error) {
            console.log('Tag operation warning:', error.message);
        }

        // Build prebuilds
        console.log('Building prebuilds...');
        execSync('npm run prebuild', { stdio: 'inherit' });

        // Create GitHub release and upload prebuilds
        console.log('Creating GitHub release...');
        const prebuildsDir = path.join(__dirname, '..', 'prebuilds');
        const files = fs.readdirSync(prebuildsDir);

        for (const file of files) {
            const filePath = path.join(prebuildsDir, file);
            if (fs.statSync(filePath).isDirectory()) {
                const prebuildFile = path.join(filePath, 'node.napi.node');
                if (fs.existsSync(prebuildFile)) {
                    const targetFile = path.join(filePath, 'tik-forge.node');
                    fs.copyFileSync(prebuildFile, targetFile);
                }
            }
        }

        // Create release using GitHub API
        const releaseData = {
            tag_name: tagName,
            name: tagName,
            body: `tik-forge ${version}`,
            draft: false,
            prerelease: false
        };

        execSync(`curl -X POST -H "Authorization: token ${process.env.GITHUB_TOKEN}" -H "Content-Type: application/json" -d '${JSON.stringify(releaseData)}' https://api.github.com/repos/HakimIno/tik-forge/releases`, { stdio: 'inherit' });

        console.log('Prebuilds published successfully');
    } catch (error) {
        console.error('Failed to publish prebuilds:', error);
        process.exit(1);
    }
}

publishPrebuilds().catch(console.error);