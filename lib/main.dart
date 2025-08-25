import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_page.dart';
import 'home_page.dart';

const _supabaseUrl  = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnon = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_supabaseUrl.isEmpty || _supabaseAnon.isEmpty) {
    throw Exception('SUPABASE_URL / SUPABASE_ANON_KEY manquants (utilise --dart-define).');
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnon,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce, // indispensable pour le Web
    ),
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
        fontFamily: 'SF Pro',
        colorSchemeSeed: const Color(0xFF6C4CF1),
      ),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, snapshot) {
        // ⚠️ toujours décider sur la *session*, pas l’event
        final session =
            snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;

        // Splash la toute première frame si rien n’est prêt
        if (!snapshot.hasData && session == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return session == null ? const AuthPage() : const HomePage();
      },
    );
  }
}
