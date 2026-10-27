import 'package:fuzzzy_ink/src/src.dart';

/// What `AppRouter.open` takes as `extra` (a bare [OpenRequest] works too).
///
/// No [request] shows "Open what you got"; a tapped message link or a file
/// handed in opens straight away. [returnsToPerson]: opened from that
/// person's page, so Done closes Open and the page underneath shows the row.
class OpenPagePayload {
  const OpenPagePayload({this.request, this.returnsToPerson = false});

  final OpenRequest? request;
  final bool returnsToPerson;

  factory OpenPagePayload.fromRoute(Object? extra) => switch (extra) {
        final OpenPagePayload payload => payload,
        final OpenRequest request => OpenPagePayload(request: request),
        _ => const OpenPagePayload(),
      };
}
