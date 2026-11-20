import 'package:flutter/widgets.dart';
import '../state/app_state.dart';
import '../screens/account_screen.dart';

/// Impede que links e rotas secundárias contornem o acesso à conta.
class AccountGate extends StatelessWidget {
  const AccountGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      AppScope.of(context).isAccount ? child : const AccountScreen();
}
