# Restore the 1.8 build

This is an immediate rollback to the exact published Universal Randomizer 1.8.0 gameplay code. All 1.9–1.11 additions are removed from the active source and package.

**1.11.1 is only the launcher update number**, allowing the rollback to install over 1.11.0. Every Lua file and all other original package contents match 1.8.0 byte for byte. Only the manifest version and its package metadata change.

Update through the launcher and fully restart. Use a 1.8 save or start a new run; newer seeds may depend on removed features and are not supported. No save files are deleted.

Original 1.8.0 ZIP: https://github.com/weskestis/UniversalRandomizer/releases/download/v1.8.0/universal_randomizer-1.8.0.zip

Verification checks the original release SHA-256, every packaged file hash, the absence of additional payload files, and byte-for-byte equality with 1.8.0 outside the two metadata files.
