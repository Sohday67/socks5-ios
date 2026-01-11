## SOCKS5 server for iOS

This app implements a *very* simple SOCKS5 server for iOS. You can use it to increase your tethering speeds when they are artificially limited; other uses are possible.

It is not distributed via the App Store because it'd probably get rejected.

## Installation Options

### Option 1: Download Pre-built IPA (Recommended)

You can download a pre-built unsigned IPA from the [Releases](../../releases) page.

### Option 2: Build using GitHub Actions

1. **Fork this repository** using the fork button on the top right
2. On your forked repository, go to **Settings** > **Actions** > **General**, and enable **Read and Write** permissions under "Workflow permissions"
3. Navigate to the **Actions** tab in your forked repository
4. Select **Build and Release SOCKS5 IPA** workflow
5. Click **Run workflow** and choose your options:
   - **Upload IPA as an Artifact**: Makes the IPA available for download from the workflow run
   - **Create a Release**: Creates a GitHub release with the IPA attached
6. Wait for the build to complete
7. Download the IPA from the workflow artifacts or from the Releases page

### Option 3: Build locally with Xcode

Download this repo, run `git submodule update --init --recursive`, and then build & deploy from Xcode.

## Installing the IPA

Since this is an unsigned IPA, you'll need to sign it before installing. Here are some options:

- **[AltStore](https://altstore.io/)**: Free sideloading tool for iOS
- **[Sideloadly](https://sideloadly.io/)**: Another free sideloading option
- **[TrollStore](https://github.com/opa334/TrollStore)**: If your device supports it, allows permanent installation without signing

## Usage

After installation, open the app. It will display a SOCKS5 proxy address (e.g., `172.20.10.1:4884`). Configure your system or browser to use this address as a SOCKS5 proxy and you're good to go!

### ⚠️ iOS Device Isolation (iOS 17+)

**Important**: Recent iOS versions (iOS 17 and later) have enhanced device isolation that blocks local network access even via USB tethering. This means devices connected to your iPhone's Personal Hotspot (via WiFi or USB) cannot directly access the SOCKS5 proxy running on the iPhone.

### Connection Methods

#### Method 1: External Router (Most Reliable)

Use a portable router to create a shared network:

1. Set up a WiFi hotspot from your portable router
2. Connect both your iPhone and your other device to the router's WiFi
3. Open the SOCKS app on your iPhone - note the displayed IP address
4. Configure your device to use that IP address as a SOCKS5 proxy

**Why this works**: The router creates a standard network where all devices can communicate freely, bypassing iOS's hotspot device isolation.

#### Method 2: USB Tethering (May Work on Older iOS)

On iOS 16 and earlier, USB tethering may bypass device isolation:

1. **Connect your iPhone to your Mac via USB cable**
2. **Enable Personal Hotspot** on your iPhone (Settings > Personal Hotspot)
3. On your Mac, go to **System Settings > Network** - you should see "iPhone USB" as a connected network
4. **Open the SOCKS app** on your iPhone - it will show the proxy address (typically `172.20.10.1:4884`)
5. Configure your Mac to use the SOCKS5 proxy (see macOS Configuration below)

**Note**: This method may not work on iOS 17+ due to enhanced security restrictions.

#### Method 3: VPN-based Solution (iOS 17+)

For iOS 17 and later, a VPN tunnel is required to bypass device isolation. Apps like [PairVPN](https://pairvpn.com/) use this approach - they create a VPN tunnel between the client device and the iPhone, allowing traffic to flow through even with device isolation enabled.

**How VPN bypasses isolation**: The VPN creates an encrypted tunnel that appears as a single connection to iOS, allowing the client device to communicate directly with the iPhone regardless of hotspot isolation settings.

### macOS Proxy Configuration

#### System-wide SOCKS5 Proxy Setup

1. Open **System Settings** (or System Preferences on older macOS)
2. Go to **Network**
3. Select your active connection (e.g., "iPhone USB" for USB tethering, or WiFi if using a router)
4. Click **Details...** (or **Advanced...** on older macOS)
5. Go to the **Proxies** tab
6. Check **SOCKS Proxy**
7. Enter:
   - **Server**: Your iPhone's IP address (shown in the app)
   - **Port**: `4884`
8. Click **OK**, then **Apply**

#### Browser-only Proxy (Firefox)

If you only want to route browser traffic through the proxy:

1. Open Firefox and go to **Settings**
2. Search for "proxy" or scroll to **Network Settings**
3. Click **Settings...**
4. Select **Manual proxy configuration**
5. Enter in **SOCKS Host**: Your iPhone's IP address and **Port**: `4884`
6. Select **SOCKS v5**
7. Check **Proxy DNS when using SOCKS v5** (recommended)
8. Click **OK**

#### Terminal/Command Line Proxy

For command-line applications that support SOCKS proxy:

```bash
# Set environment variables (replace IP with your iPhone's IP)
export ALL_PROXY=socks5://YOUR_IPHONE_IP:4884
export all_proxy=socks5://YOUR_IPHONE_IP:4884

# Or use with specific commands
curl --proxy socks5://YOUR_IPHONE_IP:4884 https://example.com
```

### Troubleshooting

- **Can't connect via Personal Hotspot (WiFi or USB)?** This is due to iOS device isolation. Use an external router (Method 1) or a VPN-based solution (Method 3).
- **"Connection refused" errors?** Make sure the SOCKS app is running on your iPhone and showing "Running" status.
- **Slow speeds?** This app is designed to bypass carrier throttling. If speeds are still slow, check your carrier's policies.
- **App stops when iPhone sleeps?** The app uses background audio to stay running, but some iOS versions may still suspend it. Keep the app in foreground for best results.
- **iOS 17+ users**: Due to enhanced device isolation, you'll need either an external router or a VPN-based solution like PairVPN.

## Alternative

UPDATE: Because sideloading apps is a pain, you might also consider using [nneonneo/iOS-SOCKS-Server](https://github.com/nneonneo/ios-socks-server) instead; it's a Python script that can be easily loaded into Pythonista for iOS and used forever without sideloading restrictions.
