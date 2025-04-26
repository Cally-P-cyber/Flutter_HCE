import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:ndef/ndef.dart';
import '../models/nfc_tag.dart';
import '../services/firestore_service.dart';
import '../services/nfc_service.dart';
import 'icon_picker.dart';

class EditTagScreen extends StatefulWidget {
  final NfcTag? existingTag;
  const EditTagScreen({Key? key, this.existingTag}) : super(key: key);

  @override
  State<EditTagScreen> createState() => _EditTagScreenState();
}

class _EditTagScreenState extends State<EditTagScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtl = TextEditingController();
  final _dataCtl = TextEditingController();
  final _rawHexCtl = TextEditingController();
  bool _expertMode = false;
  final Map<String, String> _parsedFields = {};
  String _selectedIcon = 'label';

  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    if (widget.existingTag != null) {
      final tag = widget.existingTag!;
      _nameCtl.text = tag.name;
      _dataCtl.text = tag.data;
      _selectedIcon = tag.icon;
      final bytes = Uint8List.fromList(tag.data.codeUnits);
      _rawHexCtl.text =
          bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _scanNfcTag() async {
    // Use service to handle UI and wave animation
    final rec = await NfcService.read(context, _waveController);
    if (rec == null) return;

    String text;
    // Handle URI record (type 'U')
    if (rec.tnf == TypeNameFormat.nfcWellKnown &&
        utf8.decode(rec.type!) == 'U') {
      const prefixes = <int, String>{
        0x00: '',
        0x01: 'http://www.',
        0x02: 'https://www.',
        0x03: 'http://',
        0x04: 'https://',
      };
      final code = rec.payload![0];
      final prefix = prefixes[code] ?? '';
      final body = utf8.decode(rec.payload!.sublist(1));
      text = '$prefix$body';
    }
    // Text record (type 'T')
    else if (rec.tnf == TypeNameFormat.nfcWellKnown &&
        utf8.decode(rec.type!) == 'T') {
      final status = rec.payload![0];
      final langLen = status & 0x3F;
      text = utf8.decode(rec.payload!.sublist(1 + langLen));
    }
    // Fallback raw decode
    else {
      text = utf8.decode(rec.payload!);
    }

    // Update UI
    setState(() {
      _dataCtl.text = text;
      _rawHexCtl.text = rec.payload!
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      _parsedFields.clear();
      for (var part in text.split(RegExp(r'[;,]'))) {
        final kv = part.split(':');
        if (kv.length == 2) {
          _parsedFields[kv[0].trim()] = kv[1].trim();
        }
      }
    });
  }

  Future<void> _save() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tag name cannot be empty')),
      );
      return;
    }
    final data = _expertMode ? _dataCtl.text : _dataCtl.text;
    final tag = NfcTag(
      id: widget.existingTag?.id ?? '',
      name: name,
      icon: _selectedIcon,
      data: data,
    );
    if (widget.existingTag == null) {
      await FirestoreService.addTag(tag);
    } else {
      await FirestoreService.updateTag(tag);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingTag != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Tag' : 'Add Tag')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameCtl,
              decoration: const InputDecoration(labelText: 'Tag Name'),
            ),
            const SizedBox(height: 12),
            // Icon picker
            Text('Icon', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            IconPicker(
              selectedIcon: _selectedIcon,
              onIconSelected: (icon) {
                setState(() {
                  _selectedIcon = icon;
                });
              },
            ),
            const SizedBox(height: 12),
            // Scan and display parsed data
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dataCtl,
                    readOnly: false,
                    decoration: const InputDecoration(labelText: 'Tag Data'),
                    maxLines: 2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.nfc),
                  tooltip: 'Scan NFC Tag',
                  onPressed: _scanNfcTag,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Advanced mode toggle
            SwitchListTile(
              title: const Text('Advanced Edit Mode'),
              value: _expertMode,
              onChanged: (v) => setState(() => _expertMode = v),
            ),
            const SizedBox(height: 12),
            // Advanced editable fields
            if (_expertMode) ...[
              TextField(
                controller: _rawHexCtl,
                decoration: const InputDecoration(
                  labelText: 'Raw Hex Data',
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                style: const TextStyle(fontFamily: 'Courier'),
              ),
              const SizedBox(height: 12),
              ..._parsedFields.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: TextField(
                    controller: TextEditingController(text: e.value),
                    decoration: InputDecoration(
                      labelText: e.key,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: Text(isEdit ? 'Save Changes' : 'Add Tag'),
              onPressed: _save,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Write to Tag'),
              onPressed: () async {
                final name = _nameCtl.text.trim();
                final data = _dataCtl.text.trim();
                if (name.isEmpty || data.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Tag name and data required.')),
                  );
                  return;
                }
                final success = await NfcService.write(
                  context,
                  data,
                  _waveController,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(success ? 'Write successful!' : 'Write failed.'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              },
            ),
            if (widget.existingTag != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.delete, color: Colors.white),
                label: const Text('Delete Tag'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Tag'),
                      content: const Text(
                          'Are you sure you want to delete this tag?'),
                      actions: [
                        TextButton(
                          child: const Text('Cancel'),
                          onPressed: () => Navigator.pop(context, false),
                        ),
                        TextButton(
                          child: const Text('Delete'),
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await FirestoreService.deleteTag(widget.existingTag!.id);
                    if (mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
