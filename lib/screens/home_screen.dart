import 'package:flutter/material.dart';
import '../models/nfc_tag.dart';
import '../services/firestore_service.dart';
import '../services/nfc_service.dart';
import 'edit_tag_screen.dart';
import 'settings_screen.dart';
import 'reader_screen.dart'; // Add this line

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const HomeScreen({Key? key, required this.onToggleTheme}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const Map<String, IconData> _iconMap = {
    'label': Icons.label,
    'star': Icons.star,
    'wifi': Icons.wifi,
    'link': Icons.link,
    'home': Icons.home,
    'phone_android': Icons.phone_android,
    'email': Icons.email,
    'credit_card': Icons.credit_card,
    'lock': Icons.lock,
    'location_on': Icons.location_on,
    'person': Icons.person,
    'shopping_cart': Icons.shopping_cart,
    'nfc': Icons.nfc,
    'key': Icons.vpn_key,
  };

  late AnimationController _waveController;
  final _searchCtl = TextEditingController();
  String _search = '';
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  void _showTagOptions(NfcTag tag) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Wrap(children: [
        ListTile(
          leading: const Icon(Icons.nfc),
          title: Text('Emulate "${tag.name}"'),
          onTap: () async {
            Navigator.pop(context);
            final data = tag.data.trim();
            final isUrl =
                data.startsWith('http://') || data.startsWith('https://');
            // Show popup immediately
            _showBottomSheet(
              context,
              title: 'Emulating NFC Tag…',
              icon: Icons.contactless,
              controller: _waveController,
              onCancel: () {
                _waveController.stop();
                Navigator.of(context).pop();
              },
            );
            try {
              await NfcService.setNdefPayload(data, isUrl: isUrl);
              // Optionally: auto-close after 10s
              await Future.delayed(const Duration(seconds: 10));
              // ignore: use_build_context_synchronously
              if (Navigator.of(context).canPop()) {
                _waveController.stop();
                // ignore: use_build_context_synchronously
                Navigator.of(context).pop();
              }
            } catch (e) {
              // ignore: use_build_context_synchronously
              if (Navigator.of(context).canPop()) {
                _waveController.stop();
                // ignore: use_build_context_synchronously
                Navigator.of(context).pop();
              }
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('NFC emulation failed: $e')),
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.edit),
          title: Text('Edit "${tag.name}"'),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => EditTagScreen(existingTag: tag)),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.close),
          title: const Text('Cancel'),
          onTap: () => Navigator.pop(context),
        ),
      ]),
    );
  }

  void _showBottomSheet(BuildContext ctx,
      {required String title,
      required IconData icon,
      required AnimationController controller,
      required VoidCallback onCancel}) {
    controller.repeat();
    showModalBottomSheet(
      context: ctx,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: Theme.of(ctx).textTheme.headlineSmall),
          const SizedBox(height: 12),
          ScaleTransition(
            scale: Tween(begin: 0.8, end: 1.2)
                .chain(CurveTween(curve: Curves.easeInOut))
                .animate(controller),
            child: Transform.rotate(
              angle: icon == Icons.contactless ? 270 * 3.14159 / 180 : 0,
              child: Icon(icon,
                  size: 80, color: const Color.fromARGB(255, 11, 218, 81)),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Tap your phone to the reader'),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel'),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your NFC Tags'),
        actions: [
          IconButton(
            icon: const Icon(Icons.nfc),
            tooltip: 'Read NFC Tag',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReaderScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(_showSearchBar ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_showSearchBar) {
                  _showSearchBar = false;
                  _searchCtl.clear();
                  _search = '';
                } else {
                  _showSearchBar = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SettingsScreen(onToggleTheme: widget.onToggleTheme),
                ),
              );
            },
          ),
        ],
        bottom: _showSearchBar
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchCtl,
                    autofocus: true,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search tags...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                              .inputDecorationTheme
                              .fillColor ??
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 16),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: StreamBuilder<List<NfcTag>>(
        stream: FirestoreService.tagStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading tags'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final tags = _search.isEmpty
              ? snapshot.data!
              : snapshot.data!
                  .where((t) =>
                      t.name.toLowerCase().contains(_search.toLowerCase()))
                  .toList();
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: tags.length + 1,
            itemBuilder: (context, i) {
              if (i == tags.length) {
                return Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditTagScreen()),
                    ),
                    child: const Center(child: Icon(Icons.add, size: 50)),
                  ),
                );
              }
              final tag = tags[i];
              return Card(
                child: ListTile(
                  leading: Icon(_iconMap[tag.icon] ?? Icons.label),
                  title: Text(tag.name),
                  onTap: () => _showTagOptions(tag),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
