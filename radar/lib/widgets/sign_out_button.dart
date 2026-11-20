import 'package:material_ui/material_ui.dart';
import '../data/api/http_repository.dart';
import '../data/repository.dart';
import '../routes.dart';
import '../services/supabase_bridge.dart';
import '../state/app_state.dart';
import 'primitives.dart';

/// Encerra a sessão e remove as telas privadas da navegação.
class SignOutButton extends StatefulWidget {
  const SignOutButton({super.key});
  @override
  State<SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<SignOutButton> {
  bool _busy = false;

  Future<void> _signOut() async {
    if (_busy) return;
    final state = AppScope.read(context);
    final repo = state.repo;
    if (repo is! HttpRepository) return;
    setState(() => _busy = true);
    try {
      await repo.api.signOut();
      try {
        await SupabaseBridge.signOut();
      } on Object {
        // A sessão da API já foi encerrada: falha no provedor não retém dados locais.
      }
      await state.reloadIdentity(refresh: false);
      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil(Routes.account, (_) => false);
    } on RepoException catch (e) {
      state.showToast(e.message);
    } on Object {
      state.showToast('Não foi possível sair. Tente novamente.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => RButton(
        _busy ? 'Saindo…' : 'Sair da conta',
        kind: RButtonKind.secondary,
        icon: Icons.logout,
        onPressed: _busy ? null : _signOut,
      );
}
