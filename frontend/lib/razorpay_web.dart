@JS()
library razorpay_web;

import 'package:js/js.dart';

@JS('Razorpay')
class Razorpay {
  external factory Razorpay(dynamic options);
  external void open();
}

@JS()
@anonymous
class RazorpayOptions {
  external factory RazorpayOptions({
    String? key,
    String? order_id,
    num? amount,
    String? name,
    String? description,
    dynamic prefill,
    dynamic theme,
    Function? handler,
    Function? modal,
  });
}

@JS()
@anonymous
class Prefill {
  external factory Prefill({
    String? name,
    String? email,
    String? contact,
  });
}

@JS()
@anonymous
class Theme {
  external factory Theme({
    String? color,
  });
}
