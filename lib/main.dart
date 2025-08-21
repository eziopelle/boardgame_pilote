import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_page.dart';
import 'home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  final url = dotenv.env['SUPABASE_URL'];
  final anon = dotenv.env['SUPABASE_ANON_KEY'];
  if (url == null || anon == null) {
    throw Exception('SUPABASE_URL / SUPABASE_ANON_KEY manquants dans .env');
  }

  await Supabase.initialize(
    url: url,
    anonKey: anon,
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
        fontFamily: 'SF Pro',
        colorSchemeSeed: const Color(0xFF6C4CF1),
      ),
      home: const _AuthGate(),
    );
  }
}

/// Décide quelle page afficher selon l’état d’auth
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
    final session = Supabase.instance.client.auth.currentSession;

    return StreamBuilder<AuthState>(
      stream: _authStream,
      initialData: session != null
          ? AuthState(AuthChangeEvent.signedIn, session)
          : AuthState(AuthChangeEvent.signedOut, null),
      builder: (context, snapshot) {
        final state = snapshot.data;

        if (state == null || state.event == AuthChangeEvent.signedOut) {
          return const AuthPage();
        } else {
          return const HomePage();
        }
      },
    );
  }
}
