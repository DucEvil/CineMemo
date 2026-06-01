import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_routes.dart';
import '../../widgets/buttons/google_signin_button.dart';

enum _AuthAction { none, email, google }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _initializedFromRouteArgs = false;
  bool _registerMode = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  _AuthAction _activeAuthAction = _AuthAction.none;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromRouteArgs) {
      return;
    }
    _initializedFromRouteArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['registerMode'] is bool) {
      _registerMode = args['registerMode'] as bool;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isEmailValid(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }

  Future<void> _finishSuccessfulLogin(AuthProvider auth) async {
    if (auth.needsBirthDate) {
      await Navigator.pushNamed(context, AppRoutes.birthdate);
      if (!mounted) {
        return;
      }

      if (auth.needsBirthDate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập ngày sinh để tiếp tục.')),
        );
        return;
      }
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
      return;
    }

    Navigator.pushReplacementNamed(context, AppRoutes.movieList);
  }

  Future<void> _submit(AuthProvider auth) async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    setState(() {
      _activeAuthAction = _AuthAction.email;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    var success = false;

    try {
      if (_registerMode) {
        success = await auth.signUpWithEmailPassword(
          email: email,
          password: password,
        );

        if (success && mounted) {
          setState(() {
            _registerMode = false;
          });
          _passwordController.clear();
          _confirmPasswordController.clear();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đăng ký thành công. Vui lòng đăng nhập.'),
            ),
          );
        }
      } else {
        success = await auth.signInWithEmailPassword(
          email: email,
          password: password,
        );

        if (success && mounted) {
          await _finishSuccessfulLogin(auth);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _activeAuthAction = _AuthAction.none;
        });
      }
    }
  }

  Future<void> _signInWithGoogle(AuthProvider auth) async {
    setState(() {
      _activeAuthAction = _AuthAction.google;
    });

    try {
      final success = await auth.signInWithGoogle();
      if (success && mounted) {
        await _finishSuccessfulLogin(auth);
      }
    } finally {
      if (mounted) {
        setState(() {
          _activeAuthAction = _AuthAction.none;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final appState = Provider.of<AppStateProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(_registerMode ? 'Đăng ký' : 'Đăng nhập')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'CineMemo',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'Đăng nhập để đặt vé, lưu nhật ký và đồng bộ dữ liệu.',
                style: TextStyle(color: Color(0xFF475569)),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _AuthModeTab(
                        label: 'Đăng nhập',
                        selected: !_registerMode,
                        onTap: () {
                          if (!_registerMode) {
                            return;
                          }
                          setState(() {
                            _registerMode = false;
                          });
                          Provider.of<AuthProvider>(context, listen: false).clearError();
                        },
                      ),
                    ),
                    Expanded(
                      child: _AuthModeTab(
                        label: 'Đăng ký',
                        selected: _registerMode,
                        onTap: () {
                          if (_registerMode) {
                            return;
                          }
                          setState(() {
                            _registerMode = true;
                          });
                          Provider.of<AuthProvider>(context, listen: false).clearError();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (appState.warning != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Text(
                    appState.warning!,
                    style: const TextStyle(
                      color: Color(0xFF78350F),
                      fontSize: 12,
                    ),
                  ),
                ),
              if (auth.error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    auth.error!,
                    style: const TextStyle(
                      color: Color(0xFF7F1D1D),
                      fontSize: 12,
                    ),
                  ),
                ),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'you@example.com',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        final email = (value ?? '').trim();
                        if (email.isEmpty) {
                          return 'Vui lòng nhập email.';
                        }
                        if (!_isEmailValid(email)) {
                          return 'Email không hợp lệ.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final password = value ?? '';
                        if (password.isEmpty) {
                          return 'Vui lòng nhập mật khẩu.';
                        }
                        if (password.length < 6) {
                          return 'Mật khẩu phải có ít nhất 6 ký tự.';
                        }
                        return null;
                      },
                    ),
                    if (_registerMode) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Nhập lại mật khẩu',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final confirm = value ?? '';
                          if (confirm.isEmpty) {
                            return 'Vui lòng nhập lại mật khẩu.';
                          }
                          if (confirm != _passwordController.text) {
                            return 'Mật khẩu nhập lại không khớp.';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: auth.isLoading
                            ? null
                            : () => _submit(Provider.of<AuthProvider>(context, listen: false)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child:
                            auth.isLoading &&
                                _activeAuthAction == _AuthAction.email
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _registerMode
                                    ? 'Tạo tài khoản'
                                    : 'Đăng nhập bằng email',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'hoặc',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              GoogleSignInButton(
                loading:
                    auth.isLoading && _activeAuthAction == _AuthAction.google,
                onPressed: () async {
                  if (auth.isLoading) {
                    return;
                  }
                  await _signInWithGoogle(Provider.of<AuthProvider>(context, listen: false));
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Lần đầu đăng nhập, bạn sẽ được yêu cầu nhập ngày sinh để kiểm tra giới hạn độ tuổi cho phim 18+.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthModeTab extends StatelessWidget {
  const _AuthModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x19000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF475569),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
