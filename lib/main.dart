import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

void main() => runApp(const QuranApp());

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'القرآن الكريم',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AudioPlayer _player = AudioPlayer();
  List<dynamic> _reciters = [];
  List<dynamic> _ayahs = [];
  dynamic _selectedReciter;
  bool _loading = false;
  String _status = 'اختر قارئاً وسورة';

  @override
  void initState() {
    super.initState();
    _loadReciters();
  }

  Future<void> _loadReciters() async {
    try {
      final res = await http.get(
        Uri.parse('http://mp3quran.net/api/_english.php'),
      );
      final data = json.decode(res.body);
      setState(() => _reciters = data['reciters'] ?? []);
    } catch (e) {
      setState(() => _status = 'فشل تحميل القراء: $e');
    }
  }

  Future<void> _loadSurah(int surahNumber) async {
    setState(() {
      _loading = true;
      _ayahs = [];
      _status = 'جاري تحميل النص...';
    });

    try {
      final res = await http.get(
        Uri.parse('https://api.quranpedia.net/v1/mushafs/1/$surahNumber'),
      );
      final data = json.decode(res.body);
      setState(() {
        _ayahs = data['ayahs'] ?? [];
        _loading = false;
        _status = 'تم التحميل';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'فشل تحميل النص: $e';
      });
    }
  }

  Future<void> _playAudio(int surahNumber) async {
    if (_selectedReciter == null) {
      setState(() => _status = 'الرجاء اختيار قارئ أولاً');
      return;
    }

    final server = _selectedReciter['Server'] as String;
    final number = surahNumber.toString().padLeft(3, '0');
    final url = '$server/$number.mp3';

    try {
      setState(() => _status = 'جاري التشغيل...');
      await _player.setUrl(url);
      _player.play();
      setState(() => _status = 'يعمل: $url');
    } catch (e) {
      setState(() => _status = 'فشل الصوت: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('القرآن الكريم'),
        actions: [
          if (_reciters.isNotEmpty)
            DropdownButton<dynamic>(
              value: _selectedReciter,
              hint: const Text('اختر قارئاً'),
              items: _reciters.map<DropdownMenuItem<dynamic>>((r) {
                return DropdownMenuItem(
                  value: r,
                  child: Text(r['name'] ?? ''),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedReciter = v),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_status, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: _ayahs.isEmpty
                ? const Center(child: Text('اختر سورة من الزر العائم'))
                : ListView.builder(
                    itemCount: _ayahs.length,
                    itemBuilder: (context, i) {
                      final a = _ayahs[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                a['text'] ?? '',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontFamily: 'Amiri',
                                ),
                                textAlign: TextAlign.right,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'آية ${a['number_in_surah'] ?? i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.play_arrow),
        onPressed: () => _showSurahPicker(),
      ),
    );
  }

  void _showSurahPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: ListView.builder(
          itemCount: 114,
          itemBuilder: (context, i) {
            final n = i + 1;
            return ListTile(
              title: Text('سورة $n'),
              onTap: () {
                Navigator.pop(context);
                _loadSurah(n);
                _playAudio(n);
              },
            );
          },
        ),
      ),
    );
  }
}