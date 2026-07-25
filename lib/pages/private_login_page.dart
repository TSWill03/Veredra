// Signature: dev.tswicolly03
import 'package:flutter/material.dart';

import '../services/auth/account_controller.dart';
import '../services/auth/auth_models.dart';

class PrivateLoginPage extends StatefulWidget {
  const PrivateLoginPage({super.key, required this.accountController});

  final AccountController accountController;

  @override
  State<PrivateLoginPage> createState() => _PrivateLoginPageState();
}

class _PrivateLoginPageState extends State<PrivateLoginPage> {
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _recoveryFormKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.accountController,
      builder: (BuildContext context, Widget? child) {
        final AccountController account = widget.accountController;
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: account.passwordRecovery
                          ? _buildPasswordRecovery(account)
                          : _buildLogin(account),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogin(AccountController account) {
    return AutofillGroup(
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Icon(Icons.menu_book_rounded, size: 52),
            const SizedBox(height: 16),
            Text(
              'Veredra privado',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Entre com uma conta previamente autorizada para acessar sua biblioteca.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (account.errorMessage != null) ...<Widget>[
              _MessageCard(message: account.errorMessage!, error: true),
              const SizedBox(height: 14),
            ],
            if (account.noticeMessage != null) ...<Widget>[
              _MessageCard(message: account.noticeMessage!),
              const SizedBox(height: 14),
            ],
            TextFormField(
              key: const Key('private-auth-email-field'),
              controller: _emailController,
              enabled: !account.busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const <String>[AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'E-mail autorizado',
                prefixIcon: Icon(Icons.alternate_email_rounded),
                border: OutlineInputBorder(),
              ),
              validator: (String? value) =>
                  AuthInputValidator.email(value?.trim() ?? ''),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('private-auth-password-field'),
              controller: _passwordController,
              enabled: !account.busy,
              obscureText: _obscurePassword,
              autofillHints: const <String>[AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submitLogin(account),
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.password_rounded),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (String? value) =>
                  (value ?? '').isEmpty ? 'Informe sua senha.' : null,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('private-auth-submit-button'),
              onPressed: account.busy ? null : () => _submitLogin(account),
              icon: account.busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded),
              label: const Text('Entrar'),
            ),
            TextButton(
              key: const Key('private-auth-forgot-password-button'),
              onPressed:
                  account.busy ? null : () => _sendPasswordReset(account),
              child: const Text('Esqueci minha senha'),
            ),
            const SizedBox(height: 10),
            Text(
              'Novos cadastros estão desativados.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordRecovery(AccountController account) {
    return Form(
      key: _recoveryFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Icon(Icons.lock_reset_rounded, size: 52),
          const SizedBox(height: 16),
          Text(
            'Defina uma nova senha',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'O link de recuperação foi validado. Escolha uma senha segura.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (account.errorMessage != null) ...<Widget>[
            _MessageCard(message: account.errorMessage!, error: true),
            const SizedBox(height: 14),
          ],
          TextFormField(
            key: const Key('private-recovery-password-field'),
            controller: _newPasswordController,
            enabled: !account.busy,
            obscureText: true,
            autofillHints: const <String>[AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitNewPassword(account),
            decoration: const InputDecoration(
              labelText: 'Nova senha',
              helperText: '10+ caracteres, maiúscula, minúscula e número',
              prefixIcon: Icon(Icons.lock_outline_rounded),
              border: OutlineInputBorder(),
            ),
            validator: (String? value) =>
                AuthInputValidator.password(value ?? ''),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('private-recovery-submit-button'),
            onPressed: account.busy ? null : () => _submitNewPassword(account),
            icon: account.busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: const Text('Atualizar senha'),
          ),
        ],
      ),
    );
  }

  void _submitLogin(AccountController account) {
    if (!(_loginFormKey.currentState?.validate() ?? false)) {
      return;
    }
    account.signIn(_emailController.text.trim(), _passwordController.text);
  }

  void _sendPasswordReset(AccountController account) {
    final String? error = AuthInputValidator.email(
      _emailController.text.trim(),
    );
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    account.sendPasswordReset(_emailController.text.trim());
  }

  void _submitNewPassword(AccountController account) {
    if (!(_recoveryFormKey.currentState?.validate() ?? false)) {
      return;
    }
    account.updatePassword(_newPasswordController.text);
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, this.error = false});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: error ? colors.errorContainer : colors.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color:
                error ? colors.onErrorContainer : colors.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: error
                    ? colors.onErrorContainer
                    : colors.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
