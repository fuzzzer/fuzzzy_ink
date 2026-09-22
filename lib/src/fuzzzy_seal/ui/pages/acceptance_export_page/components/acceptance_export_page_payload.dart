import 'package:fuzzzy_seal/lib.dart';

class AcceptanceExportPagePayload {
  final ChatGeneralData chatGeneralData;
  final bool hasBackButton;

  AcceptanceExportPagePayload({
    required this.chatGeneralData,
    required this.hasBackButton,
  });
}
