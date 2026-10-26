// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'fuzzzy_ink_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Georgian (`ka`).
class FuzzzyInkLocalizationsKa extends FuzzzyInkLocalizations {
  FuzzzyInkLocalizationsKa([String locale = 'ka']) : super(locale);

  @override
  String get chat => 'ჩատი';

  @override
  String get fuzzzyInk => 'Fuzzzy Ink';

  @override
  String get acceptInvitation => 'მოწვევის მიღება';

  @override
  String get back => 'უკან';

  @override
  String get create => 'შექმნა';

  @override
  String get failedToCreateChat => 'ჩატი ვერ შეიქმნა.';

  @override
  String get accept => 'მიღება';

  @override
  String get failedToReadAcceptance => 'პასუხის წაკითხვა ვერ მოხერხდა.';

  @override
  String get deleteChat => 'ჩატის წაშლა';

  @override
  String get cancel => 'გაუქმება';

  @override
  String get delete => 'წაშლა';

  @override
  String get copiedToTheClipboard => 'დაკოპირდა.';

  @override
  String get copy => 'კოპირება';

  @override
  String get share => 'გაზიარება';

  @override
  String areYouSureYouWantToDeleteChatWith(Object personName) {
    return 'წავშალოთ ჩატი: $personName?';
  }

  @override
  String get failedToGetAcceptance => 'პასუხის მიღება ვერ მოხერხდა.';

  @override
  String get errorPickingFiles => 'ფაილის არჩევა ვერ მოხერხდა.';

  @override
  String get loading => 'იტვირთება';

  @override
  String get fuzz => 'Fuzz';

  @override
  String get failedToProcessFiles => 'ფაილები ვერ დამუშავდა.';

  @override
  String get chatWithIndicatedNameAlreadyExists =>
      'ამ სახელით ჩატი უკვე არსებობს';

  @override
  String get show => 'ჩვენება';

  @override
  String get open => 'გახსნა';

  @override
  String get dropFilesHere => 'ფაილები აქ გადმოიტანეთ';

  @override
  String get basicEncryption => 'მარტივი დაშიფვრა';

  @override
  String get customKey => 'საკუთარი გასაღები';

  @override
  String get enterYourSecretKey => 'შეიყვანეთ საიდუმლო გასაღები';

  @override
  String get textToEncryptDecrypt => 'ტექსტი დასაშიფრად ან გასაშიფრად';

  @override
  String get encryptText => 'ტექსტის დაშიფვრა';

  @override
  String get decryptText => 'ტექსტის გაშიფვრა';

  @override
  String get result => 'შედეგი';

  @override
  String get processSelectedFiles => 'არჩეული ფაილების დამუშავება';

  @override
  String get pleaseEnterAKey => 'შეიყვანეთ გასაღები.';

  @override
  String get pleaseSelectFilesToProcess => 'აირჩიეთ ფაილები.';

  @override
  String get anUnknownErrorOccurred => 'მოხდა უცნობი შეცდომა.';

  @override
  String get textAndKeyCannotBeEmpty => 'შეიყვანეთ ტექსტიც და გასაღებიც.';

  @override
  String get encryptionFailed => 'დაშიფვრა ვერ მოხერხდა.';

  @override
  String get encryptedTextAndKeyCannotBeEmpty =>
      'შეიყვანეთ დაშიფრული ტექსტიც და გასაღებიც.';

  @override
  String get decryptionFailedCheckYourKeyOrEncryptedText =>
      'გაშიფვრა ვერ მოხერხდა. შეამოწმეთ გასაღები ან დაშიფრული ტექსტი.';

  @override
  String get next => 'შემდეგი';

  @override
  String get settings => 'პარამეტრები';

  @override
  String get invalidLink => 'ეს ბმული არასწორია ან დაზიანებულია.';

  @override
  String get alreadyConnected => 'უკვე დაკავშირებული ხართ!';

  @override
  String get cantAcceptOwnInvitation => 'საკუთარ მოწვევას ვერ მიიღებთ.';

  @override
  String get chatNotFoundForAcceptance =>
      'ამ პასუხის ბმულისთვის ჩატი ვერ მოიძებნა.';

  @override
  String get failedToProcessAcceptance => 'პასუხის ბმული ვერ დამუშავდა.';

  @override
  String get shareFile => 'ფაილის გაზიარება';

  @override
  String get vaultUntitled => 'უსათაურო';

  @override
  String get vaultSave => 'შენახვა';

  @override
  String get vaultPasswords => 'პაროლები';

  @override
  String get vaultNotes => 'ჩანაწერები';

  @override
  String get vaultFiles => 'ფაილები';

  @override
  String get vaultFileLabel => 'ფაილი';

  @override
  String get vaultAll => 'ყველა';

  @override
  String get vaultPasswordLabel => 'პაროლი';

  @override
  String get vaultNoteLabel => 'ჩანაწერი';

  @override
  String get vaultPassword => 'სეიფის პაროლი';

  @override
  String get vaultIncorrectPassword => 'არასწორი პაროლი';

  @override
  String get vaultUnlock => 'გახსნა';

  @override
  String get vaultForgotPassword =>
      'დაგავიწყდათ პაროლი? მონაცემები დაშიფრულია და მათი აღდგენა შეუძლებელია.';

  @override
  String get menu => 'მენიუ';

  @override
  String get unknownError => 'უცნობი შეცდომა';

  @override
  String get keyStrengthWeak => 'სუსტი (ძალიან მოკლეა)';

  @override
  String get keyStrengthModerate => 'საშუალო (დაამატეთ ციფრები ან ასოები)';

  @override
  String get keyStrengthStrong => 'ძლიერი';

  @override
  String get keyStrengthGood => 'კარგი';

  @override
  String processingFile(Object fileName, Object progress) {
    return 'მუშავდება: $fileName -> $progress%';
  }

  @override
  String get processingFailed => 'დამუშავება ვერ მოხერხდა';

  @override
  String get chatUnlockTitle => 'Fuzzzy Ink-ის განბლოკვა';

  @override
  String get chatAuthIncorrectPassword => 'არასწორი პაროლი';

  @override
  String get chatAuthUnlock => 'განბლოკვა';

  @override
  String get chatAuthResecuringKeys => 'გასაღებების ხელახლა დაცვა…';

  @override
  String get benchmarkFileEncryption =>
      'ფაილების ჩაკეტვის სიჩქარის ტესტი (dev)';

  @override
  String get benchmarkFileEncryptionDescription =>
      'კეტავს და ხსნის 64 MiB სატესტო ფაილს და აჩვენებს სიჩქარეს MB/s-ში';

  @override
  String get benchmarkResult => 'ტესტის შედეგი';

  @override
  String benchmarkResultSummary(Object encrypt, Object decrypt, Object sizeMiB,
      Object encryptKdf, Object decryptKdf, Object device, Object buildMode) {
    return 'დაშიფვრა: $encrypt MB/s · გაშიფვრა: $decrypt MB/s ($sizeMiB MiB)\nArgon2id: $encryptKdf წმ / $decryptKdf წმ (MB/s-ში არ შედის)\n$device · $buildMode ბილდი';
  }

  @override
  String get close => 'დახურვა';

  @override
  String get chatAuthPasswordTooWeak =>
      'პაროლი ძალიან სუსტია. გამოიყენეთ უფრო გრძელი, ასოებით, ციფრებით და სიმბოლოებით.';

  @override
  String get biometricNotStrongEnough =>
      'ამ მოწყობილობის ბიომეტრია თქვენი პაროლის დასაცავად საკმარისად საიმედო არ არის. განბლოკეთ პაროლით.';

  @override
  String get biometricNotTurnedOn => 'სწრაფი განბლოკვა არ ჩაირთო.';

  @override
  String get vaultBiometricInvalidated =>
      'ბიომეტრიული მონაცემები შეიცვალა, ამიტომ სწრაფი განბლოკვა გამოირთო. ხელახლა ჩართეთ პარამეტრებში.';

  @override
  String get invitationAlreadyUsed => 'ეს მოწვევა უკვე გამოყენებულია.';

  @override
  String get invalidInvitation => 'ეს მოწვევა არასწორია ან დაზიანებულია.';

  @override
  String get invalidAcceptance => 'ეს პასუხი არასწორია ან დაზიანებულია.';

  @override
  String get wrongChatBlob => 'ეს კოდი სხვა ჩატს ეკუთვნის.';

  @override
  String get alreadyUnfuzzed =>
      'ეს შეტყობინება ამ მოწყობილობაზე უკვე გაიხსნა, ან მისი ერთჯერადი გასაღები აღარ ინახება.';

  @override
  String get corruptBlob => 'ეს სწორი ჩაკეტილი შეტყობინება არ არის.';

  @override
  String get safetyNumberTitle => 'უსაფრთხოების ციფრები';

  @override
  String safetyNumberVersion(int version) {
    return 'ვერსია $version. თუ მეორე ადამიანს სხვა ვერსია უჩანს ან საერთოდ არ უჩანს, შედარებამდე ორივე აპი განაახლეთ.';
  }

  @override
  String get wrongPasswordFile =>
      'არასწორი პაროლი — ეს ფაილი მისით არ იხსნება.';

  @override
  String get fileStillArriving =>
      'ეს ფაილი ჯერ კიდევ იწერება. მოიცადეთ, სანამ ბოლომდე მოვა, და სცადეთ ხელახლა.';

  @override
  String get fileCannotBeOpenedAskToResend =>
      'ეს ფაილი ვერ გაიხსნა. სთხოვეთ გამომგზავნს, ხელახლა გამოგიგზავნოთ.';

  @override
  String get basicsWrongPassword =>
      'არასწორი გასაღები — ეს ტექსტი მისით არ იხსნება.';

  @override
  String get forwardSecrecyTitle => 'იხსნება ერთხელ, ამ მოწყობილობაზე';

  @override
  String get forwardSecrecyNotice =>
      'ყოველი ჩაკეტილი შეტყობინება ერთხელ იხსნება და მხოლოდ ამ მოწყობილობაზე. ისტორია აპში რჩება — სარეზერვო ასლისთვის გააკეთეთ არქივის ექსპორტი. ახალი მოწყობილობა ძველ შეტყობინებებს ვეღარ წაიკითხავს.';

  @override
  String get aboutEncryptionTitle => 'დაშიფვრის შესახებ';

  @override
  String get aboutEncryptionHistoryTitle => 'თქვენი ისტორია ამ მოწყობილობაზე';

  @override
  String get aboutEncryptionBodyHistory =>
      'ყველა ტექსტი, რომელსაც ჩაკეტავთ ან გახსნით, აპში ინახება — ყოველი ადამიანისთვის ცალკე, ისეთი გასაღებით ჩაკეტილი, რომელიც მხოლოდ ამ მოწყობილობას აქვს. ყველა გასაღებს მთავარი პაროლი იცავს: მის ან აღდგენის გასაღების გარეშე აქ შენახულს ვერავინ გახსნის. ჩემი სეიფი მთავარი პაროლით ან საკუთარი პაროლით იხსნება; საკუთარ პაროლთან ერთად სეიფი ახალ გასაღებს და ახალ აღდგენის გასაღებს იღებს. ფაილებიც ასე ინახება: აპი მხოლოდ ჩაკეტილ ფაილს ინახავს და მხოლოდ იმ წამს ხსნის, როცა მას გახსნით, შეინახავთ ან გააზიარებთ. შენახული ან გაზიარებული ფაილი თქვენია — ის აპს ჩვეულებრივ ფაილად ტოვებს, ამიტომ დაიცავით, როგორც ნებისმიერი სხვა ფაილი. აპი თავისით იკეტება თქვენ მიერ არჩეული უმოქმედობის დროის შემდეგ და მაშინაც, როცა ცოტა ხანს ფონზეა. თუ თითის ანაბეჭდით ან სახით განბლოკვას ჩართავთ, პაროლი ამ მოწყობილობაზე ინახება, რომ თითმა ან სახემ შეძლოს მისი გახსნა.';

  @override
  String get aboutEncryptionWindowTitle => 'გახსენით თანმიმდევრობით';

  @override
  String get aboutEncryptionBodyWindow =>
      'აპი გამოტოვებული შეტყობინებების გასაღებებს ინახავს, მაგრამ არა უსასრულოდ. შეტყობინება, რომელიც ამ ჩატში ბოლოს წაკითხულს 63-ზე მეტით ჩამორჩება, ვეღარ გაიხსნება — აპი გეტყვით, რომ ძალიან ძველია — და ერთდროულად 40-ზე მეტი გამოტოვებული შეტყობინების გასაღები არ ინახება. საკუთარ გაგზავნილ შეტყობინებებს ვერც თქვენ გახსნით; სწორედ ამიტომ ინახავს აპი იმას, რაც გაგზავნეთ.';

  @override
  String get aboutEncryptionLinksTitle => 'შეტყობინების ბმულები';

  @override
  String get aboutEncryptionBodyLinks =>
      'ბმული მხოლოდ ჩაკეტილ შეტყობინებას შეიცავს, # ნიშნის შემდეგ — იმ ნაწილში, რომელსაც ბრაუზერი არცერთ სერვერს არ უგზავნის. ბმული თავისით არაფერს ხსნის: აპი გაჩვენებთ, ვისგანაა, და გახსნის მხოლოდ მაშინ, როცა „გახსნას“ დააჭერთ. პასუხის ბმული მხოლოდ მაშინ დაგაკავშირებთ, როცა „დაკავშირებას“ დააჭერთ.';

  @override
  String get aboutEncryptionErrorsTitle => 'რას ნიშნავს შეცდომები';

  @override
  String get aboutEncryptionBodyErrors =>
      '„უკვე გახსნილია“: ეს შეტყობინება ამ მოწყობილობაზე უკვე გაიხსნა, ან მისი ერთჯერადი გასაღები აღარ არსებობს — მის წინ 40-ზე მეტი შეტყობინება გამოტოვდა, ან ჩატი მას შემდეგ რამდენიმე წრით წავიდა წინ — ამიტომ აქ ვეღარასოდეს წაიკითხება. „სწორი ჩაკეტილი შეტყობინება არ არის“: ტექსტი დაზიანებულია, არასრულია ან სხვა ჩატს ეკუთვნის — აპი ამათ ერთმანეთისგან ვერ არჩევს. „ძალიან ძველია“: ის 63-ზე მეტით ჩამორჩება ამ ადამიანისგან ბოლოს გახსნილ შეტყობინებას. „არასწორი გასაღები“ / „არასწორი პაროლი“ (მარტივი დაშიფვრა): გასაღები ან პაროლი არ ემთხვევა, ან ტექსტი თუ ფაილი დაზიანებულია — აპი ამასაც ვერ არჩევს. თუ ფაილის მიღება დაწყების შემდეგ ჩაიშალა ან გაუქმდა, ფაილის ერთჯერადი გასაღები უკვე დახარჯულია: სთხოვეთ გამომგზავნს, ხელახლა გამოგიგზავნოთ.';

  @override
  String get aboutEncryptionBodySafetyNumber =>
      'ყოველ ჩატს 60 უსაფრთხოების ციფრი აქვს, რომლებიც ორივე მოწყობილობის საიდენტიფიკაციო გასაღებებიდან გამოითვლება. შეადარეთ ისინი მეორე ადამიანთან ზარით ან პირისპირ: თუ ციფრები ემთხვევა, დაკავშირებისას შუაში არავინ ჩამდგარა. „შემოწმებულია“ თქვენივე ჩანიშვნაა, რომ ეს გააკეთეთ — აპი ამას თქვენ მაგივრად ვერ შეამოწმებს.';

  @override
  String get aboutEncryptionUnderTheHoodTitle => 'ტექნიკური დეტალები';

  @override
  String get aboutEncryptionBodyUnderTheHood =>
      'შეტყობინებები იყენებს Olm double ratchet-ს (vodozemac, დამოუკიდებელი აუდიტით შემოწმებული) — ყოველ შეტყობინებას ახალი გასაღები აქვს, ამიტომაა ჩაკეტილი ტექსტი ერთჯერადი. ფაილები ნაწილ-ნაწილ იკეტება XChaCha20-Poly1305-ით; დაზიანებულ ფაილს აპი უარყოფს და დისკზე არაფერი რჩება. პაროლები Argon2id-ით მუშავდება. საიდუმლო გასაღებები აპის ნატიურ ბირთვშია და არსად იგზავნება. ვებ-ვერსია არ არსებობს: ბირთვი ნატიური კოდია.';

  @override
  String get alreadyReceived =>
      'ეს ფაილი ამ მოწყობილობაზე უკვე მიღებულია — მეორედ ვეღარ გაიხსნება.';

  @override
  String get fileTooOld =>
      'ეს ფაილი გასახსნელად ძალიან ძველია — მის შემდეგ ბევრი ახალი შეტყობინება უკვე გაიხსნა.';

  @override
  String get fileCorrupt =>
      'ეს სწორი ჩაკეტილი ფაილი არ არის — დაზიანებულია, არასრულია ან სხვა ჩატიდანაა.';

  @override
  String get fileCancelled =>
      'მიღება გაუქმდა — ეს ფაილი ამ მოწყობილობაზე ვეღარ გაიხსნება. სთხოვეთ გამომგზავნს, ხელახლა გამოგიგზავნოთ.';

  @override
  String get exportChatArchiveFailed => 'ჩატის არქივის ექსპორტი ვერ მოხერხდა.';

  @override
  String get exportChatArchiveNothingToExport =>
      'ამ ჩატში ექსპორტისთვის შეტყობინებები არ არის.';

  @override
  String get exportChatArchiveStoreLocked =>
      'ჯერ განბლოკეთ Fuzzzy Ink — სანამ ჩაკეტილია, ისტორია ვერ წაიკითხება.';

  @override
  String get export => 'ექსპორტი';

  @override
  String get couldNotOpenFile => 'ფაილი ვერ გაიხსნა.';

  @override
  String get privacyPolicy => 'კონფიდენციალურობის პოლიტიკა';

  @override
  String get termsOfUse => 'გამოყენების პირობები';

  @override
  String get support => 'მხარდაჭერა';

  @override
  String get dataDeletion => 'მონაცემების წაშლა';

  @override
  String get couldNotOpenLink => 'ბმული ვერ გაიხსნა.';

  @override
  String get biometricUnlockChats => 'ჩატების განსაბლოკად დაადასტურეთ ვინაობა';

  @override
  String get biometricUnlockVault =>
      'ჩემი სეიფის გასახსნელად დაადასტურეთ ვინაობა';

  @override
  String get biometricUnlockVaultTitle => 'ჩემი სეიფის გახსნა';

  @override
  String get biometricSavePassword => 'პაროლის შესანახად დაადასტურეთ ვინაობა';

  @override
  String get vaultMoveUnfinishedTitle => 'სეიფის გადატანა ვერ მოხერხდა';

  @override
  String get vaultMoveUnfinishedMessage =>
      'სეიფი აპის დაცულ ადგილას ვერ გადავიდა. არაფერი წაშლილა. ხელახლა საცდელად დახურეთ და თავიდან გახსენით აპი.';

  @override
  String get copyRefused => 'მხოლოდ ჩაკეტილი ტექსტი კოპირდება.';

  @override
  String get vaultCopyPassword => 'პაროლის კოპირება';

  @override
  String get saveFile => 'შენახვა';

  @override
  String get fileSaved => 'შენახულია.';

  @override
  String get couldNotSaveFile => 'ფაილი ვერ შეინახა.';

  @override
  String get unfuzzingFile => 'იხსნება…';

  @override
  String get fileNoPreview =>
      'ამ ფაილს აპი ვერ აჩვენებს. შეინახეთ და სხვა აპით გახსენით.';

  @override
  String get basicsFuzzedFilesTitle => 'აპში შენახული ჩაკეტილი ფაილები';

  @override
  String get masterPassword => 'მთავარი პაროლი';

  @override
  String get masterPasswordPreviousData =>
      'ეს ვერსია მთავარ პაროლს იყენებს. წინა სატესტო ვერსიის ადამიანები, ისტორია და ჩემი სეიფი მისით ვერ გაიხსნება, ამიტომ წაიშლება. შენახული ფაილები ადგილზე რჩება.';

  @override
  String get accessSetupInterrupted =>
      'წინა ჯერზე დაყენება არ დასრულდა. მაშინ ნანახი აღდგენის გასაღები აღარ იმუშავებს. ახალს მიიღებთ.';

  @override
  String get masterPasswordFailed => 'გასაღებები ვერ შეიქმნა. სცადეთ ხელახლა.';

  @override
  String get recoveryKeyTitle => 'აღდგენის გასაღები';

  @override
  String get recoveryKeySaveFailed => 'აღდგენის გასაღები ვერ შეინახა.';

  @override
  String recoveryKeyFileText(String key) {
    return 'Fuzzzy Ink-ის აღდგენის გასაღები\n\n$key\n\nთუ მთავარი პაროლი დაგავიწყდათ, ამ გასაღებით ახალს დააყენებთ. შეინახეთ უსაფრთხო ადგილას, მოწყობილობისგან შორს. პაროლის ან ამ გასაღების გარეშე თქვენს მონაცემებს ვერავინ დააბრუნებს — ვერც ჩვენ.\n';
  }

  @override
  String get recoveryKeyField => 'აღდგენის გასაღები';

  @override
  String get recoveryKeyTypo =>
      'აღდგენის გასაღებში შეცდომაა. შეამოწმეთ ყოველი ოთხნიშნა ჯგუფი.';

  @override
  String get recoveryKeyWrong => 'ეს აღდგენის გასაღები ამ აპს ვერ ხსნის.';

  @override
  String get chatUnlockErase => 'ყველაფრის წაშლა და თავიდან დაწყება';

  @override
  String get eraseTitle => 'წავშალოთ ყველაფერი?';

  @override
  String get eraseMessage =>
      'თქვენი ადამიანები, ისტორია, ჩემი სეიფი და პარამეტრები ამ მოწყობილობიდან სამუდამოდ წაიშლება. დაბრუნება შეუძლებელია. შენახული ფაილები ადგილზე რჩება.';

  @override
  String get eraseConfirm => 'ყველაფრის წაშლა';

  @override
  String get storageUnavailable =>
      'Fuzzzy Ink ვერ კითხულობს მოწყობილობის გასაღებების დაცულ მეხსიერებას, ამიტომ ჩაკეტილი რჩება. სცადეთ ხელახლა; თუ ისევ მოხდა, გადატვირთეთ მოწყობილობა.';

  @override
  String get tryAgain => 'ხელახლა ცდა';

  @override
  String get appLockNow => 'Fuzzzy Ink-ის ჩაკეტვა';

  @override
  String autoLockMinutes(int count) {
    return '$count წთ';
  }

  @override
  String get autoLockSaveFailed => 'პარამეტრი ვერ შეინახა.';

  @override
  String get vaultUsesOwnPassword => 'სეიფს საკუთარი პაროლი აქვს.';

  @override
  String get vaultUseOwnPassword => 'სეიფისთვის ცალკე პაროლი';

  @override
  String get vaultUseMasterPassword => 'სეიფის გახსნა მთავარი პაროლით';

  @override
  String get vaultOwnPasswordRecoveryNote =>
      'აღდგენის გასაღები ჩემს სეიფს მაინც გახსნის.';

  @override
  String get vaultRecoveryUseMasterPassword =>
      'ჩემი სეიფი მთავარი პაროლით გაიხსნას';

  @override
  String get vaultRecoverySubmit => 'ჩემი სეიფის გახსნა';

  @override
  String get tabHome => 'მთავარი';

  @override
  String get tabMySafe => 'ჩემი სეიფი';

  @override
  String get tabSettings => 'პარამეტრები';

  @override
  String get homeLockTitle => 'ჩაკეტვა';

  @override
  String get homeLockSubtitle => 'ერთი ადამიანისთვის';

  @override
  String get homeOpenTitle => 'გახსნა';

  @override
  String get homeOpenSubtitle => 'რაც მიიღეთ';

  @override
  String get homePeople => 'ადამიანები';

  @override
  String homePeopleCount(int count) {
    return 'ადამიანები · $count';
  }

  @override
  String get homeAdd => 'დამატება';

  @override
  String get homeAddPerson => 'ადამიანის დამატება';

  @override
  String get homeNoOneYet => 'ჯერ არავინაა';

  @override
  String get homeLoadError =>
      'ადამიანები ვერ ჩაიტვირთა. დახურეთ და ხელახლა გახსენით აპი.';

  @override
  String get stepYouSendInvite => 'აგზავნით მოწვევას';

  @override
  String get stepTheyReply => 'ის პასუხობს';

  @override
  String get stepInviteSent => 'მოწვევა გაიგზავნა';

  @override
  String stepNameReplies(String name) {
    return '$name პასუხობს';
  }

  @override
  String get stepLockForEachOther => 'კეტავთ და ხსნით';

  @override
  String stepsProgress(int step, int total) {
    return 'ნაბიჯი $step / $total';
  }

  @override
  String stepsProgressWithLabel(int step, int total, String label) {
    return 'ნაბიჯი $step / $total · $label';
  }

  @override
  String stepDone(String step) {
    return 'შესრულდა: $step';
  }

  @override
  String stepNext(String step) {
    return 'შემდეგი: $step';
  }

  @override
  String get addSendInvite => 'მოწვევის გაგზავნა';

  @override
  String get addYouStart => 'თქვენ იწყებთ';

  @override
  String get addGotInvite => 'მოწვევა მივიღე';

  @override
  String get addTheyStarted => 'მან დაიწყო';

  @override
  String get chipWaitingForReply => 'პასუხს ველოდებით';

  @override
  String get chipChecked => 'შემოწმებულია';

  @override
  String get chipNotChecked => 'შეუმოწმებელი';

  @override
  String get personRowWaitingLine => 'მერე ერთმანეთისთვის ჩაკეტვას შეძლებთ';

  @override
  String waitNoteReply(String name) {
    return 'როცა $name გიპასუხებთ, ერთმანეთისთვის ჩაკეტვას შეძლებთ.';
  }

  @override
  String get waitNoteAnyWay =>
      'მოწვევა ნებისმიერი გზით გაგზავნეთ, თუნდაც საჯაროდ. ის მაინც უსაფრთხოა.';

  @override
  String get linkWhy => 'რატომ?';

  @override
  String get linkHow => 'როგორ?';

  @override
  String get linkMore => 'მეტი';

  @override
  String get linkOpensExplanation => 'განმარტებას ხსნის';

  @override
  String get gotIt => 'გასაგებია';

  @override
  String get infoNoResetTitle => 'რატომ არ აღდგება პაროლი?';

  @override
  String get infoNoResetLine1 => 'თქვენი პაროლი ამ ტელეფონს არ ტოვებს.';

  @override
  String get infoNoResetLine2 =>
      'ჩვენ მას ვერ ვხედავთ, ამიტომ ვერავინ აღადგენს.';

  @override
  String get infoNoResetLine3 => 'ერთადერთი სათადარიგო გზა აღდგენის გასაღებია.';

  @override
  String get infoRecoveryKeyTitle => 'თქვენი აღდგენის გასაღები';

  @override
  String get infoRecoveryKeyLine1 =>
      'სათადარიგო გასაღები, თუ პაროლი დაგავიწყდათ.';

  @override
  String get infoRecoveryKeyLine2 => 'ის ხსნის Fuzzzy Ink-ს და ჩემს სეიფსაც.';

  @override
  String get infoRecoveryKeyLine3 =>
      'ამობეჭდეთ ან შეინახეთ სადმე, ამ ტელეფონის გარდა. ვისაც ის და თქვენი ტელეფონი ექნება, ყველაფერს გახსნის.';

  @override
  String get infoOpensOnceTitle => 'რატომ მხოლოდ ერთხელ?';

  @override
  String get infoOpensOnceLine1 => 'ყოველ ჩაკეტილს თავისი გასაღები აქვს.';

  @override
  String get infoOpensOnceLine2 =>
      'გახსნისას გასაღები იხარჯება, ნებისმიერ ტელეფონზე.';

  @override
  String get infoOpensOnceLine3 => 'ასლი ისტორიაში რჩება, ჩაკეტილი.';

  @override
  String get infoSafeAnywhereTitle => 'ყველგან უსაფრთხოა';

  @override
  String get infoSafeAnywhereLine1 => 'მოწვევა ვერაფერს ხსნის.';

  @override
  String get infoSafeAnywhereLine2 => 'დაგაკავშირებთ მხოლოდ მისი პასუხი.';

  @override
  String get infoSafeAnywhereLine3 =>
      'მერე ციფრებს ერთად შეამოწმებთ, რომ დარწმუნდეთ, ნამდვილად ის არის.';

  @override
  String get infoCheckNumbersTitle => 'რატომ ვამოწმებთ ციფრებს?';

  @override
  String get infoCheckNumbersLine1 =>
      'თქვენს მოწვევას ნებისმიერი უპასუხებდა, ვინც ის ნახა.';

  @override
  String get infoCheckNumbersLine2 =>
      'ორივე ტელეფონზე ციფრები ერთნაირია — შუაში არავინ ჩამდგარა.';

  @override
  String get infoFilesTitle => 'სად მიდის ფაილები?';

  @override
  String get infoFilesLine1 => 'Fuzzzy Ink მხოლოდ ჩაკეტილ ასლს ინახავს.';

  @override
  String get infoFilesLine2 =>
      '„გახსნა“ ფაილს აქვე გაჩვენებთ. არაფერი ინახება.';

  @override
  String get infoFilesLine3 =>
      '„შენახვა“ ჩვეულებრივ ასლს მოგცემთ. იქიდან მისი დაცვა თქვენზეა.';

  @override
  String get infoNoCopyingTitle => 'რატომ არ კოპირდება?';

  @override
  String get infoNoCopyingLine1 => 'რასაც ხსნით, Fuzzzy Ink-ში რჩება.';

  @override
  String get infoNoCopyingLine2 =>
      'მხოლოდ ჩაკეტილი ტექსტი კოპირდება. ის ყველგან უსაფრთხოა.';

  @override
  String get infoPasswordLockingTitle => 'პაროლით ჩაკეტვა';

  @override
  String get infoPasswordLockingLine1 => 'ვინც პაროლი იცის, გახსნის.';

  @override
  String get infoPasswordLockingLine2 =>
      'პაროლი ზეპირად უთხარით. ჩაკეტილთან ერთად არასდროს გაუგზავნოთ.';

  @override
  String get infoSafePasswordTitle => 'ჩემი სეიფის საკუთარი პაროლი';

  @override
  String get infoSafePasswordLine1 => 'კიდევ ერთი დასამახსოვრებელი პაროლი.';

  @override
  String get infoSafePasswordLine2 =>
      'დაგავიწყდათ? აღდგენის გასაღები ჩემს სეიფსაც ხსნის.';

  @override
  String get tagNoCopyNoScreenshots =>
      'კოპირება და ეკრანის ანაბეჭდი გამორთულია';

  @override
  String get tagNoCopy => 'კოპირება გამორთულია';

  @override
  String get lockWhoTitle => 'ვისთვისაა?';

  @override
  String get lockWithPassword => 'პაროლით ჩაკეტვა';

  @override
  String get lockNoInviteNeeded => 'მოწვევა არ სჭირდება';

  @override
  String get lockAddPersonFirst => 'ჯერ ადამიანი დაამატეთ';

  @override
  String get orDivider => 'ან';

  @override
  String get openWhatYouGot => 'გახსენით, რაც მიიღეთ';

  @override
  String get openPasteIt => 'ჩასმა';

  @override
  String get openPasteItHint => 'ჩაკეტილი ტექსტი, მოწვევა ან პასუხი';

  @override
  String get openLinksTip =>
      'ბმულები და QR კოდები აქ მოდის. არაფერი გაიხსნება, სანამ „გახსნას“ არ დააჭერთ.';

  @override
  String get openNothingToPaste =>
      'ჩასასმელი არაფერია. ჯერ ჩაკეტილი ტექსტი დააკოპირეთ.';

  @override
  String get openLockedWithPassword => 'პაროლით ჩაკეტილი';

  @override
  String get lockStepWho => 'ვისთვის';

  @override
  String get lockStepWhat => 'რა';

  @override
  String lockForName(String name) {
    return 'ჩაკეტვა: $name';
  }

  @override
  String get lockKindMessage => 'შეტყობინება';

  @override
  String get lockKindFile => 'ფაილი';

  @override
  String get lockWriteMessageHint => 'დაწერეთ შეტყობინება…';

  @override
  String lockOnlyNameOnce(String name) {
    return 'მხოლოდ $name გახსნის, ერთხელ.';
  }

  @override
  String get lockChooseFile => 'ფაილის არჩევა';

  @override
  String get lockDropHint => 'ან კომპიუტერზე აქ გადმოიტანეთ';

  @override
  String get lockChangeFile => 'შეცვლა';

  @override
  String get lockPasswordLabel => 'ამის პაროლი';

  @override
  String get lockSayPassword => 'პაროლი ზეპირად უთხარით. ნუ გაუგზავნით.';

  @override
  String get lockAction => 'ჩაკეტვა';

  @override
  String get lockWriteSomethingFirst => 'ჯერ რამე დაწერეთ.';

  @override
  String get lockChooseFileFirst => 'ჯერ ფაილი აირჩიეთ.';

  @override
  String get lockPasswordNotGood => 'პაროლი მინიმუმ „კარგი“ უნდა იყოს.';

  @override
  String get lockFailed => 'ჩაკეტვა ვერ მოხერხდა. სცადეთ ხელახლა.';

  @override
  String get lockStoppedNothingKept => 'შეჩერდა. არაფერი შენახულა.';

  @override
  String get workingLocking => 'იკეტება';

  @override
  String get workingOpening => 'იხსნება';

  @override
  String get workingStarting => 'იწყება…';

  @override
  String get workingPause => 'პაუზა';

  @override
  String get workingGoOn => 'გაგრძელება';

  @override
  String get workingPaused => 'შეჩერებულია';

  @override
  String lockedForName(String name) {
    return 'ჩაიკეტა. გახსნის მხოლოდ $name';
  }

  @override
  String get lockedWithPassword => 'ჩაიკეტა პაროლით';

  @override
  String get lockedNowSendIt => 'ახლა გაუგზავნეთ.';

  @override
  String get lockedSentToShareMenu => 'გადაეცა გაზიარების მენიუს.';

  @override
  String get lockedShareAgain => 'ხელახლა გაზიარება';

  @override
  String get lockedCopyText => 'ჩაკეტილი ტექსტის კოპირება';

  @override
  String get lockedSaveFile => 'ჩაკეტილი ფაილის შენახვა';

  @override
  String get flowDone => 'მზადაა';

  @override
  String get openChooseFile => 'ფაილის არჩევა';

  @override
  String get openChooseFileHint => '.fuzz ფაილი';

  @override
  String get openReading => 'იკითხება…';

  @override
  String openLinkTitle(String name) {
    return '$name გიგზავნით შეტყობინებას. გავხსნათ?';
  }

  @override
  String openArrivedFileTitle(String name) {
    return '$name გიგზავნით ფაილს. გავხსნათ?';
  }

  @override
  String get openLinkLine =>
      'ერთხელ გაიხსნება და მერე თქვენს საერთო ისტორიაში დარჩება.';

  @override
  String get openLinkOpen => 'გახსნა';

  @override
  String get openLinkNotNow => 'ახლა არა';

  @override
  String replyLinkTitle(String name) {
    return 'დავუკავშირდეთ: $name?';
  }

  @override
  String replyLinkLine(String name) {
    return 'დაუკავშირდით მხოლოდ მაშინ, თუ ამ პასუხის გამომგზავნი ნამდვილად $name არის.';
  }

  @override
  String get replyLinkConnect => 'დაკავშირება';

  @override
  String get linkWaitsForSafe =>
      'ბმული გელოდებათ. გაიხსნება, როცა ამ ჩანაწერს დახურავთ.';

  @override
  String get fileWaitsForSafe =>
      'ფაილი გელოდებათ. გაიხსნება, როცა ამ ჩანაწერს დახურავთ.';

  @override
  String openedFromName(String name) {
    return 'გამომგზავნი: $name';
  }

  @override
  String openedKeptInHistory(String name) {
    return 'ახლახან · შენახულია ისტორიაში: $name';
  }

  @override
  String get openedWithPassword => 'გაიხსნა პაროლით';

  @override
  String get openedNotKept => 'ახლახან · არ ინახება';

  @override
  String openedInHistoryNow(String name) {
    return 'შეინახა ისტორიაში: $name.';
  }

  @override
  String get openedSaveTip =>
      '„შენახვა“ ჩვეულებრივ ასლს მოგცემთ. მერე ის თქვენია.';

  @override
  String get openPasswordTitle => 'რა პაროლია?';

  @override
  String get openPasswordLabel => 'პაროლი';

  @override
  String get openPasswordWrong =>
      'ამით არ იხსნება. შეამოწმეთ და სცადეთ ხელახლა.';

  @override
  String get openErrorAlreadyTitle => 'უკვე გახსნილია';

  @override
  String openErrorAlreadyLine(String name) {
    return 'ჩაკეტილი ყველაფერი ერთხელ იხსნება. ის უკვე ისტორიაშია: $name.';
  }

  @override
  String get openErrorNotYoursTitle => 'უცნობი ადამიანისგანაა';

  @override
  String get openErrorNotYoursLine => 'ჯერ მოწვევა სთხოვეთ.';

  @override
  String get openErrorDamagedTitle => 'ეს ვერ იხსნება';

  @override
  String get openErrorDamagedLine =>
      'შეიძლება, ბოლომდე არ მოსულა ან სხვისთვისაა. სთხოვეთ, ხელახლა გამოგიგზავნოთ.';

  @override
  String get openErrorOldTitle => 'გასახსნელად ძალიან ძველია';

  @override
  String openErrorOldLine(String name) {
    return 'სთხოვეთ, ხელახლა ჩაკეტოს ($name).';
  }

  @override
  String get openErrorNewerTitle => 'საჭიროა Fuzzzy Ink-ის ახალი ვერსია';

  @override
  String get openErrorNewerLine => 'განაახლეთ აპი და სცადეთ ხელახლა.';

  @override
  String get openErrorOwnTitle => 'ეს თქვენი მოწვევაა';

  @override
  String get openErrorOwnLine => 'გაუგზავნეთ მეორე ადამიანს.';

  @override
  String get openErrorConnectedTitle => 'უკვე დაკავშირებულია';

  @override
  String openErrorConnectedLine(String name) {
    return 'თქვენ და $name უკვე დაკავშირებული ხართ.';
  }

  @override
  String get openErrorNotFuzzzyTitle => 'ეს Fuzzzy Ink-ით არ არის ჩაკეტილი';

  @override
  String get openErrorNotFuzzzyLine =>
      'გახსენით ჩაკეტილი ტექსტი, მოწვევა ან პასუხი.';

  @override
  String get openErrorArrivingTitle => 'ჯერ კიდევ მოდის';

  @override
  String get openErrorArrivingLine =>
      'მოიცადეთ, სანამ ფაილი ბოლომდე მოვა, და სცადეთ ხელახლა.';

  @override
  String get openErrorResendTitle => 'ფაილი ვერ გაიხსნა';

  @override
  String get openErrorResendLine =>
      'ამ ტელეფონზე ის ვეღარ გაიხსნება. სთხოვეთ, ხელახლა გამოგიგზავნოთ.';

  @override
  String openErrorGoToName(String name) {
    return 'გადასვლა: $name';
  }

  @override
  String get openErrorOk => 'კარგი';

  @override
  String get openFailed => 'გახსნა ვერ მოხერხდა. სცადეთ ხელახლა.';

  @override
  String get shareTitleInvite => 'მოწვევის გაზიარება';

  @override
  String get shareTitleReply => 'პასუხის გაზიარება';

  @override
  String get shareTitleMessage => 'ჩაკეტილი შეტყობინების გაზიარება';

  @override
  String get shareTitleFile => 'ჩაკეტილი ფაილის გაზიარება';

  @override
  String get shareLineInvite => 'ნებისმიერი გზით, თუნდაც საჯაროდ.';

  @override
  String get shareLineReply => 'როგორც გინდათ.';

  @override
  String shareLineForName(String name) {
    return 'გახსნის მხოლოდ $name.';
  }

  @override
  String get shareLinePassword => 'პაროლი დასჭირდება.';

  @override
  String get shareSendLink => 'ბმულის გაგზავნა';

  @override
  String get shareSendLinkHint => 'აპში იხსნება';

  @override
  String get shareShowQr => 'QR კოდის ჩვენება';

  @override
  String get shareShowQrHint => 'კამერით წაიკითხავს';

  @override
  String get shareSendFile => 'ფაილად გაგზავნა';

  @override
  String get shareSendFileHint => 'პატარა ფაილი';

  @override
  String get shareCopyText => 'ტექსტად კოპირება';

  @override
  String get shareCopyTextHint => 'ყველგან ჩაკეტილი რჩება';

  @override
  String get shareTooBig => 'ძალიან დიდია. ფაილად გაგზავნეთ.';

  @override
  String get shareCopiedStaysLocked => 'დაკოპირდა. ჩაკეტილი რჩება.';

  @override
  String get qrLabelInvite => 'თქვენი მოწვევა';

  @override
  String get qrLabelReply => 'თქვენი პასუხი';

  @override
  String get qrLabelMessage => 'ჩაკეტილი შეტყობინება';

  @override
  String qrLetNameScan(String name) {
    return 'აჩვენეთ ეს კოდი — $name კამერით წაიკითხავს.';
  }

  @override
  String get qrLetThemScan => 'აჩვენეთ ეს კოდი — კამერით წაიკითხავს.';

  @override
  String get qrSafeToShowAnyone =>
      'ნებისმიერს შეგიძლიათ აჩვენოთ. დაგაკავშირებთ მხოლოდ მისი პასუხი.';

  @override
  String get qrOnlyRightPerson => 'აჩვენეთ მხოლოდ სწორ ადამიანს.';

  @override
  String get historyYouLockedMessage => 'შეტყობინება ჩაიკეტა';

  @override
  String get historyYouOpenedMessage => 'შეტყობინება გაიხსნა';

  @override
  String historyYouLockedFile(String file) {
    return 'ჩაიკეტა: $file';
  }

  @override
  String historyYouOpenedFile(String file) {
    return 'გაიხსნა: $file';
  }

  @override
  String get historyTapToRead => 'შეეხეთ წასაკითხად';

  @override
  String get historyTapToSee => 'შეეხეთ სანახავად';

  @override
  String get fileCardLocked => 'ჩაკეტილია';

  @override
  String get fileCardKeptInSafe => 'ჩაკეტილი ინახება ჩემს სეიფში';

  @override
  String get lockedPreviewLabel => 'ჩაკეტილი ვერსია · უსაფრთხოა გასაგზავნად';

  @override
  String get confirmCopied => 'დაკოპირდა';

  @override
  String get confirmHandedOver => 'გადაეცა';

  @override
  String get safetyGridLabel => 'უსაფრთხოების ციფრები';

  @override
  String lockoutWaitLeft(String time) {
    return 'მოიცადეთ $time';
  }

  @override
  String get settingsLookAndLanguage => 'იერსახე და ენა';

  @override
  String get settingsLook => 'იერსახე';

  @override
  String get settingsLanguage => 'ენა';

  @override
  String get lookLikeMyPhone => 'როგორც ტელეფონში';

  @override
  String get lookLight => 'ღია';

  @override
  String get lookDark => 'მუქი';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGeorgian => 'ქართული';

  @override
  String get fuzzzyCast => 'Fuzzzy Cast';

  @override
  String get fuzzzyCastLine => 'Fuzzz რეაგირებს, როცა კეტავთ ან ხსნით.';

  @override
  String get fuzzzyCastOn => 'Fuzzzy Cast ჩართულია.';

  @override
  String get softSounds => 'რბილი ხმები';

  @override
  String get safeLockedTitle => 'ჩემი სეიფი ჩაკეტილია';

  @override
  String get safeLockButton => 'ჩემი სეიფის ჩაკეტვა';

  @override
  String get safeOpensWithMaster => 'იხსნება მთავარი პაროლით.';

  @override
  String get safeOpensWithOwn => 'იხსნება სეიფის პაროლით.';

  @override
  String safeOpenWithFingerprint(String kind) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'faceId': 'Face ID-ით გახსნა',
        'touchId': 'Touch ID-ით გახსნა',
        'fingerprint': 'თითის ანაბეჭდით გახსნა',
        'face': 'სახით გახსნა',
        'other': 'თითის ანაბეჭდით ან სახით გახსნა',
      },
    );
    return '$_temp0';
  }

  @override
  String get safeUseMasterPassword => 'მთავარი პაროლის გამოყენება';

  @override
  String get safeUseSafePassword => 'სეიფის პაროლის გამოყენება';

  @override
  String get safePasswordField => 'სეიფის პაროლი';

  @override
  String get safeOpenButton => 'ჩემი სეიფის გახსნა';

  @override
  String get safeUseRecoveryKey => 'აღდგენის გასაღების გამოყენება';

  @override
  String get safeWrongPassword => 'არასწორია. სცადეთ ხელახლა.';

  @override
  String get safeTooManyTries => 'ძალიან ბევრი ცდა.';

  @override
  String get safeCouldNotOpen => 'ჩემი სეიფი ვერ გაიხსნა. სცადეთ ხელახლა.';

  @override
  String get safeRecoveryTitle => 'შეიყვანეთ აღდგენის გასაღები';

  @override
  String get safeRecoveryLine => 'ჰარებსა და დიდ ასოებს მნიშვნელობა არ აქვს.';

  @override
  String get safeRecoveryNoKey =>
      'გასაღები არ გაქვთ? მაშინ ამას ვერაფერი გახსნის.';

  @override
  String get safeRecoveryNewPassword => 'სეიფის ახალი პაროლი';

  @override
  String get safeSearch => 'ძებნა';

  @override
  String get safeAllGroups => 'ყველა ჯგუფი';

  @override
  String get safeNewGroup => 'ახალი ჯგუფი';

  @override
  String get safeEmptyTitle => 'აქ ჯერ არაფერია';

  @override
  String get safeEmptyLine => 'დააჭირეთ „დამატებას“.';

  @override
  String get safeNothingFound => 'ვერაფერი მოიძებნა';

  @override
  String get safeTryAnotherWord => 'სცადეთ სხვა სიტყვა.';

  @override
  String get safeLoadError =>
      'ჩემი სეიფი ვერ ჩაიტვირთა. ჩაკეტეთ და ხელახლა გახსენით.';

  @override
  String safeAutoLockTip(int minutes) {
    return '$minutes წუთის უმოქმედობის შემდეგ თავისით იკეტება';
  }

  @override
  String get safeAdd => 'დამატება';

  @override
  String get safeAddTitle => 'ჩემს სეიფში დამატება';

  @override
  String get safeUsername => 'მომხმარებლის სახელი ან ელფოსტა';

  @override
  String get safeWebsite => 'ვებსაიტი';

  @override
  String get safeNotes => 'შენიშვნები';

  @override
  String get safeShowPassword => 'პაროლის ჩვენება';

  @override
  String get safeHidePassword => 'პაროლის დამალვა';

  @override
  String safeCopiedClearsIn(int seconds) {
    return 'დაკოპირდა · წაიშლება $seconds წამში';
  }

  @override
  String safeCopyRule(int seconds) {
    return 'დაკოპირებული პაროლი $seconds წამში იშლება.';
  }

  @override
  String get safeCleared => 'წაიშალა.';

  @override
  String get safeCopyOff => 'კოპირება პარამეტრებში გამორთულია.';

  @override
  String get safeGroup => 'ჯგუფი';

  @override
  String get safeNoGroup => 'ჯგუფის გარეშე';

  @override
  String get safeMove => 'გადატანა';

  @override
  String get safeEdit => 'რედაქტირება';

  @override
  String safeMoreFor(String title) {
    return 'მეტი: $title';
  }

  @override
  String get safeSaveTip =>
      '„შენახვა“ ჩვეულებრივ ასლს მოგცემთ. მერე ის თქვენია.';

  @override
  String get safeMoveToGroup => 'ჯგუფში გადატანა';

  @override
  String safeDeleteTitle(String title) {
    return 'წავშალოთ „$title“?';
  }

  @override
  String get safeDeleteLine =>
      'ის ჩემი სეიფიდან სამუდამოდ წაიშლება. დაბრუნება შეუძლებელია.';

  @override
  String get safeDeleted => 'წაიშალა ჩემი სეიფიდან.';

  @override
  String safeMovedTo(String group) {
    return 'გადავიდა ჯგუფში: $group.';
  }

  @override
  String get safeMovedOut => 'ჯგუფიდან ამოღებულია.';

  @override
  String get safeSaved => 'შეინახა ჩემს სეიფში.';

  @override
  String get safeItemLoadFailed => 'ვერ გაიხსნა. სცადეთ ხელახლა.';

  @override
  String get safeSaveFailed => 'ვერ შეინახა. სცადეთ ხელახლა.';

  @override
  String get safeGroupName => 'ჯგუფის სახელი';

  @override
  String get safeGroupHint => 'მაგ. ოჯახი';

  @override
  String get safeAddGroup => 'ჯგუფის დამატება';

  @override
  String get safeNewPasswordTitle => 'ახალი პაროლი';

  @override
  String get safeNewNoteTitle => 'ახალი ჩანაწერი';

  @override
  String get safeNewFileTitle => 'ახალი ფაილი';

  @override
  String get safeTitle => 'სათაური';

  @override
  String get safeTitleHintPassword => 'მაგ. ბანკის აპი';

  @override
  String get safeTitleHintNote => 'მაგ. პასპორტის ნომერი';

  @override
  String get safeTitleHintFile => 'მაგ. სახლის დაზღვევა';

  @override
  String get safeOptional => 'არასავალდებულო';

  @override
  String get safeNoteHint => 'ყველაფერი, რაც დაცული უნდა იყოს';

  @override
  String get safeChooseFile => 'ფაილის არჩევა';

  @override
  String get safeOriginalStays => 'ორიგინალი თავის ადგილზე რჩება.';

  @override
  String get safeChangeFile => 'შეცვლა';

  @override
  String get safeChooseFileFirst => 'ჯერ ფაილი აირჩიეთ.';

  @override
  String get accessWelcomeLine => 'ჩაკეტეთ. გახსნის მხოლოდ ის.';

  @override
  String get accessWelcomeTag => 'ანგარიშის გარეშე · ინტერნეტის გარეშე';

  @override
  String get accessStart => 'დაწყება';

  @override
  String get accessHowItWorks => 'როგორ მუშაობს';

  @override
  String get accessHowAddPerson => 'ადამიანის დამატება';

  @override
  String get accessHowLockForThem => 'ჩაკეტეთ მისთვის';

  @override
  String get accessHowTheyOpenOnce => 'ის ერთხელ ხსნის';

  @override
  String get accessWhyOnce => 'რატომ ერთხელ?';

  @override
  String get accessHowTip =>
      'ყველაფერს ერთი მთავარი პაროლი იცავს. ახლა მას შექმნით.';

  @override
  String get accessContinue => 'გაგრძელება';

  @override
  String get accessStepPassword => 'პაროლი';

  @override
  String get accessMakeMasterPassword => 'შექმენით მთავარი პაროლი';

  @override
  String get accessTypeItAgain => 'კიდევ ერთხელ აკრიფეთ';

  @override
  String get accessNoResetBold => 'აღდგენა შეუძლებელია.';

  @override
  String get accessNoResetLine =>
      'თუ მასაც დაკარგავთ და აღდგენის გასაღებსაც, ყველაფერი დაიკარგება.';

  @override
  String get accessUnderstandNoAccess =>
      'გასაგებია: პაროლისა და გასაღების გარეშე წვდომა აღარ მექნება.';

  @override
  String get accessPasswordsDontMatch => 'ჯერ არ ემთხვევა.';

  @override
  String get accessStrengthWeak => 'სუსტი';

  @override
  String get accessStrengthFair => 'საშუალო';

  @override
  String get accessStrengthGood => 'კარგი';

  @override
  String get accessStrengthStrong => 'ძლიერი';

  @override
  String get accessStrengthHintEmpty => 'რჩევა: რამდენიმე შემთხვევითი სიტყვა.';

  @override
  String get accessStrengthHintWeak => 'უფრო გრძელი უნდა იყოს.';

  @override
  String get accessStrengthHintFair => 'დაამატეთ კიდევ რამდენიმე სიტყვა.';

  @override
  String get accessStrengthHintGood => 'ძნელად გამოსაცნობია.';

  @override
  String get accessStrengthHintStrong => 'ძალიან ძნელად გამოსაცნობია.';

  @override
  String accessStrengthLabel(String level) {
    return 'პაროლის სიძლიერე: $level';
  }

  @override
  String get accessShowPassword => 'პაროლის ჩვენება';

  @override
  String get accessHidePassword => 'პაროლის დამალვა';

  @override
  String get accessYourRecoveryKey => 'თქვენი აღდგენის გასაღები';

  @override
  String get accessRecoverySpare =>
      'სათადარიგო გასაღები, თუ პაროლი დაგავიწყდათ.';

  @override
  String get accessPrint => 'ამობეჭდვა';

  @override
  String get accessSaveAsFile => 'ფაილად შენახვა';

  @override
  String get accessSaved => 'შენახულია';

  @override
  String get accessKeepOffPhone =>
      'ამ ტელეფონზე ნუ შეინახავთ. ვისაც ის ექნება, ყველაფერს გახსნის.';

  @override
  String get accessKeptItSafe => 'უსაფრთხოდ შევინახე';

  @override
  String get accessSkipForNow => 'ახლა გამოტოვება';

  @override
  String get accessSkipKeyTitle => 'გამოვტოვოთ აღდგენის გასაღები?';

  @override
  String get accessSkipKeyMessage =>
      'თუ მის გარეშე პაროლი დაგავიწყდებათ, ყველაფერი დაიკარგება. მოგვიანებით შეგიძლიათ პარამეტრებში შექმნათ.';

  @override
  String get accessSkipKeyKeep => 'ახლავე შევინახავ';

  @override
  String get accessSkipKeyAnyway => 'მაინც გამოვტოვებ';

  @override
  String get accessPrintPreview => 'ბეჭდვის წინასწარი ხედი';

  @override
  String get accessPrintSheetTitle => 'Fuzzzy Ink · აღდგენის გასაღები';

  @override
  String get accessPrintLine1 =>
      'თუ პაროლი დაგავიწყდათ, ხსნის Fuzzzy Ink-ს და ჩემს სეიფს.';

  @override
  String get accessPrintLine2 =>
      'ვისაც ეს გასაღები და თქვენი ტელეფონი ექნება, ყველაფერს გახსნის. ტელეფონისგან შორს შეინახეთ.';

  @override
  String get accessPrintLine3 =>
      'თუ პაროლსაც დაკარგავთ და ამ გასაღებსაც, ვერაფერს აღადგენთ.';

  @override
  String accessPrintMade(String date) {
    return 'შექმნილია: $date. ახალი გასაღები (პარამეტრებიდან) ამას გააუქმებს.';
  }

  @override
  String get accessPrintHint =>
      'გაიხსნება გაზიარების მენიუ. იქ აირჩიეთ ბეჭდვა — არა ფოტოებში შენახვა ან ღრუბლოვანი აპი.';

  @override
  String get accessPrintHintIos =>
      'აირჩიეთ პრინტერი. გასაღები პირდაპირ მას მიეწოდება და ასლი არსად შეინახება.';

  @override
  String get accessPrintHintMac =>
      'გაიხსნება ბეჭდვის ფანჯარა. აირჩიეთ პრინტერი და არა PDF-ად შენახვა.';

  @override
  String get accessPrintFailed =>
      'ბეჭდვის ფურცელი ვერ შეიქმნა. სცადეთ ფაილად შენახვა.';

  @override
  String get accessStepQuickUnlock => 'სწრაფი განბლოკვა';

  @override
  String accessBioTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'faceId': 'განბლოკვა Face ID-ით?',
        'touchId': 'განბლოკვა Touch ID-ით?',
        'fingerprint': 'განბლოკვა თითის ანაბეჭდით?',
        'face': 'განბლოკვა სახით?',
        'other': 'განბლოკვა თითის ანაბეჭდით ან სახით?',
      },
    );
    return '$_temp0';
  }

  @override
  String get accessBioLine => 'პაროლიც ყოველთვის იმუშავებს.';

  @override
  String get accessBioTip => '5 წუთის უმოქმედობის შემდეგ თავისით იკეტება';

  @override
  String accessUseBio(String kind) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'faceId': 'Face ID-ის გამოყენება',
        'touchId': 'Touch ID-ის გამოყენება',
        'fingerprint': 'თითის ანაბეჭდის გამოყენება',
        'face': 'სახის გამოყენება',
        'other': 'თითის ანაბეჭდის ან სახის გამოყენება',
      },
    );
    return '$_temp0';
  }

  @override
  String get accessNotNow => 'ახლა არა';

  @override
  String get accessReadyTitle => 'მზად ხართ';

  @override
  String get accessAddFirstPerson => 'პირველი ადამიანის დამატება';

  @override
  String get accessLookAround => 'ჯერ მიმოვიხედავ';

  @override
  String get accessLockedTitle => 'Fuzzzy Ink ჩაკეტილია';

  @override
  String get accessWrongPassword => 'არასწორია. სცადეთ ხელახლა.';

  @override
  String get accessTooManyTries => 'ძალიან ბევრი ცდა.';

  @override
  String get accessForgotPassword => 'დაგავიწყდათ პაროლი?';

  @override
  String get accessLinkWaiting => 'ბმული გელოდებათ. გასახსნელად განბლოკეთ.';

  @override
  String get accessFileWaiting => 'ფაილი გელოდებათ. გასახსნელად განბლოკეთ.';

  @override
  String accessBioChanged(String kind) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'faceId':
            'Face ID შეიცვალა, ამიტომ სწრაფი განბლოკვა გამოირთო. ხელახლა ჩართეთ პარამეტრებში.',
        'touchId':
            'Touch ID შეიცვალა, ამიტომ სწრაფი განბლოკვა გამოირთო. ხელახლა ჩართეთ პარამეტრებში.',
        'fingerprint':
            'თითის ანაბეჭდები შეიცვალა, ამიტომ სწრაფი განბლოკვა გამოირთო. ხელახლა ჩართეთ პარამეტრებში.',
        'face':
            'სახის მონაცემები შეიცვალა, ამიტომ სწრაფი განბლოკვა გამოირთო. ხელახლა ჩართეთ პარამეტრებში.',
        'other':
            'თითის ანაბეჭდი ან სახე შეიცვალა, ამიტომ სწრაფი განბლოკვა გამოირთო. ხელახლა ჩართეთ პარამეტრებში.',
      },
    );
    return '$_temp0';
  }

  @override
  String get accessBioReset =>
      'განახლებამ სწრაფი განბლოკვა უსაფრთხოებისთვის გამორთო. ხელახლა ჩართეთ პარამეტრებში.';

  @override
  String get accessRecoveryKeyHeader => 'აღდგენის გასაღები';

  @override
  String get accessTypeRecoveryKey => 'შეიყვანეთ აღდგენის გასაღები';

  @override
  String get accessSpacesDontMatter =>
      'ჰარებსა და დიდ ასოებს მნიშვნელობა არ აქვს.';

  @override
  String get accessNoKeyNothing =>
      'გასაღები არ გაქვთ? მაშინ ამას ვერაფერი გახსნის.';

  @override
  String get accessKeyTooShort =>
      'აღდგენის გასაღებში 8 ჯგუფია, თითოში 4 სიმბოლო.';

  @override
  String get accessKeyDoesntMatch =>
      'ეს გასაღები არ ემთხვევა. შეამოწმეთ ყოველი ჯგუფი.';

  @override
  String get accessNewMasterPassword => 'ახალი მთავარი პაროლი';

  @override
  String get accessKeyAccepted => 'გასაღები მიღებულია.';

  @override
  String get accessSaveNewPassword => 'ახალი პაროლის შენახვა';

  @override
  String get accessNewPasswordSaved => 'ახალი მთავარი პაროლი შენახულია.';

  @override
  String get accessSettingsKeepingSafe => 'უსაფრთხოება';

  @override
  String get accessChangeIt => 'შეცვლა';

  @override
  String get accessMakeNewOne => 'ახლის შექმნა';

  @override
  String get accessNoKeyYet => 'ჯერ არ არის';

  @override
  String accessFingerprintOrFace(String kind) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'faceId': 'Face ID',
        'touchId': 'Touch ID',
        'fingerprint': 'თითის ანაბეჭდი',
        'face': 'სახით განბლოკვა',
        'other': 'თითის ანაბეჭდი ან სახე',
      },
    );
    return '$_temp0';
  }

  @override
  String get accessNotOnThisDevice => 'ამ მოწყობილობაზე არ არის';

  @override
  String get accessLockTheApp => 'აპის ჩაკეტვა';

  @override
  String accessLockAfter(String time) {
    return 'ავტომატურად $time';
  }

  @override
  String get accessLockNow => 'ახლავე ჩაკეტვა';

  @override
  String get accessLockAfterTitle => 'აპი ჩაიკეტოს';

  @override
  String get accessRightAway => 'მაშინვე';

  @override
  String get accessOneMinute => '1 წუთში';

  @override
  String get accessFiveMinutes => '5 წუთში';

  @override
  String get accessFifteenMinutes => '15 წუთში';

  @override
  String get accessOneHour => '1 საათში';

  @override
  String get accessRecommended => 'რეკომენდებული';

  @override
  String get accessOpensWith => 'რით იხსნება';

  @override
  String get accessItsOwnPassword => 'საკუთარი პაროლი';

  @override
  String get accessCopyPasswords => 'პაროლების კოპირება';

  @override
  String get accessClearsAfter30 => '30 წამში იშლება';

  @override
  String get accessOff => 'გამორთულია';

  @override
  String get accessSoftSoundsSoon => 'მომავალ განახლებაში';

  @override
  String get accessHelp => 'დახმარება';

  @override
  String get accessHowFuzzzyInkWorks => 'როგორ მუშაობს Fuzzzy Ink';

  @override
  String get accessPrivacyTermsSupport =>
      'კონფიდენციალურობა, პირობები და მხარდაჭერა';

  @override
  String get accessOpensYourBrowser => 'ბრაუზერში იხსნება';

  @override
  String get accessBrowserTip =>
      'ბრაუზერში იხსნება. თავად აპი ინტერნეტში არასდროს გადის.';

  @override
  String get accessDeveloper => 'დეველოპერისთვის';

  @override
  String accessVersionFooter(String version, String build) {
    return 'Fuzzzy Ink · ვერსია $version (build $build)';
  }

  @override
  String accessTurnOnBioTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'faceId': 'Face ID-ის ჩართვა',
        'touchId': 'Touch ID-ის ჩართვა',
        'fingerprint': 'თითის ანაბეჭდის ჩართვა',
        'face': 'სახით განბლოკვის ჩართვა',
        'other': 'თითის ანაბეჭდის ან სახის ჩართვა',
      },
    );
    return '$_temp0';
  }

  @override
  String get accessTurnOnBioLine => 'ერთხელ აკრიფეთ მთავარი პაროლი.';

  @override
  String accessTurnOnSafeBioTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'faceId': 'Face ID ჩემი სეიფისთვის',
        'touchId': 'Touch ID ჩემი სეიფისთვის',
        'fingerprint': 'თითის ანაბეჭდი ჩემი სეიფისთვის',
        'face': 'სახით განბლოკვა ჩემი სეიფისთვის',
        'other': 'თითის ანაბეჭდი ან სახე ჩემი სეიფისთვის',
      },
    );
    return '$_temp0';
  }

  @override
  String get accessTurnOnSafeBioLine => 'ერთხელ აკრიფეთ ჩემი სეიფის პაროლი.';

  @override
  String get accessTurnOn => 'ჩართვა';

  @override
  String accessBioOn(String kind) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'faceId': 'Face ID ჩართულია.',
        'touchId': 'Touch ID ჩართულია.',
        'fingerprint': 'თითის ანაბეჭდი ჩართულია.',
        'face': 'სახით განბლოკვა ჩართულია.',
        'other': 'თითის ანაბეჭდი ან სახე ჩართულია.',
      },
    );
    return '$_temp0';
  }

  @override
  String get accessMySafePassword => 'ჩემი სეიფის პაროლი';

  @override
  String get accessChangeMasterPassword => 'მთავარი პაროლის შეცვლა';

  @override
  String get accessCurrentPassword => 'ამჟამინდელი პაროლი';

  @override
  String get accessNewPassword => 'ახალი პაროლი';

  @override
  String get accessRecoveryKeepsWorking => 'აღდგენის გასაღები ისევ იმუშავებს.';

  @override
  String get accessChangePassword => 'პაროლის შეცვლა';

  @override
  String get accessMasterPasswordChanged => 'მთავარი პაროლი შეიცვალა.';

  @override
  String get accessMakeNewKey => 'ახალი გასაღების შექმნა';

  @override
  String get accessOldKeyStops => 'ძველი გასაღები აღარ იმუშავებს.';

  @override
  String get accessSafePasswordToo =>
      'ჩემს სეიფს საკუთარი პაროლი აქვს. ისიც აკრიფეთ, რომ ახალმა გასაღებმა ჩემი სეიფიც გახსნას.';

  @override
  String get accessYourNewKey => 'თქვენი ახალი გასაღები';

  @override
  String get accessNoPasswordNoKey =>
      'პაროლისა და გასაღების გარეშე წვდომა არ იქნება.';

  @override
  String get accessNewKeyKept => 'ახალი აღდგენის გასაღები მზადაა.';

  @override
  String get accessSafeOpensWith => 'რით იხსნება ჩემი სეიფი';

  @override
  String get accessSimplestRecommended => 'ყველაზე მარტივი. რეკომენდებულია.';

  @override
  String get accessOneMoreToRemember => 'კიდევ ერთი დასამახსოვრებელი';

  @override
  String get accessSafePassword => 'სეიფის პაროლი';

  @override
  String get accessSaveSafePassword => 'სეიფის პაროლის შენახვა';

  @override
  String get accessSafeHasOwnPassword =>
      'ახლა ჩემს სეიფს საკუთარი პაროლი აქვს.';

  @override
  String get accessSafeGetsNewKey =>
      'შემდეგ ახალ აღდგენის გასაღებს მიიღებთ. ის ჩემს სეიფსაც გახსნის, ძველი კი აღარ იმუშავებს.';

  @override
  String get accessUseMasterPassword => 'მთავარი პაროლის გამოყენება';

  @override
  String get accessSafeUsesMaster => 'ჩემი სეიფი ისევ მთავარი პაროლით იხსნება.';

  @override
  String get accessSafeNotMadeYet =>
      'ჩემი სეიფი ჯერ არ შექმნილა. ერთხელ გახსენით მისი ჩანართიდან.';

  @override
  String get accessMasterPasswordToConfirm => 'მთავარი პაროლი, დასადასტურებლად';

  @override
  String get accessHowOnceTitle => 'ყველაფერი ერთხელ იხსნება';

  @override
  String get accessHowOnceBody =>
      'გახსნისას გასაღები იხარჯება. ასლი ისტორიაში რჩება.';

  @override
  String get accessHowHistoryTitle => 'ისტორია ამ ტელეფონზე რჩება';

  @override
  String get accessHowHistoryBody =>
      'ჩაკეტილია მთავარი პაროლით. ახალი ტელეფონი მას ვერ წაიკითხავს. ასლისთვის ადამიანის ისტორია ფაილად შეინახეთ.';

  @override
  String get accessHowOrderTitle => 'გახსენით თანმიმდევრობით';

  @override
  String get accessHowOrderBody =>
      'ძალიან ძველი შეტყობინება შეიძლება ვეღარ გაიხსნას. მაშინ სთხოვეთ, ხელახლა ჩაკეტოს.';

  @override
  String get accessHowCheckTitle => 'ადამიანის შემოწმება';

  @override
  String get accessHowCheckBody =>
      'ორივე ტელეფონზე ციფრები ერთნაირია — შუაში არავინ ჩამდგარა. „შემოწმებულია“ თქვენივე ჩანიშვნაა.';

  @override
  String get accessHowLinksTitle => 'ბმულები';

  @override
  String get accessHowLinksBody =>
      'რაც # ნიშნის შემდეგ წერია, ჩვენს საიტამდე არასდროს მიდის.';

  @override
  String get accessHowFilesTitle => 'შენახული ფაილები';

  @override
  String get accessHowFilesBody =>
      'აპი მხოლოდ ჩაკეტილ ფაილებს ინახავს. შენახული ასლის დაცვა თქვენზეა.';

  @override
  String get accessHowHoodTitle => 'ტექნიკური დეტალები';

  @override
  String get accessHowHoodBody =>
      'შეტყობინებები იყენებს Olm double ratchet-ს (vodozemac, დამოუკიდებელი აუდიტით შემოწმებული): ყოველ შეტყობინებას ახალი გასაღები აქვს. ფაილები ნაწილ-ნაწილ იკეტება XChaCha20-Poly1305-ით. პაროლები Argon2id-ით მუშავდება. გასაღებები აპის ნატიურ ბირთვშია და არსად იგზავნება.';

  @override
  String get accessMoreAboutEncryption => 'მეტი დაშიფვრის შესახებ';

  @override
  String personMoreFor(String name) {
    return 'მეტი: $name';
  }

  @override
  String get personNotCheckedLead => 'ჯერ არ შეგიმოწმებიათ.';

  @override
  String get personNotCheckedAction => 'შეამოწმეთ ციფრები.';

  @override
  String get historyFilterAll => 'ყველა';

  @override
  String get historyFilterLocked => 'ჩაკეტილი';

  @override
  String get historyFilterOpened => 'გახსნილი';

  @override
  String get historyToday => 'დღეს';

  @override
  String get historyYesterday => 'გუშინ';

  @override
  String get historyEmpty => 'აქ ჯერ არაფერია.';

  @override
  String get historyEmptyLocked => 'ჯერ არაფერი ჩაგიკეტავთ.';

  @override
  String get historyEmptyOpened => 'ჯერ არაფერი გაგიხსნიათ.';

  @override
  String get historyStaysLocked => 'ისტორია ამ ტელეფონზე ჩაკეტილი რჩება.';

  @override
  String get historyLoadError => 'ისტორია ვერ ჩაიტვირთა.';

  @override
  String waitingCardTitle(String name) {
    return 'პასუხს ველოდებით: $name';
  }

  @override
  String get waitingShareInviteAgain => 'მოწვევის ხელახლა გაზიარება';

  @override
  String get waitingGotReply => 'პასუხი მივიღე';

  @override
  String get personMenuCheckNumbers => 'ციფრების შემოწმება';

  @override
  String get personMenuNotCheckedYet => 'ჯერ არ შემოწმებულა';

  @override
  String get personMenuSendReplyAgain => 'ჩემი პასუხის ხელახლა გაგზავნა';

  @override
  String get personMenuSaveHistory => 'ისტორიის ფაილად შენახვა';

  @override
  String get personMenuSaveHistoryHint => 'პაროლით ჩაკეტილი';

  @override
  String personMenuRemove(String name) {
    return 'წაშლა: $name';
  }

  @override
  String removePersonTitle(String name) {
    return 'წავშალოთ $name?';
  }

  @override
  String get removePersonBody =>
      'მისი ისტორია და ფაილები ამ ტელეფონიდან წაიშლება. დაბრუნება შეუძლებელია.';

  @override
  String get removePersonConfirm => 'წაშლა';

  @override
  String removePersonDone(String name) {
    return '$name წაიშალა.';
  }

  @override
  String removePersonFailed(String name) {
    return '$name ვერ წაიშალა. სცადეთ ხელახლა.';
  }

  @override
  String exportHistoryTitle(String name) {
    return 'ისტორიის შენახვა: $name';
  }

  @override
  String get exportHistoryLine => 'ერთი ფაილი, ამ პაროლით ჩაკეტილი.';

  @override
  String get exportHistoryPassword => 'ფაილის პაროლი';

  @override
  String get exportHistorySave => 'ფაილის შენახვა';

  @override
  String get exportHistorySaved => 'ისტორია ფაილად შეინახა.';

  @override
  String itemForName(String name) {
    return 'მიმღები: $name';
  }

  @override
  String itemYouLockedWhen(String day, String time) {
    return 'ჩაიკეტა · $day · $time';
  }

  @override
  String itemOpenedWhen(String day, String time) {
    return 'გაიხსნა · $day · $time';
  }

  @override
  String get itemShareAgain => 'ხელახლა გაზიარება';

  @override
  String get itemCopyLocked => 'ჩაკეტილის კოპირება';

  @override
  String get itemOnlyLockedKept => 'მხოლოდ ჩაკეტილი ასლი ინახება.';

  @override
  String get itemSave => 'შენახვა';

  @override
  String get itemUnreadable => 'ეს შეტყობინება ამ ტელეფონზე ვერ იკითხება.';

  @override
  String get itemDone => 'მზადაა';

  @override
  String get inviteStepName => 'სახელი';

  @override
  String get inviteStepSend => 'გაგზავნა';

  @override
  String get inviteWhoFor => 'ვისთვისაა?';

  @override
  String get inviteTheirName => 'მისი სახელი';

  @override
  String get inviteNameHint => 'მაგ. თამარი';

  @override
  String get inviteOnlyYouSee => 'ამას მხოლოდ თქვენ ხედავთ.';

  @override
  String get inviteMake => 'მოწვევის შექმნა';

  @override
  String get inviteNameTaken => 'ამ სახელით უკვე გყავთ ადამიანი.';

  @override
  String get inviteMakeFailed => 'მოწვევა ვერ შეიქმნა. სცადეთ ხელახლა.';

  @override
  String inviteSendTo(String name) {
    return 'გაუგზავნეთ: $name';
  }

  @override
  String get inviteDoneForNow => 'დანარჩენი მოგვიანებით';

  @override
  String inviteGotNameReply(String name) {
    return 'პასუხი მივიღე: $name';
  }

  @override
  String get inviteSharedLine => 'გადაეცა გაზიარების მენიუს.';

  @override
  String get inviteConnecting => 'კავშირი მყარდება…';

  @override
  String get inviteLoadFailed =>
      'მოწვევის წაკითხვა ვერ მოხერხდა. დახურეთ და ხელახლა გახსენით.';

  @override
  String get replyOpenTitle => 'პასუხის გახსნა';

  @override
  String get pasteItHint => 'დაკოპირებული ტექსტი ან ბმული';

  @override
  String get chooseFile => 'ფაილის არჩევა';

  @override
  String get chooseFileHint => 'ფაილი, რომელიც გამოგიგზავნათ';

  @override
  String get replyNothingToPaste =>
      'ჩასასმელი არაფერია. ჯერ პასუხი დააკოპირეთ.';

  @override
  String get inviteNothingToPaste =>
      'ჩასასმელი არაფერია. ჯერ მოწვევა დააკოპირეთ.';

  @override
  String get notAReply => 'ეს პასუხი არ არის. შეამოწმეთ, რა ჩასვით.';

  @override
  String get couldNotReadFile => 'ფაილის წაკითხვა ვერ მოხერხდა.';

  @override
  String get replyNotConnected =>
      'ამ პასუხმა ვერ დაგაკავშირათ. სთხოვეთ ხელახლა.';

  @override
  String get gotStepOpen => 'გახსნა';

  @override
  String get gotStepReply => 'პასუხი';

  @override
  String get gotOpenTitle => 'მოწვევის გახსნა';

  @override
  String get gotInviteGood => 'მოწვევა სწორია.';

  @override
  String get gotWhoSent => 'ვინ გამოგიგზავნათ?';

  @override
  String get gotAccept => 'მიღება';

  @override
  String get gotOwnInviteTitle => 'ეს თქვენი მოწვევაა';

  @override
  String get gotOwnInviteLine => 'გაუგზავნეთ მეორე ადამიანს.';

  @override
  String get gotAlreadyTitle => 'უკვე დაკავშირებული ხართ';

  @override
  String get gotAlreadyLine => 'ეს მოწვევა ამ ტელეფონზე უკვე გახსნილია.';

  @override
  String get gotDamagedTitle => 'ეს ვერ იხსნება';

  @override
  String get gotDamagedLine =>
      'შეიძლება, ბოლომდე არ მოსულა ან სხვისთვისაა. სთხოვეთ, ხელახლა გამოგიგზავნოთ.';

  @override
  String get gotAcceptFailed => 'მოწვევის მიღება ვერ მოხერხდა. სცადეთ ხელახლა.';

  @override
  String replySendTo(String name) {
    return 'პასუხი გაუგზავნეთ: $name';
  }

  @override
  String get replySameWay => 'იმავე გზით, რითაც მოწვევა მოვიდა.';

  @override
  String get replyCheckTip => 'მერე ერთად შეამოწმეთ ციფრები.';

  @override
  String get stepInviteOpened => 'მოწვევა გაიხსნა';

  @override
  String get stepYouReply => 'თქვენ პასუხობთ';

  @override
  String connectedWith(String name) {
    return 'თქვენ და $name დაკავშირებული ხართ';
  }

  @override
  String isItReally(String name) {
    return 'ნამდვილად $name არის?';
  }

  @override
  String get checkTogether => 'ციფრები ერთად შეამოწმეთ.';

  @override
  String get checkNow => 'ახლავე შემოწმება';

  @override
  String get checkLater => 'მოგვიანებით';

  @override
  String get twiceTitle => 'შესაძლოა, სხვამ უპასუხა';

  @override
  String twiceLine(String name) {
    return 'მოწვევაზე ($name) ორი პასუხი მოვიდა.';
  }

  @override
  String twiceNoteLead(String name) {
    return 'ჯერ არაფერი ჩაკეტოთ ამ ადამიანისთვის.';
  }

  @override
  String get twiceNoteRest => 'ჯერ ციფრები შეამოწმეთ.';

  @override
  String twiceRemove(String name) {
    return 'წაშლა და ხელახლა მოწვევა';
  }

  @override
  String get safetyCompare => 'შეადარეთ ზარით ან ტელეფონები გვერდიგვერდ დადეთ.';

  @override
  String get safetySame => 'ციფრები ერთნაირია';

  @override
  String get safetyDifferent => 'ციფრები განსხვავდება';

  @override
  String get safetyMarkNotChecked => 'შეუმოწმებლად მონიშვნა';

  @override
  String safetyCheckedBefore(String name) {
    return '$name უკვე შემოწმებული გყავთ.';
  }

  @override
  String safetyNowNotChecked(String name) {
    return '$name ახლა შეუმოწმებელია.';
  }

  @override
  String get safetyLoadFailed =>
      'ციფრების წაკითხვა ვერ მოხერხდა. დახურეთ და ხელახლა გახსენით.';

  @override
  String get safetySaveFailed => 'ვერ შეინახა. სცადეთ ხელახლა.';

  @override
  String mismatchLead(String name) {
    return 'არაფერი გაუგზავნოთ ამ ადამიანს.';
  }

  @override
  String get mismatchRest =>
      'შესაძლოა, შუაში ვიღაც დგას. წაშალეთ და თავიდან დაამატეთ, სჯობს პირისპირ.';

  @override
  String checkedTitle(String name) {
    return 'ეს ნამდვილად $name არის';
  }

  @override
  String get incomingFileUnreadable =>
      'ფაილის წაკითხვა ვერ მოხერხდა. ხელახლა გახსენით იქიდან, სადაც არის.';
}
