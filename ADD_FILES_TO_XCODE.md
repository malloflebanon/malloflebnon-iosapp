# 📱 How to Add WebRTC Files to Xcode Project

## 🚨 **Files Already Added to Project Build System**
The files are already configured in the project.pbxproj file, but you need to organize them visually in Xcode.

## 📂 **Where to Add Each File in Xcode**

### **1. Open Xcode**
```bash
cd /Users/ahmadbaba/Desktop/iosapp/MallOfLebanon-iOS
open MallOfLebanon-iOS.xcodeproj
```

### **2. Add Files to Correct Groups**

#### **Services Group** 📁
In Xcode Project Navigator:
1. **Right-click** on `Services` folder
2. Select **"Add Files to 'MallOfLebanon-iOS'"**
3. Navigate to `MallOfLebanon-iOS/Services/` and add:
   - ✅ **WebRTCService.swift**
   - ✅ **SocketService.swift**

#### **Views Group** 📁
In Xcode Project Navigator:
1. **Right-click** on `Views` folder
2. Select **"Add Files to 'MallOfLebanon-iOS'"**
3. Navigate to `MallOfLebanon-iOS/Views/` and add:
   - ✅ **WebRTCVideoView.swift**
   - ✅ **WebRTCLiveStreamView.swift**

## 🎯 **File Locations on Disk**

```
MallOfLebanon-iOS/
├── Services/
│   ├── WebRTCService.swift      ← Add to Services group
│   └── SocketService.swift      ← Add to Services group
└── Views/
    ├── WebRTCVideoView.swift    ← Add to Views group
    └── WebRTCLiveStreamView.swift ← Add to Views group
```

## ⚠️ **Important Notes**

1. **Don't Create New Files** - The files already exist on disk
2. **Just Reference Them** - Use "Add Files" to reference existing files
3. **Check Target Membership** - Ensure files are added to MallOfLebanon-iOS target
4. **Verify Build Phases** - Files should appear in "Compile Sources"

## 🔧 **Alternative: Drag & Drop Method**

1. **Open Finder** - Navigate to project folder
2. **Drag WebRTCService.swift** → Drop on `Services` group in Xcode
3. **Drag SocketService.swift** → Drop on `Services` group in Xcode
4. **Drag WebRTCVideoView.swift** → Drop on `Views` group in Xcode
5. **Drag WebRTCLiveStreamView.swift** → Drop on `Views` group in Xcode

## ✅ **Verification**

After adding files, verify:
- [ ] Files appear in correct groups in Project Navigator
- [ ] Files show checkmark next to target name
- [ ] Build Phases → Compile Sources lists all WebRTC files
- [ ] No build errors when compiling

## 📱 **Result**
Your Project Navigator should look like:
```
MallOfLebanon-iOS
├── Services/
│   ├── WebRTCService.swift      ✅
│   ├── SocketService.swift      ✅
│   └── ... (other services)
└── Views/
    ├── WebRTCVideoView.swift    ✅
    ├── WebRTCLiveStreamView.swift ✅
    └── ... (other views)
```