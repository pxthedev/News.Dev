import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../data/repository.dart';
import '../l10n/app_copy.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/primitives.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _bio;
  Uint8List? _newPhoto;
  bool _removePhoto = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    _name = TextEditingController(text: state.userName);
    _bio = TextEditingController(text: state.userBio);
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
        requestFullMetadata: false,
      );
      if (file == null || !mounted) return;
      if (await file.length() > 256 * 1024) {
        throw const RepoException(
            'Escolha uma imagem JPG ou PNG de até 256 KB.');
      }
      final bytes = await file.readAsBytes();
      final jpeg = bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff;
      final png = bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4e &&
          bytes[3] == 0x47;
      if (!jpeg && !png) {
        throw const RepoException(
            'Escolha uma imagem JPG ou PNG de até 256 KB.');
      }
      if (!mounted) return;
      setState(() {
        _newPhoto = bytes;
        _removePhoto = false;
      });
    } on RepoException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Exception {
      if (mounted) setState(() => _error = 'Não foi possível abrir a galeria.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_form.currentState?.validate() != true) return;
    final state = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await state.updateProfile(
        name: _name.text.trim(),
        bio: _bio.text.trim(),
        avatar: _newPhoto,
        removeAvatar: _removePhoto,
      );
      if (!mounted) return;
      state.showToast(context.tr('Perfil atualizado.'));
      Navigator.of(context).pop();
    } on RepoException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Exception {
      if (mounted) setState(() => _error = 'Não foi possível salvar o perfil.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final picture = _removePhoto ? null : (_newPhoto ?? state.userAvatar);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Editar perfil'))),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                      child: InitialsAvatar(state.initials,
                          photo: picture, size: 88)),
                  const SizedBox(height: 12),
                  RButton(
                    picture == null ? 'Adicionar foto' : 'Trocar foto',
                    icon: Icons.photo_outlined,
                    kind: RButtonKind.secondary,
                    onPressed: _busy ? null : _pickPhoto,
                  ),
                  if (picture != null)
                    RButton(
                      'Remover foto',
                      kind: RButtonKind.text,
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _newPhoto = null;
                                _removePhoto = true;
                                _error = null;
                              }),
                    ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _name,
                    enabled: !_busy,
                    maxLength: 80,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: context.tr('Nome')),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? context.tr('Informe seu nome.')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bio,
                    enabled: !_busy,
                    maxLines: 3,
                    maxLength: 160,
                    decoration:
                        InputDecoration(labelText: context.tr('Sobre você')),
                  ),
                  if (_error case final error?) ...[
                    const SizedBox(height: 8),
                    Text(context.tr(error),
                        style: RText.footnote.withColor(RColors.urgent)),
                  ],
                  const SizedBox(height: 16),
                  RButton('Salvar', onPressed: _busy ? null : _save),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
