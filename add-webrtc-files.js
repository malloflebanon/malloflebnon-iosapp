#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('uuid');

console.log('🔧 Adding WebRTC files to Xcode project...');

const projectPath = 'MallOfLebanon-iOS.xcodeproj/project.pbxproj';
const projectContent = fs.readFileSync(projectPath, 'utf8');

// WebRTC files to add
const filesToAdd = [
    { name: 'WebRTCService.swift', path: 'Services/WebRTCService.swift' },
    { name: 'SocketService.swift', path: 'Services/SocketService.swift' },
    { name: 'WebRTCVideoView.swift', path: 'Views/WebRTCVideoView.swift' },
    { name: 'WebRTCLiveStreamView.swift', path: 'Views/WebRTCLiveStreamView.swift' }
];

// Generate UUIDs for the new files
const fileRefs = {};
const buildFiles = {};

filesToAdd.forEach(file => {
    fileRefs[file.name] = uuidv4().replace(/-/g, '').substring(0, 24).toUpperCase();
    buildFiles[file.name] = uuidv4().replace(/-/g, '').substring(0, 24).toUpperCase();
});

let updatedContent = projectContent;

// Find the PBXBuildFile section and add new build files
const buildFileSection = updatedContent.match(/\/\* Begin PBXBuildFile section \*\/([\s\S]*?)\/\* End PBXBuildFile section \*\//);
if (buildFileSection) {
    let buildFileContent = buildFileSection[1];

    filesToAdd.forEach(file => {
        const buildFileEntry = `\t\t${buildFiles[file.name]} /* ${file.name} in Sources */ = {isa = PBXBuildFile; fileRef = ${fileRefs[file.name]} /* ${file.name} */; };\n`;
        buildFileContent += buildFileEntry;
    });

    updatedContent = updatedContent.replace(buildFileSection[0],
        `/* Begin PBXBuildFile section */${buildFileContent}/* End PBXBuildFile section */`);
}

// Find the PBXFileReference section and add new file references
const fileRefSection = updatedContent.match(/\/\* Begin PBXFileReference section \*\/([\s\S]*?)\/\* End PBXFileReference section \*\//);
if (fileRefSection) {
    let fileRefContent = fileRefSection[1];

    filesToAdd.forEach(file => {
        const fileRefEntry = `\t\t${fileRefs[file.name]} /* ${file.name} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${file.name}; sourceTree = "<group>"; };\n`;
        fileRefContent += fileRefEntry;
    });

    updatedContent = updatedContent.replace(fileRefSection[0],
        `/* Begin PBXFileReference section */${fileRefContent}/* End PBXFileReference section */`);
}

// Find the PBXSourcesBuildPhase section and add build files to sources
const sourcesBuildPhase = updatedContent.match(/(\/\* Sources \*\/ = {\s*isa = PBXSourcesBuildPhase;\s*buildActionMask = [^;]+;\s*files = \(\s*)([\s\S]*?)(\s*\);\s*runOnlyForDeploymentPostprocessing = 0;\s*};)/);
if (sourcesBuildPhase) {
    let sourcesContent = sourcesBuildPhase[2];

    filesToAdd.forEach(file => {
        const sourceEntry = `\t\t\t\t${buildFiles[file.name]} /* ${file.name} in Sources */,\n`;
        sourcesContent += sourceEntry;
    });

    updatedContent = updatedContent.replace(sourcesBuildPhase[0],
        sourcesBuildPhase[1] + sourcesContent + sourcesBuildPhase[3]);
}

// Find the Services and Views groups and add file references
const servicesGroup = updatedContent.match(/(\/\* Services \*\/ = {\s*isa = PBXGroup;\s*children = \(\s*)([\s\S]*?)(\s*\);\s*path = Services;\s*sourceTree = "<group>";\s*};)/);
if (servicesGroup) {
    let servicesContent = servicesGroup[2];

    ['WebRTCService.swift', 'SocketService.swift'].forEach(fileName => {
        const serviceEntry = `\t\t\t\t${fileRefs[fileName]} /* ${fileName} */,\n`;
        servicesContent += serviceEntry;
    });

    updatedContent = updatedContent.replace(servicesGroup[0],
        servicesGroup[1] + servicesContent + servicesGroup[3]);
}

const viewsGroup = updatedContent.match(/(\/\* Views \*\/ = {\s*isa = PBXGroup;\s*children = \(\s*)([\s\S]*?)(\s*\);\s*path = Views;\s*sourceTree = "<group>";\s*};)/);
if (viewsGroup) {
    let viewsContent = viewsGroup[2];

    ['WebRTCVideoView.swift', 'WebRTCLiveStreamView.swift'].forEach(fileName => {
        const viewEntry = `\t\t\t\t${fileRefs[fileName]} /* ${fileName} */,\n`;
        viewsContent += viewEntry;
    });

    updatedContent = updatedContent.replace(viewsGroup[0],
        viewsGroup[1] + viewsContent + viewsGroup[3]);
}

// Write the updated project file
fs.writeFileSync(projectPath, updatedContent);

console.log('✅ Successfully added WebRTC files to Xcode project:');
filesToAdd.forEach(file => {
    console.log(`   • ${file.name} (${file.path})`);
});

console.log('\n📱 Files added with UUIDs:');
Object.entries(fileRefs).forEach(([name, uuid]) => {
    console.log(`   ${name}: ${uuid}`);
});

console.log('\n🎯 Next steps:');
console.log('   1. Open MallOfLebanon-iOS.xcodeproj in Xcode');
console.log('   2. Verify the files appear in the project navigator');
console.log('   3. Build and test the WebRTC functionality');