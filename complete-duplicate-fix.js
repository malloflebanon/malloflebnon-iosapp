#!/usr/bin/env node

const fs = require('fs');

console.log('🔧 Complete duplicate WebRTC file cleanup...');

const projectPath = 'MallOfLebanon-iOS.xcodeproj/project.pbxproj';
let content = fs.readFileSync(projectPath, 'utf8');

// All WebRTC file references to completely clean up
const webrtcFiles = [
    'WebRTCService.swift',
    'SocketService.swift',
    'WebRTCVideoView.swift',
    'WebRTCLiveStreamView.swift'
];

console.log('🗑️  Removing ALL WebRTC file references...');

// First, remove ALL build file entries for WebRTC files
webrtcFiles.forEach(fileName => {
    // Remove all build file entries (multiple patterns to catch all variants)
    const buildFilePatterns = [
        new RegExp(`\\s*\\t\\t[A-F0-9]+\\s*\\/\\*\\s*${fileName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*in Sources\\s*\\*\\/\\s*=\\s*\\{[^}]*\\};\\s*`, 'g'),
        new RegExp(`\\s*\\t\\t[A-F0-9]+\\s*\\/\\*\\s*${fileName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*in Sources\\s*\\*\\/\\s*,?\\s*`, 'g')
    ];

    buildFilePatterns.forEach(pattern => {
        content = content.replace(pattern, '');
    });

    // Remove all file reference entries
    const fileRefPatterns = [
        new RegExp(`\\s*\\t\\t[A-F0-9]+\\s*\\/\\*\\s*${fileName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*\\*\\/\\s*=\\s*\\{[^}]*\\};\\s*`, 'g'),
        new RegExp(`\\s*\\t\\t[A-F0-9]+\\s*\\/\\*\\s*${fileName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*\\*\\/\\s*,?\\s*`, 'g')
    ];

    fileRefPatterns.forEach(pattern => {
        content = content.replace(pattern, '');
    });

    // Remove from sources build phase
    const sourcesPatterns = [
        new RegExp(`\\s*\\t\\t\\t\\t[A-F0-9]+\\s*\\/\\*\\s*${fileName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*in Sources\\s*\\*\\/\\s*,\\s*`, 'g'),
        new RegExp(`\\s*\\t\\t\\t\\t[A-F0-9]+\\s*\\/\\*\\s*${fileName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\s*in Sources\\s*\\*\\/\\s*`, 'g')
    ];

    sourcesPatterns.forEach(pattern => {
        content = content.replace(pattern, '');
    });
});

console.log('➕ Adding single clean WebRTC file references...');

// Generate new clean UUIDs
function generateUUID() {
    return 'XXXXXXXXXXXXXXXXXXXXXXXX'.replace(/[X]/g, function() {
        return (Math.random() * 16 | 0).toString(16).toUpperCase();
    });
}

// Create clean new references for each WebRTC file
const webrtcFileData = {};
webrtcFiles.forEach(fileName => {
    webrtcFileData[fileName] = {
        fileRef: generateUUID(),
        buildFile: generateUUID()
    };
});

// Add clean PBXBuildFile entries
const buildFileSection = content.match(/(\/\* Begin PBXBuildFile section \*\/)([\s\S]*?)(\/\* End PBXBuildFile section \*\/)/);
if (buildFileSection) {
    let newBuildFiles = '';
    Object.keys(webrtcFileData).forEach(fileName => {
        const { fileRef, buildFile } = webrtcFileData[fileName];
        newBuildFiles += `\t\t${buildFile} /* ${fileName} in Sources */ = {isa = PBXBuildFile; fileRef = ${fileRef} /* ${fileName} */; };\n`;
    });

    const newBuildFileSection = buildFileSection[1] + buildFileSection[2] + newBuildFiles + buildFileSection[3];
    content = content.replace(buildFileSection[0], newBuildFileSection);
}

// Add clean PBXFileReference entries
const fileRefSection = content.match(/(\/\* Begin PBXFileReference section \*\/)([\s\S]*?)(\/\* End PBXFileReference section \*\/)/);
if (fileRefSection) {
    let newFileRefs = '';
    Object.keys(webrtcFileData).forEach(fileName => {
        const { fileRef } = webrtcFileData[fileName];
        const folderName = (fileName.includes('Service')) ? 'Services' : 'Views';
        newFileRefs += `\t\t${fileRef} /* ${fileName} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${fileName}; sourceTree = "<group>"; };\n`;
    });

    const newFileRefSection = fileRefSection[1] + fileRefSection[2] + newFileRefs + fileRefSection[3];
    content = content.replace(fileRefSection[0], newFileRefSection);
}

// Add to Services group
const servicesGroup = content.match(/(EA3FAAB12F390AC0008C6164 \/\* Services \*\/ = \{[\s\S]*?children = \()([\s\S]*?)(\);)/);
if (servicesGroup) {
    let serviceFiles = servicesGroup[2];

    // Add WebRTC service files
    ['WebRTCService.swift', 'SocketService.swift'].forEach(fileName => {
        const { fileRef } = webrtcFileData[fileName];
        if (!serviceFiles.includes(fileName)) {
            serviceFiles += `\t\t\t\t${fileRef} /* ${fileName} */,\n`;
        }
    });

    const newServicesGroup = servicesGroup[1] + serviceFiles + servicesGroup[3];
    content = content.replace(servicesGroup[0], newServicesGroup);
}

// Add to Views group
const viewsGroup = content.match(/(EA3FAAB82F390AC0008C6164 \/\* Views \*\/ = \{[\s\S]*?children = \()([\s\S]*?)(\);)/);
if (viewsGroup) {
    let viewFiles = viewsGroup[2];

    // Add WebRTC view files
    ['WebRTCVideoView.swift', 'WebRTCLiveStreamView.swift'].forEach(fileName => {
        const { fileRef } = webrtcFileData[fileName];
        if (!viewFiles.includes(fileName)) {
            viewFiles += `\t\t\t\t${fileRef} /* ${fileName} */,\n`;
        }
    });

    const newViewsGroup = viewsGroup[1] + viewFiles + viewsGroup[3];
    content = content.replace(viewsGroup[0], newViewsGroup);
}

// Add to sources build phase
const sourcesBuildPhase = content.match(/(EA3FAAA72F390AC0008C6164 \/\* Sources \*\/ = \{[\s\S]*?files = \()([\s\S]*?)(\);)/);
if (sourcesBuildPhase) {
    let sourceFiles = sourcesBuildPhase[2];

    // Add all WebRTC files to sources
    Object.keys(webrtcFileData).forEach(fileName => {
        const { buildFile } = webrtcFileData[fileName];
        if (!sourceFiles.includes(`${fileName} in Sources`)) {
            sourceFiles += `\t\t\t\t${buildFile} /* ${fileName} in Sources */,\n`;
        }
    });

    const newSourcesBuildPhase = sourcesBuildPhase[1] + sourceFiles + sourcesBuildPhase[3];
    content = content.replace(sourcesBuildPhase[0], newSourcesBuildPhase);
}

// Write the cleaned content back
fs.writeFileSync(projectPath, content);

console.log('✅ Complete WebRTC duplicate cleanup finished!');
console.log('');
console.log('📋 Summary:');
console.log('   • Removed ALL duplicate WebRTC file references');
console.log('   • Added single clean reference for each WebRTC file');
console.log('   • Files properly organized in Services and Views groups');
console.log('   • Build phase correctly configured');
console.log('');
console.log('🚀 Project should now build without duplicate errors!');