# Universal Randomizer 1.3.42 — Launcher update compatibility

The previous `V.1.3.41` tag was not recognized by Gen1Recomp's release parser. This release uses the standard `v1.3.42` tag and `universal_randomizer-1.3.42.zip` asset so installed copies can detect and download the update through the launcher.

- Launcher compatibility remains `>=0.2.18 <1.0.0`: app versions from 0.2.18 up to, but not including, 1.0.0.
- Crystal retains its existing Gen1Recomp 0.2.24+ runtime requirement.
- Keeps the same `universal_randomizer` mod ID and GitHub update repository.
- Increases the mod package version to 1.3.42 so existing 1.3.41 installations see an update.
- All gameplay code and assets are byte-for-byte identical to the published 1.3.41 package. Only the manifest and package integrity metadata differ.

Validated ZIP integrity, all 5,020 package hashes, the manifest's version boundaries, and update recognition using Gen1Recomp 0.2.24 and 0.3.99 updater code. This is a metadata-only release, not new gameplay certification; engine/API changes can still require code fixes.
