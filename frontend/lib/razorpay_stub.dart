// Stub for platforms that don't support Razorpay
class Razorpay {
  Razorpay();
  
  void on(String event, Function(dynamic) handler) {}
  
  void open(Map<String, dynamic> options) {
    print('⚠️ Razorpay not supported on this platform');
  }
}
