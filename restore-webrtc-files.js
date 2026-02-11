#!/usr/bin/env node

const fs = require('fs');

console.log('🔧 Restoring WebRTC files to Xcode project...');

const projectPath = 'MallOfLebanon-iOS.xcodeproj/project.pbxproj';
let content = fs.readFileSync(projectPath, 'utf8');

// Generate UUIDs for WebRTC files
function generateUUID() {
    return 'XXXXXXXXXXXXXXXXXXXXXXXX'.replace(/[X]/g, function() {
        return (Math.random() * 16 | 0).toString(16).toUpperCase();
    });
}

const webrtcFiles = {
    'WebRTCService.swift': {
        fileRef: generateUUID(),
        buildFile: generateUUID(),
        group: 'Services'
    },
    'SocketService.swift': {
        fileRef: 'EA50231F2F3918BE00B64D18', // Use existing UUID
        buildFile: 'EA5023202F3918BE00B64D18', // Use existing UUID
        group: 'Services'
    },
    'WebRTCVideoView.swift': {
        fileRef: generateUUID(),
        buildFile: generateUUID(),
        group: 'Views'
    },
    'WebRTCLiveStreamView.swift': {
        fileRef: generateUUID(),
        buildFile: generateUUID(),
        group: 'Views'
    }
};

console.log('📦 Generated UUIDs for WebRTC files');

// Add PBXBuildFile entries
const buildFileSection = content.match(/(\/* Begin PBXBuildFile section \*\/)([^]*?)(\/* End PBXBuildFile section \*\/)/);
if (buildFileSection) {
    let newBuildFiles = '';

    Object.keys(webrtcFiles).forEach(fileName => {
        if (fileName !== 'SocketService.swift') { // Skip SocketService as it might already exist
            const { buildFile, fileRef } = webrtcFiles[fileName];
            newBuildFiles += `\t\t${buildFile} /* ${fileName} in Sources */ = {isa = PBXBuildFile; fileRef = ${fileRef} /* ${fileName} */; };\n`;
        }
    });

    const updatedSection = buildFileSection[1] + buildFileSection[2] + newBuildFiles + buildFileSection[3];
    content = content.replace(buildFileSection[0], updatedSection);
    console.log('✅ Added PBXBuildFile entries');
}

// Add PBXFileReference entries
const fileRefSection = content.match(/(\/* Begin PBXFileReference section \*\/)([^]*?)(\/* End PBXFileReference section \*\/)/);
if (fileRefSection) {
    let newFileRefs = '';

    Object.keys(webrtcFiles).forEach(fileName => {
        if (fileName !== 'SocketService.swift') { // Skip SocketService as it might already exist
            const { fileRef } = webrtcFiles[fileName];
            newFileRefs += `\t\t${fileRef} /* ${fileName} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${fileName}; sourceTree = \"<group>\"; };\n`;
        }
    });

    const updatedSection = fileRefSection[1] + fileRefSection[2] + newFileRefs + fileRefSection[3];
    content = content.replace(fileRefSection[0], updatedSection);
    console.log('✅ Added PBXFileReference entries');
}

// Add to Services group
const servicesGroup = content.match(/(EA3FAAB12F390AC0008C6164 \/\* Services \*\/ = \{[^}]*children = \()([^)]*?)(\);)/);
if (servicesGroup) {
    let children = servicesGroup[2];

    ['WebRTCService.swift', 'SocketService.swift'].forEach(fileName => {
        const { fileRef } = webrtcFiles[fileName];
        if (!children.includes(fileName)) {
            children += `\t\t\t\t${fileRef} /* ${fileName} */,\n`;
        }
    });

    const updatedGroup = servicesGroup[1] + children + servicesGroup[3];
    content = content.replace(servicesGroup[0], updatedGroup);
    console.log('✅ Added to Services group');
}

// Add to Views group
const viewsGroup = content.match(/(EA3FAAB82F390AC0008C6164 \/\* Views \*\/ = \{[^}]*children = \()([^)]*?)(\);)/);
if (viewsGroup) {
    let children = viewsGroup[2];

    ['WebRTCVideoView.swift', 'WebRTCLiveStreamView.swift'].forEach(fileName => {
        const { fileRef } = webrtcFiles[fileName];
        if (!children.includes(fileName)) {
            children += `\t\t\t\t${fileRef} /* ${fileName} */,\n`;
        }
    });

    const updatedGroup = viewsGroup[1] + children + viewsGroup[3];
    content = content.replace(viewsGroup[0], updatedGroup);
    console.log('✅ Added to Views group');
}

// Add to Sources build phase
const sourcesBuildPhase = content.match(/(EA3FAAA72F390AC0008C6164 \/\* Sources \*\/ = \{[^}]*files = \()([^)]*?)(\);)/);
if (sourcesBuildPhase) {
    let files = sourcesBuildPhase[2];

    Object.keys(webrtcFiles).forEach(fileName => {
        const { buildFile } = webrtcFiles[fileName];
        if (!files.includes(`${fileName} in Sources`)) {
            files += `\t\t\t\t${buildFile} /* ${fileName} in Sources */,\n`;
        }
    });

    const updatedPhase = sourcesBuildPhase[1] + files + sourcesBuildPhase[3];
    content = content.replace(sourcesBuildPhase[0], updatedPhase);
    console.log('✅ Added to Sources build phase');
}

// Write the updated content
fs.writeFileSync(projectPath, content);

console.log('');
console.log('🎯 WebRTC files restored to Xcode project!');
console.log('');
console.log('📋 Files added:');
Object.keys(webrtcFiles).forEach(fileName => {
    const group = webrtcFiles[fileName].group;
    console.log(`   • ${fileName} (${group})`);
});
console.log('');