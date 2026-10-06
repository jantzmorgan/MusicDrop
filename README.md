# MusicDrop

**Your music. Your library.**

MusicDrop is a rootless jailbreak tweak for importing local audio into the native iOS Music library.

## Milestone 1 — Import Pipeline
The first milestone intentionally focuses on proving the import pipeline before building the final UI.

1. Receive a local audio file.
2. Validate the file and supported type.
3. Read basic metadata.
4. Hand it to the MusicDrop import service.
5. Import it into the native Music library.
6. Confirm success/failure without crashing Music or SpringBoard.

## Planned 1.0
- MP3 and M4A/AAC import
- Single and batch import
- Metadata editing
- Embedded/custom artwork
- Duplicate detection
- Playlist destination
- Rootless packaging
- Native-feeling import UI

## Development
Built with Theos for rootless jailbreak environments.

> This repository contains an original implementation. Do not copy proprietary code from MImport or other commercial tweaks.
