import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'pages/trash_page.dart'; 

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});
  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();

  final _dietary = <String>{};
  final _allergens = <String>{};
  final _cuisines = <String>{};

  String _skill = 'beginner';
  String _units = 'us';

  bool _notifyComments = true, _notifyFollows = true, _notifySaves = true;
  bool _profilePublic = true, _showSaved = false;
  bool _saving = false;
  bool _loading = true;

  Uint8List? _pickedBytes;   // cropped PNG bytes (preview + upload)
  XFile? _pickedFile;        // original file, optional
  String? _photoURL;         // saved URL

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      setState(() => _loading = false);
      return;
    }

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(me.uid).get();
    final m = doc.data() ?? {};

    _displayName.text =
        (m['displayName'] ?? me.displayName ?? '').toString();
    _username.text = (m['username'] ?? '').toString();
    _bio.text = (m['bio'] ?? '').toString();

    _skill = (m['skill'] ?? _skill).toString();
    _units = (m['units'] ?? _units).toString();

    _profilePublic = (m['profilePublic'] ?? _profilePublic) == true;
    _showSaved = (m['showSaved'] ?? _showSaved) == true;
    _notifyComments = (m['notifyComments'] ?? _notifyComments) == true;
    _notifyFollows = (m['notifyFollows'] ?? _notifyFollows) == true;
    _notifySaves = (m['notifySaves'] ?? _notifySaves) == true;

    _dietary
      ..clear()
      ..addAll(((m['dietary'] ?? const []) as List)
          .map((e) => e.toString()));
    _allergens
      ..clear()
      ..addAll(((m['allergens'] ?? const []) as List)
          .map((e) => e.toString()));
    _cuisines
      ..clear()
      ..addAll(((m['cuisines'] ?? const []) as List)
          .map((e) => e.toString()));

    _photoURL = (m['photoURL'] ?? me.photoURL)?.toString();
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  String? _displayNameValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.length < 2) return 'At least 2 characters';
    if (s.length > 40) return 'Keep under 40 characters';
    return null;
  }

  String? _usernameValidator(String? v) {
    final s = (v ?? '').trim();
    if (s.length < 3) return 'At least 3 characters';
    if (s.length > 20) return 'Max 20 characters';
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(s)) {
      return 'Use lowercase, numbers, _';
    }
    return null;
  }

  // ---- Pick & crop (circle) ----
  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 95);
      if (picked == null) return;
      final raw = await picked.readAsBytes();

      final cropped = await _circleCropDialog(raw);
      if (cropped == null) return;

      setState(() {
        _pickedFile = picked;
        _pickedBytes = cropped;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick image: $e')),
      );
    }
  }

  Future<Uint8List?> _circleCropDialog(Uint8List bytes) async {
    final controller = CropController();
    Uint8List? result;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(12),
        content: SizedBox(
          width: 380,
          height: 460,
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Crop(
                    image: bytes,
                    controller: controller,
                    withCircleUi: true,
                    baseColor: Theme.of(ctx).colorScheme.surface,
                    maskColor: Colors.black.withOpacity(.65),
                    progressIndicator:
                        const Center(child: CircularProgressIndicator()),
                    onCropped: (CropResult cropResult) {
                      result = cropResult.image;
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () => controller.crop(),
                    icon: const Icon(Icons.check),
                    label: const Text('Use photo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result;
  }

  // ---- Upload PNG + return download URL ----
  Future<String> _uploadPhotoToStorage() async {
    final me = FirebaseAuth.instance.currentUser!;
    final ref =
        FirebaseStorage.instance.ref('users/${me.uid}/profile.png'); // PNG
    final meta = SettableMetadata(
      contentType: 'image/png',
      cacheControl: 'no-cache, no-store, max-age=0, must-revalidate',
    );
    final task = await ref.putData(_pickedBytes!, meta);
    final url = await task.ref.getDownloadURL();
    return url;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final me = FirebaseAuth.instance.currentUser;
      if (me == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not signed in')),
        );
        setState(() => _saving = false);
        return;
      }

      String? newPhotoURL = _photoURL;
      if (_pickedBytes != null) {
        newPhotoURL = await _uploadPhotoToStorage();
        await me.updatePhotoURL(newPhotoURL);
        _photoURL = newPhotoURL;
      }

      final payload = {
        'displayName': _displayName.text.trim(),
        'username': _username.text.trim(),
        'bio': _bio.text.trim(),
        'dietary': _dietary.toList(),
        'allergens': _allergens.toList(),
        'cuisines': _cuisines.toList(),
        'skill': _skill,
        'units': _units,
        'profilePublic': _profilePublic,
        'showSaved': _showSaved,
        'notifyComments': _notifyComments,
        'notifyFollows': _notifyFollows,
        'notifySaves': _notifySaves,
        'photoURL': newPhotoURL,
        'updatedAt': FieldValue.serverTimestamp(), // for cache-bust
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(me.uid)
          .set(payload, SetOptions(merge: true));
      await me.updateDisplayName(_displayName.text.trim());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
      setState(() => _saving = false);
    }
  }

  InputDecoration get _input =>
      const InputDecoration(border: OutlineInputBorder(), filled: true);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                child: Column(
                  children: [
                    InkWell(
                      onTap: _saving ? null : _pickImage,
                      borderRadius: BorderRadius.circular(64),
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white.withOpacity(.9),
                        backgroundImage: _pickedBytes != null
                            ? MemoryImage(_pickedBytes!)
                            : (_photoURL != null && _photoURL!.isNotEmpty)
                                ? NetworkImage(_photoURL!) as ImageProvider
                                : null,
                        child: (_pickedBytes == null &&
                                (_photoURL == null ||
                                    _photoURL!.isEmpty))
                            ? Text(
                                (_displayName.text.isEmpty
                                        ? (email.isNotEmpty ? email[0] : 'N')
                                        : _displayName.text[0])
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _saving ? null : _pickImage,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Change photo'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // --- form sections ---
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    _SectionCard(
                      title: 'Account',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _displayName,
                            decoration:
                                _input.copyWith(labelText: 'Display name'),
                            validator: _displayNameValidator,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _username,
                            decoration: _input.copyWith(
                              labelText: 'Username',
                              helperText:
                                  '3–20 chars • lowercase • numbers • _',
                              prefixText: '@',
                            ),
                            validator: _usernameValidator,
                            textInputAction: TextInputAction.done,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _bio,
                            maxLength: 160,
                            maxLines: 3,
                            decoration:
                                _input.copyWith(labelText: 'Bio'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'Food Preferences',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Chips(
                            label: 'Dietary',
                            options: const [
                              'vegetarian',
                              'vegan',
                              'pescatarian',
                              'halal',
                              'kosher',
                              'gluten free',
                              'dairy free',
                              'low carb',
                            ],
                            selected: _dietary,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          _Chips(
                            label: 'Allergens',
                            options: const [
                              'peanuts',
                              'tree nuts',
                              'shellfish',
                              'eggs',
                              'soy',
                              'sesame',
                              'wheat',
                              'dairy',
                            ],
                            selected: _allergens,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          _Chips(
                            label: 'Favorite cuisines',
                            options: const [
                              'mexican',
                              'italian',
                              'japanese',
                              'indian',
                              'thai',
                              'french',
                              'american',
                              'mediterranean',
                            ],
                            selected: _cuisines,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _skill,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'beginner',
                                      child: Text('Beginner'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'intermediate',
                                      child: Text('Intermediate'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'advanced',
                                      child: Text('Advanced'),
                                    ),
                                  ],
                                  onChanged: (v) => setState(
                                      () => _skill = v ?? 'beginner'),
                                  decoration: _input.copyWith(
                                      labelText: 'Skill level'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _units,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'us',
                                      child: Text('US Customary'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'metric',
                                      child: Text('Metric'),
                                    ),
                                  ],
                                  onChanged: (v) => setState(
                                      () => _units = v ?? 'us'),
                                  decoration: _input.copyWith(
                                      labelText: 'Units'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'Settings',
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Public profile'),
                            value: _profilePublic,
                            onChanged: (v) =>
                                setState(() => _profilePublic = v),
                          ),
                          SwitchListTile(
                            title: const Text(
                                'Show saved recipes on profile'),
                            value: _showSaved,
                            onChanged: (v) =>
                                setState(() => _showSaved = v),
                          ),

                          const Divider(height: 24),
                          ListTile(
                            leading:
                                const Icon(Icons.delete_outline),
                            title: const Text('Recently Deleted Recipes'),
                            subtitle: const Text(
                                'View and restore deleted recipes'),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const TrashPage(),
                                ),
                              );
                            },
                          ),

                          const Divider(height: 24),

                          CheckboxListTile(
                            title:
                                const Text('Notify on comments'),
                            value: _notifyComments,
                            onChanged: (v) => setState(
                                () => _notifyComments = v ?? true),
                          ),
                          CheckboxListTile(
                            title:
                                const Text('Notify on follows'),
                            value: _notifyFollows,
                            onChanged: (v) => setState(
                                () => _notifyFollows = v ?? true),
                          ),
                          CheckboxListTile(
                            title:
                                const Text('Notify on saves'),
                            value: _notifySaves,
                            onChanged: (v) => setState(
                                () => _notifySaves = v ?? true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on CropResult {
  Uint8List? get image => null;
}

/* ---------- UI helpers ---------- */

class _Header extends StatelessWidget {
  const _Header({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 88, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withOpacity(.6)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: -6,
          children: [
            for (final o in options)
              FilterChip(
                label: Text(o),
                selected: selected.contains(o),
                onSelected: (v) {
                  final next = {...selected};
                  v ? next.add(o) : next.remove(o);
                  onChanged(next);
                },
              ),
          ],
        ),
      ],
    );
  }
}
