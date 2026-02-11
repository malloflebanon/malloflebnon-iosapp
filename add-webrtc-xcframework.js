#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

console.log('🔧 Adding WebRTC XCFramework manually to Xcode project...');

const projectPath = 'MallOfLebanon-iOS.xcodeproj/project.pbxproj';
let content = fs.readFileSync(projectPath, 'utf8');

// Generate UUIDs for WebRTC framework
function generateUUID() {
    return 'XXXXXXXXXXXXXXXXXXXXXXXX'.replace(/[X]/g, function() {
        return (Math.random() * 16 | 0).toString(16).toUpperCase();
    });
}

const webrtcUUIDs = {
    frameworkRef: generateUUID(),
    buildFile: generateUUID(),
    frameworksBuildPhase: 'EA3FAAA72F390AC0008C6164' // Use existing frameworks build phase
};

console.log('📦 Generated UUIDs for WebRTC framework integration');

// Add PBXBuildFile entry for WebRTC
const buildFileSection = content.match(/(\/* Begin PBXBuildFile section \*\/)([^]*?)(\/* End PBXBuildFile section \*\/)/);
if (buildFileSection) {
    const newBuildFile = `\t\t${webrtcUUIDs.buildFile} /* WebRTC.xcframework in Frameworks */ = {isa = PBXBuildFile; fileRef = ${webrtcUUIDs.frameworkRef} /* WebRTC.xcframework */; };`;

    const updatedSection = buildFileSection[1] + buildFileSection[2] + '\t' + newBuildFile + '\n' + buildFileSection[3];
    content = content.replace(buildFileSection[0], updatedSection);
    console.log('✅ Added PBXBuildFile entry for WebRTC.xcframework');
}

// Add PBXFileReference entry for WebRTC
const fileRefSection = content.match(/(\/* Begin PBXFileReference section \*\/)([^]*?)(\/* End PBXFileReference section \*\/)/);
if (fileRefSection) {
    const newFileRef = `\t\t${webrtcUUIDs.frameworkRef} /* WebRTC.xcframework */ = {isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; name = WebRTC.xcframework; path = Frameworks/WebRTC.xcframework; sourceTree = "<group>"; };`;

    const updatedSection = fileRefSection[1] + fileRefSection[2] + '\t' + newFileRef + '\n' + fileRefSection[3];
    content = content.replace(fileRefSection[0], updatedSection);
    console.log('✅ Added PBXFileReference entry for WebRTC.xcframework');
}

// Add to Frameworks group
const frameworksGroup = content.match(/(EA3FAAB02F390AC0008C6164 \/\* Frameworks \*\/ = \{[^}]*children = \()([^)]*?)(\);)/);
if (frameworksGroup) {
    const children = frameworksGroup[2];
    if (!children.includes('WebRTC.xcframework')) {
        const newChildren = children + `\t\t\t\t${webrtcUUIDs.frameworkRef} /* WebRTC.xcframework */,\n`;
        const updatedGroup = frameworksGroup[1] + newChildren + frameworksGroup[3];
        content = content.replace(frameworksGroup[0], updatedGroup);
        console.log('✅ Added WebRTC.xcframework to Frameworks group');
    }
}

// Add to PBXFrameworksBuildPhase
const frameworksBuildPhase = content.match(/(EA3FAAA82F390AC0008C6164 \/\* Frameworks \*\/ = \{[^}]*files = \()([^)]*?)(\);)/);
if (frameworksBuildPhase) {
    const files = frameworksBuildPhase[2];
    if (!files.includes(webrtcUUIDs.buildFile)) {
        const newFiles = files + `\t\t\t\t${webrtcUUIDs.buildFile} /* WebRTC.xcframework in Frameworks */,\n`;
        const updatedPhase = frameworksBuildPhase[1] + newFiles + frameworksBuildPhase[3];
        content = content.replace(frameworksBuildPhase[0], updatedPhase);
        console.log('✅ Added WebRTC.xcframework to Frameworks build phase');
    }
}

// Write the updated content
fs.writeFileSync(projectPath, content);

// Create Frameworks directory if it doesn't exist
const frameworksDir = './Frameworks';
if (!fs.existsSync(frameworksDir)) {
    fs.mkdirSync(frameworksDir, { recursive: true });
    console.log('📁 Created Frameworks directory');
}

console.log('');
console.log('🎯 WebRTC XCFramework integration complete!');
console.log('');
console.log('📋 Next steps:');
console.log('1. Download WebRTC.xcframework from a reliable source');
console.log('2. Place it in the Frameworks/ directory');
console.log('3. The project should build successfully with WebRTC imports');
console.log('');
console.log('💡 Suggested download sources:');
console.log('   - https://github.com/stasel/WebRTC/releases');
console.log('   - Google WebRTC builds');
console.log('');