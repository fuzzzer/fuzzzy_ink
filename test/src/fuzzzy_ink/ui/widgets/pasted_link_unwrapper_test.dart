import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';

/// Desktop apps receive links by paste: a field that takes a blob takes the
/// link too, and shows the blob inside it.
void main() {
  test("a pasted link of the field's kind becomes its blob", () {
    final controller = TextEditingController(
      text: ' https://ink.fuzzzycore.com/message#$_chatId.RlVaWgED\n',
    )..unwrapPastedLink(FuzzyLinkType.message);

    expect(controller.text, 'Fuzz/RlVaWgED');
  });

  test('a link of another kind, or plain text, stays as typed', () {
    const invite = 'https://ink.fuzzzycore.com/invite#RlVaWgEB';
    final controller = TextEditingController(text: invite)
      ..unwrapPastedLink(FuzzyLinkType.acceptance);
    expect(controller.text, invite);

    controller
      ..text = 'hello https://ink.fuzzzycore.com/accept#RlVaWgEC'
      ..unwrapPastedLink(FuzzyLinkType.acceptance);
    expect(controller.text, 'hello https://ink.fuzzzycore.com/accept#RlVaWgEC');
  });
}
