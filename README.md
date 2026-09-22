# Fuzzzy Ink 🤫

**First of all, this is not a chat!** (At least, not the kind that spies on your every word.)

Fuzzzy Ink is your personal, **offline encryption system**. It gives you private, local "message spaces" for two parties. Perfect for managing encrypted words and files you plan to share.
Think of it like a invisible ink pen and decoder ring, but for your digital stuff!

Once you link up with someone, within the app 'fuzz' (encrypt) messages and files to send out via any channel, then 'unfuzz' (decrypt) any coded replies you get back. (And don't worry about linking up: the Invitation and Acceptance can be shared openly. Just make super sure the _Acceptance code you get back_ is from the person you actually intended to link with!)

<!-- [TODO: add GIF here showing the basic flows] -->

## 🚀 Get Fuzzzy Ink!

Ready to start fuzzing? Fuzzzy Ink runs on **Android, Windows, macOS and Linux**. (The web build is
unsupported — the encryption core is native code. iOS builds from this repo but is not in the App Store.)
Grab the latest version here:

<!-- [TODO: add app build and link them] -->

- **Android:** [Download Fuzzzy Ink vX.Y.Z APK](https://github.com/fuzzzer/fuzzy_chat/releases/tag/v1.0.0)
- **Windows (64-bit):** [Download Fuzzzy Ink vX.Y.Z ZIP](https://github.com/fuzzzer/fuzzy_chat/releases/tag/v1.0.0)
- **macOS (Universal):** [Download Fuzzzy Ink vX.Y.Z DMG](https://github.com/fuzzzer/fuzzy_chat/releases/tag/v1.0.0)
- **Linux (AppImage) (TO BE ADDED SOON):** [Download Fuzzzy Ink vX.Y.Z AppImage](https://github.com/fuzzzer/fuzzy_chat/releases/tag/v1.0.0)

Or visit the [**Latest Releases Page**](https://github.com/fuzzzer/fuzzy_chat/releases) for all releases.

## What's the Big Idea?

Imagine you've written down the secret recipe for your grandma's legendary cookies, or perhaps the coordinates to your hidden treasure...

- You pop it into a Connected Fuzzzy Ink Text Field
- _POOF!_ Fuzzzy Ink scrambles it into a jumble of nonsense letters and numbers.
- You can then email this jumble, save it to a USB stick shaped like a rubber ducky, or even (if you're feeling dramatic) print it out and send it by raven.
- Only the person with the matching Fuzzzy Ink "key" can turn that jumble back into your precious secret.

That's Fuzzzy Ink! It wraps your digital secrets in a cozy, unreadable blanket, ensuring only your chosen partner can peek inside.

## Why Fuzzzy Ink? Unleash Your Inner Secret Agent (or just be sensible)!

Fuzzzy Ink is for anyone who values true privacy, whether you're:

- 🤫 **Sharing Top-Secret Stuff (or just really good gossip):**
  - Planning a surprise party for your best friend and don't want them accidentally seeing the plans on a shared family computer? Fuzz it!
  - Coordinating your next D&D campaign's most diabolical plot twist with your co-DM? Fuzz it!
  - Sending your super-secret, not-yet-patented invention idea to your trusted collaborator? You guessed it... Fuzz it!
- 💼 **Being Professionally Discreet (because some things aren't for the whole office):**
  - Sending sensitive client information to a colleague working remotely, even over company email, with an extra layer of "nope, can't read this."
  - Discussing a confidential merger before it's public knowledge.
  - Sharing a draft of that _really_ honest performance review before it's finalized.
- ✈️ **Going Off-Grid (or just having spotty Wi-Fi):**
  - Need to pass vital info to your trekking buddy in the Himalayas where the only connection is "yak-mail"? Encrypt first, then figure out the yak.
  - Working on a project in a secure facility with no internet access (an "air-gapped" setup)? Fuzzzy Ink doesn't mind.
- 📝 **Keeping Personal Notes Actually Personal:**
  - Journaling your deepest thoughts without worrying about cloud provider data breaches.
  - Storing that embarrassing poem you wrote in high school, securely. (We won't tell.)

Basically, if it's important and needs to stay between just you and one other person, Fuzzzy Ink is your friend.

## Getting Started: Your First Secret Handshake!

Setting up a private link is like learning a secret handshake – you do it once per person, and then you're good to go!

**Let's say YOU (The Mastermind) want to start a secure link with YOUR TRUSTED ALLY:**

1.  **You (The Mastermind):**

    - Open Fuzzzy Ink and tap `+ New Chat`.
    - Give this new secret channel a codename (e.g., "Operation Rubber Ducky" or "Grandma's Recipe Vault").
    - The app will conjure an **Invitation Code**. Tap `Copy Invitation` or `Share Invitation`.
    - Send this `Invitation Code` to YOUR ALLY (via smoke signal, carrier pigeon, or, you know, email).

2.  **Your TRUSTED ALLY:**

    - Opens Fuzzzy Ink on their device and taps `Accept Invitation`.
    - They'll paste the `Invitation Code` you sent and can give the channel their own codename. Tap `Accept Invitation`.
    - Fuzzzy Ink will then generate an **Acceptance Code**. They need to `Copy Acceptance`.
    - YOUR ALLY sends this `Acceptance Code` back to YOU.

3.  **You (The Mastermind again):**
    - Find your pending channel (it'll say "Waiting for acceptance" with an hourglass ⏳ icon).
    - Paste the `Acceptance Code` YOUR ALLY sent you into the "Acceptance Text" box.
    - Tap `Accept`.

✨ **BOOM! Your secret channel is live!** You'll see a padlock 🔒 icon. You and YOUR ALLY are now cleared for classified (or just fun) communications.

## Sending Your Secrets (Securely!)

Once your channel is active:

1.  **Open the Channel:** Tap on its codename (e.g., "Operation Rubber Ducky") in your Fuzzzy Ink list.
2.  **Compose Your Message or Add a File:**
    - Type your secret message in the "Text goes here...." box.
    - To send a classified file (or that cookie recipe), tap the **upload/attach icon** (arrow pointing up from a tray ⬆️).
3.  **Hit the "Scramble" Button (aka Send):** Tap the **send icon** (paper plane ▶️).
    - Fuzzzy Ink instantly encrypts it into gobbledygook.
    - This gobbledygook is what appears in your chat window.
4.  **Pass the Gobbledygook:** Copy this scrambled block. Send it to YOUR ALLY using _any_ method you like (email, text, flash drive hidden in a fake rock).
5.  **YOUR ALLY Unscrambles:**
    - They open the same channel in their Fuzzzy Ink.
    - They paste the gobbledygook you sent into their message box.
    - They tap their **send icon** (paper plane ▶️).
    - _PRESTO!_ Your original message or file appears, clear as day!

Repeat as many times as your secret-sharing heart desires!

## Important Little Secrets About Your Secrets:

- **Each Blob Unfuzzes Once, On One Device:** a fuzzed message can be unfuzzed exactly once, on the device it was sent to — paste it a second time and Fuzzzy Ink tells you it was already unfuzzed. Your readable **text** history stays inside the app on that device, sealed per channel under a key only that device holds (and behind your app-lock password, if you set one). Unfuzzed **files** are different: they land as plain files in the channel's folder on your device — not sealed, not locked by the app — so protect them like any other file. Want a backup? Chat settings → "Export chat archive" writes a password-protected file of the channel's history — it opens in Basics → file decryption with the same password. A new device, or a fresh install, cannot re-read old blobs, and there is no cloud copy. Guard your device like the precious thing it is!
- **Unfuzz Roughly In Order:** the app keeps keys for skipped messages, but not without limit — a blob more than 63 messages behind the newest one you already unfuzzed in that channel is gone for good ("too old"), and at most 40 skipped messages are kept at once.
- **Know Your Recipient:** Double-check you're sending Invitation and Acceptance codes to the right spy... er, person. The codes themselves are fine to send over any channel to establish the link, but you want the _right_ person getting them!
- **Check the Safety Number:** every live channel has a 60-digit safety number (the shield icon in the chat header), computed from both devices' identity keys. Read it to your ally by voice or compare it in person: if the digits match, nobody sat in the middle when you linked up. Tap "Mark as verified" as your own note that you did this — the app cannot check it for you.
- **One Chat, One Ally (No Threesomes!):** Always create a **new, unique chat** for each new person you want to communicate with. If you try to reuse an existing chat link with multiple people, they'll all be able to read each other's messages. Think of it like giving everyone the same key to the same diary – awkward!
- **Fuzzy is Your Friend (Plain Text is Not!):** The only thing that can "expose" you is sharing something that _isn't_ fuzzed!
  - The scrambled "fuzz" (encrypted content) from Fuzzzy Ink? Totally safe to splash all over the internet. It's designed to be unreadable nonsense to anyone but your linked secret sharer.
  - Plain text messages or unencrypted files you _meant_ to fuzz but forgot? Well, that's like shouting your secret password in a crowded library. Fuzzzy Ink can't help you if you don't use it first! So, always fuzz before you fuss (with sending).

## Want to Dive Deeper into the Rabbit Hole?

- 🎬 **Watch the Quick Mission Briefing (Video Guide):** [//TODO video guide link]
- 📖 **For Gadget Q-Branch Types ([Technical Details](documents/security/PROTOCOL.md)):** the protocol
  specification; also the [threat model](documents/security/THREAT_MODEL.md), the
  [2026 hardening write-up](documents/security/HARDENING_2026.md) and, for building the app yourself,
  the [developer notes](documents/technical_documentation.md).
- 🐛 **Spotted a Gremlin? Got Ideas for a New Gadget?** Report to HQ (GitHub Issues): [https://github.com/fuzzzer/fuzzy_chat/issues]

Happy (and secure) scheming with Fuzzzy Ink! 🛡️
