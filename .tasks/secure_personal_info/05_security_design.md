# Fuzzy Vault — Security Design Document

> **Document:** Security architecture, threat model, and cryptographic decisions
> **Status:** PLANNING

---

## 1. Threat Model

### Assets to protect:
1. **Stored passwords** — credentials for other services.
2. **Secure notes** — sensitive textual information.
3. **Group structure** — organizational metadata that could reveal usage patterns.
4. **Master password** — must never be stored or leaked.

### Threat actors:
| Actor | Access | Risk |
|-------|--------|------|
| Physical device access (unlocked) | App data, file system | Vault must be locked and require master password |
| Physical device access (locked) | Can extract app data with tools | All content encrypted at rest with AES-256-GCM |
| Malware/spyware | Can read app memory | Master key cleared from memory on lock; clipboard auto-cleared |
| Backup extraction | Cloud/local backups may contain app data | Encrypted blobs are meaningless without master password |
| Shoulder surfing | Can see screen | Password fields masked; quick-copy doesn't display password |

### Out of scope (by design — offline app):
- Network-based attacks (MITM, server breach)
- Remote exploits (no server, no API)
- Side-channel timing attacks (acceptable risk for mobile app)

---

## 2. Cryptographic Choices

### Master key derivation: Argon2id
```
Algorithm:  Argon2id
Salt:       16 bytes, cryptographically random, unique per vault
Key length: 32 bytes (256 bits)
Iterations: 4
Memory:     65536 KB (64 MB)
Parallelism: 4 lanes
```

**Why Argon2id?**
- Winner of the Password Hashing Competition.
- Already in use in the app's `PasswordBasedEncryptionService`.
- Resistant to GPU and ASIC brute-force attacks due to memory-hardness.
- The `id` variant provides resistance against both side-channel and time-memory tradeoff attacks.

### Content encryption: AES-256-GCM
```
Algorithm:  AES-256 in GCM mode
Nonce:      12 bytes, random per encryption
MAC:        128-bit authentication tag (built into GCM)
```

**Why AES-GCM?**
- Authenticated encryption — detects tampering and corruption.
- Already implemented in `PasswordBasedEncryptionService`.
- GCM auth tag failure = reliable "wrong password" or "corrupted data" signal.

### File format per encrypted blob:
```
[16 bytes salt][12 bytes nonce][N bytes ciphertext + 16 bytes GCM tag]
```

This matches the existing `PasswordBasedEncryptionService` format exactly — we reuse it as-is.

---

## 3. Master Password Verification

We do NOT store the master password or its hash. Instead:

1. On vault creation:
   - Generate a 32-byte random **verification token**.
   - Encrypt it with the derived master key.
   - Store the encrypted token in `vault.meta`.

2. On unlock:
   - Derive key from entered password + stored salt.
   - Attempt to decrypt the verification token.
   - If GCM tag validation passes → correct password.
   - If GCM tag fails → wrong password.

**Why not just store a hash?**
- A hash allows offline brute-force against the hash itself.
- With our approach, the attacker must perform the full Argon2id derivation AND AES-GCM decryption for each guess — significantly more expensive.

---

## 4. Custom Password (Double Encryption)

Items/groups with a custom password use **layered encryption**:

```
plaintext
  → encrypt with custom_key (Argon2id(custom_password, custom_salt) → AES-GCM)
  → encrypt with master_key (AES-GCM)
  = stored ciphertext
```

To decrypt:
```
stored ciphertext
  → decrypt with master_key → intermediate ciphertext
  → decrypt with custom_key → plaintext
```

**Key design decision:** The master key is always the outer layer. This means:
- Items cannot be read even with the custom password alone — master password is always required.
- The custom password adds defense-in-depth for the most sensitive items.
- Deleting/moving items only requires the master password.

### Custom password detection:
- `VaultItemMetadata.hasCustomPassword` flag (plaintext in Isar).
- When decryption is attempted with only the master key, the intermediate ciphertext will fail GCM validation on the inner layer, signaling that a custom password is needed.

---

## 5. Brute-Force Protection

### Argon2id cost parameters:
- At 64MB memory + 4 iterations, each password attempt takes ~500ms on a modern phone.
- An attacker with 32 GB RAM can run ~512 parallel instances = ~1024 attempts/second.
- A 12-character password with mixed case + digits + symbols has ~72^12 ≈ 10^22 possibilities.
- Time to exhaust: ~10^19 seconds ≈ 300 billion years.

### UI-level protection:
- After 5 failed attempts: 30-second lockout.
- After 10 failed attempts: 5-minute lockout.
- After 20 failed attempts: 30-minute lockout.
- Lockout state stored in `SharedPreferences` (persists across app restarts).

---

## 6. Memory Security

| Concern | Mitigation |
|---------|------------|
| Master key in memory | Cleared (`Uint8List.fill(0)`) on vault lock |
| Decrypted content in memory | State cleared on vault lock; Dart GC handles the rest |
| Clipboard exposure | Auto-clear after 30s (configurable); platform clipboard API |
| Screenshot protection | Consider `FLAG_SECURE` on Android (deferred to V2) |

### Key lifecycle:
```
unlock() → derive master key → store in VaultAuthState.masterKey
  ↓
all operations use masterKey from state
  ↓
lock() → masterKey.fillRange(0, length, 0) → emit state without key
```

---

## 7. File Integrity

### Write-ahead log (journal.wal):
Each operation is logged before execution:
```
TIMESTAMP|OPERATION|ITEM_ID|VERSION
2026-05-09T10:30:00|SAVE|uuid-1234|3
2026-05-09T10:30:01|DELETE|uuid-5678|0
```

On crash recovery:
1. Parse journal entries.
2. For incomplete `SAVE`: check `.tmp/` for the written file → complete the rename.
3. For incomplete `DELETE`: check if file still exists → delete it.
4. For items with newer versions in `.conflicts/`: skip (user resolves manually).

### Atomic file writes:
```
write(items/{id}.vault):
  1. Write to .tmp/{id}.vault.tmp
  2. fsync()
  3. Rename .tmp/{id}.vault.tmp → items/{id}.vault
  4. fsync() parent directory
```

Step 3 (rename) is atomic on all supported platforms. If the app crashes between steps 1 and 3, the `.tmp` file is detected and cleaned up on next launch.

---

## 8. Export Security

### Export file format (.fvault):
```
[MAGIC_BYTES: "FVLT"][VERSION: 1 byte][ENCRYPTED_ZIP_BLOB]
```

The `ENCRYPTED_ZIP_BLOB` is the entire ZIP archive encrypted with `PasswordBasedEncryptionService` using the export password.

### Inside the ZIP (before encryption):
```
manifest.json         — version, item count, export date, SHA-256 of items/
items/{id}.vault      — already encrypted with master key
groups.json           — group definitions (NOT encrypted again — items are already encrypted)
```

**Note:** Items inside the ZIP are already encrypted with the vault's master key. The export password adds a second encryption layer. This means importing into a different vault with a different master password requires:
1. Decrypt export archive with export password.
2. Decrypt each item with the **original** vault's master key.
3. Re-encrypt with the **new** vault's master key.

**Implication:** Export includes the master-key-encrypted blobs. To import into a new vault, the user must also provide the original master password. This is by design — it prevents unauthorized re-use of exported data.

### Alternative (simpler, recommended for V1):
Export decrypts items with the current master key, then re-encrypts the entire archive with the export password. This allows import with only the export password, which is more user-friendly for cross-device scenarios.

**Decision: Use the simpler approach for V1.** The user provides an export password, and the exported data is decrypted from master key and re-encrypted with the export password.

---

## 9. Custom Directory Security Considerations

When reading from a custom directory:
- Files are treated as **untrusted input**.
- Each `.vault` file must successfully decrypt with the master key, or it's ignored.
- Malformed files (wrong size, invalid format) are logged and skipped.
- No code execution or deserialization of untrusted data beyond AES-GCM decryption (which validates integrity via auth tag).
- The custom directory path is stored in `vault.meta` (encrypted).
