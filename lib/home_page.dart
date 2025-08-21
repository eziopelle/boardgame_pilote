import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ajout_jeux.dart';
import 'jeux_liste_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;

  int _totalJeux = 0;

  // Top 2 contributeurs
  // Chaque entrée: { 'id': String, 'display_name': String?, 'avatar_url': String?, 'count': int }
  List<Map<String, dynamic>> _leaders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // 1) Total jeux
      final all = await supabase.from('jeux').select('id');
      final total = (all as List).length;

      // 2) Comptage par created_by (simple & fiable)
      // Récupère seulement la colonne created_by puis compte côté client
      final rows = await supabase.from('jeux').select('created_by');
      final counts = <String, int>{};
      for (final r in rows) {
        final uid = r['created_by'] as String?;
        if (uid == null) continue;
        counts.update(uid, (v) => v + 1, ifAbsent: () => 1);
      }

      // Trie par nombre desc
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topIds = sorted.take(2).map((e) => e.key).toList();

      // 3) Récup info profils pour top 2
      final leaders = <Map<String, dynamic>>[];
      for (final uid in topIds) {
        final prof = await supabase
            .from('profiles')
            .select('id, display_name, avatar_url')
            .eq('id', uid)
            .maybeSingle();

        final count = counts[uid] ?? 0;
        leaders.add({
          'id': uid,
          'display_name': prof?['display_name'] ?? 'Inconnu',
          'avatar_url': prof?['avatar_url'],
          'count': count,
        });
      }

      if (!mounted) return;
      setState(() {
        _totalJeux = total;
        _leaders = leaders;
      });
    } catch (e) {
      // silencieux, mais tu peux logger
      if (!mounted) return;
      setState(() {
        _totalJeux = 0;
        _leaders = [];
      });
    }
  }

  Widget _leaderCard(Map<String, dynamic>? user) {
    // Gestion placeholder si pas assez de contributeurs
    final displayName = user?['display_name'] as String? ?? '—';
    final avatarUrl = user?['avatar_url'] as String?;
    final count = user?['count'] as int? ?? 0;

    final progress = (count / 100).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar centré
        CircleAvatar(
          radius: 36,
          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
              ? NetworkImage(avatarUrl)
              : null,
          child: (avatarUrl == null || avatarUrl.isEmpty)
              ? const Icon(Icons.person, size: 36)
              : null,
        ),
        const SizedBox(height: 8),
        // Nom
        Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        // Nombre de jeux
        Text(
          '$count jeu${count > 1 ? "x" : ""} renseigné${count > 1 ? "s" : ""}',
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 8),
        // Barre de progression vers 100
        SizedBox(
          width: 140,
          child: Column(
            children: [
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 4),
              Text('${(progress * 100).floor()}/100',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Boardgame Pilote"),
        backgroundColor: const Color(0xFF6C4CF1),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Logo
            Image.asset('assets/Boardgame-Project.png', height: 140),
            const SizedBox(height: 16),

            // Compteur total
            Text(
              '$_totalJeux jeu${_totalJeux > 1 ? "x" : ""} au total',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 24),

            // Bouton "Ajouter un jeu"
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C4CF1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AjoutJeuxPage()),
                  );
                  if (!mounted) return;
                  _loadData(); // refresh compteur & leaders
                },
                child: const Text("Ajouter un jeu",
                    style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),

            const SizedBox(height: 16),

            // Bouton "Liste des jeux"
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const JeuxListePage()),
                  );
                  if (!mounted) return;
                  _loadData(); // refresh en revenant
                },
                child: const Text("Liste des jeux",
                    style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),

            const SizedBox(height: 24),

            // Top contributeurs (2 colonnes)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Top contributeurs',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(child: Center(child: _leaderCard(_leaders.isNotEmpty ? _leaders[0] : null))),
                const SizedBox(width: 16),
                Expanded(child: Center(child: _leaderCard(_leaders.length > 1 ? _leaders[1] : null))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
