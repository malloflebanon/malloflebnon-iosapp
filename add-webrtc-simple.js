#!/usr/bin/env node

const fs = require('fs');

console.log('🔧 Adding WebRTC files to Xcode project...');

const projectPath = 'MallOfLebanon-iOS.xcodeproj/project.pbxproj';
let projectContent = fs.readFileSync(projectPath, 'utf8');

// Generate simple UUIDs (24 chars uppercase hex)
function generateUUID() {
    return Math.random().toString(16).substr(2, 24).toUpperCase().padEnd(24, '0');
}

// WebRTC files to add
const filesToAdd = [
    { name: 'WebRTCService.swift', path: 'Services/WebRTCService.swift', group: 'Services' },
    { name: 'SocketService.swift', path: 'Services/SocketService.swift', group: 'Services' },
    { name: 'WebRTCVideoView.swift', path: 'Views/WebRTCVideoView.swift', group: 'Views' },
    { name: 'WebRTCLiveStreamView.swift', path: 'Views/WebRTCLiveStreamView.swift', group: 'Views' }
];

// Generate UUIDs for the new files
const fileData = {};
filesToAdd.forEach(file => {
    fileData[file.name] = {
        fileRef: generateUUID(),
        buildFile: generateUUID(),
        ...file
    };
});

console.log('Generated UUIDs:');
Object.entries(fileData).forEach(([name, data]) => {
    console.log(`  ${name}: fileRef=${data.fileRef}, buildFile=${data.buildFile}`);
});

// 1. Add PBXBuildFile entries
const buildFilePattern = /\/\* End PBXBuildFile section \*\//;
let buildFileEntries = '';
Object.entries(fileData).forEach(([name, data]) => {
    buildFileEntries += `\t\t${data.buildFile} /* ${name} in Sources */ = {isa = PBXBuildFile; fileRef = ${data.fileRef} /* ${name} */; };\n`;
});

projectContent = projectContent.replace(buildFilePattern, buildFileEntries + '/* End PBXBuildFile section */');

// 2. Add PBXFileReference entries
const fileRefPattern = /\/\* End PBXFileReference section \*\//;
let fileRefEntries = '';
Object.entries(fileData).forEach(([name, data]) => {
    fileRefEntries += `\t\t${data.fileRef} /* ${name} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${name}; sourceTree = "<group>"; };\n`;
});

projectContent = projectContent.replace(fileRefPattern, fileRefEntries + '/* End PBXFileReference section */');

// 3. Add to PBXSourcesBuildPhase (find Sources build phase)
const sourcesPattern = /(isa = PBXSourcesBuildPhase;[\s\S]*?files = \(\s*)([\s\S]*?)(\s*\);[\s\S]*?runOnlyForDeploymentPostprocessing = 0;)/;
const sourcesMatch = projectContent.match(sourcesPattern);

if (sourcesMatch) {
    let sourcesEntries = '';
    Object.entries(fileData).forEach(([name, data]) => {
        sourcesEntries += `\t\t\t\t${data.buildFile} /* ${name} in Sources */,\n`;
    });

    const newSourcesSection = sourcesMatch[1] + sourcesMatch[2] + sourcesEntries + sourcesMatch[3];
    projectContent = projectContent.replace(sourcesMatch[0], newSourcesSection);
}

console.log('✅ Successfully added entries to project file');

// Write the updated project file
fs.writeFileSync(projectPath, projectContent);

console.log('✅ Project file updated with WebRTC files:');
filesToAdd.forEach(file => {
    console.log(`   • ${file.name} (${file.path})`);
});

console.log('\n🎯 Next steps:');
console.log('   1. Open Xcode and add the files to the correct groups manually');
console.log('   2. Add WebRTC framework to project dependencies');
console.log('   3. Build and test the project');