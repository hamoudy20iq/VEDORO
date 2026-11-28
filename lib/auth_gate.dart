import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart' show MainScreen;

const _accent = Color(0xFF9B6DFF);
const _background = Color(0xFF08080D);

final _supabase = Supabase.instance.client;

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (_supabase.auth.currentSession == null) {
          return const AuthScreen();
        }
        return const AuthenticatedHome();
      },
    );
  }
}

class AuthenticatedHome extends StatefulWidget {
  const AuthenticatedHome({super.key});

  @override
  State<AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<AuthenticatedHome> {
  @override
  void initState() {
    super.initState();
    _syncProfile();
  }

  Future<void> _syncProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final metadata = user.userMetadata ?? {};
    final username = (metadata['username'] ?? '').toString().trim().toLowerCase();
    final displayName = (metadata['display_name'] ?? '').toString().trim();
    if (username.isEmpty) return;
    try {
      await _supabase.from('profiles').update({
        'username': username,
        if (displayName.isNotEmpty) 'display_name': displayName,
      }).eq('id', user.id);
    } catch (_) {
      // A username may already be taken. Authentication remains valid;
      // the user can still use the account and edit the profile later.
    }
  }

  @override
  Widget build(BuildContext context) => MainScreen();
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSignup = true;
  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : const Color(0xFF292238),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = _email.text.trim().toLowerCase();
      final password = _password.text;
      if (_isSignup) {
        final username = _username.text.trim().toLowerCase();
        final response = await _supabase.auth.signUp(
          email: email,
          password: password,
          data: {
            'username': username,
            'display_name': _username.text.trim(),
          },
        );
        if (response.session == null) {
          _message('تم إنشاء الطلب. افتح بريدك الإلكتروني وأكّد الحساب، وبعدها سجّل الدخول.');
        } else {
          _message('تم إنشاء حسابك بنجاح 💜');
        }
      } else {
        await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        _message('أهلاً بعودتك إلى VEDORO 💜');
      }
    } on AuthException catch (e) {
      _message(_friendlyError(e.message), error: true);
    } catch (e) {
      _message('تعذر إكمال العملية. تحقق من الإنترنت وحاول مرة ثانية.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+
    final value = message.toLowerCase();
    if (value.contains('already registered') || value.contains('already been registered')) {
      return 'هذا البريد مسجّل مسبقاً. جرّب تسجيل الدخول.';
    }
    if (value.contains('invalid login credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }
    if (value.contains('email not confirmed')) {
      return 'لازم تأكد بريدك الإلكتروني أولاً.';
    }
    if (value.contains('password')) {
      return 'كلمة المرور غير مقبولة. استخدم 8 أحرف أو أكثر.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 28),
                    const Icon(Icons.play_circle_fill_rounded, color: _accent, size: 76),
                    const SizedBox(height: 12),
                    const Text(
                      'VEDORO',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 4),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'مجتمعك. فيديوهاتك. لحظاتك.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 15),
                    ),
                    const SizedBox(height: 38),
                    Text(
                      _isSignup ? 'أنشئ حسابك' : 'سجّل دخولك',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    if (_isSignup) ...[
                      _field(
                        controller: _username,
                        label: 'اسم المستخدم',
                        icon: Icons.alternate_email,
                        validator: (value) {
                          final v = (value ?? '').trim();
                          if (v.length < 3 || v.length > 20) return 'الاسم من 3 إلى 20 حرفاً';
                          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
                            return 'استخدم أحرف إنجليزية وأرقام وشرطة سفلية فقط';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    _field(
                      controller: _email,
                      label: 'البريد الإلكتروني',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                          return 'أدخل بريداً إلكترونياً صحيحاً';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(_hidePassword ? Icons.visibility_off : Icons.visibility),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: .06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      validator: (value) {
                        if ((value ?? '').length < 8) return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                        return null;
                      },
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isSignup ? 'إنشاء الحساب' : 'تسجيل الدخول', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    if (!_isSignup)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _loading ? null : _resetPassword,
                          child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: Colors.white70)),
                        ),
                      ),
                    TextButton(
                      onPressed: _loading ? null : () => setState(() => _isSignup = !_isSignup),
                      child: Text(
                        _isSignup ? 'عندك حساب؟ سجّل دخولك' : 'ما عندك حساب؟ أنشئ حساب جديد',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'بالمتابعة أنت توافق على شروط استخدام VEDORO.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white.withValues(alpha: .06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      validator: validator,
    );
  }
}
).hasMatch(email)) {
      _message('اكتب بريدك الإلكتروني أولاً حتى نرسل رابط الاستعادة.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      _message('إذا كان البريد مسجلاً، راح توصلك رسالة لاستعادة كلمة المرور.');
    } on AuthException catch (e) {
      _message(_friendlyError(e.message), error: true);
    } catch (_) {
      _message('تعذر إرسال رابط الاستعادة. تحقق من الإنترنت.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String message) {
    final value = message.toLowerCase();
    if (value.contains('already registered') || value.contains('already been registered')) {
      return 'هذا البريد مسجّل مسبقاً. جرّب تسجيل الدخول.';
    }
    if (value.contains('invalid login credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }
    if (value.contains('email not confirmed')) {
      return 'لازم تأكد بريدك الإلكتروني أولاً.';
    }
    if (value.contains('password')) {
      return 'كلمة المرور غير مقبولة. استخدم 8 أحرف أو أكثر.';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 28),
                    const Icon(Icons.play_circle_fill_rounded, color: _accent, size: 76),
                    const SizedBox(height: 12),
                    const Text(
                      'VEDORO',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 4),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'مجتمعك. فيديوهاتك. لحظاتك.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 15),
                    ),
                    const SizedBox(height: 38),
                    Text(
                      _isSignup ? 'أنشئ حسابك' : 'سجّل دخولك',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    if (_isSignup) ...[
                      _field(
                        controller: _username,
                        label: 'اسم المستخدم',
                        icon: Icons.alternate_email,
                        validator: (value) {
                          final v = (value ?? '').trim();
                          if (v.length < 3 || v.length > 20) return 'الاسم من 3 إلى 20 حرفاً';
                          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(v)) {
                            return 'استخدم أحرف إنجليزية وأرقام وشرطة سفلية فقط';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    _field(
                      controller: _email,
                      label: 'البريد الإلكتروني',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                          return 'أدخل بريداً إلكترونياً صحيحاً';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(_hidePassword ? Icons.visibility_off : Icons.visibility),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: .06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                      validator: (value) {
                        if ((value ?? '').length < 8) return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                        return null;
                      },
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_isSignup ? 'إنشاء الحساب' : 'تسجيل الدخول', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _loading ? null : () => setState(() => _isSignup = !_isSignup),
                      child: Text(
                        _isSignup ? 'عندك حساب؟ سجّل دخولك' : 'ما عندك حساب؟ أنشئ حساب جديد',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'بالمتابعة أنت توافق على شروط استخدام VEDORO.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white.withValues(alpha: .06),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
      validator: validator,
    );
  }
}
