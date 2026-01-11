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

## Alternative

UPDATE: Because sideloading apps is a pain, you might also consider using [nneonneo/iOS-SOCKS-Server](https://github.com/nneonneo/ios-socks-server) instead; it's a Python script that can be easily loaded into Pythonista for iOS and used forever without sideloading restrictions.
