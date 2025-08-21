import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Charger les variables d'env
  await dotenv.load(fileName: '.env');
  final url = dotenv.env['SUPABASE_URL'];
  final anon = dotenv.env['SUPABASE_ANON_KEY'];
  if (url == null || anon == null) {
    throw Exception('SUPABASE_URL / SUPABASE_ANON_KEY manquants dans .env');
  }

  // 2) Initialiser Supabase (à faire AVANT runApp)
  await Supabase.initialize(
    url: url,
    anonKey: anon,
    // PKCE recommandé; marche web/mobile
    authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
  );

  runApp(const BoardgamePiloteApp());
}

class BoardgamePiloteApp extends StatelessWidget {
  const BoardgamePiloteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boardgame Pilote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'SF Pro', // prend la police du système si non dispo
        colorSchemeSeed: const Color(0xFF6C4CF1),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      home: const AuthPage(),
    );
  }
}
