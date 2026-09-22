import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'fuzzzy_seal_localizations_en.dart';
import 'fuzzzy_seal_localizations_ka.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of FuzzzySealLocalizations
/// returned by `FuzzzySealLocalizations.of(context)`.
///
/// Applications need to include `FuzzzySealLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated_localizations/fuzzzy_seal_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: FuzzzySealLocalizations.localizationsDelegates,
///   supportedLocales: FuzzzySealLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the FuzzzySealLocalizations.supportedLocales
/// property.
abstract class FuzzzySealLocalizations {
  FuzzzySealLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static FuzzzySealLocalizations? of(BuildContext context) {
    return Localizations.of<FuzzzySealLocalizations>(
        context, FuzzzySealLocalizations);
  }

  static const LocalizationsDelegate<FuzzzySealLocalizations> delegate =
      _FuzzzySealLocalizationsDelegate();

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

  /// No description provided for @fuzzzySeal.
  ///
  /// In en, this message translates to:
  /// **'Fuzzzy Seal'**
  String get fuzzzySeal;

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

  /// No description provided for @welcomeToFuzzzySeal.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Fuzzzy Seal'**
  String get welcomeToFuzzzySeal;

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

  /// No description provided for @securityWarning.
  ///
  /// In en, this message translates to:
  /// **'Security Warning'**
  String get securityWarning;

  /// No description provided for @areYouSureYouWantToCopyUnencryptedDataToYourClipboardThisCouldCompromiseYourSecureChat.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to copy unencrypted data to your clipboard? This could compromise your secure chat.'**
  String
      get areYouSureYouWantToCopyUnencryptedDataToYourClipboardThisCouldCompromiseYourSecureChat;

  /// No description provided for @copyFuzz.
  ///
  /// In en, this message translates to:
  /// **'Copy Fuzz'**
  String get copyFuzz;

  /// No description provided for @copyPlaintext.
  ///
  /// In en, this message translates to:
  /// **'Copy Plaintext'**
  String get copyPlaintext;

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

  /// No description provided for @securityLevel.
  ///
  /// In en, this message translates to:
  /// **'Security Level'**
  String get securityLevel;

  /// No description provided for @strict.
  ///
  /// In en, this message translates to:
  /// **'Strict'**
  String get strict;

  /// No description provided for @moderate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get moderate;

  /// No description provided for @strictSecurityDescription.
  ///
  /// In en, this message translates to:
  /// **'Shows a confirmation dialog before copying any decrypted text. Recommended for maximum privacy.'**
  String get strictSecurityDescription;

  /// No description provided for @moderateSecurityDescription.
  ///
  /// In en, this message translates to:
  /// **'Received messages are selectable and can be copied directly without a warning.'**
  String get moderateSecurityDescription;

  /// No description provided for @shareAsLink.
  ///
  /// In en, this message translates to:
  /// **'Share as Link'**
  String get shareAsLink;

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

  /// No description provided for @updateRequired.
  ///
  /// In en, this message translates to:
  /// **'This link requires a newer version of Fuzzzy Seal.'**
  String get updateRequired;

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

  /// No description provided for @invitationLinkExpired.
  ///
  /// In en, this message translates to:
  /// **'This invitation link has expired.'**
  String get invitationLinkExpired;

  /// No description provided for @acceptanceLinkExpired.
  ///
  /// In en, this message translates to:
  /// **'This acceptance link has expired.'**
  String get acceptanceLinkExpired;

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

  /// No description provided for @vaultCopyingNotImplemented.
  ///
  /// In en, this message translates to:
  /// **'Copying not fully implemented yet.'**
  String get vaultCopyingNotImplemented;

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

  /// No description provided for @vaultCreateDescription.
  ///
  /// In en, this message translates to:
  /// **'Your vault encrypts all passwords and notes locally on your device.\nChoose a strong master password.'**
  String get vaultCreateDescription;

  /// No description provided for @vaultPassword.
  ///
  /// In en, this message translates to:
  /// **'Vault Password'**
  String get vaultPassword;

  /// No description provided for @vaultConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get vaultConfirmPassword;

  /// No description provided for @vaultPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get vaultPasswordsDoNotMatch;

  /// No description provided for @vaultPasswordCannotBeReset.
  ///
  /// In en, this message translates to:
  /// **'This password cannot be reset. If you forget it, your data will be permanently lost.'**
  String get vaultPasswordCannotBeReset;

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
  /// **'Unlock Fuzzzy Seal'**
  String get chatUnlockTitle;

  /// No description provided for @chatUnlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to access your chats.'**
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

  /// No description provided for @chatAuthForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password? Your encrypted data cannot be recovered without it.'**
  String get chatAuthForgotPassword;

  /// No description provided for @chatAuthSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Protect Your Chats'**
  String get chatAuthSetupTitle;

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

  /// No description provided for @chatAuthEnabled.
  ///
  /// In en, this message translates to:
  /// **'Chat Protection Enabled'**
  String get chatAuthEnabled;

  /// No description provided for @chatAuthDisabled.
  ///
  /// In en, this message translates to:
  /// **'Chat Protection Disabled'**
  String get chatAuthDisabled;

  /// No description provided for @chatAuthEnableProtection.
  ///
  /// In en, this message translates to:
  /// **'Enable Chat Protection'**
  String get chatAuthEnableProtection;

  /// No description provided for @chatAuthDisableProtection.
  ///
  /// In en, this message translates to:
  /// **'Disable Chat Protection'**
  String get chatAuthDisableProtection;

  /// No description provided for @chatAuthProtectionDescription.
  ///
  /// In en, this message translates to:
  /// **'When enabled, you must enter a password to access your chats. Your keys will be encrypted with this password.'**
  String get chatAuthProtectionDescription;

  /// No description provided for @chatAuthMigratingKeys.
  ///
  /// In en, this message translates to:
  /// **'Encrypting your keys...'**
  String get chatAuthMigratingKeys;

  /// No description provided for @chatAuthResecuringKeys.
  ///
  /// In en, this message translates to:
  /// **'Re-securing your keys…'**
  String get chatAuthResecuringKeys;

  /// No description provided for @chatAuthentication.
  ///
  /// In en, this message translates to:
  /// **'Chat Authentication'**
  String get chatAuthentication;

  /// No description provided for @chatAuthenticationDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage chat password protection'**
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

  /// No description provided for @chatAuthEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your current password'**
  String get chatAuthEnterPassword;

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
  /// **'This message was already unfuzzed on this device.'**
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
  /// **'Every text you send or unfuzz is kept in the app, sealed per chat under a key only this device holds. If you set an app-lock password, that key is protected by it — without the password, the stored text history cannot be opened. Unfuzzed files are different: they are saved as ordinary files in this chat’s folder on the device and are not sealed or locked by the app — anyone who can read the device’s storage can open them, so protect them like any other file. Once unlocked, your chats stay open until you close the app; the app does not lock itself after a while. If you turn on biometric unlock, your password is stored securely on this device so a fingerprint or face can release it.'**
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
  /// **'“Already unfuzzed”: this blob was unfuzzed on this device before and cannot be read a second time. “Not a valid fuzzed message”: the blob is damaged, incomplete, or belongs to a different chat — the app cannot tell these apart. “Too old”: too many newer messages were unfuzzed first. “Incorrect key” / “Wrong password” (Basics): the key or password does not match, or the text or file is damaged — the app cannot tell these apart either. For files, a receive that fails or is cancelled after it started has already used the file’s one-time key: ask the sender to send the file again.'**
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
  /// **'Unlock Fuzzzy Seal first — your history cannot be read while it is locked.'**
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
}

class _FuzzzySealLocalizationsDelegate
    extends LocalizationsDelegate<FuzzzySealLocalizations> {
  const _FuzzzySealLocalizationsDelegate();

  @override
  Future<FuzzzySealLocalizations> load(Locale locale) {
    return SynchronousFuture<FuzzzySealLocalizations>(
        lookupFuzzzySealLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ka'].contains(locale.languageCode);

  @override
  bool shouldReload(_FuzzzySealLocalizationsDelegate old) => false;
}

FuzzzySealLocalizations lookupFuzzzySealLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return FuzzzySealLocalizationsEn();
    case 'ka':
      return FuzzzySealLocalizationsKa();
  }

  throw FlutterError(
      'FuzzzySealLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
