#!/usr/bin/env node

const fs = require('fs');

console.log('🔧 Final WebRTC cleanup - removing ALL remaining duplicates...');

const projectPath = 'MallOfLebanon-iOS.xcodeproj/project.pbxproj';
let content = fs.readFileSync(projectPath, 'utf8');

// Remove ALL legacy UUID references for WebRTC files
const legacyUUIDs = [
    // From previous grep results
    'EA3FAAB62F390AC0008C6164', 'EA3FAAB32F390AC0008C6164',
    'EA3FAAB72F390AEA008C6164',
    'BD9449D20C00F00000000000',
    '7FF8F48D3D57C00000000000',
    '4660D0BA7F79F00000000000'
];

console.log('🗑️  Removing legacy UUID references...');

legacyUUIDs.forEach(uuid => {
    // Remove any line containing this UUID
    const uuidPattern = new RegExp(`.*${uuid}.*\\n`, 'g');
    content = content.replace(uuidPattern, '');
});

// Also remove any orphaned references in sources build phase
const orphanedSourcesPatterns = [
    /\s*EA3FAAB62F390AC0008C6164[^,\n]*,?\s*/g,
    /\s*4660D0BA7F79F00000000000[^,\n]*,?\s*/g,
    /\s*7FF8F48D3D57C00000000000[^,\n]*,?\s*/g
];

orphanedSourcesPatterns.forEach(pattern => {
    content = content.replace(pattern, '');
});

// Clean up any empty lines or malformed entries
content = content.replace(/\n\s*\n\s*\n/g, '\n\n'); // Remove triple newlines
content = content.replace(/,\s*,/g, ','); // Remove double commas
content = content.replace(/,\s*\n\s*\)/g, '\n\t\t\t)'); // Fix trailing commas before closing parentheses

fs.writeFileSync(projectPath, content);

console.log('✅ Final cleanup complete!');
console.log('   • Removed all legacy WebRTC UUID references');
console.log('   • Cleaned up orphaned source entries');
console.log('   • Fixed formatting issues');
console.log('');
console.log('🎯 Project should now have ZERO duplicate WebRTC references!');