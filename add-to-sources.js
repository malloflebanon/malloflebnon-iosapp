#!/usr/bin/env node

const fs = require('fs');

console.log('🔧 Adding WebRTC files to Sources build phase...');

const projectPath = 'MallOfLebanon-iOS.xcodeproj/project.pbxproj';
let content = fs.readFileSync(projectPath, 'utf8');

// Find the Sources build phase files section and add WebRTC files
const sourcesBuildPhase = content.match(/(E19999940000000000000000 \/\* Sources \*\/ = \{[\s\S]*?files = \()([\s\S]*?)(\);)/);

if (sourcesBuildPhase) {
    console.log('📝 Found Sources build phase, adding WebRTC files...');

    let sourceFiles = sourcesBuildPhase[2];

    // Add all WebRTC build file references to the sources
    const webrtcBuildFiles = [
        '74C8476E10321898A28A3829 /* WebRTCService.swift in Sources */,',
        '75AF86F67C4FB834FD193EE9 /* SocketService.swift in Sources */,',
        '2B7BF29AA184CBB63CD04ABA /* WebRTCVideoView.swift in Sources */,',
        '7B1ED1F00B655775AD186AB3 /* WebRTCLiveStreamView.swift in Sources */,'
    ];

    // Add WebRTC files to the end of the sources list
    webrtcBuildFiles.forEach(buildFile => {
        if (!sourceFiles.includes(buildFile.split(' /*')[0])) {
            sourceFiles += '\t\t\t\t' + buildFile + '\n';
        }
    });

    const newSourcesBuildPhase = sourcesBuildPhase[1] + sourceFiles + sourcesBuildPhase[3];
    content = content.replace(sourcesBuildPhase[0], newSourcesBuildPhase);

    // Write the updated content
    fs.writeFileSync(projectPath, content);

    console.log('✅ Successfully added WebRTC files to Sources build phase!');
    console.log('');
    console.log('📋 Added to build phase:');
    webrtcBuildFiles.forEach(file => {
        const fileName = file.match(/\/\* (.*?) in Sources/)[1];
        console.log(`   • ${fileName}`);
    });
    console.log('');
    console.log('🚀 Project should now build successfully!');

} else {
    console.log('❌ Could not find Sources build phase section');
    process.exit(1);
}