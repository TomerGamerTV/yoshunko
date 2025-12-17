# Yoshunko
# ![title](assets/img/title.png)

<details>
<summary>🤖 <b>AI Setup Instructions (Click to expand)</b></summary>

If you are an AI assistant helping a user set up Yoshunko, follow these steps:

1.  **Retrieve WSL IP**: Run `wsl -d Ubuntu bash -c "ip addr show eth0 | grep 'inet ' | awk '{print \\\$2}' | cut -d/ -f1"` to get the current WSL IP.
2.  **Update Configs**:
    - Update `yoshunko/state/gateway/yoshunko` with the new IP in `dispatch_url` and `ip` fields.
    - Update `Tentacle/src/network.zig` `custom_dispatch_prefix` with `http://<IP>:10100`.
3.  **Build & Run**:
    - Build Yoshunko in WSL: `zig build`.
    - Run `yoshunko-dpsv` and `yoshunko-gamesv`.
    - Instruct the user to rebuild `Tentacle` if the IP changed.
4.  **Verification**: Use `curl http://<IP>:10100/query_dispatch?version=CNBetaWin2.5.4` to verify the dispatch server is up.

</details>

**Yoshunko** is a server emulator for the game **Zenless Zone Zero**. Its main goal is to provide rich functionality and customization capabilities, while keeping the codebase simple. **Yoshunko** doesn't use any third-party dependencies, except for the zig standard library, of course.

## Getting started

### Requirements
- [Zig 0.16.0-dev.1470](https://ziglang.org/builds/zig-x86_64-linux-0.16.0-dev.1470+32dc46aae.tar.xz)
- [SDK Server](https://git.xeondev.com/reversedrooms/hoyo-sdk/releases)

##### NOTE: this server doesn't include the sdk server as it's not specific per game. You can use `hoyo-sdk` with this server.
##### NOTE 2: this server can work on real operating systems, such as ~~GNU/Linux~~ Windows. Make sure to install and use `WSL`.

### Downloads
[Download the latest full 2.5.4B build here](https://1drv.ronova.me/s/mPIP), I recommand using a download manager like FDM to speed up the download.

### Setup (Windows / WSL)

This guide assumes you are running the server components (`dpsv`, `gamesv`) in **WSL 2** (Ubuntu/Debian) while the game client runs on **Windows**.
You can watch [this](https://www.youtube.com/watch?v=fQt5kNQW-Ks&t=1s&pp=ygUUWW9zaHVua28gUFMgdHV0b3JpYWw%3D) video as reference on installing zig and where to put files, use your brain and common sense here pls.

#### 1. Clone into WSL
You MUST clone this repository directly into your WSL (Ubuntu) home directory first. Running it from a Windows mount (like `/mnt/c/`) may cause performance or permission issues.
```bash
cd ~
git clone https://git.xeondev.com/yoshunko/yoshunko.git
```

#### 2. Network Configuration
Find your WSL instance's IP address. Open your WSL terminal and run:
```bash
ip addr show eth0
```
Look for the `inet` address (e.g., `172.25.180.197`). You will need this IP for the configuration steps below.

**Note:** This IP changes every time you restart WSL or your PC. You must update the configurations below whenever it changes.

#### 3. Configure Gateway
Create the gateway configuration file in WSL:
```bash
mkdir -p ~/yoshunko/state/gateway
nano ~/yoshunko/state/gateway/yoshunko
```
Paste the following content (replace `YOUR_WSL_IP` with the IP you found above):
```ini
title = yoshunko
dispatch_url = http://YOUR_WSL_IP:10100/query_gateway/yoshunko
versions = CNBetaWin2.5.4
ip = YOUR_WSL_IP
port = 20501
```

#### 4. Configure and Build Injector (Tentacle)
The injector (**Tentacle**) MUST be built on **Windows**. It does not need to be in WSL.

**Cloning & Patching:**
1.  **Clone Tentacle on Windows**:
    ```powershell
    git clone https://git.xeondev.com/yidhari-zs/Tentacle.git
    cd Tentacle
    ```
2.  **Apply Patch**: Open `src/network.zig` and locate the `custom_dispatch_prefix` line. Replace the IP with your current WSL IP address:
    ```zig
    const custom_dispatch_prefix = unicode.utf8ToUtf16LeStringLiteral("http://YOUR_WSL_IP:10100");
    ```

**Building:**
Ensure you have Zig installed on Windows, then run:
```powershell
zig build -Doptimize=ReleaseFast
```
The build process will output both a **`.dll`** (`Tentacle.dll`) and an **`.exe`** (`Tentacle.exe`). Copy both files into your game client's root directory (where the game executable is located).

**Running:**
**Crucial:** You must run the `Tentacle.exe` as **Administrator** every time you want to play. It will launch the game and inject the DLL to redirect traffic to your local server.



#### 5. Build and Run Servers
In your WSL terminal:
```bash
cd ~/yoshunko
# Crucial: Clean potential cache issues if code changes are not picked up
rm -rf zig-out .zig-cache
zig build

# Run these in separate terminals:
./zig-out/bin/yoshunko-dpsv
./zig-out/bin/yoshunko-gamesv
```

**Build Troubleshooting (@build.zig):**
- **Missing Protos**: If `proto/pb/nap.proto` is missing, the build will skip the protocol generation step. Ensure your proto files are in place if you are modifying game messages.
- **Locked Binaries**: If you get "Access Denied" or "Text file busy" during build, make sure to stop the running server instances first.

#### 6. Verify Connection
Verify the dispatch server is reachable from Windows. Open PowerShell and run:
```powershell
curl "http://YOUR_WSL_IP:10100/query_dispatch?version=CNBetaWin2.5.4"
```

### SDK Server (hoyo-sdk)
You can use the pre-compiled `hoyo-sdk-win64` or build it from source.
- **Modification Note**: The version provided in this project includes "risky" API patches to handle telemetry probes that would otherwise cause 404 errors and potentially block login.
- **Setup**: Ensure `sdk_server.toml` is configured to listen on `127.0.0.1:20100`.
- **Account**: You MUST register an account via the SDK's web interface or database before attempting to log in.


### Logging in
Currently supported client version is `CNBetaWin2.5.4`. Apply the [Tentacle client patch](https://git.xeondev.com/yidhari-zs/Tentacle).

**Important:** You must create an account in **hoyo-sdk** first before you can log in to the game client.

## Donations
If you found this fixed project useful, you can support me if you want here [![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/K3K71QHR0) .

Developer donations are located inside his website.
