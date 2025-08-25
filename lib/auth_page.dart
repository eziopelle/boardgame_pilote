import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  final _signupEmail = TextEditingController();
  final _signupPass = TextEditingController();
  final _signupConfirm = TextEditingController();

  bool _loading = false;
  StreamSubscription<AuthState>? _authSub;

  SupabaseClient get _supa => Supabase.instance.client;

  // URL de redirection pour OAuth (gère GitHub Pages /boardgame_pilote/)
  Uri _redirectUri() {
    if (kIsWeb) {
      final u = Uri.base;
      final path = u.path.endsWith('/') ? u.path : '${u.path}/';
      // ❌ NE PAS supprimer la query ici
      return u.replace(path: path);
    }
    // Mobile/Desktop : mets ton deeplink si tu en utilises
    return Uri.parse('https://eziopelle.github.io/boardgame_pilote/');
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);

    final s = _supa.auth.currentSession;
    debugPrint('session? ${Supabase.instance.client.auth.currentSession != null}'); // Diagnostic express

    if (s != null) _goHome();

    _authSub = _supa.auth.onAuthStateChange.listen((state) {
      debugPrint('[auth] event=${state.event} hasSession=${state.session != null}'); // Diagnostic express
      // ➜ dès qu’une session existe (PKCE/Email/OAuth), bascule Home
      if (state.session != null && mounted) _goHome();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _tab.dispose();
    _loginEmail.dispose();
    _loginPass.dispose();
    _signupEmail.dispose();
    _signupPass.dispose();
    _signupConfirm.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _withLoading(Future<void> Function() fn) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await fn();
    } on AuthException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('Erreur: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goHome() {
    // Remplace la page d’auth par Home
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  // === LOGIQUES ===

  Future<void> _loginEmailPassword() async {
    final email = _loginEmail.text.trim();
    final pass = _loginPass.text;
    if (email.isEmpty || pass.isEmpty) {
      _toast('Email et mot de passe requis.');
      return;
    }
    await _withLoading(() async {
      final res = await _supa.auth.signInWithPassword(email: email, password: pass);
      if (res.session != null && mounted) _goHome(); // ✅ pas de maybePop()
    });
  }

  Future<void> _signupEmailPassword() async {
    final email = _signupEmail.text.trim();
    final pass = _signupPass.text;
    final confirm = _signupConfirm.text;
    if (email.isEmpty || pass.isEmpty) {
      _toast('Email et mot de passe requis.');
      return;
    }
    if (pass.length < 6) {
      _toast('Mot de passe trop court (min 6 caractères).');
      return;
    }
    if (pass != confirm) {
      _toast('La confirmation ne correspond pas.');
      return;
    }
    await _withLoading(() async {
      await _supa.auth.signUp(email: email, password: pass);
      _toast('Compte créé. Vérifie ton e-mail si la confirmation est activée.');
      _tab.animateTo(0);
    });
  }

  Future<void> _resetPassword() async {
    final email = _loginEmail.text.trim();
    if (email.isEmpty) {
      _toast('Saisis ton email pour réinitialiser le mot de passe.');
      return;
    }
    await _withLoading(() async {
      await _supa.auth.resetPasswordForEmail(email, redirectTo: _redirectUri().toString());
      _toast('Email de réinitialisation envoyé si le compte existe.');
    });
  }

  Future<void> _oauthGoogle() async {
    await _withLoading(() async {
      await _supa.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _redirectUri().toString(), // ✅ essentiel en Web sous /boardgame_pilote/
      );
    });
  }

  Future<void> _oauthApple() async {
    await _withLoading(() async {
      await _supa.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: _redirectUri().toString(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _loading,
          child: Stack(
            children: [
              if (isWide)
                Row(
                  children: [
                    // LEFT: Form
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 620),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Text(
                                  'Boardgame Pilote',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 20),
                                _TabsHeader(tabController: _tab),
                                const SizedBox(height: 24),
                                SizedBox(
                                  height: 420,
                                  child: TabBarView(
                                    controller: _tab,
                                    physics: const NeverScrollableScrollPhysics(),
                                    children: [
                                      _LoginForm(
                                        email: _loginEmail,
                                        pass: _loginPass,
                                        onLogin: _loginEmailPassword,
                                        onForgot: _resetPassword,
                                        onGoogle: _oauthGoogle,
                                        onApple: _oauthApple,
                                      ),
                                      _SignupForm(
                                        email: _signupEmail,
                                        pass: _signupPass,
                                        confirm: _signupConfirm,
                                        onSignup: _signupEmailPassword,
                                        onGoogle: _oauthGoogle,
                                        onApple: _oauthApple,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // RIGHT: Image pleine hauteur
                    const Expanded(
                      child: _RightImagePanel(
                        imageUrl:
                            'https://images.unsplash.com/photo-1465447142348-e9952c393450?q=80&w=1974&auto=format&fit=crop',
                      ),
                    ),
                  ],
                )
              else
                _CompactStack(
                  imageUrl:
                      'https://images.unsplash.com/photo-1465447142348-e9952c393450?q=80&w=1974&auto=format&fit=crop',
                  tab: _tab,
                  loginEmail: _loginEmail,
                  loginPass: _loginPass,
                  signupEmail: _signupEmail,
                  signupPass: _signupPass,
                  signupConfirm: _signupConfirm,
                  onLogin: _loginEmailPassword,
                  onForgot: _resetPassword,
                  onSignup: _signupEmailPassword,
                  onGoogle: _oauthGoogle,
                  onApple: _oauthApple,
                ),

              if (_loading)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x11000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabsHeader extends StatelessWidget {
  const _TabsHeader({required this.tabController});
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabBar(
          controller: tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorSize: TabBarIndicatorSize.tab,
          labelPadding: const EdgeInsets.only(right: 24),
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          indicatorWeight: 3,
          indicatorColor: const Color(0xFF6C4CF1),
          labelStyle: t.displaySmall?.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: t.displaySmall?.copyWith(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Connexion'),
            Tab(text: 'Inscription'),
          ],
        ),
      ],
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm({
    required this.email,
    required this.pass,
    required this.onLogin,
    required this.onForgot,
    required this.onGoogle,
    required this.onApple,
  });
  final TextEditingController email;
  final TextEditingController pass;
  final VoidCallback onLogin;
  final VoidCallback onForgot;
  final VoidCallback onGoogle;
  final VoidCallback onApple;

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connectez-vous ici', style: t.titleMedium?.copyWith(color: Colors.black.withOpacity(0.7))),
        const SizedBox(height: 16),
        TextField(
          controller: widget.email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.pass,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Password',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 260,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C4CF1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              elevation: 4,
            ),
            onPressed: widget.onLogin,
            child: const Text('Connexion', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: widget.onForgot,
          child: const Text('Mot de passe oublié'),
        ),
        const SizedBox(height: 8),
        Text(
          'Ou créer un compte ici',
          style: t.bodyMedium?.copyWith(color: Colors.black.withOpacity(0.6)),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            _OAuthButton.google(onPressed: widget.onGoogle),
            _OAuthButton.apple(onPressed: widget.onApple),
          ],
        ),
      ],
    );
  }
}

class _SignupForm extends StatefulWidget {
  const _SignupForm({
    required this.email,
    required this.pass,
    required this.confirm,
    required this.onSignup,
    required this.onGoogle,
    required this.onApple,
  });
  final TextEditingController email;
  final TextEditingController pass;
  final TextEditingController confirm;
  final VoidCallback onSignup;
  final VoidCallback onGoogle;
  final VoidCallback onApple;

  @override
  State<_SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<_SignupForm> {
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Inscrivez-vous ici', style: t.titleMedium?.copyWith(color: Colors.black.withOpacity(0.7))),
        const SizedBox(height: 16),
        TextField(
          controller: widget.email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.pass,
          obscureText: _obscure1,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: 'Password',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure1 = !_obscure1),
              icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.confirm,
          obscureText: _obscure2,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure2 = !_obscure2),
              icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 260,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6C4CF1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              elevation: 4,
            ),
            onPressed: widget.onSignup,
            child: const Text('Create Account', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 20),
        Text('Or sign up with', style: t.bodyMedium?.copyWith(color: Colors.black.withOpacity(0.6))),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            _OAuthButton.google(onPressed: widget.onGoogle),
            _OAuthButton.apple(onPressed: widget.onApple),
          ],
        ),
      ],
    );
  }
}

class _OAuthButton extends StatelessWidget {
  const _OAuthButton.google({super.key, required this.onPressed})
      : icon = const _GoogleLogo(),
        label = 'Continue with Google';
  const _OAuthButton.apple({super.key, required this.onPressed})
      : icon = const Icon(CupertinoIcons.lock, size: 18),
        label = 'Continue with Apple';

  final Widget icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 10),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        'G',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black.withOpacity(0.85)),
      ),
    );
  }
}

class _RightImagePanel extends StatelessWidget {
  const _RightImagePanel({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(imageUrl, fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.05)),
        ],
      ),
    );
  }
}

class _CompactStack extends StatelessWidget {
  const _CompactStack({
    required this.imageUrl,
    required this.tab,
    required this.loginEmail,
    required this.loginPass,
    required this.signupEmail,
    required this.signupPass,
    required this.signupConfirm,
    required this.onLogin,
    required this.onForgot,
    required this.onSignup,
    required this.onGoogle,
    required this.onApple,
  });

  final String imageUrl;
  final TabController tab;
  final TextEditingController loginEmail;
  final TextEditingController loginPass;
  final TextEditingController signupEmail;
  final TextEditingController signupPass;
  final TextEditingController signupConfirm;
  final VoidCallback onLogin;
  final VoidCallback onForgot;
  final VoidCallback onSignup;
  final VoidCallback onGoogle;
  final VoidCallback onApple;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: _RightImagePanel(imageUrl: imageUrl),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Boardgame Pilote', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _TabsHeader(tabController: tab),
              const SizedBox(height: 16),
              SizedBox(
                height: 520,
                child: TabBarView(
                  controller: tab,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _LoginForm(
                      email: loginEmail,
                      pass: loginPass,
                      onLogin: onLogin,
                      onForgot: onForgot,
                      onGoogle: onGoogle,
                      onApple: onApple,
                    ),
                    _SignupForm(
                      email: signupEmail,
                      pass: signupPass,
                      confirm: signupConfirm,
                      onSignup: onSignup,
                      onGoogle: onGoogle,
                      onApple: onApple,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
