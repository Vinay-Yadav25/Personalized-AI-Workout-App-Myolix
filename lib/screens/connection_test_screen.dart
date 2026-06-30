import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api.dart';

class ConnectionTestScreen extends StatefulWidget {
  const ConnectionTestScreen({super.key});
  @override
  State<ConnectionTestScreen> createState() => _ConnectionTestScreenState();
}

class _ConnectionTestScreenState extends State<ConnectionTestScreen> {
  String result = "Tap the button to test";
  bool loading = false;

  Future<void> _test() async {
    setState(() { loading = true; result = "Testing..."; });
    try {
      final res = await http
          .get(Uri.parse("${Api.baseUrl}/ping.php"))
          .timeout(const Duration(seconds: 8));

      setState(() {
        result = "✅ Status: ${res.statusCode}\n\n"
            "URL: ${Api.baseUrl}/ping.php\n\n"
            "Response:\n${res.body}";
      });
    } catch (e) {
      setState(() {
        result = "❌ Connection FAILED\n\n"
            "URL: ${Api.baseUrl}/ping.php\n\n"
            "Error: $e";
      });
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Connection Test")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: loading ? null : _test,
              icon: const Icon(Icons.wifi_tethering),
              label: const Text("Test Backend Connection"),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    result,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}