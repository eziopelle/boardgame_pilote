// lib/ajout_jeux.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AjoutJeuxPage extends StatefulWidget {
  const AjoutJeuxPage({super.key});

  @override
  State<AjoutJeuxPage> createState() => _AjoutJeuxPageState();
}

class _AjoutJeuxPageState extends State<AjoutJeuxPage> {
  final supa = Supabase.instance.client;

  // --- Form state
  final _formKey = GlobalKey<FormState>();
  final _titre = TextEditingController();
  final _imageBoite = TextEditingController();
  final _imageMateriel = TextEditingController();
  final _description = TextEditingController();
  final _regleUrl = TextEditingController();
  final _videoUrl = TextEditingController();
  final _nbMin = TextEditingController();
  final _nbMax = TextEditingController();
  final _tMin = TextEditingController();
  final _tMax = TextEditingController();

  // --- Référentiels
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> materiels = [];
  List<Map<String, dynamic>> access = [];
  List<Map<String, dynamic>> tags = [];

  String? selectedCategorieId;
  String? selectedMaterielId;
  String? selectedAccessId;
  final Set<String> selectedTagIds = {};

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _loadRefs();
  }

  @override
  void dispose() {
    _titre.dispose();
    _imageBoite.dispose();
    _imageMateriel.dispose();
    _description.dispose();
    _regleUrl.dispose();
    _videoUrl.dispose();
    _nbMin.dispose();
    _nbMax.dispose();
    _tMin.dispose();
    _tMax.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadRefs() async {
    try {
      final results = await Future.wait([
        supa.from('categorie').select('id,label').order('label'),
        supa.from('materiel').select('id,label').order('label'),
        supa.from('accessibilite').select('id,label,scale').order('scale'),
        supa.from('tag').select('id,label').order('label'),
      ]);

      setState(() {
        categories = (results[0] as List).cast<Map<String, dynamic>>();
        materiels = (results[1] as List).cast<Map<String, dynamic>>();
        access = (results[2] as List).cast<Map<String, dynamic>>();
        tags = (results[3] as List).cast<Map<String, dynamic>>();
        // pré-sélections par défaut
        selectedCategorieId = categories.isNotEmpty ? categories.first['id'] as String : null;
        selectedMaterielId = materiels.isNotEmpty ? materiels.first['id'] as String : null;
        selectedAccessId = access.isNotEmpty ? access.first['id'] as String : null;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      _toast('Erreur chargement des listes: $e');
    }
  }

Future<void> _submit() async {
  if (!(_formKey.currentState?.validate() ?? false)) return;
  if (selectedCategorieId == null || selectedMaterielId == null || selectedAccessId == null) {
    _toast('Choisis catégorie, matériel et accessibilité.');
    return;
  }

  // 👉 ID utilisateur (auth)
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    _toast('Tu dois être connecté pour ajouter un jeu.');
    return;
  }
  final createdBy = user.id; // correspond à profiles.id

  final int? joueursMin = int.tryParse(_nbMin.text.trim());
  final int? joueursMax = int.tryParse(_nbMax.text.trim());
  final int? tmin = int.tryParse(_tMin.text.trim());
  final int? tmax = int.tryParse(_tMax.text.trim());

  if (joueursMin != null && joueursMax != null && joueursMax < joueursMin) {
    _toast('Nombre de joueurs : max doit être ≥ min.');
    return;
  }
  if (tmin != null && tmax != null && tmax < tmin) {
    _toast('Durée : max doit être ≥ min.');
    return;
  }

  setState(() => saving = true);
  try {
    // 1) insert jeu (+ created_by)
    final inserted = await supa.from('jeux').insert({
      'titre': _titre.text.trim(),
      'image_boite': _imageBoite.text.trim().isEmpty ? null : _imageBoite.text.trim(),
      'image_materiel': _imageMateriel.text.trim().isEmpty ? null : _imageMateriel.text.trim(),
      'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
      'regle_url': _regleUrl.text.trim().isEmpty ? null : _regleUrl.text.trim(),
      'video_regle_url': _videoUrl.text.trim().isEmpty ? null : _videoUrl.text.trim(),
      'nombre_joueurs_min': joueursMin,
      'nombre_joueurs_max': joueursMax,
      'temps_min_minutes': tmin,
      'temps_max_minutes': tmax,
      'categorie_id': selectedCategorieId,
      'materiel_id': selectedMaterielId,
      'accessibilite_id': selectedAccessId,
      'created_by': createdBy, // ✅ important
    }).select('id').single();

    final jeuId = inserted['id'] as String;

    // 2) liaisons tags
    if (selectedTagIds.isNotEmpty) {
      final rows = selectedTagIds.map((tid) => {'jeu_id': jeuId, 'tag_id': tid}).toList();
      await supa.from('jeu_tag').insert(rows);
    }

    _toast('Jeu ajouté ✅');
    if (mounted) Navigator.pop(context);
  } on PostgrestException catch (e) {
    _toast('Erreur Supabase: ${e.message}');
  } catch (e) {
    _toast('Erreur: $e');
  } finally {
    if (mounted) setState(() => saving = false);
  }
}

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un jeu')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Infos principales', style: t.titleMedium),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _titre,
                    decoration: const InputDecoration(labelText: 'Titre *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Titre obligatoire' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _description,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCategorieId,
                          decoration: const InputDecoration(labelText: 'Catégorie *'),
                          items: [
                            for (final c in categories)
                              DropdownMenuItem(
                                value: c['id'] as String,
                                child: Text(c['label'] as String),
                              )
                          ],
                          onChanged: (v) => setState(() => selectedCategorieId = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedMaterielId,
                          decoration: const InputDecoration(labelText: 'Matériel *'),
                          items: [
                            for (final m in materiels)
                              DropdownMenuItem(
                                value: m['id'] as String,
                                child: Text(m['label'] as String),
                              )
                          ],
                          onChanged: (v) => setState(() => selectedMaterielId = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedAccessId,
                    decoration: const InputDecoration(labelText: 'Accessibilité *'),
                    items: [
                      for (final a in access)
                        DropdownMenuItem(
                          value: a['id'] as String,
                          child: Text(a['label'] as String),
                        )
                    ],
                    onChanged: (v) => setState(() => selectedAccessId = v),
                  ),

                  const SizedBox(height: 20),
                  Text('Joueurs & durée', style: t.titleMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nbMin,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Joueurs min'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _nbMax,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Joueurs max'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _tMin,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Durée min (min)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _tMax,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Durée max (min)'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Text('Médias (URLs)', style: t.titleMedium),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _imageBoite,
                    decoration: const InputDecoration(labelText: 'Image de la boîte (URL)'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _imageMateriel,
                    decoration: const InputDecoration(labelText: 'Image matériel (URL)'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _regleUrl,
                    decoration: const InputDecoration(labelText: 'Règles (URL PDF/page)'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _videoUrl,
                    decoration: const InputDecoration(labelText: 'Vidéo règle (URL YouTube, …)'),
                  ),

                  const SizedBox(height: 24),
                  Text('Tags (multi-sélection)', style: t.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tRow in tags)
                        FilterChip(
                          label: Text(tRow['label'] as String),
                          selected: selectedTagIds.contains(tRow['id']),
                          onSelected: (sel) {
                            setState(() {
                              final id = tRow['id'] as String;
                              if (sel) {
                                selectedTagIds.add(id);
                              } else {
                                selectedTagIds.remove(id);
                              }
                            });
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 28),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: Text(saving ? 'Enregistrement…' : 'Ajouter ce jeu'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C4CF1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      onPressed: saving ? null : _submit,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
