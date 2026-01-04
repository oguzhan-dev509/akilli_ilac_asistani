import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert'; 
import 'package:intl/intl.dart';
import 'package:record/record.dart'; 
import 'package:audioplayers/audioplayers.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const MaterialApp(home: IlacTakipApp(), debugShowCheckedModeBanner: false));

class IlacTakipApp extends StatefulWidget {
  const IlacTakipApp({super.key});
  @override
  State<IlacTakipApp> createState() => _IlacTakipAppState();
}

class _IlacTakipAppState extends State<IlacTakipApp> {
  String _suAnkiSaat = "";
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _alarmPlayer = AudioPlayer(); 
  final TextEditingController _yakinNoController = TextEditingController();
  final TextEditingController _yeniIlacController = TextEditingController();
  
  bool _isEnglish = false; 
  String _secilenKategori = "Kalp ve Tansiyon";
  String _secilenOgun = "ÖĞÜN SEÇİN"; 
  String _secilenDurum = "DURUM SEÇİN"; 
  bool _kayitEdiliyor = false;

  // 17 KATEGORİLİK TAM LİSTE - TEKRAR EKLENDİ
  List<Map<String, dynamic>> kategoriler = [
    {'tr': 'Kalp ve Tansiyon', 'en': 'Heart & Blood Pressure', 'ilaclar': []},
    {'tr': 'Tiroid', 'en': 'Thyroid', 'ilaclar': []},
    {'tr': 'Diyabet', 'en': 'Diabetes', 'ilaclar': []},
    {'tr': 'Gastrit & Ülser', 'en': 'Gastritis & Ulcer', 'ilaclar': []},
    {'tr': 'Böbrek Yetmezliği', 'en': 'Kidney Failure', 'ilaclar': []},
    {'tr': 'Bağırsak Hastalıkları', 'en': 'Intestinal Diseases', 'ilaclar': []},
    {'tr': 'Hepatit', 'en': 'Hepatitis', 'ilaclar': []},
    {'tr': 'Anemi', 'en': 'Anemia', 'ilaclar': []},
    {'tr': 'Romatizma', 'en': 'Rheumatism', 'ilaclar': []},
    {'tr': 'Kolesterol', 'en': 'Cholesterol', 'ilaclar': []},
    {'tr': 'Astım', 'en': 'Asthma', 'ilaclar': []},
    {'tr': 'Bronşit', 'en': 'Bronchitis', 'ilaclar': []},
    {'tr': 'KOAH & Zatürre', 'en': 'COPD & Pneumonia', 'ilaclar': []},
    {'tr': 'Cilt Hastalıkları', 'en': 'Skin Diseases', 'ilaclar': []},
    {'tr': 'Göz Hastalıkları', 'en': 'Eye Diseases', 'ilaclar': []},
    {'tr': 'Nöroloji', 'en': 'Neurology', 'ilaclar': []},
    {'tr': 'Vitamin & Takviye', 'en': 'Vitamin & Supplement', 'ilaclar': []},
  ];

  @override
  void initState() {
    super.initState();
    _saatiGuncelle();
    _verileriYukle(); 
    Timer.periodic(const Duration(seconds: 1), (Timer t) => _saatiGuncelle());
  }

  Future<void> _verileriKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yakin_no', _yakinNoController.text);
    await prefs.setBool('is_english', _isEnglish);
    await prefs.setString('kategoriler_data', jsonEncode(kategoriler));
  }

  Future<void> _verileriYukle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _yakinNoController.text = prefs.getString('yakin_no') ?? "";
      _isEnglish = prefs.getBool('is_english') ?? false;
      String? data = prefs.getString('kategoriler_data');
      if (data != null) {
        var decoded = jsonDecode(data) as List;
        for (var item in decoded) {
          var index = kategoriler.indexWhere((k) => k['tr'] == item['tr']);
          if (index != -1) kategoriler[index]['ilaclar'] = item['ilaclar'];
        }
      }
    });
  }

  void _saatiGuncelle() {
    if (!mounted) return;
    DateTime simdi = DateTime.now();
    setState(() => _suAnkiSaat = DateFormat('HH:mm:ss').format(simdi));
    if (simdi.second == 0) _alarmKontrolEt(DateFormat('HH:mm').format(simdi));
  }

  void _alarmKontrolEt(String suAnkiSaat) {
    for (var kat in kategoriler) {
      for (var ilac in kat['ilaclar']) {
        if (ilac['saat'] == suAnkiSaat) _alarmBaslat(ilac);
      }
    }
  }

  void _alarmBaslat(Map<String, dynamic> ilac) async {
    ilac['durum_takip'] = "BEKLIYOR";
    try {
      await _alarmPlayer.setReleaseMode(ReleaseMode.loop);
      await _alarmPlayer.play(UrlSource("https://www.soundjay.com/nature/sounds/bird-chirp-03.mp3"));
    } catch (e) { }

    Timer(const Duration(minutes: 15), () {
      if (ilac['durum_takip'] == "BEKLIYOR") {
        String tel = _yakinNoController.text;
        if (tel.isNotEmpty) {
          String mesaj = "DİKKAT! Hastanız ilacını henüz ALMADI. Lütfen kontrol edin!";
          launchUrl(Uri.parse("https://wa.me/$tel?text=${Uri.encodeComponent(mesaj)}"), mode: LaunchMode.externalApplication);
        }
      }
    });
    _uyariGoster(ilac);
  }

  void _uyariGoster(Map<String, dynamic> ilac) {
    showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(
      title: const Text("İlaç Vakti!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      content: Text("${ilac['ad']} (${ilac['ogun']} - ${ilac['durum']})"),
      actions: [ElevatedButton(onPressed: () { _alarmPlayer.stop(); setState(() => ilac['durum_takip'] = "ALINDI"); Navigator.pop(context); }, child: const Text("ALDIM"))],
    ));
  }

  Future<void> _sesKaydiYonet() async {
    if (_kayitEdiliyor) {
      await _recorder.stop();
      setState(() => _kayitEdiliyor = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ses Kaydı Başarılı!")));
    } else {
      if (await _recorder.hasPermission()) {
        await _recorder.start(const RecordConfig(), path: 'ilac_sesi.m4a');
        setState(() => _kayitEdiliyor = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Akıllı İlaç Asistanı', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.shade800,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: TextField(
              controller: _yakinNoController,
              decoration: const InputDecoration(labelText: "Yakın Telefon (90...)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_android, color: Colors.green)),
              onChanged: (v) => _verileriKaydet(),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.teal)),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: _yeniIlacController, decoration: const InputDecoration(hintText: "İlaç Adı Yazın..."))),
                    DropdownButton<String>(
                      value: _secilenKategori,
                      items: kategoriler.map((k) => DropdownMenuItem(value: k['tr'].toString(), child: Text(k['tr']))).toList(),
                      onChanged: (val) => setState(() => _secilenKategori = val!),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<String>(
                      hint: const Text("ÖĞÜN"),
                      value: _secilenOgun == "ÖĞÜN SEÇİN" ? null : _secilenOgun,
                      items: ["Sabah", "Öğle", "Akşam", "Gece"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _secilenOgun = v!),
                    ),
                    DropdownButton<String>(
                      hint: const Text("DURUM"),
                      value: _secilenDurum == "DURUM SEÇİN" ? null : _secilenDurum,
                      items: ["Aç Karnına", "Tok Karnına", "Ara Öğün"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _secilenDurum = v!),
                    ),
                    IconButton(
                      icon: const Icon(Icons.alarm_add, color: Colors.red, size: 35),
                      onPressed: () async {
                        TimeOfDay? t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (t != null && _yeniIlacController.text.isNotEmpty) {
                          setState(() {
                            var kat = kategoriler.firstWhere((e) => e['tr'] == _secilenKategori);
                            kat['ilaclar'].add({
                              'ad': _yeniIlacController.text, 
                              'saat': "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}", 
                              'ogun': _secilenOgun,
                              'durum': _secilenDurum,
                              'durum_takip': 'BEKLIYOR'
                            });
                          });
                          _verileriKaydet();
                        }
                      },
                    ),
                    const Text("SABİTLE / DEĞİŞTİR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal)),
                  ],
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(5), child: Text(_suAnkiSaat, style: const TextStyle(fontSize: 40, color: Colors.teal, fontWeight: FontWeight.bold))),
          Expanded(
            child: ListView.builder(
              itemCount: kategoriler.length,
              itemBuilder: (context, index) {
                final kat = kategoriler[index];
                return ExpansionTile(
                  key: PageStorageKey(kat['tr']),
                  initiallyExpanded: (kat['ilaclar'] as List).isNotEmpty,
                  title: Text(kat['tr'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: (kat['ilaclar'] as List).map<Widget>((ilac) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.medication, color: Colors.teal),
                      title: Text("${ilac['ad']} (${ilac['ogun']})"),
                      subtitle: Text("${ilac['durum']} | Saat: ${ilac['saat']}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: Icon(_kayitEdiliyor ? Icons.stop_circle : Icons.mic, color: Colors.blue), onPressed: () => _sesKaydiYonet()),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.grey), onPressed: () {
                            setState(() => kat['ilaclar'].remove(ilac));
                            _verileriKaydet();
                          }),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          _yeniIlacController.text = ilac['ad'];
                          _secilenKategori = kat['tr'];
                          _secilenOgun = ilac['ogun'];
                          _secilenDurum = ilac['durum'];
                        });
                      },
                    ),
                  )).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}