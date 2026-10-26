import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'fuzzzy_ink_localizations_en.dart';
import 'fuzzzy_ink_localizations_ka.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of FuzzzyInkLocalizations
/// returned by `FuzzzyInkLocalizations.of(context)`.
///
/// Applications need to include `FuzzzyInkLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated_localizations/fuzzzy_ink_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
///   supportedLocales: FuzzzyInkLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the FuzzzyInkLocalizations.supportedLocales
/// property.
abstract class FuzzzyInkLocalizations {
  FuzzzyInkLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static FuzzzyInkLocalizations? of(BuildContext context) {
    return Localizations.of<FuzzzyInkLocalizations>(
        context, FuzzzyInkLocalizations);
  }

  static const LocalizationsDelegate<FuzzzyInkLocalizations> delegate =
      _FuzzzyInkLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ka')
  ];

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @fuzzzyInk.
  ///
  /// In en, this message translates to:
  /// **'Fuzzzy Ink'**
  String get fuzzzyInk;

  /// No description provided for @failedToLoadChats.
  ///
  /// In en, this message translates to:
  /// **'Failed to load chats.'**
  String get failedToLoadChats;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get newChat;

  /// No description provided for @acceptInvitation.
  ///
  /// In en, this message translates to:
  /// **'Accept Invitation'**
  String get acceptInvitation;

  /// No description provided for @createANewChat.
  ///
  /// In en, this message translates to:
  /// **'Create a New Chat'**
  String get createANewChat;

  /// No description provided for @enterChatName.
  ///
  /// In en, this message translates to:
  /// **'Enter Chat Name'**
  String get enterChatName;

  /// No description provided for @eg.
  ///
  /// In en, this message translates to:
  /// **'e.g.'**
  String get eg;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @chatWithAlice.
  ///
  /// In en, this message translates to:
  /// **'Chat with Alice'**
  String get chatWithAlice;

  /// No description provided for @failedToCreateChat.
  ///
  /// In en, this message translates to:
  /// **'Failed to create chat.'**
  String get failedToCreateChat;

  /// No description provided for @pleaseEnterAChatName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a chat name.'**
  String get pleaseEnterAChatName;

  /// No description provided for @pleasePasteTheAcceptanceContent.
  ///
  /// In en, this message translates to:
  /// **'Please paste the acceptance content.'**
  String get pleasePasteTheAcceptanceContent;

  /// No description provided for @failedToCompleteHandshake.
  ///
  /// In en, this message translates to:
  /// **'Failed to complete handshake.'**
  String get failedToCompleteHandshake;

  /// No description provided for @sendInvitation.
  ///
  /// In en, this message translates to:
  /// **'Send Invitation'**
  String get sendInvitation;

  /// No description provided for @copyInvitation.
  ///
  /// In en, this message translates to:
  /// **'Copy Invitation'**
  String get copyInvitation;

  /// No description provided for @invitationCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Invitation copied to clipboard.'**
  String get invitationCopiedToClipboard;

  /// No description provided for @provideAcceptance.
  ///
  /// In en, this message translates to:
  /// **'Provide Acceptance'**
  String get provideAcceptance;

  /// No description provided for @pasteAcceptanceText.
  ///
  /// In en, this message translates to:
  /// **'Paste Acceptance Text'**
  String get pasteAcceptanceText;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @unexpectedFailureOccuredPleaseContactUs.
  ///
  /// In en, this message translates to:
  /// **'Unexpected failure occurred, please contact us.'**
  String get unexpectedFailureOccuredPleaseContactUs;

  /// No description provided for @failedToGenerateInvitation.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate invitation.'**
  String get failedToGenerateInvitation;

  /// No description provided for @inOrderToStartAChatWithSomeoneFirstTheyNeedToImportTheInvitationAndProvideAcceptanceFileOrTextGeneratedOnTheirChatSoTheyCanAlsoSendAndUnlockMessages.
  ///
  /// In en, this message translates to:
  /// **'To start a chat with someone, they must first import the invitation and provide the acceptance text generated in their chat. This will allow them to send and unlock messages.'**
  String
      get inOrderToStartAChatWithSomeoneFirstTheyNeedToImportTheInvitationAndProvideAcceptanceFileOrTextGeneratedOnTheirChatSoTheyCanAlsoSendAndUnlockMessages;

  /// No description provided for @theAcceptanceThatYouGetFromInvitedPersonShouldBePastedHere.
  ///
  /// In en, this message translates to:
  /// **'The acceptance that you get from the invited person should be pasted here:'**
  String get theAcceptanceThatYouGetFromInvitedPersonShouldBePastedHere;

  /// No description provided for @failedToAcceptInvitation.
  ///
  /// In en, this message translates to:
  /// **'Failed to accept invitation.'**
  String get failedToAcceptInvitation;

  /// No description provided for @pleaseProvideInvitationTextAndChatName.
  ///
  /// In en, this message translates to:
  /// **'Please provide invitation text and chat name.'**
  String get pleaseProvideInvitationTextAndChatName;

  /// No description provided for @acceptChatInvitation.
  ///
  /// In en, this message translates to:
  /// **'Accept Chat Invitation'**
  String get acceptChatInvitation;

  /// No description provided for @pasteInvitationText.
  ///
  /// In en, this message translates to:
  /// **'Paste Invitation Text'**
  String get pasteInvitationText;

  /// No description provided for @failedToGenerateAcceptance.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate acceptance.'**
  String get failedToGenerateAcceptance;

  /// No description provided for @failedToReadAcceptance.
  ///
  /// In en, this message translates to:
  /// **'Failed to read acceptance.'**
  String get failedToReadAcceptance;

  /// No description provided for @goToChat.
  ///
  /// In en, this message translates to:
  /// **'Go to Chat'**
  String get goToChat;

  /// No description provided for @copyAcceptance.
  ///
  /// In en, this message translates to:
  /// **'Copy Acceptance'**
  String get copyAcceptance;

  /// No description provided for @yourAcceptanceHasBeenGeneratedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Your acceptance has been generated successfully.'**
  String get yourAcceptanceHasBeenGeneratedSuccessfully;

  /// No description provided for @exportAcceptance.
  ///
  /// In en, this message translates to:
  /// **'Export Acceptance'**
  String get exportAcceptance;

  /// No description provided for @acceptanceCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Acceptance copied to clipboard.'**
  String get acceptanceCopiedToClipboard;

  /// No description provided for @tapToViewChat.
  ///
  /// In en, this message translates to:
  /// **'Tap to view chat.'**
  String get tapToViewChat;

  /// No description provided for @waitingForAcceptance.
  ///
  /// In en, this message translates to:
  /// **'Waiting for acceptance.'**
  String get waitingForAcceptance;

  /// No description provided for @deleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete Chat'**
  String get deleteChat;

  /// No description provided for @areYouSureYouWantToDeleteThisChat.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this chat?'**
  String get areYouSureYouWantToDeleteThisChat;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @textGoesHere.
  ///
  /// In en, this message translates to:
  /// **'Text goes here.'**
  String get textGoesHere;

  /// No description provided for @encrypting.
  ///
  /// In en, this message translates to:
  /// **'Encrypting'**
  String get encrypting;

  /// No description provided for @decrypting.
  ///
  /// In en, this message translates to:
  /// **'Decrypting'**
  String get decrypting;

  /// No description provided for @copiedToTheClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to the clipboard.'**
  String get copiedToTheClipboard;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @areYouSureYouWantToDeleteChatWith.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete chat with {personName}'**
  String areYouSureYouWantToDeleteChatWith(Object personName);

  /// No description provided for @failedToGetAcceptance.
  ///
  /// In en, this message translates to:
  /// **'Failed to get acceptance'**
  String get failedToGetAcceptance;

  /// No description provided for @storagePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Storage permission denied.'**
  String get storagePermissionDenied;

  /// No description provided for @errorPickingFiles.
  ///
  /// In en, this message translates to:
  /// **'Error picking files.'**
  String get errorPickingFiles;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @fuzz.
  ///
  /// In en, this message translates to:
  /// **'Fuzz'**
  String get fuzz;

  /// No description provided for @defuzz.
  ///
  /// In en, this message translates to:
  /// **'Defuzz'**
  String get defuzz;

  /// No description provided for @failedToProcessFiles.
  ///
  /// In en, this message translates to:
  /// **'Failed to process files'**
  String get failedToProcessFiles;

  /// No description provided for @chatWithIndicatedNameAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'Chat with indicated name already exists'**
  String get chatWithIndicatedNameAlreadyExists;

  /// No description provided for @reveal.
  ///
  /// In en, this message translates to:
  /// **'Reveal'**
  String get reveal;

  /// No description provided for @show.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get show;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @dropFilesHere.
  ///
  /// In en, this message translates to:
  /// **'Drop files here'**
  String get dropFilesHere;

  /// No description provided for @shareInvitation.
  ///
  /// In en, this message translates to:
  /// **'Share invitation'**
  String get shareInvitation;

  /// No description provided for @acceptanceText.
  ///
  /// In en, this message translates to:
  /// **'Acceptance Text'**
  String get acceptanceText;

  /// No description provided for @basicEncryption.
  ///
  /// In en, this message translates to:
  /// **'Basic Encryption'**
  String get basicEncryption;

  /// No description provided for @customKey.
  ///
  /// In en, this message translates to:
  /// **'Custom Key'**
  String get customKey;

  /// No description provided for @enterYourSecretKey.
  ///
  /// In en, this message translates to:
  /// **'Enter your secret key'**
  String get enterYourSecretKey;

  /// No description provided for @textToEncryptDecrypt.
  ///
  /// In en, this message translates to:
  /// **'Text to Encrypt Decrypt'**
  String get textToEncryptDecrypt;

  /// No description provided for @encryptText.
  ///
  /// In en, this message translates to:
  /// **'Encrypt Text'**
  String get encryptText;

  /// No description provided for @decryptText.
  ///
  /// In en, this message translates to:
  /// **'Decrypt Text'**
  String get decryptText;

  /// No description provided for @result.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get result;

  /// No description provided for @processSelectedFiles.
  ///
  /// In en, this message translates to:
  /// **'Process Selected Files'**
  String get processSelectedFiles;

  /// No description provided for @pleaseEnterAKey.
  ///
  /// In en, this message translates to:
  /// **'Please enter a key'**
  String get pleaseEnterAKey;

  /// No description provided for @pleaseSelectFilesToProcess.
  ///
  /// In en, this message translates to:
  /// **'Please select files to process'**
  String get pleaseSelectFilesToProcess;

  /// No description provided for @anUnknownErrorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred'**
  String get anUnknownErrorOccurred;

  /// No description provided for @textAndKeyCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Text and key cannot be empty'**
  String get textAndKeyCannotBeEmpty;

  /// No description provided for @encryptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Encryption failed'**
  String get encryptionFailed;

  /// No description provided for @encryptedTextAndKeyCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Encrypted text and key cannot be empty'**
  String get encryptedTextAndKeyCannotBeEmpty;

  /// No description provided for @decryptionFailedCheckYourKeyOrEncryptedText.
  ///
  /// In en, this message translates to:
  /// **'Decryption failed check your key or encrypted text'**
  String get decryptionFailedCheckYourKeyOrEncryptedText;

  /// No description provided for @welcomeToFuzzzyInk.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Fuzzzy Ink'**
  String get welcomeToFuzzzyInk;

  /// No description provided for @offlineEncryptedClipboard.
  ///
  /// In en, this message translates to:
  /// **'Offline Encrypted Clipboard'**
  String get offlineEncryptedClipboard;

  /// No description provided for @yourDataNeverLeavesYourDeviceNoServersNoTracking.
  ///
  /// In en, this message translates to:
  /// **'Your data never leaves your device. No servers, no tracking.'**
  String get yourDataNeverLeavesYourDeviceNoServersNoTracking;

  /// No description provided for @secureHandshake.
  ///
  /// In en, this message translates to:
  /// **'Secure Handshake'**
  String get secureHandshake;

  /// No description provided for @connectWithOthersUsingASecureOfflineCodeExchange.
  ///
  /// In en, this message translates to:
  /// **'Connect with others using a secure, offline code exchange.'**
  String get connectWithOthersUsingASecureOfflineCodeExchange;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @noOngoingChats.
  ///
  /// In en, this message translates to:
  /// **'No Ongoing Chats'**
  String get noOngoingChats;

  /// No description provided for @tapTheButtonBelowToCreateANewSecureHandshakeOrAcceptAnInvitation.
  ///
  /// In en, this message translates to:
  /// **'Tap the button below to create a new secure handshake or accept an invitation.'**
  String get tapTheButtonBelowToCreateANewSecureHandshakeOrAcceptAnInvitation;

  /// No description provided for @stepSendYourInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Step 1: Send Your Invite Code'**
  String get stepSendYourInviteCode;

  /// No description provided for @sendThisCodeToThePersonYouWantToChatWithUsingAnySecureChannel.
  ///
  /// In en, this message translates to:
  /// **'Send this code to the person you want to chat with using any secure channel.'**
  String get sendThisCodeToThePersonYouWantToChatWithUsingAnySecureChannel;

  /// No description provided for @stepPasteTheirAcceptanceCode.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Paste Their Acceptance Code'**
  String get stepPasteTheirAcceptanceCode;

  /// No description provided for @onceTheyAcceptYourInviteTheyWillSendACodeBackPasteItBelow.
  ///
  /// In en, this message translates to:
  /// **'Once they accept your invite, they will send a code back. Paste it below.'**
  String get onceTheyAcceptYourInviteTheyWillSendACodeBackPasteItBelow;

  /// No description provided for @stepPasteTheirInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Step 1: Paste Their Invite Code'**
  String get stepPasteTheirInviteCode;

  /// No description provided for @askYourContactToShareTheirInviteCodeSecurelyAndPasteItBelow.
  ///
  /// In en, this message translates to:
  /// **'Ask your contact to share their invite code securely and paste it below.'**
  String get askYourContactToShareTheirInviteCodeSecurelyAndPasteItBelow;

  /// No description provided for @stepNameThisChat.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Name This Chat'**
  String get stepNameThisChat;

  /// No description provided for @chooseALocalNameForThisChatThisIsOnlyVisibleToYou.
  ///
  /// In en, this message translates to:
  /// **'Choose a local name for this chat. This is only visible to you.'**
  String get chooseALocalNameForThisChatThisIsOnlyVisibleToYou;

  /// No description provided for @copyFuzz.
  ///
  /// In en, this message translates to:
  /// **'Copy Fuzz'**
  String get copyFuzz;

  /// No description provided for @firstEncryption.
  ///
  /// In en, this message translates to:
  /// **'First Encryption'**
  String get firstEncryption;

  /// No description provided for @typeAMessageAndPressSendItWillBeEncryptedLocallyAndYouCanThenCopyTheSecureFuzzedText.
  ///
  /// In en, this message translates to:
  /// **'Type a message and press send. It will be encrypted locally, and you can then copy the secure fuzzed text.'**
  String
      get typeAMessageAndPressSendItWillBeEncryptedLocallyAndYouCanThenCopyTheSecureFuzzedText;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @copyAsLink.
  ///
  /// In en, this message translates to:
  /// **'Copy as Link'**
  String get copyAsLink;

  /// No description provided for @linkCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard.'**
  String get linkCopiedToClipboard;

  /// No description provided for @shareAcceptance.
  ///
  /// In en, this message translates to:
  /// **'Share acceptance'**
  String get shareAcceptance;

  /// No description provided for @linkExpired.
  ///
  /// In en, this message translates to:
  /// **'This link has expired.'**
  String get linkExpired;

  /// No description provided for @linkShared.
  ///
  /// In en, this message translates to:
  /// **'Link shared.'**
  String get linkShared;

  /// No description provided for @invalidLink.
  ///
  /// In en, this message translates to:
  /// **'This link is invalid or corrupted.'**
  String get invalidLink;

  /// No description provided for @noMatchingChat.
  ///
  /// In en, this message translates to:
  /// **'No matching chat found.'**
  String get noMatchingChat;

  /// No description provided for @alreadyConnected.
  ///
  /// In en, this message translates to:
  /// **'Already connected!'**
  String get alreadyConnected;

  /// No description provided for @cantAcceptOwnInvitation.
  ///
  /// In en, this message translates to:
  /// **'You can\'t accept your own invitation.'**
  String get cantAcceptOwnInvitation;

  /// No description provided for @connectionComplete.
  ///
  /// In en, this message translates to:
  /// **'Connection established!'**
  String get connectionComplete;

  /// No description provided for @incomingInvitation.
  ///
  /// In en, this message translates to:
  /// **'Incoming invitation detected.'**
  String get incomingInvitation;

  /// No description provided for @chatNotFoundForAcceptance.
  ///
  /// In en, this message translates to:
  /// **'Chat not found for this acceptance link.'**
  String get chatNotFoundForAcceptance;

  /// No description provided for @failedToProcessAcceptance.
  ///
  /// In en, this message translates to:
  /// **'Failed to process acceptance link.'**
  String get failedToProcessAcceptance;

  /// No description provided for @chatNotFoundForMessage.
  ///
  /// In en, this message translates to:
  /// **'Chat not found for this message link.'**
  String get chatNotFoundForMessage;

  /// No description provided for @failedToProcessMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to process message link.'**
  String get failedToProcessMessage;

  /// No description provided for @shareFile.
  ///
  /// In en, this message translates to:
  /// **'Share File'**
  String get shareFile;

  /// No description provided for @vaultUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get vaultUntitled;

  /// No description provided for @vaultNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get vaultNewPassword;

  /// No description provided for @vaultNewNote.
  ///
  /// In en, this message translates to:
  /// **'New Note'**
  String get vaultNewNote;

  /// No description provided for @vaultEditItem.
  ///
  /// In en, this message translates to:
  /// **'Edit Item'**
  String get vaultEditItem;

  /// No description provided for @vaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get vaultTitle;

  /// No description provided for @vaultUsernameEmail.
  ///
  /// In en, this message translates to:
  /// **'Username / Email'**
  String get vaultUsernameEmail;

  /// No description provided for @vaultUrlWebsite.
  ///
  /// In en, this message translates to:
  /// **'URL (Website)'**
  String get vaultUrlWebsite;

  /// No description provided for @vaultNotesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (Optional)'**
  String get vaultNotesOptional;

  /// No description provided for @vaultSecureNote.
  ///
  /// In en, this message translates to:
  /// **'Secure Note'**
  String get vaultSecureNote;

  /// No description provided for @vaultSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get vaultSave;

  /// No description provided for @vaultPasswords.
  ///
  /// In en, this message translates to:
  /// **'Passwords'**
  String get vaultPasswords;

  /// No description provided for @vaultNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get vaultNotes;

  /// No description provided for @vaultFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get vaultFiles;

  /// No description provided for @vaultNoFilesYet.
  ///
  /// In en, this message translates to:
  /// **'No files yet'**
  String get vaultNoFilesYet;

  /// No description provided for @vaultFileLabel.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get vaultFileLabel;

  /// No description provided for @vaultAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get vaultAll;

  /// No description provided for @vaultAddGroup.
  ///
  /// In en, this message translates to:
  /// **'Add Group'**
  String get vaultAddGroup;

  /// No description provided for @vaultNewGroup.
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get vaultNewGroup;

  /// No description provided for @vaultGroupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get vaultGroupName;

  /// No description provided for @vaultMoveToGroup.
  ///
  /// In en, this message translates to:
  /// **'Move to Group'**
  String get vaultMoveToGroup;

  /// No description provided for @vaultNoOtherGroups.
  ///
  /// In en, this message translates to:
  /// **'No other groups available'**
  String get vaultNoOtherGroups;

  /// No description provided for @vaultNoResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get vaultNoResultsFound;

  /// No description provided for @vaultNoPasswordsYet.
  ///
  /// In en, this message translates to:
  /// **'No passwords yet.\nTap + to add one.'**
  String get vaultNoPasswordsYet;

  /// No description provided for @vaultNoNotesYet.
  ///
  /// In en, this message translates to:
  /// **'No notes yet.\nTap + to add one.'**
  String get vaultNoNotesYet;

  /// No description provided for @vaultIsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Vault is empty.\nAdd a password or note.'**
  String get vaultIsEmpty;

  /// No description provided for @vaultPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get vaultPasswordLabel;

  /// No description provided for @vaultNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get vaultNoteLabel;

  /// No description provided for @vaultFailedToLoadItem.
  ///
  /// In en, this message translates to:
  /// **'Failed to load item'**
  String get vaultFailedToLoadItem;

  /// No description provided for @vaultSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search passwords & notes'**
  String get vaultSearchHint;

  /// No description provided for @vaultCreateYourVault.
  ///
  /// In en, this message translates to:
  /// **'Create Your Vault'**
  String get vaultCreateYourVault;

  /// No description provided for @vaultPassword.
  ///
  /// In en, this message translates to:
  /// **'Vault Password'**
  String get vaultPassword;

  /// No description provided for @vaultCreateVault.
  ///
  /// In en, this message translates to:
  /// **'Create Vault'**
  String get vaultCreateVault;

  /// No description provided for @vaultFailedToCreate.
  ///
  /// In en, this message translates to:
  /// **'Failed to create vault: {failureType}'**
  String vaultFailedToCreate(Object failureType);

  /// No description provided for @vaultUnlockVault.
  ///
  /// In en, this message translates to:
  /// **'Unlock Vault'**
  String get vaultUnlockVault;

  /// No description provided for @vaultIncorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get vaultIncorrectPassword;

  /// No description provided for @vaultUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get vaultUnlock;

  /// No description provided for @vaultForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password? Your data is encrypted and cannot be recovered.'**
  String get vaultForgotPassword;

  /// No description provided for @vaultUnlockFailed.
  ///
  /// In en, this message translates to:
  /// **'Unlock failed: {failureType}'**
  String vaultUnlockFailed(Object failureType);

  /// No description provided for @vaultPasswordStrength.
  ///
  /// In en, this message translates to:
  /// **'Password Strength'**
  String get vaultPasswordStrength;

  /// No description provided for @fuzzyVault.
  ///
  /// In en, this message translates to:
  /// **'Fuzzy Vault'**
  String get fuzzyVault;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @fuzzyUserAuth.
  ///
  /// In en, this message translates to:
  /// **'Fuzzy User Auth'**
  String get fuzzyUserAuth;

  /// No description provided for @authError.
  ///
  /// In en, this message translates to:
  /// **'Error: {errorMessage}'**
  String authError(Object errorMessage);

  /// No description provided for @unknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// No description provided for @noDataFoundPleaseSetYourData.
  ///
  /// In en, this message translates to:
  /// **'No data found. Please set your data.'**
  String get noDataFoundPleaseSetYourData;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last Updated:'**
  String get lastUpdated;

  /// No description provided for @keyStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak (Too short)'**
  String get keyStrengthWeak;

  /// No description provided for @keyStrengthModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate (Consider adding numbers or letters)'**
  String get keyStrengthModerate;

  /// No description provided for @keyStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get keyStrengthStrong;

  /// No description provided for @keyStrengthGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get keyStrengthGood;

  /// No description provided for @processingFile.
  ///
  /// In en, this message translates to:
  /// **'Processing: {fileName} -> {progress}%'**
  String processingFile(Object fileName, Object progress);

  /// No description provided for @processingFailed.
  ///
  /// In en, this message translates to:
  /// **'Processing Failed'**
  String get processingFailed;

  /// No description provided for @chatUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock Fuzzzy Ink'**
  String get chatUnlockTitle;

  /// No description provided for @chatUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your master password to open the app.'**
  String get chatUnlockSubtitle;

  /// No description provided for @chatAuthPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get chatAuthPassword;

  /// No description provided for @chatAuthIncorrectPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get chatAuthIncorrectPassword;

  /// No description provided for @chatAuthUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get chatAuthUnlock;

  /// No description provided for @chatAuthSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'Set a password to encrypt your chat keys. This adds an extra layer of security to your conversations.'**
  String get chatAuthSetupDescription;

  /// No description provided for @chatAuthSetPassword.
  ///
  /// In en, this message translates to:
  /// **'Set Password'**
  String get chatAuthSetPassword;

  /// No description provided for @chatAuthConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get chatAuthConfirmPassword;

  /// No description provided for @chatAuthPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get chatAuthPasswordsDoNotMatch;

  /// No description provided for @chatAuthProtectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Your master password protects every key in the app: your chats, your history and, unless it has its own password, the vault. It cannot be switched off.'**
  String get chatAuthProtectionDescription;

  /// No description provided for @chatAuthResecuringKeys.
  ///
  /// In en, this message translates to:
  /// **'Re-securing your keys…'**
  String get chatAuthResecuringKeys;

  /// No description provided for @chatAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Master password'**
  String get chatAuthentication;

  /// No description provided for @chatAuthenticationDescription.
  ///
  /// In en, this message translates to:
  /// **'Password, recovery key and auto-lock'**
  String get chatAuthenticationDescription;

  /// No description provided for @benchmarkFileEncryption.
  ///
  /// In en, this message translates to:
  /// **'Benchmark file encryption (dev)'**
  String get benchmarkFileEncryption;

  /// No description provided for @benchmarkFileEncryptionDescription.
  ///
  /// In en, this message translates to:
  /// **'Fuzzes and unfuzzes a 64 MiB temp file and reports MB/s'**
  String get benchmarkFileEncryptionDescription;

  /// No description provided for @benchmarkResult.
  ///
  /// In en, this message translates to:
  /// **'Benchmark result'**
  String get benchmarkResult;

  /// No description provided for @benchmarkResultSummary.
  ///
  /// In en, this message translates to:
  /// **'Encrypt: {encrypt} MB/s · Decrypt: {decrypt} MB/s ({sizeMiB} MiB)\nArgon2id: {encryptKdf} s / {decryptKdf} s (not in the MB/s)\n{device} · {buildMode} build'**
  String benchmarkResultSummary(Object encrypt, Object decrypt, Object sizeMiB,
      Object encryptKdf, Object decryptKdf, Object device, Object buildMode);

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @chatAuthBiometricUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics'**
  String get chatAuthBiometricUnlock;

  /// No description provided for @chatAuthBiometricEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Biometric Unlock'**
  String get chatAuthBiometricEnable;

  /// No description provided for @chatAuthBiometricDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable Biometric Unlock'**
  String get chatAuthBiometricDisable;

  /// No description provided for @chatAuthBiometricEnabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric Unlock Enabled'**
  String get chatAuthBiometricEnabled;

  /// No description provided for @chatAuthBiometricDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to confirm, then unlock with fingerprint or Face ID.'**
  String get chatAuthBiometricDescription;

  /// No description provided for @chatAuthBiometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication is not available on this device.'**
  String get chatAuthBiometricUnavailable;

  /// No description provided for @chatAuthBiometricFailed.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication failed.'**
  String get chatAuthBiometricFailed;

  /// No description provided for @chatAuthBiometricInvalidated.
  ///
  /// In en, this message translates to:
  /// **'Your biometrics have changed. Biometric unlock has been disabled. Please re-enable it from settings.'**
  String get chatAuthBiometricInvalidated;

  /// No description provided for @chatAuthPasswordTooWeak.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Use a longer one with letters, numbers and symbols.'**
  String get chatAuthPasswordTooWeak;

  /// No description provided for @chatAuthLockedOut.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong attempts. Try again in {time}.'**
  String chatAuthLockedOut(Object time);

  /// No description provided for @chatAuthBiometricReset.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock was turned off by an update that makes it safer. Unlock with your password, then turn it on again in Settings.'**
  String get chatAuthBiometricReset;

  /// No description provided for @biometricNotStrongEnough.
  ///
  /// In en, this message translates to:
  /// **'This device\'s biometrics aren\'t strong enough to protect your password. Keep unlocking with your password.'**
  String get biometricNotStrongEnough;

  /// No description provided for @biometricNotTurnedOn.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock was not turned on.'**
  String get biometricNotTurnedOn;

  /// No description provided for @vaultBiometricUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics'**
  String get vaultBiometricUnlock;

  /// No description provided for @vaultBiometricEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Biometric Unlock'**
  String get vaultBiometricEnable;

  /// No description provided for @vaultBiometricDisable.
  ///
  /// In en, this message translates to:
  /// **'Disable Biometric Unlock'**
  String get vaultBiometricDisable;

  /// No description provided for @vaultBiometricEnabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric Unlock Enabled'**
  String get vaultBiometricEnabled;

  /// No description provided for @vaultBiometricDescription.
  ///
  /// In en, this message translates to:
  /// **'Confirm with your master password to enable biometric unlock for this vault.'**
  String get vaultBiometricDescription;

  /// No description provided for @vaultBiometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication is not available on this device.'**
  String get vaultBiometricUnavailable;

  /// No description provided for @vaultBiometricSettings.
  ///
  /// In en, this message translates to:
  /// **'Biometric Settings'**
  String get vaultBiometricSettings;

  /// No description provided for @vaultBiometricInvalidPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect vault password.'**
  String get vaultBiometricInvalidPassword;

  /// No description provided for @vaultBiometricInvalidated.
  ///
  /// In en, this message translates to:
  /// **'Your biometrics have changed. Biometric unlock has been disabled. Please re-enable it from settings.'**
  String get vaultBiometricInvalidated;

  /// No description provided for @vaultAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Vault Authentication'**
  String get vaultAuthentication;

  /// No description provided for @vaultAuthenticationDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage vault biometric unlock'**
  String get vaultAuthenticationDescription;

  /// No description provided for @vaultNotCreated.
  ///
  /// In en, this message translates to:
  /// **'Create a vault first to enable biometric unlock.'**
  String get vaultNotCreated;

  /// No description provided for @vaultLockVault.
  ///
  /// In en, this message translates to:
  /// **'Lock Vault'**
  String get vaultLockVault;

  /// No description provided for @chatAuthCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get chatAuthCurrentPassword;

  /// No description provided for @chatAuthNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get chatAuthNewPassword;

  /// No description provided for @chatAuthPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Chat Password Changed'**
  String get chatAuthPasswordChanged;

  /// No description provided for @vaultFileSaveWarning.
  ///
  /// In en, this message translates to:
  /// **'⚠️ The original file is NOT auto-deleted. After a successful save, the user\'s source file remains on disk untouched. The app currently doesn\'t warn about this.'**
  String get vaultFileSaveWarning;

  /// No description provided for @invitationAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'This invitation was already used.'**
  String get invitationAlreadyUsed;

  /// No description provided for @invalidInvitation.
  ///
  /// In en, this message translates to:
  /// **'This invitation is invalid or damaged.'**
  String get invalidInvitation;

  /// No description provided for @invalidAcceptance.
  ///
  /// In en, this message translates to:
  /// **'This acceptance is invalid or damaged.'**
  String get invalidAcceptance;

  /// No description provided for @wrongChatBlob.
  ///
  /// In en, this message translates to:
  /// **'This code belongs to a different chat.'**
  String get wrongChatBlob;

  /// No description provided for @alreadyUnfuzzed.
  ///
  /// In en, this message translates to:
  /// **'This message was already unfuzzed on this device, or its one-time key is no longer kept.'**
  String get alreadyUnfuzzed;

  /// No description provided for @blobTooOld.
  ///
  /// In en, this message translates to:
  /// **'This message is too old to unfuzz — too many newer messages were unfuzzed first.'**
  String get blobTooOld;

  /// No description provided for @corruptBlob.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid fuzzed message.'**
  String get corruptBlob;

  /// No description provided for @safetyNumberTitle.
  ///
  /// In en, this message translates to:
  /// **'Safety number'**
  String get safetyNumberTitle;

  /// No description provided for @safetyNumberExplanation.
  ///
  /// In en, this message translates to:
  /// **'Compare these digits with your partner by voice or in person. Until they match, someone who intercepted the invitation or acceptance could be in the middle.'**
  String get safetyNumberExplanation;

  /// No description provided for @safetyNumberVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}. If your partner sees another version, or none, update both apps before comparing.'**
  String safetyNumberVersion(int version);

  /// No description provided for @safetyNumberMarkVerified.
  ///
  /// In en, this message translates to:
  /// **'Mark as verified'**
  String get safetyNumberMarkVerified;

  /// No description provided for @safetyNumberUnmark.
  ///
  /// In en, this message translates to:
  /// **'Unmark'**
  String get safetyNumberUnmark;

  /// No description provided for @safetyNumberVerifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get safetyNumberVerifiedBadge;

  /// No description provided for @verifySafetyNumberCta.
  ///
  /// In en, this message translates to:
  /// **'Verify safety number'**
  String get verifySafetyNumberCta;

  /// No description provided for @wrongPasswordFile.
  ///
  /// In en, this message translates to:
  /// **'Wrong password — this file cannot be unfuzzed with it.'**
  String get wrongPasswordFile;

  /// No description provided for @fileStillArriving.
  ///
  /// In en, this message translates to:
  /// **'This file is still being written — wait until it has fully arrived, then try again.'**
  String get fileStillArriving;

  /// No description provided for @fileCannotBeOpenedAskToResend.
  ///
  /// In en, this message translates to:
  /// **'This file cannot be opened; ask the sender to send it again.'**
  String get fileCannotBeOpenedAskToResend;

  /// No description provided for @basicsWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect key — this text cannot be unfuzzed with it.'**
  String get basicsWrongPassword;

  /// No description provided for @forwardSecrecyTitle.
  ///
  /// In en, this message translates to:
  /// **'Unfuzzed once, on this device'**
  String get forwardSecrecyTitle;

  /// No description provided for @forwardSecrecyNotice.
  ///
  /// In en, this message translates to:
  /// **'Each fuzzed message can be unfuzzed once, on this device only. Your history stays in the app — export an archive to back it up. A new device cannot re-read old blobs.'**
  String get forwardSecrecyNotice;

  /// No description provided for @aboutEncryptionTitle.
  ///
  /// In en, this message translates to:
  /// **'About encryption'**
  String get aboutEncryptionTitle;

  /// No description provided for @aboutEncryptionDescription.
  ///
  /// In en, this message translates to:
  /// **'What single-use unfuzzing means, and how your history is kept'**
  String get aboutEncryptionDescription;

  /// No description provided for @aboutEncryptionHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your history on this device'**
  String get aboutEncryptionHistoryTitle;

  /// No description provided for @aboutEncryptionBodyHistory.
  ///
  /// In en, this message translates to:
  /// **'Every text you send or unfuzz is kept in the app, sealed per chat under a key only this device holds. If you set an app-lock password, that key is protected by it — without the password, the stored text history cannot be opened. Files are kept the same way: the app keeps only the sealed file, and unfuzzes it for the moment you open, save or share it. A file you save or share is yours — it leaves the app as an ordinary file, so protect it like any other file. Once unlocked, your chats stay open until you close the app; the app does not lock itself after a while. If you turn on biometric unlock, your password is stored securely on this device so a fingerprint or face can release it.'**
  String get aboutEncryptionBodyHistory;

  /// No description provided for @aboutEncryptionWindowTitle.
  ///
  /// In en, this message translates to:
  /// **'Unfuzz in order'**
  String get aboutEncryptionWindowTitle;

  /// No description provided for @aboutEncryptionBodyWindow.
  ///
  /// In en, this message translates to:
  /// **'The app keeps keys for skipped messages, but not without limit. A blob more than 63 messages behind the newest one you already read in that chat can no longer be unfuzzed — the app says it is too old — and no more than 40 skipped messages are kept at once. Your own sent blobs cannot be unfuzzed by you either; that is why the app keeps what you sent.'**
  String get aboutEncryptionBodyWindow;

  /// No description provided for @aboutEncryptionLinksTitle.
  ///
  /// In en, this message translates to:
  /// **'Message links'**
  String get aboutEncryptionLinksTitle;

  /// No description provided for @aboutEncryptionBodyLinks.
  ///
  /// In en, this message translates to:
  /// **'A message copied or shared as a link carries the chat’s id next to the blob, so tapping the link opens the right chat. The id is not part of the secret, but anyone who sees the link can tell which chat it belongs to. The blob itself carries no chat id.'**
  String get aboutEncryptionBodyLinks;

  /// No description provided for @aboutEncryptionErrorsTitle.
  ///
  /// In en, this message translates to:
  /// **'What the errors mean'**
  String get aboutEncryptionErrorsTitle;

  /// No description provided for @aboutEncryptionBodyErrors.
  ///
  /// In en, this message translates to:
  /// **'“Already unfuzzed”: this blob was unfuzzed on this device before, or its one-time key is gone — more than 40 messages before it were skipped, or the chat has moved on several rounds since — so it can never be read here. “Not a valid fuzzed message”: the blob is damaged, incomplete, or belongs to a different chat — the app cannot tell these apart. “Too old”: it is more than 63 messages behind the newest one you already unfuzzed from that person. “Incorrect key” / “Wrong password” (Basics): the key or password does not match, or the text or file is damaged — the app cannot tell these apart either. For files, a receive that fails or is cancelled after it started has already used the file’s one-time key: ask the sender to send the file again.'**
  String get aboutEncryptionBodyErrors;

  /// No description provided for @aboutEncryptionBodySafetyNumber.
  ///
  /// In en, this message translates to:
  /// **'Every chat has a 60-digit safety number, computed from both devices’ identity keys. Compare it with your partner by voice or in person: if the digits match, nobody sat in the middle when you paired. “Verified” is your own note that you did this — the app cannot check it for you.'**
  String get aboutEncryptionBodySafetyNumber;

  /// No description provided for @aboutEncryptionUnderTheHoodTitle.
  ///
  /// In en, this message translates to:
  /// **'Under the hood'**
  String get aboutEncryptionUnderTheHoodTitle;

  /// No description provided for @aboutEncryptionBodyUnderTheHood.
  ///
  /// In en, this message translates to:
  /// **'Messages use the Olm double ratchet (vodozemac, independently audited) — a fresh key per message, which is what makes a blob single-use. Files are sealed with XChaCha20-Poly1305 in chunks; a damaged file is refused and nothing is left on disk. Passwords go through Argon2id. Your secret keys live in the app’s native core and are never sent anywhere. There is no web version: the core is native code.'**
  String get aboutEncryptionBodyUnderTheHood;

  /// No description provided for @alreadyReceived.
  ///
  /// In en, this message translates to:
  /// **'This file was already received on this device — it cannot be unfuzzed a second time.'**
  String get alreadyReceived;

  /// No description provided for @fileTooOld.
  ///
  /// In en, this message translates to:
  /// **'This file is too old to unfuzz — too many newer messages were unfuzzed first.'**
  String get fileTooOld;

  /// No description provided for @fileCorrupt.
  ///
  /// In en, this message translates to:
  /// **'This is not a valid fuzzed file — it is damaged, incomplete, or from a different chat.'**
  String get fileCorrupt;

  /// No description provided for @fileCancelled.
  ///
  /// In en, this message translates to:
  /// **'Receiving was cancelled — this file cannot be unfuzzed on this device now; ask the sender to send it again.'**
  String get fileCancelled;

  /// No description provided for @exportChatArchive.
  ///
  /// In en, this message translates to:
  /// **'Export chat archive'**
  String get exportChatArchive;

  /// No description provided for @exportChatArchiveDescription.
  ///
  /// In en, this message translates to:
  /// **'Seals this chat\'s history into a password-protected file (one message per line). Open it later in Basic Encryption → file decryption with the same password.'**
  String get exportChatArchiveDescription;

  /// No description provided for @exportChatArchivePassword.
  ///
  /// In en, this message translates to:
  /// **'Archive password'**
  String get exportChatArchivePassword;

  /// No description provided for @exportChatArchiveDone.
  ///
  /// In en, this message translates to:
  /// **'Chat archive exported.'**
  String get exportChatArchiveDone;

  /// No description provided for @exportChatArchiveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export the chat archive.'**
  String get exportChatArchiveFailed;

  /// No description provided for @exportChatArchiveNothingToExport.
  ///
  /// In en, this message translates to:
  /// **'This chat has no messages to export.'**
  String get exportChatArchiveNothingToExport;

  /// No description provided for @exportChatArchiveStoreLocked.
  ///
  /// In en, this message translates to:
  /// **'Unlock Fuzzzy Ink first — your history cannot be read while it is locked.'**
  String get exportChatArchiveStoreLocked;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @couldNotOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Could not open file.'**
  String get couldNotOpenFile;

  /// No description provided for @legalAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Legal and support'**
  String get legalAndSupport;

  /// No description provided for @legalAndSupportDescription.
  ///
  /// In en, this message translates to:
  /// **'These open fuzzzycore.com in your browser. Fuzzzy Ink itself never goes online.'**
  String get legalAndSupportDescription;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicyDescription.
  ///
  /// In en, this message translates to:
  /// **'What the app keeps, and where'**
  String get privacyPolicyDescription;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get termsOfUse;

  /// No description provided for @termsOfUseDescription.
  ///
  /// In en, this message translates to:
  /// **'The rules for using Fuzzzy Ink'**
  String get termsOfUseDescription;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @supportDescription.
  ///
  /// In en, this message translates to:
  /// **'Help, questions and reporting a problem'**
  String get supportDescription;

  /// No description provided for @dataDeletion.
  ///
  /// In en, this message translates to:
  /// **'Deleting your data'**
  String get dataDeletion;

  /// No description provided for @dataDeletionDescription.
  ///
  /// In en, this message translates to:
  /// **'How to remove everything the app keeps'**
  String get dataDeletionDescription;

  /// No description provided for @couldNotOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Could not open the link.'**
  String get couldNotOpenLink;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version} (build {build})'**
  String appVersion(Object version, Object build);

  /// No description provided for @biometricUnlockChats.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to unlock chats'**
  String get biometricUnlockChats;

  /// No description provided for @biometricUnlockVault.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to unlock vault'**
  String get biometricUnlockVault;

  /// No description provided for @biometricUnlockVaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock Fuzzy Vault'**
  String get biometricUnlockVaultTitle;

  /// No description provided for @biometricSavePassword.
  ///
  /// In en, this message translates to:
  /// **'Authenticate to save password'**
  String get biometricSavePassword;

  /// No description provided for @vaultMoveUnfinishedTitle.
  ///
  /// In en, this message translates to:
  /// **'Vault not moved'**
  String get vaultMoveUnfinishedTitle;

  /// No description provided for @vaultMoveUnfinishedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your vault couldn\'t be moved to its safe place in the app. Nothing was deleted. Close and reopen the app to try again.'**
  String get vaultMoveUnfinishedMessage;

  /// No description provided for @copyRefused.
  ///
  /// In en, this message translates to:
  /// **'Only sealed text can be copied.'**
  String get copyRefused;

  /// No description provided for @copyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Copying'**
  String get copyPolicyTitle;

  /// No description provided for @copyPolicyDescription.
  ///
  /// In en, this message translates to:
  /// **'Only the sealed text you send can be copied out of the app. Decrypted messages, notes and file locations stay inside. Anything copied is removed from the clipboard after a short time.'**
  String get copyPolicyDescription;

  /// No description provided for @copyPolicyVaultPasswordNote.
  ///
  /// In en, this message translates to:
  /// **'Vault passwords are the one exception: a copied password is kept out of clipboard history where the system allows it and is removed after {seconds} seconds.'**
  String copyPolicyVaultPasswordNote(int seconds);

  /// No description provided for @vaultCopyPassword.
  ///
  /// In en, this message translates to:
  /// **'Copy password'**
  String get vaultCopyPassword;

  /// No description provided for @vaultPasswordCopiedClearsIn.
  ///
  /// In en, this message translates to:
  /// **'Password copied. It is removed from the clipboard in {seconds} seconds.'**
  String vaultPasswordCopiedClearsIn(int seconds);

  /// No description provided for @shareAsLinkOption.
  ///
  /// In en, this message translates to:
  /// **'Send as a link'**
  String get shareAsLinkOption;

  /// No description provided for @shareAsLinkOptionHint.
  ///
  /// In en, this message translates to:
  /// **'Opens straight in Fuzzzy Ink. Without the app, the link shows where to get it.'**
  String get shareAsLinkOptionHint;

  /// No description provided for @shareAsQrCodeOption.
  ///
  /// In en, this message translates to:
  /// **'Show a QR code'**
  String get shareAsQrCodeOption;

  /// No description provided for @shareAsQrCodeOptionHint.
  ///
  /// In en, this message translates to:
  /// **'The other phone scans it with its camera.'**
  String get shareAsQrCodeOptionHint;

  /// No description provided for @shareAsFileOption.
  ///
  /// In en, this message translates to:
  /// **'Send as a file'**
  String get shareAsFileOption;

  /// No description provided for @shareAsFileOptionHint.
  ///
  /// In en, this message translates to:
  /// **'For e-mail, or a chat that cuts long links.'**
  String get shareAsFileOptionHint;

  /// No description provided for @qrCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Point the other phone\'s camera at this code. It opens Fuzzzy Ink there, or the download page if the app is missing.'**
  String get qrCodeHint;

  /// No description provided for @notVerified.
  ///
  /// In en, this message translates to:
  /// **'Not verified'**
  String get notVerified;

  /// No description provided for @pairingWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Someone else may have accepted your invitation'**
  String get pairingWarningTitle;

  /// No description provided for @pairingWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'Your chat with {chatName} is already connected, and this acceptance is a different one. Someone else may have accepted your invitation. Compare the safety number with {chatName} in person or on a call before you trust this chat.'**
  String pairingWarningMessage(Object chatName);

  /// No description provided for @saveFile.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveFile;

  /// No description provided for @fileSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get fileSaved;

  /// No description provided for @couldNotSaveFile.
  ///
  /// In en, this message translates to:
  /// **'Could not save the file.'**
  String get couldNotSaveFile;

  /// No description provided for @sentFileHint.
  ///
  /// In en, this message translates to:
  /// **'Fuzzed — share or save it'**
  String get sentFileHint;

  /// No description provided for @receivedFileHint.
  ///
  /// In en, this message translates to:
  /// **'Kept sealed — open or save it'**
  String get receivedFileHint;

  /// No description provided for @unfuzzingFile.
  ///
  /// In en, this message translates to:
  /// **'Unfuzzing…'**
  String get unfuzzingFile;

  /// No description provided for @fileNoPreview.
  ///
  /// In en, this message translates to:
  /// **'This file cannot be shown in the app. Save it to open it with another app.'**
  String get fileNoPreview;

  /// No description provided for @basicsFuzzedFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Fuzzed files kept in the app'**
  String get basicsFuzzedFilesTitle;

  /// No description provided for @masterPassword.
  ///
  /// In en, this message translates to:
  /// **'Master password'**
  String get masterPassword;

  /// No description provided for @masterPasswordSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your master password'**
  String get masterPasswordSetupTitle;

  /// No description provided for @masterPasswordSetupDescription.
  ///
  /// In en, this message translates to:
  /// **'One password protects everything in Fuzzzy Ink: your chats, your history and your vault. You will enter it each time you open the app.'**
  String get masterPasswordSetupDescription;

  /// No description provided for @masterPasswordPreviousData.
  ///
  /// In en, this message translates to:
  /// **'This version uses a master password. Chats and the vault from the earlier test version can\'t be opened with it, so they will be removed. Files you unfuzzed stay where they are.'**
  String get masterPasswordPreviousData;

  /// No description provided for @masterPasswordCreate.
  ///
  /// In en, this message translates to:
  /// **'Create master password'**
  String get masterPasswordCreate;

  /// No description provided for @masterPasswordCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating your keys…'**
  String get masterPasswordCreating;

  /// No description provided for @masterPasswordFailed.
  ///
  /// In en, this message translates to:
  /// **'Your keys could not be created. Try again.'**
  String get masterPasswordFailed;

  /// No description provided for @masterPasswordIsOn.
  ///
  /// In en, this message translates to:
  /// **'Master password is on'**
  String get masterPasswordIsOn;

  /// No description provided for @recoveryKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery key'**
  String get recoveryKeyTitle;

  /// No description provided for @recoveryKeyDescription.
  ///
  /// In en, this message translates to:
  /// **'If you forget your master password, this key lets you set a new one. Write it down or save it, and keep it somewhere safe, away from this device. You see it only now.'**
  String get recoveryKeyDescription;

  /// No description provided for @recoveryKeyWarning.
  ///
  /// In en, this message translates to:
  /// **'Without your password or this recovery key, nobody — not even us — can get your data back.'**
  String get recoveryKeyWarning;

  /// No description provided for @recoveryKeySave.
  ///
  /// In en, this message translates to:
  /// **'Save or print…'**
  String get recoveryKeySave;

  /// No description provided for @recoveryKeySaved.
  ///
  /// In en, this message translates to:
  /// **'Recovery key saved to a file'**
  String get recoveryKeySaved;

  /// No description provided for @recoveryKeySaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The recovery key was not saved.'**
  String get recoveryKeySaveFailed;

  /// No description provided for @recoveryKeyConfirm.
  ///
  /// In en, this message translates to:
  /// **'I have saved my recovery key'**
  String get recoveryKeyConfirm;

  /// No description provided for @recoveryKeyContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get recoveryKeyContinue;

  /// No description provided for @recoveryKeySkip.
  ///
  /// In en, this message translates to:
  /// **'Continue without a recovery key'**
  String get recoveryKeySkip;

  /// No description provided for @recoveryKeySkipTitle.
  ///
  /// In en, this message translates to:
  /// **'Go on without a recovery key?'**
  String get recoveryKeySkipTitle;

  /// No description provided for @recoveryKeySkipMessage.
  ///
  /// In en, this message translates to:
  /// **'If you forget your master password, your chats, history and vault are lost for good. Without your password or this recovery key, nobody — not even us — can get your data back.'**
  String get recoveryKeySkipMessage;

  /// No description provided for @recoveryKeySkipConfirm.
  ///
  /// In en, this message translates to:
  /// **'Continue without it'**
  String get recoveryKeySkipConfirm;

  /// No description provided for @recoveryKeyFileText.
  ///
  /// In en, this message translates to:
  /// **'Fuzzzy Ink recovery key\n\n{key}\n\nIf you forget your master password, this key lets you set a new one. Keep it somewhere safe, away from the device. Without your password or this recovery key, nobody — not even us — can get your data back.\n'**
  String recoveryKeyFileText(String key);

  /// No description provided for @recoveryKeyIsSet.
  ///
  /// In en, this message translates to:
  /// **'A recovery key is set.'**
  String get recoveryKeyIsSet;

  /// No description provided for @recoveryKeyNotSet.
  ///
  /// In en, this message translates to:
  /// **'No recovery key. If you forget your master password, your data is lost for good.'**
  String get recoveryKeyNotSet;

  /// No description provided for @recoveryKeyCreateNew.
  ///
  /// In en, this message translates to:
  /// **'Create a new recovery key'**
  String get recoveryKeyCreateNew;

  /// No description provided for @recoveryKeyCreateNewDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your master password to create a new recovery key. The old one stops working.'**
  String get recoveryKeyCreateNewDescription;

  /// No description provided for @recoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'New password with your recovery key'**
  String get recoveryTitle;

  /// No description provided for @recoveryDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the recovery key you saved when you set up the app, then choose a new master password.'**
  String get recoveryDescription;

  /// No description provided for @recoveryKeyField.
  ///
  /// In en, this message translates to:
  /// **'Recovery key'**
  String get recoveryKeyField;

  /// No description provided for @recoverySubmit.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get recoverySubmit;

  /// No description provided for @recoveryKeyTypo.
  ///
  /// In en, this message translates to:
  /// **'This recovery key has a typo. Check each group of four.'**
  String get recoveryKeyTypo;

  /// No description provided for @recoveryKeyWrong.
  ///
  /// In en, this message translates to:
  /// **'This recovery key does not open this app.'**
  String get recoveryKeyWrong;

  /// No description provided for @chatUnlockForgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get chatUnlockForgot;

  /// No description provided for @chatUnlockUseRecoveryKey.
  ///
  /// In en, this message translates to:
  /// **'Use my recovery key'**
  String get chatUnlockUseRecoveryKey;

  /// No description provided for @chatUnlockErase.
  ///
  /// In en, this message translates to:
  /// **'Erase everything and start over'**
  String get chatUnlockErase;

  /// No description provided for @eraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Erase everything?'**
  String get eraseTitle;

  /// No description provided for @eraseMessage.
  ///
  /// In en, this message translates to:
  /// **'Your chats, history, vault and settings are deleted from this device and cannot be brought back. Files you unfuzzed stay where they are.'**
  String get eraseMessage;

  /// No description provided for @eraseConfirm.
  ///
  /// In en, this message translates to:
  /// **'Erase everything'**
  String get eraseConfirm;

  /// No description provided for @storageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Fuzzzy Ink can\'t read this device\'s secure key storage, so it stays locked. Try again; if it keeps happening, restart the device.'**
  String get storageUnavailable;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @appLockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock Fuzzzy Ink'**
  String get appLockNow;

  /// No description provided for @autoLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock'**
  String get autoLockTitle;

  /// No description provided for @autoLockIdle.
  ///
  /// In en, this message translates to:
  /// **'Lock after no activity for'**
  String get autoLockIdle;

  /// No description provided for @autoLockBackground.
  ///
  /// In en, this message translates to:
  /// **'Lock after leaving the app'**
  String get autoLockBackground;

  /// No description provided for @autoLockImmediately.
  ///
  /// In en, this message translates to:
  /// **'At once'**
  String get autoLockImmediately;

  /// No description provided for @autoLockMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String autoLockMinutes(int count);

  /// No description provided for @autoLockSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The setting was not saved.'**
  String get autoLockSaveFailed;

  /// No description provided for @vaultPasswordModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Vault password'**
  String get vaultPasswordModeTitle;

  /// No description provided for @vaultUsesMasterPassword.
  ///
  /// In en, this message translates to:
  /// **'Your master password opens the vault.'**
  String get vaultUsesMasterPassword;

  /// No description provided for @vaultUsesOwnPassword.
  ///
  /// In en, this message translates to:
  /// **'The vault has its own password.'**
  String get vaultUsesOwnPassword;

  /// No description provided for @vaultUseOwnPassword.
  ///
  /// In en, this message translates to:
  /// **'Use a different password for the vault'**
  String get vaultUseOwnPassword;

  /// No description provided for @vaultUseMasterPassword.
  ///
  /// In en, this message translates to:
  /// **'Open the vault with the master password'**
  String get vaultUseMasterPassword;

  /// No description provided for @vaultOwnPasswordNote.
  ///
  /// In en, this message translates to:
  /// **'No recovery key is set: without this password the vault is lost for good.'**
  String get vaultOwnPasswordNote;

  /// No description provided for @vaultOwnPasswordRecoveryNote.
  ///
  /// In en, this message translates to:
  /// **'Your recovery key can still open My safe.'**
  String get vaultOwnPasswordRecoveryNote;

  /// No description provided for @vaultUseRecoveryKey.
  ///
  /// In en, this message translates to:
  /// **'Use my recovery key'**
  String get vaultUseRecoveryKey;

  /// No description provided for @vaultRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Open My safe with your recovery key'**
  String get vaultRecoveryTitle;

  /// No description provided for @vaultRecoveryDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your recovery key, then choose a new password for My safe, or let your master password open it.'**
  String get vaultRecoveryDescription;

  /// No description provided for @vaultRecoveryUseMasterPassword.
  ///
  /// In en, this message translates to:
  /// **'Open My safe with my master password'**
  String get vaultRecoveryUseMasterPassword;

  /// No description provided for @vaultRecoverySubmit.
  ///
  /// In en, this message translates to:
  /// **'Open My safe'**
  String get vaultRecoverySubmit;

  /// No description provided for @recoveryKeyVaultPasswordNote.
  ///
  /// In en, this message translates to:
  /// **'My safe has its own password. Enter it too, so the new key opens My safe as well.'**
  String get recoveryKeyVaultPasswordNote;

  /// No description provided for @vaultOwnNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New vault password'**
  String get vaultOwnNewPassword;

  /// No description provided for @vaultCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current vault password'**
  String get vaultCurrentPassword;

  /// No description provided for @vaultPasswordModeChanged.
  ///
  /// In en, this message translates to:
  /// **'Vault password updated'**
  String get vaultPasswordModeChanged;

  /// No description provided for @vaultCreateWithMasterDescription.
  ///
  /// In en, this message translates to:
  /// **'Your vault keeps passwords, notes and files sealed on this device. Your master password opens it; enter it to create the vault.'**
  String get vaultCreateWithMasterDescription;

  /// No description provided for @vaultForgotMasterPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your master password? Lock the app and use your recovery key.'**
  String get vaultForgotMasterPassword;

  /// No description provided for @vaultTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong passwords. Wait a moment and try again.'**
  String get vaultTooManyAttempts;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'My safe'**
  String get tabMySafe;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get homeLockTitle;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'For one person'**
  String get homeLockSubtitle;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get homeOpenTitle;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'What you got'**
  String get homeOpenSubtitle;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get homePeople;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'People · {count}'**
  String homePeopleCount(int count);

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get homeAdd;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Add a person'**
  String get homeAddPerson;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'No one yet'**
  String get homeNoOneYet;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load your people. Close and open the app again.'**
  String get homeLoadError;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'You send an invite'**
  String get stepYouSendInvite;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'They reply'**
  String get stepTheyReply;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Invite sent'**
  String get stepInviteSent;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'{name} replies'**
  String stepNameReplies(String name);

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Lock for each other'**
  String get stepLockForEachOther;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String stepsProgress(int step, int total);

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total} · {label}'**
  String stepsProgressWithLabel(int step, int total, String label);

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Done: {step}'**
  String stepDone(String step);

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Next: {step}'**
  String stepNext(String step);

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Send an invite'**
  String get addSendInvite;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'You start'**
  String get addYouStart;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'I got an invite'**
  String get addGotInvite;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'They started'**
  String get addTheyStarted;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Waiting for reply'**
  String get chipWaitingForReply;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get chipChecked;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Not checked'**
  String get chipNotChecked;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Then you can lock for each other'**
  String get personRowWaitingLine;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Once {name} replies, you can lock messages for each other.'**
  String waitNoteReply(String name);

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Send the invite any way, even publicly. It stays safe.'**
  String get waitNoteAnyWay;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Why?'**
  String get linkWhy;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'How?'**
  String get linkHow;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get linkMore;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Opens an explanation'**
  String get linkOpensExplanation;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Why no reset?'**
  String get infoNoResetTitle;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Your password never leaves this phone.'**
  String get infoNoResetLine1;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'We can\'t see it, so no one can reset it.'**
  String get infoNoResetLine2;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Your recovery key is the only spare.'**
  String get infoNoResetLine3;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Your recovery key'**
  String get infoRecoveryKeyTitle;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Your spare if you forget the password.'**
  String get infoRecoveryKeyLine1;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'It opens Fuzzzy Ink, and My safe too.'**
  String get infoRecoveryKeyLine2;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Print it or save it off this phone. Anyone with it and your phone can open everything.'**
  String get infoRecoveryKeyLine3;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Why only once?'**
  String get infoOpensOnceTitle;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Each locked thing has its own key.'**
  String get infoOpensOnceLine1;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Opening it uses the key up, on any phone.'**
  String get infoOpensOnceLine2;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'A copy stays in your history, locked.'**
  String get infoOpensOnceLine3;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Safe to send anywhere'**
  String get infoSafeAnywhereTitle;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'An invite can\'t open anything.'**
  String get infoSafeAnywhereLine1;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Only their reply connects you two.'**
  String get infoSafeAnywhereLine2;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Then you check numbers together, so you know it\'s them.'**
  String get infoSafeAnywhereLine3;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Why check numbers?'**
  String get infoCheckNumbersTitle;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Anyone who saw your invite could answer it.'**
  String get infoCheckNumbersLine1;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Same numbers on both phones: nobody got in between.'**
  String get infoCheckNumbersLine2;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Where do files go?'**
  String get infoFilesTitle;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Fuzzzy Ink keeps only the locked copy.'**
  String get infoFilesLine1;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Open shows it here. Nothing is saved.'**
  String get infoFilesLine2;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Save gives you a normal copy. From then on it\'s yours to protect.'**
  String get infoFilesLine3;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Why no copying?'**
  String get infoNoCopyingTitle;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'What you open stays inside Fuzzzy Ink.'**
  String get infoNoCopyingLine1;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Only locked text can be copied. It is safe anywhere.'**
  String get infoNoCopyingLine2;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Locking with a password'**
  String get infoPasswordLockingTitle;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Anyone with the password can open it.'**
  String get infoPasswordLockingLine1;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Say the password. Never send it with the locked thing.'**
  String get infoPasswordLockingLine2;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'My safe\'s own password'**
  String get infoSafePasswordTitle;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'One more password to remember.'**
  String get infoSafePasswordLine1;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Forgot it? Your recovery key opens My safe too.'**
  String get infoSafePasswordLine2;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'No copy · no screenshots'**
  String get tagNoCopyNoScreenshots;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'No copy'**
  String get tagNoCopy;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'No screenshots'**
  String get tagNoScreenshots;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Who\'s it for?'**
  String get lockWhoTitle;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Lock with a password'**
  String get lockWithPassword;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'No invite needed'**
  String get lockNoInviteNeeded;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Add a person first'**
  String get lockAddPersonFirst;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get orDivider;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Open what you got'**
  String get openWhatYouGot;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Paste it'**
  String get openPasteIt;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Locked text, invite or reply'**
  String get openPasteItHint;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Links and QR codes open here by themselves.'**
  String get openLinksTip;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Nothing to paste. Copy the locked text first.'**
  String get openNothingToPaste;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Paste a link here. Locked text opens on the person\'s page.'**
  String get openPasteNotALink;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Locked with a password'**
  String get openLockedWithPassword;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Share invite'**
  String get shareTitleInvite;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Share reply'**
  String get shareTitleReply;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Share locked message'**
  String get shareTitleMessage;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Share locked file'**
  String get shareTitleFile;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Any way. Even publicly.'**
  String get shareLineInvite;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Any way you like.'**
  String get shareLineReply;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Only {name} can open it.'**
  String shareLineForName(String name);

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'They need the password.'**
  String get shareLinePassword;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Send a link'**
  String get shareSendLink;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Opens in the app'**
  String get shareSendLinkHint;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Show a QR code'**
  String get shareShowQr;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'They scan it'**
  String get shareShowQrHint;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Send as a file'**
  String get shareSendFile;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'A small file'**
  String get shareSendFileHint;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Copy as text'**
  String get shareCopyText;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Stays locked anywhere'**
  String get shareCopyTextHint;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Too big. Send it as a file.'**
  String get shareTooBig;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Copied. It stays locked.'**
  String get shareCopiedStaysLocked;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Your invite'**
  String get qrLabelInvite;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Your reply'**
  String get qrLabelReply;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Locked message'**
  String get qrLabelMessage;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Let {name} scan this.'**
  String qrLetNameScan(String name);

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Let them scan this.'**
  String get qrLetThemScan;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Safe to show anyone. Only their reply connects you.'**
  String get qrSafeToShowAnyone;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Only show it to the right person.'**
  String get qrOnlyRightPerson;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'You locked a message'**
  String get historyYouLockedMessage;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'You opened a message'**
  String get historyYouOpenedMessage;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'You locked {file}'**
  String historyYouLockedFile(String file);

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'You opened {file}'**
  String historyYouOpenedFile(String file);

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'tap to read'**
  String get historyTapToRead;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'tap to see'**
  String get historyTapToSee;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get fileCardLocked;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Kept locked in My safe'**
  String get fileCardKeptInSafe;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Locked version · safe to send'**
  String get lockedPreviewLabel;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get confirmCopied;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Handed over'**
  String get confirmHandedOver;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Safety numbers'**
  String get safetyGridLabel;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Wait {time}'**
  String lockoutWaitLeft(String time);

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Look and language'**
  String get settingsLookAndLanguage;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Look'**
  String get settingsLook;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Like my phone'**
  String get lookLikeMyPhone;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lookLight;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get lookDark;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'ქართული'**
  String get languageGeorgian;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Fuzzzy Cast'**
  String get fuzzzyCast;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Fuzzz reacts when you lock and open.'**
  String get fuzzzyCastLine;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Fuzzzy Cast is on.'**
  String get fuzzzyCastOn;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Soft sounds'**
  String get softSounds;

  /// Fuzzzy Ink redesign (DESIGN.md copy table).
  ///
  /// In en, this message translates to:
  /// **'Never on silent'**
  String get softSoundsLine;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'My safe is locked'**
  String get safeLockedTitle;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Opens with your master password.'**
  String get safeOpensWithMaster;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Opens with your safe password.'**
  String get safeOpensWithOwn;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Open with fingerprint'**
  String get safeOpenWithFingerprint;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Use master password'**
  String get safeUseMasterPassword;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Use safe password'**
  String get safeUseSafePassword;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Safe password'**
  String get safePasswordField;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Open My safe'**
  String get safeOpenButton;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Use recovery key'**
  String get safeUseRecoveryKey;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Not right. Try again.'**
  String get safeWrongPassword;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Too many tries.'**
  String get safeTooManyTries;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open My safe. Try again.'**
  String get safeCouldNotOpen;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Type your recovery key'**
  String get safeRecoveryTitle;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Spaces and capitals don\'t matter.'**
  String get safeRecoveryLine;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'No key? Then nothing can open it.'**
  String get safeRecoveryNoKey;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'New safe password'**
  String get safeRecoveryNewPassword;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get safeSearch;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'All groups'**
  String get safeAllGroups;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get safeNewGroup;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get safeEmptyTitle;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Tap Add.'**
  String get safeEmptyLine;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get safeNothingFound;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Try another word.'**
  String get safeTryAnotherWord;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load My safe. Lock it and open it again.'**
  String get safeLoadError;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Locks itself after {minutes} minutes away'**
  String safeAutoLockTip(int minutes);

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get safeAdd;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Add to My safe'**
  String get safeAddTitle;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Username or email'**
  String get safeUsername;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get safeWebsite;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get safeNotes;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get safeShowPassword;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get safeHidePassword;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Copied · clears in {seconds} s'**
  String safeCopiedClearsIn(int seconds);

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Copied passwords clear after {seconds} seconds.'**
  String safeCopyRule(int seconds);

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Cleared.'**
  String get safeCleared;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Copying is off in Settings.'**
  String get safeCopyOff;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get safeGroup;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'No group'**
  String get safeNoGroup;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get safeMove;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get safeEdit;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'More for {title}'**
  String safeMoreFor(String title);

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Save gives you a normal copy. Then it\'s yours.'**
  String get safeSaveTip;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Move to a group'**
  String get safeMoveToGroup;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Delete {title}?'**
  String safeDeleteTitle(String title);

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'It leaves My safe for good. No undo.'**
  String get safeDeleteLine;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Deleted from My safe.'**
  String get safeDeleted;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Moved to {group}.'**
  String safeMovedTo(String group);

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Removed from its group.'**
  String get safeMovedOut;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Saved in My safe.'**
  String get safeSaved;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open this. Try again.'**
  String get safeItemLoadFailed;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Try again.'**
  String get safeSaveFailed;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get safeGroupName;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'e.g. Family'**
  String get safeGroupHint;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Add group'**
  String get safeAddGroup;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get safeNewPasswordTitle;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get safeNewNoteTitle;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get safeNewFileTitle;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get safeTitle;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'e.g. Bank app'**
  String get safeTitleHintPassword;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'e.g. Passport number'**
  String get safeTitleHintNote;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'e.g. Home insurance'**
  String get safeTitleHintFile;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get safeOptional;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Anything to keep safe'**
  String get safeNoteHint;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get safeChooseFile;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Your original stays where it is.'**
  String get safeOriginalStays;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get safeChangeFile;

  /// Fuzzzy Ink redesign, My safe (DESIGN.md sections 4.11 and 7).
  ///
  /// In en, this message translates to:
  /// **'Choose a file first.'**
  String get safeChooseFileFirst;
}

class _FuzzzyInkLocalizationsDelegate
    extends LocalizationsDelegate<FuzzzyInkLocalizations> {
  const _FuzzzyInkLocalizationsDelegate();

  @override
  Future<FuzzzyInkLocalizations> load(Locale locale) {
    return SynchronousFuture<FuzzzyInkLocalizations>(
        lookupFuzzzyInkLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ka'].contains(locale.languageCode);

  @override
  bool shouldReload(_FuzzzyInkLocalizationsDelegate old) => false;
}

FuzzzyInkLocalizations lookupFuzzzyInkLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return FuzzzyInkLocalizationsEn();
    case 'ka':
      return FuzzzyInkLocalizationsKa();
  }

  throw FlutterError(
      'FuzzzyInkLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
