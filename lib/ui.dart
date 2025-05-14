import 'package:flutter/material.dart';
import 'scanning_logic.dart';

class BruteforceScreen extends StatefulWidget {
  const BruteforceScreen({super.key});

  @override
  State<BruteforceScreen> createState() => _BruteforceScreenState();
}

class _BruteforceScreenState extends State<BruteforceScreen> with SingleTickerProviderStateMixin {
  final _baseUrlController = TextEditingController(text: 'https://httpbin.org');
  final _threadsController = TextEditingController(text: '5');
  final _customWordlistPathController = TextEditingController();

  bool _useCustomWordlist = false;
  bool _ignoreSsl = false;
  List<ScanResult> _scanResults = [];
  bool _isLoading = false;

  List<int> _includeStatusCodes = [];
  List<int> _excludeStatusCodes = [];
  List<String> _extensions = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Initialize status code lists
    _includeStatusCodes = []; // Default to empty
    _excludeStatusCodes = []; // Default to empty
  }

  Future<void> _startScan() async {
    setState(() {
      _isLoading = true;
      _scanResults = [];
    });

    final baseUrl = _baseUrlController.text.trim();
    final threads = int.tryParse(_threadsController.text.trim()) ?? 5;
    String path = _useCustomWordlist
        ? _customWordlistPathController.text.trim()
        : 'assets/wordlists/small.txt'; // Default wordlist

    if (baseUrl.isEmpty || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please provide valid inputs.")));
      setState(() => _isLoading = false);
      return;
    }

    try {
      final wordlist = await readWordlist(path);
      if (wordlist.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to load wordlist.")));
        setState(() => _isLoading = false);
        return;
      }

      // Ensure that the status code lists are not null
      if (_includeStatusCodes.isEmpty) {
        _includeStatusCodes = [200]; // Default to include 200 OK
      }
      if (_excludeStatusCodes.isEmpty) {
        _excludeStatusCodes = []; // Default to exclude nothing
      }

      final results = await startBruteforce(
        baseUrl,
        wordlist,
        numberOfThreads: threads,
        includeStatusCodes: _includeStatusCodes,
        excludeStatusCodes: _excludeStatusCodes,
        extensions: _extensions,
        ignoreSsl: _ignoreSsl,
      );

      setState(() {
        _scanResults = results;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isLoading = false);
    }
  }

  // Add a method to parse status codes from user input
  void _parseStatusCodes(String input, bool isInclude) {
    List<int> parsedCodes = input.split(',')
        .map((code) => int.tryParse(code.trim()))
        .where((code) => code != null)
        .cast<int>()
        .toList();

    if (isInclude) {
      _includeStatusCodes = parsedCodes;
    } else {
      _excludeStatusCodes = parsedCodes;
    }
  }

  // UI for entering status codes
  Widget _buildStatusCodeInput() {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(labelText: 'Include Status Codes (comma-separated) '),
          onChanged: (value) => _parseStatusCodes(value, true),
        ),
        TextField(
          decoration: const InputDecoration(labelText: 'Exclude Status Codes (comma-separated)'),
          onChanged: (value) => _parseStatusCodes(value, false),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bruteforce Scanner'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Scan'),
            Tab(text: 'Results'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildStatusCodeInput(),
                // Other UI elements like base URL and thread count inputs
                TextField(
                  controller: _baseUrlController,
                  decoration: const InputDecoration(labelText: 'Base URL'),
                ),
                TextField(
                  controller: _threadsController,
                  decoration: const InputDecoration(labelText: 'Number of Threads'),
                  keyboardType: TextInputType.number,
                ),
                // Custom wordlist toggle and path input
                SwitchListTile(
                  title: const Text('Use Customt Wordlist'),
                  value: _useCustomWordlist,
                  onChanged: (value) {
                    setState(() {
                      _useCustomWordlist = value;
                    });
                  },
                ),
                if (_useCustomWordlist)
                  TextField(
                    controller: _customWordlistPathController,
                    decoration: const InputDecoration(labelText: 'Custom Wordlist Path'),
                  ),
                ElevatedButton(
                  onPressed: _startScan,
                  child: _isLoading ? const CircularProgressIndicator() : const Text('Start Scan'),
                ),
              ],
            ),
          ),
          // Results display
          ListView.builder(
            itemCount: _scanResults.length,
            itemBuilder: (context, index) {
              final result = _scanResults[index];
              return ListTile(
                title: Text(result.url),
                subtitle: Text('Status: ${result.error}'),
              );
            },
          ),
        ],
      ),
    );
  }
}




