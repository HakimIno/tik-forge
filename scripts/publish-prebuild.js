const path = require('path');
const fs = require('fs');
const { execSync } = require('child_process');
const https = require('https');

async function createGitHubRelease(token, owner, repo, tagName, name, body) {
    return new Promise((resolve, reject) => {
        const data = JSON.stringify({
            tag_name: tagName,
            name: name,
            body: body,
            draft: false,
            prerelease: false
        });

        const options = {
            hostname: 'api.github.com',
            path: `/repos/${owner}/${repo}/releases`,
            method: 'POST',
            headers: {
                'Accept': 'application/vnd.github.v3+json',
                'Authorization': `token ${token}`,
                'User-Agent': 'Node.js',
                'Content-Type': 'application/json',
                'Content-Length': data.length
            }
        };

        const req = https.request(options, (res) => {
            let responseData = '';
            res.on('data', (chunk) => responseData += chunk);
            res.on('end', () => {
                if (res.statusCode === 201) {
                    resolve(JSON.parse(responseData));
                } else {
                    reject(new Error(`GitHub API responded with status ${res.statusCode}: ${responseData}`));
                }
            });
        });

        req.on('error', reject);
        req.write(data);
        req.end();
    });
}

async function publishPrebuilds() {
    try {
        // Get version from package.json
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

        // Create GitHub release
        console.log('Creating GitHub release...');
        await createGitHubRelease(
            process.env.GITHUB_TOKEN,
            'HakimIno',
            'tik-forge',
            tagName,
            tagName,
            `tik-forge ${version}`
        );

        // Now publish the prebuilds
        console.log('Publishing prebuilds...');
        execSync('npx node-pre-gyp package', {
            stdio: 'inherit'
        });

        execSync('npx node-pre-gyp-github publish', {
            stdio: 'inherit',
            env: {
                ...process.env,
                NODE_PRE_GYP_GITHUB_TOKEN: process.env.GITHUB_TOKEN
            }
        });

        console.log('Prebuilds published successfully');
    } catch (error) {
        console.error('Failed to publish prebuilds:', error);
        process.exit(1);
    }
}

publishPrebuilds().catch(console.error);