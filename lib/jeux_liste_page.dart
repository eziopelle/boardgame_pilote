import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit_jeu_page.dart';

class JeuxListePage extends StatefulWidget {
  const JeuxListePage({super.key});

  @override
  State<JeuxListePage> createState() => _JeuxListePageState();
}

class _JeuxListePageState extends State<JeuxListePage> {
  final supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;

  Future<List<Map<String, dynamic>>> _fetch() async {
    final data = await supabase
        .from('jeux')
        .select('''
          id, titre, image_boite,
          nombre_joueurs_min, nombre_joueurs_max,
          temps_min_minutes, temps_max_minutes,
          categorie:categorie_id (label),
          accessibilite:accessibilite_id (label, scale),
          materiel:materiel_id (label)
        ''')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  String _range(int? a, int? b, {String sep = '–'}) {
    if (a == null && b == null) return '—';
    if (a != null && b != null && a != b) return '$a$sep$b';
    return '${a ?? b}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jeux')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erreur: ${snap.error}'));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('Aucun jeu pour le moment.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final j = items[i];
              final cat = j['categorie']?['label'] ?? '—';
              final acc = j['accessibilite']?['label'] ?? '—';
              final mat = j['materiel']?['label'] ?? '—';
              final joueurs = _range(j['nombre_joueurs_min'], j['nombre_joueurs_max']);
              final temps = _range(j['temps_min_minutes'], j['temps_max_minutes']);

              return ListTile(
                leading: (j['image_boite'] != null && (j['image_boite'] as String).isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(j['image_boite'], width: 56, height: 56, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.games_outlined, size: 32),
                title: Text(j['titre'] ?? ''),
                subtitle: Text('Cat.: $cat • Accès: $acc • Mat.: $mat\nJoueurs: $joueurs  •  Temps: $temps min'),
                isThreeLine: true,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditJeuPage(jeuId: j['id'] as String)),
                  );
                  // au retour, on refresh
                  setState(() => _future = _fetch());
                },
              );
            },
          );
        },
      ),
    );
  }
}
