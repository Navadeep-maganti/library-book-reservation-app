import "dart:math";

import "package:url_launcher/url_launcher.dart";

class UpiPaymentService {
  static final Random _random = Random();

  static const List<Map<String, String>> _demoPayees = [
    {
      "pa": "campuslibrarydemo@ibl",
      "pn": "Campus Library Demo",
    },
    {
      "pa": "readhubdemo@okaxis",
      "pn": "Read Hub Demo",
    },
    {
      "pa": "bookdeskdemo@ybl",
      "pn": "Book Desk Demo",
    },
  ];

  static Future<bool> launchDemoPayment({
    required double amount,
    required String note,
  }) async {
    if (amount <= 0) return false;

    final payee = _demoPayees[_random.nextInt(_demoPayees.length)];
    final txnRef =
        "LIB${DateTime.now().millisecondsSinceEpoch}${100 + _random.nextInt(900)}";

    final uri = Uri(
      scheme: "upi",
      host: "pay",
      queryParameters: {
        "pa": payee["pa"],
        "pn": payee["pn"],
        "tn": note,
        "tr": txnRef,
        "am": amount.toStringAsFixed(2),
        "cu": "INR",
      },
    );

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
