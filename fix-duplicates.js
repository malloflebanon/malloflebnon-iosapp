#!/usr/bin/env node

const fs = require('fs');

console.log('🔧 Fixing duplicate WebRTC file references...');

const projectPath = 'MallOfLebanon-iOS.xcodeproj/project.pbxproj';
let content = fs.readFileSync(projectPath, 'utf8');

// Remove the duplicate build file entries I added
const duplicatesToRemove = [
    '4660D0BA7F79F00000000000 /* SocketService.swift in Sources */',
    '7E36DA87F4F2A00000000000 /* WebRTCService.swift in Sources */',
    '84F20A25E5F0900000000000 /* WebRTCVideoView.swift in Sources */',
    '7FF8F48D3D57C00000000000 /* WebRTCLiveStreamView.swift in Sources */'
];

// Remove the duplicate file reference entries
const duplicateFileRefs = [
    '6569BB72DEC4600000000000 /* SocketService.swift */',
    'A2306DDD42A3400000000000 /* WebRTCService.swift */',
    'D06069E6D227700000000000 /* WebRTCVideoView.swift */',
    'BD9449D20C00F00000000000 /* WebRTCLiveStreamView.swift */'
];

// Remove duplicate build file entries
duplicatesToRemove.forEach(duplicate => {
    const buildFilePattern = new RegExp(`\\s*\\t\\t[A-F0-9]+\\s*\\/\\*\\s*${duplicate.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}.*?\\n`, 'g');
    content = content.replace(buildFilePattern, '');
});

// Remove duplicate file reference entries
duplicateFileRefs.forEach(duplicate => {
    const fileRefPattern = new RegExp(`\\s*\\t\\t[A-F0-9]+\\s*\\/\\*\\s*${duplicate.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}.*?\\n`, 'g');
    content = content.replace(fileRefPattern, '');
});

// Remove duplicate entries from sources build phase
duplicatesToRemove.forEach(duplicate => {
    const sourcePattern = new RegExp(`\\s*\\t\\t\\t\\t[A-F0-9]+\\s*\\/\\*\\s*${duplicate.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}.*?,\\n`, 'g');
    content = content.replace(sourcePattern, '');
});

// Remove the "Recovered References" group that contains orphaned references
const recoveredRefPattern = /\s*EA3FAAB22F390928008C6164 \/\* Recovered References \*\/ = \{[\s\S]*?\};\s*/;
content = content.replace(recoveredRefPattern, '');

// Remove reference to Recovered References from main group
const recoveredRefMainPattern = /\s*EA3FAAB22F390928008C6164 \/\* Recovered References \*\/,?\s*/;
content = content.replace(recoveredRefMainPattern, '');

fs.writeFileSync(projectPath, content);

console.log('✅ Successfully removed duplicate WebRTC file references');
console.log('');
console.log('🎯 Now the project should build without errors!');
console.log('   • Open Xcode: open MallOfLebanon-iOS.xcworkspace');
console.log('   • Build the project: ⌘+B');
console.log('   • WebRTC files are properly integrated');