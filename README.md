# Fuzzzy Ink 🤫

**First of all, this is not a chat!** (At least, not the kind that spies on your every word.)

Fuzzzy Ink is your personal, **offline encryption system**. It gives you private, local "message spaces" for two parties. Perfect for managing encrypted words and files you plan to share.
Think of it like a invisible ink pen and decoder ring, but for your digital stuff!

Once you link up with someone, you **lock** (encrypt) messages and files in the app to send out via any channel, then **open** (decrypt) the locked ones you get back. (And don't worry about linking up: the invite and the reply can be shared openly. Just make super sure the _reply you get back_ is from the person you actually intended to link with!)

<!-- [TODO: add GIF here showing the basic flows] -->

## 🚀 Get Fuzzzy Ink!

Ready to start fuzzing? Fuzzzy Ink runs on **Android, Windows and macOS**; the iPhone app is in testing
(TestFlight). Linux builds from this repository, but there is no packaged Linux download yet. The web build is
unsupported — the encryption core is native code.

Every download is on the [**latest release**](https://github.com/fuzzzer/fuzzzy_ink/releases/latest) page:
the Android APK, the Windows ZIP and the macOS app ZIP, with `SHA256SUMS` and a build certificate for each file
([how to check them](documents/security/RELEASE.md#3-verifying-a-release)). All releases:
[releases](https://github.com/fuzzzer/fuzzzy_ink/releases).

## What's the Big Idea?

Imagine you've written down the secret recipe for your grandma's legendary cookies, or perhaps the coordinates to your hidden treasure...

- You write it in Fuzzzy Ink and tap Lock
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

## First Things First: Your Master Password

The first time you open Fuzzzy Ink you choose one **master password**. It locks every key in the app: your
people, your history, My safe. It has to be a good one, and it cannot be switched off.

Next you get a **recovery key**: 32 letters and numbers, shown once. Print it or save it as a file and keep it
away from this device. If you ever forget the master password, the recovery key opens the app and lets you set a
new one. Without the password and without the key, nobody can bring your data back, us included.

The app locks itself after the idle time you choose (5 minutes unless you change it) and shortly after you leave
it. Wrong passwords start a growing wait after five tries.

## Getting Started: Your First Secret Handshake!

Setting up a private link is like learning a secret handshake: you do it once per person, and then you're good
to go.

1. **You:** tap **Add a person**, give them a name only you see, and share the **invite** (a link, a QR code or
   a file; it is safe to send openly).
2. **Them:** they open the invite in Fuzzzy Ink, say who sent it, and share their **reply** back to you.
3. **You:** open their reply (tap the link, or paste it into **Open**) and tap **Connect**.

✨ **That's it, you're connected.** Then compare your **safety number** with them by voice or in person: if the
digits match, nobody sat in the middle when you linked up. Mark them as checked once you have.

## Sending Your Secrets (Securely!)

1. **Lock:** pick the person, write the message or choose a file, and tap **Lock**. Fuzzzy Ink turns it into a
   jumble only they can open.
2. **Share it any way you like:** as a link, a QR code, a `.fuzz` file or plain text. Email, a messenger, a USB
   stick hidden in a fake rock: the jumble is safe anywhere.
3. **They open it:** they tap the link and then **Open**, or paste it into Open. A link never opens anything by
   itself. Their message lands in their history with you.

**Basics** locks text or a file with a password instead, for someone who doesn't have the app set up with you.
Say the password, never send it with the locked thing. **My safe** keeps your own passwords, notes and files.

## Important Little Secrets About Your Secrets:

- **Each Locked Message Opens Once, On One Device:** a locked message opens exactly once, on the device it was
  locked for; opening it again says it was already opened and where to find it. What you read stays in your
  history in the app, sealed per person under a key only this device holds, behind your master password.
  **Files** are kept sealed too: the app keeps only the locked file and unlocks it for the moment you open, save
  or share it. A file you save or share is yours: it leaves the app as a plain file, so protect it like any
  other file. Want a backup of a conversation? A person's page offers a password-protected export of their
  history, which opens in Basics with the same password. A new device or a fresh install cannot re-read old
  messages, and there is no cloud copy.
- **Open Roughly In Order:** the app keeps keys for skipped messages, but not without limit: a message more than
  63 behind the newest one you already opened from that person is gone for good ("too old"), and at most 40
  skipped messages are kept at once.
- **Know Your Recipient:** invites and replies are fine to send over any channel, but make sure the reply you
  get back is from the person you meant. If the app ever says *someone else answered your invite*, it found a
  second, real reply: check the safety number with your person before you trust the link.
- **Nothing Plain Leaves By Accident:** opened messages, passwords and the recovery key cannot be copied,
  shared or sent to another app from their fields, keyboards are asked not to learn them, and private screens
  are kept out of screenshots and the app switcher where the system allows it. A copied safe password clears
  itself after 30 seconds.
- **One Person, One Link:** add each person separately; never share one link between several people.
- **Fuzzy is Your Friend (Plain Text is Not!):** the locked jumble is safe to splash all over the internet.
  Something you meant to lock but sent plain is not: always lock before you send.

## Want to Dive Deeper into the Rabbit Hole?

- 🎬 **Watch the Quick Mission Briefing (Video Guide):** [//TODO video guide link]
- 📖 **For Gadget Q-Branch Types ([Technical Details](documents/security/PROTOCOL.md)):** the protocol
  specification and the [threat model](documents/security/THREAT_MODEL.md), which describe the app as it is;
  for building the app yourself, the [developer notes](documents/technical_documentation.md). The
  [2026 hardening write-up](documents/security/HARDENING_2026.md) and [what changed](documents/security/WHAT_CHANGED.md)
  are history: where they differ from the protocol and the threat model, those win.
- 🐛 **Spotted a Gremlin? Got Ideas for a New Gadget?** Report to HQ (GitHub Issues): <https://github.com/fuzzzer/fuzzzy_ink/issues>. Security problems go privately instead: see [SECURITY.md](SECURITY.md).

Happy (and secure) scheming with Fuzzzy Ink! 🛡️
