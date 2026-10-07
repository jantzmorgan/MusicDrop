# MusicDrop

**Your music. Your library.**

MusicDrop is a rootless jailbreak tweak whose finished purpose is simple:

**Choose or share local audio → review/edit metadata and artwork → tap Import → the track appears in Apple's Music library and plays normally.**

## Product contract

A build is not considered a usable MusicDrop test unless the user has a visible entry point and a specific expected result.

### Core 1.0 flow
1. Receive MP3/M4A/AAC from Files or a share action.
2. Copy the selected file into MusicDrop-controlled temporary storage.
3. Read title, artist, album, album artist, genre, year, track/disc numbers, duration, and embedded artwork when available.
4. Present a native metadata editor.
5. Detect obvious duplicates before import.
6. Import the audio into the device's native Music library.
7. Verify the imported item exists and can be opened in Music.
8. Report a real success or actionable failure.

### 1.0 features
- Single-file import
- Batch import
- Metadata editing
- Embedded/custom artwork
- Duplicate detection
- Optional playlist destination
- Import history and useful errors
- Rootless packaging
- Native-feeling UI

## Current engineering gates

**Gate A — injection:** MusicDrop must demonstrably load in the Music process on the target device.

**Gate B — file intake:** Files picker/share intake must return a readable local copy and metadata.

**Gate C — native import:** the import backend must create a real Music-library item. A placeholder success message is never acceptable.

**Gate D — product UI:** metadata/artwork editing, batch flow, duplicate handling, playlist selection, and polish.

The project does not copy proprietary code. Public prior art may be studied to understand iOS behavior and compatibility.
