# PocketPass

[中文 README](README.md)

PocketPass is a local-first password manager for macOS, iPhone and iPad, built with Swift and SwiftUI. It stores vault data locally in an encrypted database and does not connect to iCloud in the current release.

> Current version: **V1.2(4)**  
> macOS: **26 or later**  
> macOS architectures: **Apple Silicon and Intel (Universal Binary)**

## Highlights

- AES-GCM encrypted local vault for accounts, passwords, categories, tags and attachments.
- Multiple login records per account, custom fields, field deletion and reordering.
- Custom categories, tags, colors, icons and a local custom icon library.
- Built-in icon search, App Store region selection, website favicons and local images.
- Password generator, application lock, recycle bin and batch account management.
- `.pocketpass` encrypted backup plus JSON, CSV and Markdown transfer formats.
- Duplicate detection and merge rules that make repeated imports idempotent.
- Import/export progress reporting and cross-platform macOS/iOS/iPadOS data models.
- Native Simplified Chinese and English localization.

## Download

Visit the [Releases](https://github.com/LoongYu/PocketPass/releases) page for the latest macOS Universal DMG and the unsigned iOS/iPadOS IPA. Drag the macOS app to **Applications**. The iOS/iPadOS IPA must be signed with your own Apple ID or Apple Developer certificate before installation.

## Build locally

Requirements: Xcode and the macOS 26 SDK.

```bash
swift test
swift run PocketPass
./Scripts/build-release.sh
```

The macOS build is a Universal Binary for Apple Silicon and Intel. The repository also contains a Universal iOS/iPadOS target that can be run from Xcode on a simulator or a signed device.

## Privacy and security

PocketPass does not read the macOS Keychain, does not upload the vault, and does not include analytics or tracking SDKs. The current release is local-first and does not provide iCloud synchronization. Keep encrypted backups safe and evaluate the security risks before storing high-value credentials; the project has not undergone an independent security audit.

## Roadmap

- Password strength, weak-password and duplicate-password checks.
- Developer ID signing, notarization and automatic updates.
- More complete conflict handling and backup management.
- iCloud synchronization with end-to-end encryption when the required Apple development capabilities are available.
- Productization and distribution of the iPhone and iPad clients.
- Browser extensions and system password autofill.

## License

PocketPass is licensed for personal, non-commercial use only. You may download, run and modify it for your own personal purposes. Commercial use, sale, rental, commercial redistribution, commercial hosting and use in a commercial service are not permitted. See [LICENSE](LICENSE) for the full terms.
