import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailService {
  static const String _serverUrl = 'https://8db2a9074017.ngrok-free.app/send-otp';
  static Future<bool> sendOtpEmail(String recipientEmail, String otpCode) async {
    try {
      final response = await http.post(
        Uri.parse(_serverUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "from": "noreply@test-51ndgwvzdydlzqx8.mlsender.net", 
          "to": recipientEmail,
          "subject": "Kode OTP Anda",
          "html": "<p>Kode OTP Anda adalah: <strong>$otpCode</strong></p>",
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Email OTP berhasil dikirim ke $recipientEmail");
        return true;
      } else {
        final errorBody = jsonDecode(response.body);
        print("❌ Gagal mengirim OTP:");
        print("Status: ${response.statusCode}");
        print("Pesan: ${errorBody['message'] ?? 'Tidak diketahui'}");
        print("Detail: ${errorBody['error'] ?? 'Tidak diketahui'}");
        return false;
      }
    } catch (e) {
      print("❌ Terjadi kesalahan saat mengirim email: $e");
      return false;
    }
  }
}
