import 'package:flutter/material.dart';
import '../auth_service.dart';

class UsernameScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const UsernameScreen({super.key, required this.onComplete});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

typedef PortraitChange = void Function(String asset);

class _PortraitPager extends StatefulWidget {
  final List<String> assets;
  final String? initial;
  final PortraitChange onChanged;

  const _PortraitPager({required this.assets, this.initial, required this.onChanged});

  @override
  State<_PortraitPager> createState() => _PortraitPagerState();
}

class _PortraitPagerState extends State<_PortraitPager> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initial != null ? widget.assets.indexOf(widget.initial!) : 0;
    if (_index < 0 || _index >= widget.assets.length) _index = 0;
    _controller = PageController(viewportFraction: 0.8, initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.assets.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              widget.onChanged(widget.assets[i]);
            },
            itemBuilder: (context, i) {
              final asset = widget.assets[i];
              final selected = i == _index;
              return AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: selected ? 6 : 12, vertical: selected ? 4 : 12),
                child: Material(
                  elevation: selected ? 6 : 2,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.hardEdge,
                  child: Image.asset(asset, fit: BoxFit.cover, width: double.infinity),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.assets.length, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == _index ? 10 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _index ? Theme.of(context).primaryColor : Colors.grey[400],
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _UsernameScreenState extends State<UsernameScreen> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _selectedPortrait;
  final List<String> _portraitAssets = [
  'assets/images/portraits/Gemini_Generated_Image_jxdhrijxdhrijxdh.png',
  'assets/images/portraits/Gemini_Generated_Image_ldt41vldt41vldt4.png',
  'assets/images/portraits/Gemini_Generated_Image_rgtie3rgtie3rgti.png',
  'assets/images/portraits/Gemini_Generated_Image_u5ou4lu5ou4lu5ou.png',
  'assets/images/portraits/Gemini_Generated_Image_xgeshlxgeshlxges.png',
  ];

  @override
  void initState() {
    super.initState();
    _selectedPortrait = _portraitAssets.isNotEmpty ? _portraitAssets[0] : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.setUsername(_name.text.trim());
      if (_selectedPortrait != null) {
        await _auth.setPortrait(_selectedPortrait!);
      }
      widget.onComplete();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 390,
        height: 844,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Scaffold(
            appBar: AppBar(title: const Text('Choose Username')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Pick a unique display name'),
                      const SizedBox(height: 12),
                      if (_portraitAssets.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Choose a portrait', style: Theme.of(context).textTheme.titleMedium),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 220,
                          child: _PortraitPager(
                            assets: _portraitAssets,
                            initial: _selectedPortrait,
                            onChanged: (asset) => setState(() => _selectedPortrait = asset),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Username'),
                        validator: (v) => v != null && v.trim().length >= 3 ? null : 'Min 3 chars',
                      ),
                      const SizedBox(height: 12),
                      if (_error != null)
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _busy ? null : _save,
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
