import '../l10n/app_copy.dart';

import 'package:material_ui/material_ui.dart';
import '../data/api/api_client.dart';
import '../data/api/http_repository.dart';
import '../data/repository.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import '../services/supabase_bridge.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/primitives.dart';
import 'onboarding/topics_screen.dart';
import '../widgets/sign_out_button.dart';

enum _Mode { login, register, forgot, reset }

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, this.resetToken, this.register = false});
  final bool register;
  final String? resetToken;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  late _Mode _mode;
  bool _busy = false;
  bool _visible = false;
  String? _error;
  String? _message;
  ApiClient? get _api => AppScope.read(context).repo is HttpRepository
      ? (AppScope.read(context).repo as HttpRepository).api
      : null;
  @override
  void initState() {
    super.initState();
    _mode = widget.resetToken != null
        ? _Mode.reset
        : widget.register
            ? _Mode.register
            : _Mode.login;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _change(_Mode mode) {
    if (_busy) return;
    setState(() {
      _mode = mode;
      _error = null;
      _message = null;
      _password.clear();
      _confirmPassword.clear();
      _form.currentState?.reset();
    });
  }

  Future<void> _run(Future<void> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await task();
    } on GoogleSignInException catch (e) {
      if (mounted && e.code != GoogleSignInExceptionCode.canceled) {
        setState(() =>
            _error = 'Não foi possível entrar com Google. Tente novamente.');
      }
    } on AuthException catch (e) {
      if (mounted && e.code != 'flow_state_not_found') {
        setState(() => _error =
            'Não foi possível autenticar sua conta Google. Tente novamente.');
      }
    } on RepoException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'Não foi possível concluir. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishAccount() async {
    final state = AppScope.read(context);
    await state.reloadIdentity();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const TopicsScreen()),
      (_) => false,
    );
  }

  void _requireApi() {
    if (_api == null) {
      throw const RepoException(
          'O acesso à conta está indisponível nesta versão. Conecte o aplicativo ao servidor e tente novamente.');
    }
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    await _run(() async {
      _requireApi();
      switch (_mode) {
        case _Mode.login:
          await _api!.signIn(_email.text, _password.text);
          _password.clear();
          await _finishAccount();
        case _Mode.register:
          await _api!.signUp(_name.text, _email.text, _password.text);
          _password.clear();
          await _finishAccount();
        case _Mode.forgot:
          await _api!.forgotPassword(_email.text);
          if (mounted) {
            setState(() => _message =
                'Se esse email tiver uma conta, você receberá um link para criar outra senha.');
          }
        case _Mode.reset:
          await _api!.resetPassword(widget.resetToken!, _password.text);
          _password.clear();
          if (mounted) {
            setState(() {
              _mode = _Mode.login;
              _message = 'Senha alterada. Entre com sua nova senha.';
            });
          }
      }
    });
  }

  Future<void> _social(bool apple) => _run(() async {
        _requireApi();
        if (!SupabaseBridge.ready) {
          throw const RepoException(
              'O login com Google ainda não está disponível nesta versão. Use email e senha.');
        }
        final token = await SupabaseBridge.socialToken(apple: apple);
        await _api!.socialSignIn(token);
        await _finishAccount();
      });
  Future<void> _link(bool apple) => _run(() async {
        _requireApi();
        if (!SupabaseBridge.ready) {
          throw const RepoException(
              'O login com Google ainda não está disponível nesta versão. Use email e senha.');
        }
        final token = await SupabaseBridge.socialToken(apple: apple);
        await _api!.linkSocial(token);
        if (mounted) setState(() => _message = 'Acesso vinculado à sua conta.');
      });
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final account = state.isAccount && widget.resetToken == null;
    final title = account
        ? 'Sua conta'
        : switch (_mode) {
            _Mode.login => 'Entrar no news.dev',
            _Mode.register => 'Criar sua conta',
            _Mode.forgot => 'Recuperar senha',
            _Mode.reset => 'Criar nova senha'
          };
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(title))),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      if (account) ...[
                        Text(state.userName, style: RText.title2),
                        if (state.userEmail != null) ...[
                          const SizedBox(height: 8),
                          Text(state.userEmail!, style: RText.body)
                        ],
                        const SizedBox(height: 24),
                        if (SupabaseBridge.ready) ...[
                          RButton('Vincular Google',
                              kind: RButtonKind.secondary,
                              onPressed: _busy ? null : () => _link(false)),
                          const SizedBox(height: 8),
                          RButton('Vincular Apple',
                              kind: RButtonKind.secondary,
                              onPressed: _busy ? null : () => _link(true)),
                          const SizedBox(height: 16),
                        ],
                        const SignOutButton(),
                      ] else ...[
                        const Center(child: BrandLockup(size: 56)),
                        const SizedBox(height: 24),
                        Text(
                            _mode == _Mode.register
                                ? 'Crie sua conta para escolher seus interesses e montar seu feed.'
                                : 'Entre para continuar e personalizar suas notícias.',
                            style: RText.body.withColor(RColors.textSecondary)),
                        const SizedBox(height: 24),
                        Form(
                            key: _form,
                            child: AutofillGroup(
                                child: Column(children: [
                              if (_mode == _Mode.register) ...[
                                TextFormField(
                                    controller: _name,
                                    decoration: InputDecoration(
                                        labelText: context.tr('Nome')),
                                    autofillHints: const [AutofillHints.name],
                                    maxLength: 80,
                                    enabled: !_busy,
                                    validator: (value) =>
                                        (value?.trim().isEmpty ?? true)
                                            ? context.tr('Informe seu nome.')
                                            : null),
                                const SizedBox(height: 12),
                              ],
                              if (_mode != _Mode.reset) ...[
                                TextFormField(
                                    controller: _email,
                                    decoration: InputDecoration(
                                        labelText: context.tr('Email')),
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.email],
                                    autocorrect: false,
                                    maxLength: 254,
                                    enabled: !_busy,
                                    validator: (value) => value != null &&
                                            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                                .hasMatch(value.trim())
                                        ? null
                                        : context
                                            .tr('Informe um email válido.')),
                                const SizedBox(height: 12),
                              ],
                              if (_mode != _Mode.forgot) ...[
                                TextFormField(
                                    controller: _password,
                                    decoration: InputDecoration(
                                        labelText: context.tr('Senha'),
                                        suffixIcon: IconButton(
                                            onPressed: () => setState(
                                                () => _visible = !_visible),
                                            icon: Icon(_visible
                                                ? Icons.visibility_off
                                                : Icons.visibility))),
                                    obscureText: !_visible,
                                    enableSuggestions: false,
                                    autocorrect: false,
                                    autofillHints: [
                                      _mode == _Mode.login
                                          ? AutofillHints.password
                                          : AutofillHints.newPassword
                                    ],
                                    enabled: !_busy,
                                    validator: (value) => value == null ||
                                            value.isEmpty
                                        ? context.tr('Informe sua senha.')
                                        : _mode != _Mode.login &&
                                                value.length < 8
                                            ? context.tr(
                                                'Use pelo menos 8 caracteres.')
                                            : null,
                                    onFieldSubmitted: (_) => _submit()),
                                const SizedBox(height: 24),
                              ],
                              if (_mode == _Mode.register ||
                                  _mode == _Mode.reset) ...[
                                TextFormField(
                                  controller: _confirmPassword,
                                  decoration: InputDecoration(
                                      labelText: context.tr('Confirmar senha')),
                                  obscureText: !_visible,
                                  enableSuggestions: false,
                                  autocorrect: false,
                                  enabled: !_busy,
                                  validator: (value) => value == _password.text
                                      ? null
                                      : 'As senhas precisam ser iguais.',
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                                const SizedBox(height: 24),
                              ],
                              RButton(
                                  _busy
                                      ? 'Aguarde…'
                                      : switch (_mode) {
                                          _Mode.login => 'Entrar',
                                          _Mode.register => 'Criar conta',
                                          _Mode.forgot => 'Enviar link',
                                          _Mode.reset => 'Salvar nova senha'
                                        },
                                  onPressed: _busy ? null : _submit),
                            ]))),
                        if (_mode == _Mode.login) ...[
                          RButton('Esqueci minha senha',
                              kind: RButtonKind.text,
                              onPressed:
                                  _busy ? null : () => _change(_Mode.forgot)),
                          RButton('Criar conta',
                              kind: RButtonKind.secondary,
                              onPressed:
                                  _busy ? null : () => _change(_Mode.register)),
                        ] else if (_mode != _Mode.reset)
                          RButton('Voltar para entrar',
                              kind: RButtonKind.text,
                              onPressed:
                                  _busy ? null : () => _change(_Mode.login)),
                        if (_mode == _Mode.login ||
                            _mode == _Mode.register) ...[
                          const SizedBox(height: 20),
                          const Row(children: [
                            Expanded(child: Divider()),
                            Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Text('ou')),
                            Expanded(child: Divider())
                          ]),
                          const SizedBox(height: 20),
                          RButton('Continuar com Google',
                              kind: RButtonKind.secondary,
                              onPressed: _busy ? null : () => _social(false)),
                        ],
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                            liveRegion: true,
                            child: Text(_error!,
                                style: RText.body.withColor(RColors.urgent)))
                      ],
                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                            liveRegion: true,
                            child: Text(_message!, style: RText.body))
                      ],
                    ],
                  )))),
    );
  }
}
