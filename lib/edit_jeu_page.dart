import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditJeuPage extends StatefulWidget {
  final String jeuId;
  const EditJeuPage({super.key, required this.jeuId});

  @override
  State<EditJeuPage> createState() => _EditJeuPageState();
}

class _EditJeuPageState extends State<EditJeuPage> {
  final supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  final titreCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final imageBoiteCtrl = TextEditingController();
  final imageMaterielCtrl = TextEditingController();
  final regleCtrl = TextEditingController();
  final videoCtrl = TextEditingController();
  final njMinCtrl = TextEditingController();
  final njMaxCtrl = TextEditingController();
  final tMinCtrl = TextEditingController();
  final tMaxCtrl = TextEditingController();

  String? categorieId;
  String? accessibiliteId;
  String? materielId;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _access = [];
  List<Map<String, dynamic>> _materiels = [];

  Future<void> _loadRefs() async {
    final cats = await supabase.from('categorie').select('id,label').order('label');
    final accs = await supabase.from('accessibilite').select('id,label,scale').order('scale');
    final mats = await supabase.from('materiel').select('id,label').order('label');
    _categories = List<Map<String, dynamic>>.from(cats);
    _access = List<Map<String, dynamic>>.from(accs);
    _materiels = List<Map<String, dynamic>>.from(mats);
  }

  Future<void> _loadJeu() async {
    final j = await supabase.from('jeux').select('*').eq('id', widget.jeuId).single();
    titreCtrl.text = j['titre'] ?? '';
    descCtrl.text = j['description'] ?? '';
    imageBoiteCtrl.text = j['image_boite'] ?? '';
    imageMaterielCtrl.text = j['image_materiel'] ?? '';
    regleCtrl.text = j['regle_url'] ?? '';
    videoCtrl.text = j['video_regle_url'] ?? '';
    njMinCtrl.text = (j['nombre_joueurs_min'] ?? '').toString();
    njMaxCtrl.text = (j['nombre_joueurs_max'] ?? '').toString();
    tMinCtrl.text = (j['temps_min_minutes'] ?? '').toString();
    tMaxCtrl.text = (j['temps_max_minutes'] ?? '').toString();
    categorieId = j['categorie_id'];
    accessibiliteId = j['accessibilite_id'];
    materielId = j['materiel_id'];
  }

  Future<void> _init() async {
    await _loadRefs();
    await _loadJeu();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    int? toInt(String s) => s.trim().isEmpty ? null : int.tryParse(s.trim());

    final payload = {
      'titre': titreCtrl.text.trim(),
      'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
      'image_boite': imageBoiteCtrl.text.trim().isEmpty ? null : imageBoiteCtrl.text.trim(),
      'image_materiel': imageMaterielCtrl.text.trim().isEmpty ? null : imageMaterielCtrl.text.trim(),
      'regle_url': regleCtrl.text.trim().isEmpty ? null : regleCtrl.text.trim(),
      'video_regle_url': videoCtrl.text.trim().isEmpty ? null : videoCtrl.text.trim(),
      'nombre_joueurs_min': toInt(njMinCtrl.text),
      'nombre_joueurs_max': toInt(njMaxCtrl.text),
      'temps_min_minutes': toInt(tMinCtrl.text),
      'temps_max_minutes': toInt(tMaxCtrl.text),
      'categorie_id': categorieId,
      'accessibilite_id': accessibiliteId,
      'materiel_id': materielId,
    };

    await supabase.from('jeux').update(payload).eq('id', widget.jeuId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jeu mis à jour')));
    Navigator.pop(context);
  }

  @override
  void dispose() {
    titreCtrl.dispose();
    descCtrl.dispose();
    imageBoiteCtrl.dispose();
    imageMaterielCtrl.dispose();
    regleCtrl.dispose();
    videoCtrl.dispose();
    njMinCtrl.dispose();
    njMaxCtrl.dispose();
    tMinCtrl.dispose();
    tMaxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _categories.isNotEmpty || _access.isNotEmpty || _materiels.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Éditer le jeu')),
      body: !ready
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: titreCtrl,
                      decoration: const InputDecoration(labelText: 'Titre'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Titre requis' : null,
                    ),
                    TextFormField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 4),
                    TextFormField(controller: imageBoiteCtrl, decoration: const InputDecoration(labelText: 'URL image boîte')),
                    TextFormField(controller: imageMaterielCtrl, decoration: const InputDecoration(labelText: 'URL image matériel')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: njMinCtrl,
                            decoration: const InputDecoration(labelText: 'Joueurs min'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: njMaxCtrl,
                            decoration: const InputDecoration(labelText: 'Joueurs max'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: tMinCtrl,
                            decoration: const InputDecoration(labelText: 'Temps min (min)'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: tMaxCtrl,
                            decoration: const InputDecoration(labelText: 'Temps max (min)'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: categorieId,
                      items: _categories
                          .map((e) => DropdownMenuItem(value: e['id'] as String, child: Text(e['label'] as String)))
                          .toList(),
                      onChanged: (v) => setState(() => categorieId = v),
                      decoration: const InputDecoration(labelText: 'Catégorie'),
                    ),
                    DropdownButtonFormField<String>(
                      value: accessibiliteId,
                      items: _access
                          .map((e) => DropdownMenuItem(
                              value: e['id'] as String,
                              child: Text('${e['scale']}. ${e['label']}')))
                          .toList(),
                      onChanged: (v) => setState(() => accessibiliteId = v),
                      decoration: const InputDecoration(labelText: 'Accessibilité'),
                    ),
                    DropdownButtonFormField<String>(
                      value: materielId,
                      items: _materiels
                          .map((e) => DropdownMenuItem(value: e['id'] as String, child: Text(e['label'] as String)))
                          .toList(),
                      onChanged: (v) => setState(() => materielId = v),
                      decoration: const InputDecoration(labelText: 'Matériel'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: regleCtrl, decoration: const InputDecoration(labelText: 'URL règle')),
                    TextFormField(controller: videoCtrl, decoration: const InputDecoration(labelText: 'URL vidéo règle')),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _save,
                        child: const Text('Enregistrer'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
