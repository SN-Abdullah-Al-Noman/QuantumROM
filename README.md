![QuantumROM Logo](QuantumROM/logo/QuantumROM.jpg)

## 📌 Overview.
This Custom ROM is built by combining and refining features from multiple projects, including UNICA, Legacy-UI, and AstroRom.
- The goal of this ROM is to provide a clean, optimized, and stable One UI experience with enhanced usability and performance.

### 🛠️ Tools features.
- Download firmware directly from samsung server.
- File config and file contexts generate.
- Extract and img build ( erofs and ext4 supported).

### ✨ Key Features.
- System Optimization.
- Heavy debloated system (removed unnecessary apps & services).
- Improved performance and smoother UI experience.
- Optimized background processes.
- Better battery efficiency.
- Enhanced Functionality.
- Screenshot anywhere (enabled globally).
- Built-in Screen Recorder.
- More floating features enabled.
- Edge features fully working.
- Stock device conig always be added.
- Extra brightness support.
- Object, shadow and reflection remover support.
- Multi user support.
- Camera privacy toggle support.
- Private share patch.
- Google photos unlimited backup.
- JDM device support.
- [BluetoothLibraryPatcher](https://github.com/3arthur6/BluetoothLibraryPatcher) integrated

### 🔐 Security & Privacy.
- Secure Folder support.
- Essential security components retained.
- Stable and safe daily-driver experience.

### 📱 One UI Experience.
- Full One UI apps included.
- Important system apps preserved.
- China Smart Manager support.
- AI features enabled.

### 🎯 Project Goal.
- To deliver a lightweight yet fully featured Samsung One UI ROM that balances.
- Performance.
- Stability.
- Essential Features.
- Clean User Experience.

## How to Use:
#### 1. Fork the Repository.
Give a ⭐ star to the repository.
Fork the repository to your GitHub account.

#### 2. Run the Workflow.
Open your forked repository.
- Go to the Actions tab.
- Select QuantumROM Tools.
- Click Run workflow.

#### 3. Set Your Device Model.
Update your device model in the STOCK_DEVICE_MODEL option.
- If your model is available in /QuantumROM/Device folder of this repository, the tool will work for your device.
- If your model is not present, set STOCK_DEVICE_MODEL to None.

#### 4. Kernel BPF Version Option.
Set this o
ption to True if your kernel BPF version is 5.4 (lower than 5.10).
- Otherwise, set it to False.

#### 5. Set Target Device Information.
- Configure the following options:
- TARGET_DEVICE_MODEL
- The device model from which you want to port the ROM.
- TARGET_DEVICE_CSC
- The country/region code used to download the target device firmware.
- TARGET_DEVICE_IMEI
- Required to download the target device firmware from the Samsung server.
- Change the IMEI if you want to change the target device.

#### 6. OUTPUT_FILESYSTEM (erofs / ext4).
My tool can build images in two formats:
- erofs
  - Recommended if your device partition size is small.
  - Saves storage space.
  - Your kernel must support EROFS.
- ext4
  - Use this if your kernel does not support EROFS.
  - The generated image will be larger in size.

#### 7. Compress IMG to XZ (True / False).
If set to True:
 - The generated image will be compressed to .xz format.
 - This reduces file size before uploading.

If set to False:
 - The image will remain in its original format without compression.
   
#### 8. Add Git Credentials:
In your forked repository, go to:
-Settings → Secrets and variables → Actions
- Click **New repository secret**, then create a new secret:
- Name:
  - GIT_TOKEN
  - Add git secret token and save.
  - You can search on YouTube for a guide on how to create a GitHub Personal Access Token.
  - If you do not add the `GIT_TOKEN`, the built ROM info and link will not be added to your repository's Release section. You will get link only in runner output.

### Credits:
#### 1. Samsung Firmware Downloader.
- martinetd
- https://github.com/martinetd/samloader
- Used for downloading Samsung firmware.

#### 2. Multi Disabler.
- ianmacd
- https://github.com/ianmacd/multidisabler-samsung
- Used for disabling Samsung security and data encryption.

#### 3. Bluetooth Library Patcher.
- 3arthur6
- https://github.com/3arthur6/BluetoothLibraryPatcher
- Used for patching Samsung Bluetooth libraries.

#### 4. UN1CA Project.
- salvogiangri
- https://github.com/salvogiangri/UN1CA

#### Components Used from UN1CA.
- `HEX_PATCH` function (modified from UN1CA implementation)
- Knox Guard Patch (from UN1CA)
- Secure Flag Patch (from UN1CA)
- SSRM Patch (from UN1CA)
- Some SELinux patches followed the UN1CA implementation.

#### 5. Bootanimation fix.
-  ExtremeXT
-  https://github.com/ExtremeXT
- For bootanimation then reboot bug fix.

#### 6. Google photos unlimited backup.
- VehanRajintha
- https://github.com/VehanRajintha/Free-Unlimited-Google-Cloud-Backup-Magisk-Module

#### 7. ChatGPT.
- https://chat.openai.com
- For providing bash commands and bash functions according to the project requirements and instructions.

#### 8. GoFile Uploader.
- Sushrut1101
- https://github.com/Sushrut1101/GoFile-Upload

### Licensing.
This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.
- **[android-tools](https://github.com/nmeum/android-tools)** - Licensed under Apache License 2.0
- **[apktool](https://github.com/iBotPeaches/Apktool)** - Licensed under Apache License 2.0  
- **[erofs-utils](https://github.com/sekaiacg/erofs-utils)** - Dual licensed (GPL-2.0, Apache-2.0)
- **[platform_build](https://android.googlesource.com/platform/build)** - Licensed under Apache License 2.0
- **[e2fsprogs](https://github.com/tytso/e2fsprogs)** - Licensed under GPL-2.0 / LGPL-2.1
