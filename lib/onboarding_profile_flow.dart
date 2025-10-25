import 'dart:async';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; // web picker

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/* ──────────────────────────────────────────────────────────────────────────
   Inclusive option catalogs (centralized)
   ────────────────────────────────────────────────────────────────────────── */

const kCuisineOptions = <String>[
  // Americas
  'american','bbq','cajun/creole','soul food','tex-mex','hawaiian',
  'mexican','central american','caribbean','cuban','puerto rican','dominican',
  'brazilian','argentinian','peruvian',
  // Europe
  'italian','french','spanish','portuguese','greek','turkish',
  'german','polish','russian','ukrainian',
  // MENA
  'mediterranean','lebanese','israeli','persian/iranian','moroccan','egyptian',
  // Sub-Saharan Africa
  'ethiopian','west african','east african','south african',
  // South & Central Asia
  'indian','pakistani','bangladeshi','sri lankan','nepali',
  // East & Southeast Asia
  'japanese','chinese','korean','thai','vietnamese','filipino','malaysian',
  'indonesian','singaporean',
  // Other / modern
  'fusion','vegetarian-focused','street food'
];

const kDietOptions = <String>[
  'vegetarian','vegan','pescatarian','halal','kosher',
  'gluten-free','dairy-free','nut-free','egg-free','soy-free','sesame-free',
  'low carb','keto','paleo','whole30','low FODMAP','diabetic-friendly',
  'high protein','high fiber','reduced sugar'
];

/// EU + common allergens
const kAllergenOptions = <String>[
  'peanuts','tree nuts','sesame','soy','wheat/gluten','dairy/milk','eggs',
  'fish','shellfish','molluscs','celery','mustard','lupin','sulphites'
];

const kGearOptions = <String>[
  'air fryer','slow cooker','instant pot/pressure cooker','rice cooker',
  'microwave','toaster oven','oven + stove','cast-iron skillet','dutch oven',
  'grill','smoker','sous vide',
  'blender','immersion blender','food processor',
  'hand mixer','stand mixer',
  'steamer','waffle maker','bread machine','pizza stone','pasta maker','tagine'
];

const kCookTimeOptions = <String>['10','20','30','45','60+']; // minutes

/* ────────────────────────────────────────────────────────────────────────── */

class OnboardingProfileFlow extends StatefulWidget {
  const OnboardingProfileFlow({super.key});
  @override
  State<OnboardingProfileFlow> createState() => _OnboardingProfileFlowState();
}

class _OnboardingProfileFlowState extends State<OnboardingProfileFlow> {
  final _pageCtrl = PageController();
  int _index = 0;

  // Step 0 — name
  final _nameCtrl = TextEditingController();

  // Step 1 — handle + avatar
  final _usernameCtrl = TextEditingController();
  ImageProvider? _avatarPreview;      // shown in CircleAvatar
  Uint8List? _avatarBytes;            // cropped PNG/JPG bytes for upload
  Timer? _userCheckDebounce;
  bool? _userAvailable;               // null=checking, true ok, false taken

  // Step 2 — household + goal
  int _household = 1;
  String _goal = 'eat_better';

  // Step 3 — how you cook
  String _skill = 'beginner';
  final _cookTimes = <String>{};
  final _gear = <String>{};

  // Step 4 — cuisines
  final _favCuisines = <String>{};

  // Step 5 — diet + allergens + units
  final _dietary = <String>{};
  final _allergens = <String>{};
  String _units = 'us';

  bool _saving = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _userCheckDebounce?.cancel();
    super.dispose();
  }

  /* ---------------- validation ---------------- */

  String? get _nameError {
    final s = _nameCtrl.text.trim();
    if (s.isEmpty) return 'Please enter your display name';
    if (s.length < 2) return 'Name is too short';
    return null;
  }

  String? get _usernameError {
    final u = _usernameCtrl.text.trim();
    if (u.isEmpty) return 'Pick a username';
    if (u.length < 3) return 'At least 3 characters';
    if (u.length > 20) return 'Max 20 characters';
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(u)) {
      return 'Use lowercase, numbers, underscore';
    }
    if (_userAvailable == false) return 'That handle is taken';
    return null;
  }

  bool get _step1Valid => _nameError == null;
  bool get _step2Valid => _usernameError == null;
  bool get _step3Valid => _household >= 1 && _goal.isNotEmpty;
  bool get _stepCookValid => _skill.isNotEmpty;
  bool get _step4Valid => _favCuisines.isNotEmpty;
  bool get _step5Valid => true;

  /* ---- username availability (debounced mock; wire to Firestore later) ---- */
  void _checkUsername(String raw) {
    final s = raw.trim();
    _userCheckDebounce?.cancel();
    setState(() => _userAvailable = null);
    _userCheckDebounce = Timer(const Duration(milliseconds: 400), () async {
      // TODO: replace with real availability check
      final taken = s.length < 3 || s.contains('nibble');
      if (!mounted) return;
      setState(() => _userAvailable = !taken);
    });
  }

  /* ---------------- avatar picker + cropper (web) ---------------- */

  void _pickAvatar() async {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Native picker coming soon (iOS/Android).')),
      );
      return;
    }
    final input = html.FileUploadInputElement()..accept = 'image/*';
    input.click();
    await input.onChange.first;
    final file = input.files?.first;
    if (file == null) return;

    final reader = html.FileReader();
    reader.readAsArrayBuffer(file); // raw bytes for cropper
    await reader.onLoadEnd.first;

    final bytes = Uint8List.view(reader.result as ByteBuffer);
    if (!mounted) return;
    _showCropper(bytes); // open crop dialog
  }

  // v1.x-compatible crop dialog (circle UI + pinch/zoom/drag)
  Future<void> _showCropper(Uint8List originalBytes) async {
    final controller = CropController();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
              contentPadding: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              content: SizedBox(
                width: 520,
                height: 520,
                child: Column(
                  children: [
                    Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.all(12),
                      child: const Text('Adjust photo',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Crop(
                          controller: controller,
                          image: originalBytes,
                          // v1: keep it simple — circle mask implies a square crop
                          withCircleUi: true,
                          baseColor: Colors.black12,
                          maskColor: Colors.black.withOpacity(0.5),
                          interactive: true,
                          // v1: returns raw bytes directly
                          onCropped: (Uint8List data) {
                            _avatarBytes = data;
                            _avatarPreview = MemoryImage(data);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Photo updated')),
                              );
                              setState(() {}); // refresh avatar preview
                            }
                          },
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: saving ? null : () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          const Spacer(),
                          // v1: no undo/redo API — keep UI simple
                          FilledButton.icon(
                            onPressed: saving
                                ? null
                                : () async {
                                    setState(() => saving = true);
                                    controller.crop(); // bytes delivered in onCropped above
                                    await Future<void>.delayed(const Duration(milliseconds: 100));
                                    if (context.mounted) setState(() => saving = false);
                                  },
                            icon: saving
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check),
                            label: const Text('Use photo'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /* ---------------- nav ---------------- */

  void _next() {
    FocusScope.of(context).unfocus();
    if (_index == 0 && !_step1Valid) return;
    if (_index == 1 && !_step2Valid) return;
    if (_index == 2 && !_step3Valid) return;
    if (_index == 3 && !_stepCookValid) return;
    if (_index == 4 && !_step4Valid) return;

    if (_index < 5) {
      setState(() => _index++);
      _pageCtrl.animateToPage(
        _index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _back() {
    if (_index > 0) {
      setState(() => _index--);
      _pageCtrl.animateToPage(
        _index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _finish() async {
    if (!_step5Valid) return;
    setState(() => _saving = true);

    final payload = {
      'displayName': _nameCtrl.text.trim(),
      'username': _usernameCtrl.text.trim(),
      'avatarBytes_len': _avatarBytes?.length ?? 0, // placeholder
      'household': _household,
      'goal': _goal,
      'skill': _skill,
      'cookTimes': _cookTimes.toList(),
      'gear': _gear.toList(),
      'favoriteCuisines': _favCuisines.toList(),
      'dietary': _dietary.toList(),
      'allergens': _allergens.toList(),
      'units': _units,
    };

    await Future<void>.delayed(const Duration(milliseconds: 500));
    debugPrint('ONBOARDING_PAYLOAD => $payload');

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved — welcome to Nibble!')),
    );
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Welcome', 'Your handle', 'Your household',
      'How you cook', 'Cuisines', 'Diet & units',
    ];

    final canNext = switch (_index) {
      0 => _step1Valid,
      1 => _step2Valid,
      2 => _step3Valid,
      3 => _stepCookValid,
      4 => _step4Valid,
      _ => false,
    };

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Text(titles[_index], key: ValueKey(_index)),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              if (_index > 0)
                OutlinedButton.icon(
                  onPressed: _back,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                )
              else
                const SizedBox.shrink(),
              const Spacer(),
              if (_index < 5)
                FilledButton.icon(
                  onPressed: canNext ? _next : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                )
              else
                FilledButton.icon(
                  onPressed: _saving ? null : _finish,
                  icon: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Finish'),
                ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (_index + 1) / 6),
              duration: const Duration(milliseconds: 250),
              builder: (_, value, __) => LinearProgressIndicator(value: value),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StepName(
                  nameCtrl: _nameCtrl,
                  nameError: _nameError,
                  onChanged: () => setState(() {}),
                ),
                _StepHandle(
                  usernameCtrl: _usernameCtrl,
                  usernameError: _usernameError,
                  userAvailable: _userAvailable,
                  onChanged: (v) {
                    _checkUsername(v);
                    setState(() {});
                  },
                  onPickAvatar: _pickAvatar,
                  onReadjust: _avatarBytes == null
                      ? null
                      : () => _showCropper(_avatarBytes!),
                  hasAvatar: _avatarBytes != null,
                  avatarPreview: _avatarPreview,
                ),
                _StepHouseholdGoal(
                  household: _household,
                  onHousehold: (v) => setState(() => _household = v),
                  goal: _goal,
                  onGoal: (v) => setState(() => _goal = v),
                ),
                _StepCook(
                  skill: _skill,
                  onSkill: (v) => setState(() => _skill = v),
                  cookTimes: _cookTimes,
                  onToggleTime: (v) => setState(() {
                    _cookTimes.contains(v) ? _cookTimes.remove(v) : _cookTimes.add(v);
                  }),
                  gear: _gear,
                  onToggleGear: (v) => setState(() {
                    _gear.contains(v) ? _gear.remove(v) : _gear.add(v);
                  }),
                ),
                _StepCuisines(
                  favCuisines: _favCuisines,
                  onToggleCuisine: (v) => setState(() {
                    _favCuisines.contains(v)
                        ? _favCuisines.remove(v)
                        : _favCuisines.add(v);
                  }),
                ),
                _StepEat(
                  dietary: _dietary,
                  onDiet: (v) => setState(() {
                    _dietary.contains(v) ? _dietary.remove(v) : _dietary.add(v);
                  }),
                  allergens: _allergens,
                  onAllergen: (v) => setState(() {
                    _allergens.contains(v) ? _allergens.remove(v) : _allergens.add(v);
                  }),
                  units: _units,
                  onUnits: (v) => setState(() => _units = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────────── shared step shell (scrollable) ───────────────────── */

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const double bottomReserve = 96; // space for nav buttons
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: const EdgeInsets.only(bottom: bottomReserve),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 16),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ───────────────────── Step 0: Name ───────────────────── */

class _StepName extends StatelessWidget {
  const _StepName({
    required this.nameCtrl,
    required this.nameError,
    required this.onChanged,
  });

  final TextEditingController nameCtrl;
  final String? nameError;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: "hey, I’m Nibble 👋",
      subtitle: "what should I call you?",
      child: TextField(
        controller: nameCtrl,
        onChanged: (_) => onChanged(),
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Display name',
          hintText: 'e.g., Maribel',
          prefixIcon: const Icon(Icons.person_outline),
          filled: true,
          border: const OutlineInputBorder(),
          errorText: nameError,
          helperText: nameError == null
              ? 'Shown on your recipes & comments.'
              : null,
        ),
      ),
    );
  }
}

/* ───────────────── Step 1: Handle & photo ───────────────── */

class _StepHandle extends StatelessWidget {
  const _StepHandle({
    required this.usernameCtrl,
    required this.usernameError,
    required this.userAvailable,
    required this.onChanged,
    required this.onPickAvatar,
    required this.onReadjust,
    required this.hasAvatar,
    required this.avatarPreview,
  });

  final TextEditingController usernameCtrl;
  final String? usernameError;
  final bool? userAvailable; // nullable
  final ValueChanged<String> onChanged;
  final VoidCallback onPickAvatar;
  final VoidCallback? onReadjust;     // null until a photo exists
  final bool hasAvatar;
  final ImageProvider? avatarPreview;

  @override
  Widget build(BuildContext context) {
    final ua = userAvailable;
    final suffix = ua == null
        ? const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : Icon(ua ? Icons.check_circle : Icons.cancel,
            color: ua ? Colors.green : Colors.red);

    return _StepScaffold(
      title: "claim your kitchen handle",
      subtitle: "lowercase, numbers and underscore only",
      child: Column(
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundImage: avatarPreview,
                  child: avatarPreview == null
                      ? const Icon(Icons.person, size: 44)
                      : null,
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  OutlinedButton.icon(
                    onPressed: onPickAvatar,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Upload photo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onReadjust,
                    icon: const Icon(Icons.tune),
                    label: const Text('Re-adjust'),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: usernameCtrl,
            onChanged: onChanged,
            decoration: InputDecoration(
              prefixText: '@',
              labelText: 'Username',
              helperText: '3–20 chars • lowercase • numbers • _',
              border: const OutlineInputBorder(),
              errorText: usernameError,
              suffixIcon: suffix,
            ),
          ),
        ],
      ),
    );
  }
}

/* ──────────────── Step 2: Household + goal ──────────────── */

class _StepHouseholdGoal extends StatelessWidget {
  const _StepHouseholdGoal({
    required this.household,
    required this.onHousehold,
    required this.goal,
    required this.onGoal,
  });

  final int household;
  final ValueChanged<int> onHousehold;
  final String goal; // 'eat_better'|'save_time'|'save_money'|'learn_basics'
  final ValueChanged<String> onGoal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final goals = const <MapEntry<String, String>>[
      MapEntry('eat_better', 'Eat better'),
      MapEntry('save_time', 'Save time'),
      MapEntry('save_money', 'Save money'),
      MapEntry('learn_basics', 'Learn basics'),
    ];

    return _StepScaffold(
      title: "about your kitchen",
      subtitle: "so portions & tips feel right",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int>(
            value: household,
            decoration: const InputDecoration(
              labelText: 'Household size',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Just me (1)')),
              DropdownMenuItem(value: 2, child: Text('2 people')),
              DropdownMenuItem(value: 3, child: Text('3 people')),
              DropdownMenuItem(value: 4, child: Text('4 people')),
              DropdownMenuItem(value: 5, child: Text('5 people')),
              DropdownMenuItem(value: 6, child: Text('6+ people')),
            ],
            onChanged: (v) => onHousehold(v ?? 1),
          ),
          const SizedBox(height: 16),
          Text('What’s your main goal?',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withOpacity(.9),
              )),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final g in goals)
                ChoiceChip(
                  label: Text(g.value),
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  selected: goal == g.key,
                  onSelected: (_) => onGoal(g.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ───────────────── Step 3: How you cook ───────────────── */

class _StepCook extends StatelessWidget {
  const _StepCook({
    required this.skill,
    required this.onSkill,
    required this.cookTimes,
    required this.onToggleTime,
    required this.gear,
    required this.onToggleGear,
  });

  final String skill;
  final void Function(String v) onSkill;
  final Set<String> cookTimes;
  final void Function(String v) onToggleTime;
  final Set<String> gear;
  final void Function(String v) onToggleGear;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: "how you like to cook",
      subtitle: "so I don’t send you soufflés on a Monday 😅",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: skill,
            decoration: const InputDecoration(
              labelText: 'Skill level',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
              DropdownMenuItem(value: 'comfortable', child: Text('Comfortable')),
              DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
            ],
            onChanged: (v) => onSkill(v ?? 'beginner'),
          ),
          const SizedBox(height: 16),
          const Text('Typical weeknight cook time'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final t in kCookTimeOptions)
                FilterChip(
                  label: Text('$t min'),
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  selected: cookTimes.contains(t),
                  onSelected: (_) => onToggleTime(t),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Gear you use'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final g in kGearOptions)
                FilterChip(
                  label: Text(g),
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  selected: gear.contains(g),
                  onSelected: (_) => onToggleGear(g),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ──────────────── Step 4: Favorite cuisines ──────────────── */

class _StepCuisines extends StatelessWidget {
  const _StepCuisines({
    required this.favCuisines,
    required this.onToggleCuisine,
  });

  final Set<String> favCuisines;
  final void Function(String v) onToggleCuisine;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: "what do you crave?",
      subtitle: "pick a few to tune your feed",
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final c in kCuisineOptions)
            FilterChip(
              label: Text(c),
              labelPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              selected: favCuisines.contains(c),
              onSelected: (_) => onToggleCuisine(c),
            ),
        ],
      ),
    );
  }
}

/* ──────── Step 5: Diet + allergens + units (finish) ──────── */

class _StepEat extends StatelessWidget {
  const _StepEat({
    required this.dietary,
    required this.onDiet,
    required this.allergens,
    required this.onAllergen,
    required this.units,
    required this.onUnits,
  });

  final Set<String> dietary;
  final void Function(String v) onDiet;
  final Set<String> allergens;
  final void Function(String v) onAllergen;
  final String units;
  final void Function(String v) onUnits;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: "what you eat (and avoid)",
      subtitle: "tell me what to skip and I’ll remember",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dietary preferences'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final d in kDietOptions)
                FilterChip(
                  label: Text(d),
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  selected: dietary.contains(d),
                  onSelected: (_) => onDiet(d),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Allergens'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final a in kAllergenOptions)
                FilterChip(
                  label: Text(a),
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  selected: allergens.contains(a),
                  onSelected: (_) => onAllergen(a),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: units,
            decoration: const InputDecoration(
              labelText: 'Units',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'us', child: Text('US Customary')),
              DropdownMenuItem(value: 'metric', child: Text('Metric')),
            ],
            onChanged: (v) => onUnits(v ?? 'us'),
          ),
        ],
      ),
    );
  }
}
