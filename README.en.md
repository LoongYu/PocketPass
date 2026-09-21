# PocketPass

[中文](README.md) | [English](README.en.md)

<p align="center">
  <img src="Sources/PocketPass/Resources/PocketLogo.png" width="160" alt="PocketPass app logo">
</p>

<p align="center">A local-first macOS password manager built natively with SwiftUI.</p>

> Current version: **V1.2(4)**<br>
> System requirement: **macOS 26 or later**<br>
> Architectures: **Apple Silicon and Intel (Universal Binary)**

## Purpose

PocketPass (Chinese brand name: 口袋密码) organizes login information for websites, apps and services locally on your Mac. It does not read the macOS Keychain or connect to iCloud in the current version. On first launch, it provides default categories but no preloaded accounts or passwords.

## Implemented features

- **Encrypted local storage:** Accounts, passwords, categories, tags and attachments are stored in an AES-GCM encrypted vault.
- **Multiple logins:** An account item can contain multiple logins, each with its own username, password and custom fields.
- **Flexible fields:** Common templates include account, password, phone number, email, ID, nickname, registration date and URL. You can also create arbitrary fields.
- **Categories and tags:** Customize category names, icons and colors; drag to reorder categories; reuse tags across accounts.
- **Custom icon library:** Upload and manage image icons for reuse across accounts and categories.
- **Icon sources:** Built-in monochrome icons, App Store search across nine common regions, website favicons and local photo library images.
- **Image attachments:** Save a limited number of local image attachments on each account item.
- **App lock:** Unlock with Touch ID or your macOS device password; choose immediate or delayed automatic locking.
- **Recycle bin:** Deleted data is retained for 30 days and can be restored or permanently deleted earlier.
- **Bulk management:** Select individual or all accounts to move to the recycle bin; restore or permanently delete items in bulk.
- **Data transfer:** Import and export encrypted `.pocketpass` backups, JSON, CSV and Markdown. `.pocketpass` and JSON preserve complete account, category and custom icon data; CSV and Markdown are plain-text formats.
- **Duplicate detection:** Records with the same ID are merged by modification time. Identical account contents are skipped to prevent duplicate imports.
- **Progress feedback:** Import and export show progress, processed counts and result summaries.
- **Search and sorting:** Search accounts, URLs, tags and field contents; sort by name, category or last modification.
- **Password generator:** Configure length, uppercase and lowercase letters, digits and symbols; copy a result or insert it directly into a password field.
- **Bilingual interface:** Native Simplified Chinese and English, switchable immediately in settings with the choice remembered.

## V1.2 highlights

- Hardened the local vault: missing keys, corrupted ciphertext and failed saves cannot overwrite existing data; unsuccessful changes are rolled back.
- Fixed the app-lock overlay so account details and edit windows are dismissed when the vault locks.
- Improved round-trip transfer and duplicate detection for `.pocketpass`, JSON, CSV and Markdown.
- `.pocketpass` and JSON preserve account icons, category icons and the custom icon library.
- Added a 250 MB import-file limit and moved import, export and encryption work to the background.
- Limited remote icon download size and image pixel dimensions to reduce resource use from unusual images.
- Unified the data model, brand icons, and Chinese and English resources across macOS, iPhone and iPad.

## Product characteristics

### Local-first

V1.2(4) does not connect to cloud services. The vault is stored in the current user's:

```text
~/Library/Application Support/口袋密码/
```

Vault contents are encrypted with AES-GCM. The local encryption key is kept in the same application data directory with file permissions limited to the current user. The app does not read the system Keychain.

### Native experience

The app uses Swift and SwiftUI. Its interface, Touch ID/device-password verification, file picker and system icons use native macOS capabilities.

### Portable data

An encrypted `.pocketpass` backup is suited to complete, secure migration. JSON also contains complete data and icons, but account passwords and image contents are encoded as plaintext. CSV and Markdown are useful for reviewing, organizing or exchanging textual data with other tools; they do not include icons or attachments. Protect every plaintext export carefully.

## Download and installation

1. Download the latest macOS DMG or unsigned iOS/iPadOS IPA from [Releases](https://github.com/LoongYu/PocketPass/releases).
2. Open the DMG and drag “口袋密码” into **Applications**.
3. Launch PocketPass from the Applications folder.

### First-launch notice

The current build has a temporary signature and has not been signed and notarized with Apple Developer ID. If macOS blocks the first launch:

1. Right-click “口袋密码” in Applications and choose **Open**; or
2. Open **System Settings → Privacy & Security**, locate the warning and choose **Open Anyway**.

Download only official releases from this repository. You can verify a download with the SHA-256 value on the release page.

## Build locally

Install Xcode and the macOS 26 SDK:

```bash
swift run PocketPass
```

Build a Universal app and DMG:

```bash
./Scripts/build-release.sh
```

The output is:

```text
dist/PocketPass-V1.2(4)-20260921.dmg
```

## Privacy and security

- The app does not read information from the macOS Keychain.
- V1.2(4) does not upload the vault or include analytics, advertising or tracking SDKs.
- App lock prevents others from viewing data in the app interface; it does not replace disk encryption or macOS account security.
- A damaged device or lost application data directory may make recovery impossible. Create encrypted `.pocketpass` backups regularly.
- This project has not undergone an independent security audit. Evaluate the risks before using it for high-value production credentials.

## Roadmap

### V1.x

- Password strength, weak-password and duplicate-password checks.
- More complete bulk import, conflict handling and backup management.
- Developer ID signing, notarization and automatic updates.
- Accessibility, keyboard navigation and performance improvements.

### V2.0

- End-to-end encrypted iCloud synchronization when an Apple Developer account and CloudKit capabilities become available.
- A conflict strategy that prefers the more recently modified version, with conflict records.
- Productized, released native iPhone and iPad clients using compatible data structures and migration formats.

### Later goals

- Safari, Chrome, Edge and Firefox extensions.
- System password autofill and saving credentials after login.
- Cross-device sharing, emergency access and more granular security policies.

## Local iOS / iPadOS installation

The repository includes a Universal iOS target that you can run on an iPhone or iPad from Xcode. The release page provides an unsigned IPA; sign it with your own Apple ID or developer certificate before installation. An unsigned IPA cannot be installed directly. The current iOS/iPadOS version also stores data locally and does not connect to iCloud.

## Not yet included

- iCloud synchronization.
- An iOS/iPadOS release through the App Store or TestFlight (a Universal iOS target and unsigned IPA are available).
- Browser extensions or web autofill.

## License

This project is licensed for personal, non-commercial use. Individuals may download, run and modify it for personal purposes. Commercial use, sale, rental, commercial redistribution, commercial hosting and use of this project or its derivatives in commercial services are prohibited. See [LICENSE](LICENSE) for the full terms. Password managers handle sensitive data; assess the security risks and keep encrypted backups.
