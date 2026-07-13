// Signature: dev.tswicolly03
import 'package:flutter/material.dart';

import '../services/auth/account_controller.dart';
import '../services/auth/auth_models.dart';
import '../services/sync/sync_coordinator.dart';
import '../services/sync/sync_models.dart';

enum _AccountFormMode { signIn, signUp }

class AccountPage extends StatefulWidget {
  const AccountPage({
    super.key,
    required this.accountController,
    this.syncCoordinator,
  });

  final AccountController accountController;
  final SyncCoordinator? syncCoordinator;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmationController = TextEditingController();
  _AccountFormMode _mode = _AccountFormMode.signIn;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Listenable> listenables = <Listenable>[
      widget.accountController,
      if (widget.syncCoordinator != null) widget.syncCoordinator!,
    ];
    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (BuildContext context, Widget? child) {
        final AccountController account = widget.accountController;
        return Scaffold(
          appBar: AppBar(title: const Text('Conta e sincronizacao')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: <Widget>[
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (account.errorMessage != null)
                          _MessageCard(
                            key: const Key('auth-error-message'),
                            icon: Icons.error_outline_rounded,
                            message: account.errorMessage!,
                            error: true,
                          ),
                        if (account.noticeMessage != null)
                          _MessageCard(
                            key: const Key('auth-notice-message'),
                            icon: Icons.check_circle_outline_rounded,
                            message: account.noticeMessage!,
                          ),
                        if (account.sessionExpired)
                          const _MessageCard(
                            icon: Icons.lock_clock_outlined,
                            message:
                                'A sessao expirou. A leitura local continua disponivel.',
                            error: true,
                          ),
                        if (!account.isConfigured)
                          const _LocalModeCard()
                        else if (account.passwordRecovery)
                          _buildPasswordRecovery(account)
                        else if (account.isSignedIn)
                          _buildSignedIn(account)
                        else
                          _buildSignedOut(account),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSignedOut(AccountController account) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Continue localmente ou conecte sua conta',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Entrar e sincronizar e opcional. Nenhum livro e enviado sem uma '
          'escolha explicita.',
        ),
        const SizedBox(height: 24),
        SegmentedButton<_AccountFormMode>(
          segments: const <ButtonSegment<_AccountFormMode>>[
            ButtonSegment<_AccountFormMode>(
              value: _AccountFormMode.signIn,
              label: Text('Entrar'),
              icon: Icon(Icons.login_rounded),
            ),
            ButtonSegment<_AccountFormMode>(
              value: _AccountFormMode.signUp,
              label: Text('Criar conta'),
              icon: Icon(Icons.person_add_alt_1_rounded),
            ),
          ],
          selected: <_AccountFormMode>{_mode},
          onSelectionChanged: account.busy
              ? null
              : (Set<_AccountFormMode> value) {
                  setState(() {
                    _mode = value.first;
                    _formKey.currentState?.reset();
                  });
                },
        ),
        const SizedBox(height: 20),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                textField: true,
                label: 'E-mail da conta Veredra',
                child: TextFormField(
                  key: const Key('auth-email-field'),
                  controller: _emailController,
                  enabled: !account.busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const <String>[AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (String? value) =>
                      AuthInputValidator.email(value ?? ''),
                ),
              ),
              const SizedBox(height: 14),
              Semantics(
                textField: true,
                label: 'Senha da conta Veredra',
                child: TextFormField(
                  key: const Key('auth-password-field'),
                  controller: _passwordController,
                  enabled: !account.busy,
                  obscureText: _obscurePassword,
                  autofillHints: _mode == _AccountFormMode.signIn
                      ? const <String>[AutofillHints.password]
                      : const <String>[AutofillHints.newPassword],
                  textInputAction: _mode == _AccountFormMode.signUp
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (_mode == _AccountFormMode.signIn) {
                      _submit(account);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    helperText: _mode == _AccountFormMode.signUp
                        ? '10+ caracteres, maiuscula, minuscula e numero'
                        : null,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.password_rounded),
                    suffixIcon: IconButton(
                      tooltip:
                          _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (String? value) => _mode == _AccountFormMode.signUp
                      ? AuthInputValidator.password(value ?? '')
                      : (value ?? '').isEmpty
                          ? 'Informe sua senha.'
                          : null,
                ),
              ),
              if (_mode == _AccountFormMode.signUp) ...<Widget>[
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('auth-password-confirmation-field'),
                  controller: _confirmationController,
                  enabled: !account.busy,
                  obscureText: true,
                  autofillHints: const <String>[AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar senha',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (String? value) =>
                      value != _passwordController.text
                          ? 'As senhas nao coincidem.'
                          : null,
                  onFieldSubmitted: (_) => _submit(account),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('auth-submit-button'),
                onPressed: account.busy ? null : () => _submit(account),
                icon: account.busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _mode == _AccountFormMode.signIn
                            ? Icons.login_rounded
                            : Icons.person_add_alt_1_rounded,
                      ),
                label: Text(
                  _mode == _AccountFormMode.signIn ? 'Entrar' : 'Criar conta',
                ),
              ),
              if (_mode == _AccountFormMode.signIn)
                TextButton(
                  key: const Key('forgot-password-button'),
                  onPressed:
                      account.busy ? null : () => _recoverPassword(account),
                  child: const Text('Esqueci minha senha'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          children: <Widget>[
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('ou'),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const Key('google-sign-in-button'),
          onPressed: account.busy ? null : account.signInWithGoogle,
          icon: const Icon(Icons.g_mobiledata_rounded),
          label: const Text('Entrar com Google'),
        ),
      ],
    );
  }

  Widget _buildPasswordRecovery(AccountController account) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Defina uma nova senha',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
            'O link de recuperacao foi validado. Escolha uma nova senha.'),
        const SizedBox(height: 20),
        TextFormField(
          key: const Key('recovery-password-field'),
          controller: _passwordController,
          enabled: !account.busy,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Nova senha',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('recovery-submit-button'),
          onPressed: account.busy
              ? null
              : () {
                  final String? error =
                      AuthInputValidator.password(_passwordController.text);
                  if (error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error)),
                    );
                    return;
                  }
                  account.updatePassword(_passwordController.text);
                },
          child: const Text('Atualizar senha'),
        ),
      ],
    );
  }

  Widget _buildSignedIn(AccountController account) {
    final SyncCoordinator? sync = widget.syncCoordinator;
    final AuthUser user = account.user!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.person_rounded)),
          title: Text(user.email),
          subtitle: Text(
            user.emailVerified ? 'E-mail verificado' : 'Confirmacao pendente',
          ),
          trailing: Icon(
            user.emailVerified
                ? Icons.verified_user_rounded
                : Icons.mark_email_unread_outlined,
          ),
        ),
        if (!user.emailVerified)
          const _MessageCard(
            icon: Icons.outgoing_mail,
            message:
                'Confirme seu e-mail. A leitura local permanece disponivel.',
          ),
        const SizedBox(height: 20),
        Text('Sincronizacao', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: <Widget>[
              ListTile(
                leading: Icon(_syncIcon(sync)),
                title: Text(sync?.phase.label ?? 'Somente local'),
                subtitle: Text(
                  sync == null
                      ? 'Sincronizacao indisponivel neste build.'
                      : '${sync.pendingCount} alteracoes pendentes',
                ),
              ),
              SwitchListTile(
                key: const Key('sync-consent-switch'),
                value: sync?.preferences.enabled ?? false,
                onChanged:
                    sync == null || account.busy ? null : sync.setConsent,
                title: const Text('Sincronizar dados de leitura'),
                subtitle: const Text(
                  'Metadados, preferencias, progresso, marcadores, anotacoes, '
                  'destaques e estatisticas. Exige consentimento.',
                ),
              ),
              SwitchListTile(
                key: const Key('sync-automatic-switch'),
                value: sync?.preferences.automatic ?? true,
                onChanged:
                    sync == null || !(sync.preferences.enabled) || account.busy
                        ? null
                        : sync.setAutomatic,
                title: const Text('Sincronizacao automatica controlada'),
                subtitle: const Text('Tambem pode ser executada manualmente.'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('sync-now-button'),
                    onPressed: sync == null ||
                            !sync.preferences.enabled ||
                            sync.phase == SyncPhase.synchronizing
                        ? null
                        : sync.syncNow,
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Sincronizar agora'),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Armazenamento', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Card(
          child: Column(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.data_usage_rounded),
                title: Text('Somente dados de leitura'),
                subtitle:
                    Text('Politica atual. Arquivos e capas ficam locais.'),
                trailing: Icon(Icons.check_circle_rounded),
              ),
              ListTile(
                enabled: false,
                leading: Icon(Icons.cloud_upload_outlined),
                title: Text('Sincronizacao completa'),
                subtitle: Text(
                  'Bloqueada ate o upload criptograficamente verificado e os '
                  'limites de quota serem habilitados.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Dispositivos', style: Theme.of(context).textTheme.titleLarge),
        const Card(
          child: ListTile(
            leading: Icon(Icons.devices_rounded),
            title: Text('Este dispositivo'),
            subtitle: Text(
              'Recebe um UUID local. Nenhum identificador de hardware e coletado.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Privacidade', style: Theme.of(context).textTheme.titleLarge),
        const Card(
          child: ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Leitura continua mesmo sem backend'),
            subtitle: Text(
              'Erros de conta ou sincronizacao nunca bloqueiam a biblioteca '
              'local. Conteudo de livros nao e enviado no modo atual.',
            ),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          key: const Key('sign-out-button'),
          onPressed: account.busy ? null : account.signOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sair da conta'),
        ),
        TextButton.icon(
          key: const Key('delete-account-button'),
          onPressed: account.busy ? null : () => _confirmDeleteAccount(account),
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text('Excluir conta e dados remotos'),
        ),
      ],
    );
  }

  Future<void> _submit(AccountController account) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_mode == _AccountFormMode.signIn) {
      await account.signIn(_emailController.text, _passwordController.text);
    } else {
      await account.signUp(_emailController.text, _passwordController.text);
    }
  }

  Future<void> _recoverPassword(AccountController account) async {
    final String? error = AuthInputValidator.email(_emailController.text);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await account.sendPasswordReset(_emailController.text);
  }

  Future<void> _confirmDeleteAccount(AccountController account) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Excluir conta?'),
            content: const Text(
              'Os dados remotos serao excluidos. A biblioteca local nao sera '
              'apagada automaticamente.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Excluir definitivamente'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) {
      await account.deleteAccount();
    }
  }

  IconData _syncIcon(SyncCoordinator? sync) {
    switch (sync?.phase ?? SyncPhase.localOnly) {
      case SyncPhase.synchronized:
        return Icons.cloud_done_rounded;
      case SyncPhase.synchronizing:
        return Icons.sync_rounded;
      case SyncPhase.offline:
        return Icons.cloud_off_rounded;
      case SyncPhase.pending:
        return Icons.cloud_upload_outlined;
      case SyncPhase.error:
        return Icons.sync_problem_rounded;
      case SyncPhase.sessionExpired:
        return Icons.lock_clock_outlined;
      case SyncPhase.localOnly:
        return Icons.phone_android_rounded;
    }
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    super.key,
    required this.icon,
    required this.message,
    this.error = false,
  });

  final IconData icon;
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      color: error ? colors.errorContainer : colors.secondaryContainer,
      child: ListTile(
        leading: Icon(icon),
        title: Text(message),
      ),
    );
  }
}

class _LocalModeCard extends StatelessWidget {
  const _LocalModeCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('Modo local', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.offline_bolt_rounded),
            title: Text('Conta online nao configurada neste build'),
            subtitle: Text(
              'A biblioteca, progresso, anotacoes e backups locais continuam '
              'funcionando. Configure SUPABASE_URL e '
              'SUPABASE_PUBLISHABLE_KEY para habilitar contas.',
            ),
          ),
        ),
      ],
    );
  }
}
