import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({Key? key}) : super(key: key);

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen>
    with SingleTickerProviderStateMixin {
  String? _status;
  Map<String, dynamic>? _tagFields;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 0.8,
      upperBound: 1.2,
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _readTag());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _readTag() async {
    setState(() {
      _status = 'Waiting for NFC tag...';
      _tagFields = null;
    });
    try {
      final tag =
          await FlutterNfcKit.poll(timeout: const Duration(seconds: 20));
      final fields = <String, dynamic>{
        'ID': tag.id,
        'Type': tag.type.toString(),
        'Standard': tag.standard,
        'ATQA': tag.atqa,
        'SAK': tag.sak,
        'Historical Bytes': tag.historicalBytes,
        'Protocol Info': tag.protocolInfo,
        'Application Data': tag.applicationData,
        'Manufacturer': tag.manufacturer,
        'System Code': tag.systemCode,
        'DSF ID': tag.dsfId,
      };
      try {
        final ndefAvailable = tag.ndefAvailable ?? false;
        fields['Is NDEF'] = ndefAvailable;
        if (ndefAvailable) {
          final ndefRecords = await FlutterNfcKit.readNDEFRecords();
          fields['NDEF Records'] =
              ndefRecords.map((r) => r.toString()).toList();
        }
      } catch (e) {
        fields['NDEF Records'] = 'Error reading NDEF: $e';
      }
      setState(() {
        _status = 'Tag scanned!';
        _tagFields = fields;
      });
      await FlutterNfcKit.finish();
    } on PlatformException catch (e) {
      setState(() {
        if (e.code == '405') {
          _status =
              'NDEF not supported on this tag.\nTry a different tag or device.';
        } else {
          _status = 'Error: ${e.message}';
        }
      });
      await FlutterNfcKit.finish();
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
      await FlutterNfcKit.finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NFC Reader')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Transform.scale(
                    scale: _controller.value,
                    child: Icon(Icons.nfc, size: 80, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 24),
                if (_status != null) ...[
                  Text(_status!, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 12),
                ],
                if (_tagFields != null) ...[
                  if ((_tagFields!['NDEF Records'] == null ||
                          _tagFields!['NDEF Records']
                              .toString()
                              .contains('Error')) &&
                      _tagFields!['ID'] != null) ...[
                    const Divider(),
                    Text('Raw Tag Data:',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 2),
                    SelectableText(
                        _tagFields!.entries
                            .map((e) => '${e.key}: ${e.value}')
                            .join('\n'),
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                  ],
                  ..._tagFields!.entries.map((e) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.key}:',
                              style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: 2),
                          SelectableText('${e.value ?? ""}'),
                          const SizedBox(height: 8),
                        ],
                      )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
