import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart' as ndef;
import 'package:nfc_host_card_emulation/nfc_host_card_emulation.dart';

/// Service for NFC-Forum Type 4 NDEF tag emulation with full APDU logging
class NfcService {
  static const List<int> _aid = [0xD2, 0x76, 0x00, 0x00, 0x85, 0x01, 0x01];
  static const List<int> _ccFile = [
    0x00, 0x0F, // CCLEN = 15 bytes
    0x20, // Mapping version 2.0
    0x00, 0x3B, // MLe = 59
    0x00, 0x34, // MLc = 52
    // NDEF File Control TLV (8 bytes)
    0x04, // Tag: NDEF File Control TLV
    0x06, // Length: 6
    0xE1, 0x04, // File ID: E104
    0x00, 0xFF, // Max NDEF size: 255 bytes
    0x00, // Read access: 0x00 (no security)
    0xFF, // Write access: 0xFF (read-only)
  ];

  static const List<int> _swSuccess = [0x90, 0x00];
  static const List<int> _swCommandNotAllowed = [0x6A, 0x81];

  static int _currentFile = 0xE103;

  /// Initialize HCE (call before runApp)
  static Future<void> init() async {
    await NfcHce.init(
      aid: Uint8List.fromList(_aid),
      permanentApduResponses: false,
      listenOnlyConfiguredPorts: false,
    );
  }

  /// Emulate an NDEF payload with YouTube scheme + AAR
  static Future<void> emulate(
    BuildContext context,
    String payload,
    AnimationController controller, {
    int durationSec = 60,
  }) async {
    await init();
    _showBottomSheet(
      context,
      title: 'Emulating NFC Tag…',
      icon: Icons.contactless,
      controller: controller,
      onCancel: () => Navigator.of(context).pop(),
    );

    final fileBytes = _makeUriNdef(payload);
    debugPrint(
        'NDEF file bytes: ${fileBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

    final sub = NfcHce.stream.listen((cmd) async {
      final c = cmd.command;
      debugPrint(
          '→ APDU in: ${c.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      debugPrint(
          'APDU raw bytes: length=${c.length}, bytes=${c.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      debugPrint('_isSelectAid: ${_isSelectAid(c)}');
      debugPrint('_isSelectFile(CC): ${_isSelectFile(c, 0xE1, 0x03)}');
      debugPrint('_isSelectFile(NDEF): ${_isSelectFile(c, 0xE1, 0x04)}');
      debugPrint('_isReadBinary: ${_isReadBinary(c)}');
      debugPrint('Current file: 0x${_currentFile.toRadixString(16)}');
      try {
        if (_isSelectAid(c)) {
          debugPrint('APDU: SELECT AID');
          _currentFile = 0xE103;
          await _send(cmd.port, Uint8List.fromList(_swSuccess));
        } else if (_isSelectFile(c, 0xE1, 0x03)) {
          debugPrint('APDU: SELECT FILE (CC)');
          _currentFile = 0xE103;
          // Standards-compliant FCI Proprietary Template for CC file
          final fci = [0x62, 0x00];
          await _send(cmd.port, Uint8List.fromList([...fci, ..._swSuccess]));
        } else if (_isSelectFile(c, 0xE1, 0x04)) {
          debugPrint('APDU: SELECT FILE (NDEF)');
          _currentFile = 0xE104;
          // Standards-compliant FCI Proprietary Template for NDEF file
          final fci = [0x62, 0x00];
          await _send(cmd.port, Uint8List.fromList([...fci, ..._swSuccess]));
        } else if (_isReadBinary(c)) {
          final offset = (c[2] << 8) | c[3];
          final le = c.length > 4 ? (c[4] == 0 ? 256 : c[4]) : 256;
          debugPrint('APDU: READ BINARY (offset: $offset, len: $le)');
          final data = _slice(_currentFile == 0xE103 ? _ccFile : fileBytes, c);
          debugPrint(
              '→ Data out: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
          await _send(cmd.port, Uint8List.fromList([...data, ..._swSuccess]));
        } else if (c.length == 1 && c[0] == 0x60) {
          debugPrint('APDU: GET RESPONSE (0x60)');
          await NfcHce.addApduResponse(
            cmd.port,
            Uint8List.fromList(_swSuccess),
          );
        } else {
          debugPrint(
              'APDU: UNHANDLED, raw=${c.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
          await NfcHce.addApduResponse(
            cmd.port,
            Uint8List.fromList(_swCommandNotAllowed),
          );
        }
      } catch (e) {
        debugPrint('APDU handler error: $e');
        await NfcHce.addApduResponse(
          cmd.port,
          Uint8List.fromList(_swCommandNotAllowed),
        );
      }
    });

    await Future.delayed(Duration(seconds: durationSec));
    await sub.cancel();
    controller.stop();
    // ignore: use_build_context_synchronously
    Navigator.of(context).pop();
  }

  /// Read a physical tag
  static Future<ndef.NDEFRecord?> read(
    BuildContext context,
    AnimationController controller, {
    int timeoutSec = 10,
  }) async {
    ndef.NDEFRecord? result;
    _showBottomSheet(
      context,
      title: 'Scan NFC Tag…',
      icon: Icons.nfc,
      controller: controller,
      onCancel: () => Navigator.of(context).pop(),
    );
    try {
      await FlutterNfcKit.poll(timeout: Duration(seconds: timeoutSec));
      final recs = await FlutterNfcKit.readNDEFRecords();
      if (recs.isNotEmpty) result = recs.first;
      await FlutterNfcKit.finish();
    } catch (e) {
      debugPrint('Read error: $e');
    }
    controller.stop();
    // ignore: use_build_context_synchronously
    Navigator.of(context).pop();
    return result;
  }

  /// Write a tag so that it opens the YouTube app directly
  static Future<bool> write(
    BuildContext context,
    String payload,
    AnimationController controller, {
    int timeoutSec = 10,
  }) async {
    _showBottomSheet(
      context,
      title: 'Write to NFC Tag…',
      icon: Icons.edit,
      controller: controller,
      onCancel: () => Navigator.of(context).pop(),
    );

    try {
      await FlutterNfcKit.poll(timeout: Duration(seconds: timeoutSec));

      // Build the vnd.youtube URI if it's a youtu.be link
      String uri = payload;
      // if (payload.startsWith('https://youtu.be/')) {
      //   uri = 'vnd.youtube://' + payload.split('/').last;
      // }

      // Create the URI record
      final uriRecord = ndef.UriRecord.fromString(uri);
      // Create the Android Application Record (AAR)
      final aarRecord = ndef.AARRecord(
        packageName: 'com.google.android.youtube',
      );

      // Write both records to the tag
      await FlutterNfcKit.writeNDEFRecords([uriRecord, aarRecord]);
      await FlutterNfcKit.finish();
      controller.stop();
      // ignore: use_build_context_synchronously
      Navigator.of(context).pop();
      return true;
    } catch (e) {
      debugPrint('Write error: $e');
      controller.stop();
      // ignore: use_build_context_synchronously
      Navigator.of(context).pop();
      return false;
    }
  }

  // Platform channel to communicate with native HCE service
  static const MethodChannel _channel = MethodChannel('nfc_emulator_channel');

  /// Set the payload to emulate (URL or plain text)
  static Future<void> setNdefPayload(String payload,
      {bool isUrl = true}) async {
    await _channel.invokeMethod('setNdefPayload', {
      'payload': payload,
      'isUrl': isUrl,
    });
  }

  // ─────────── private helpers ───────────

  static Future<void> _send(int port, Uint8List data) async {
    // Only append status word if not already present
    List<int> out;
    if (data.length >= 2 &&
        data[data.length - 2] == _swSuccess[0] &&
        data[data.length - 1] == _swSuccess[1]) {
      out = data;
    } else {
      out = [...data, ..._swSuccess];
    }
    debugPrint(
        '→ Response out: ${out.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    await NfcHce.addApduResponse(port, Uint8List.fromList(out));
  }

  static bool _isSelectAid(List<int> c) =>
      c.length >= 12 &&
      c[0] == 0x00 &&
      c[1] == 0xA4 &&
      c[2] == 0x04 &&
      c[3] == 0x00 &&
      c[4] == 0x07 &&
      const ListEquality().equals(c.sublist(5, 12), _aid);

  static bool _isSelectFile(List<int> c, int hi, int lo) {
    if (c.length != 7) {
      debugPrint(
          '[_isSelectFile] length mismatch: got ${c.length}, expected 7. APDU: ${c.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
      return false;
    }
    if (c[0] != 0x00) {
      debugPrint(
          '[_isSelectFile] CLA mismatch: got ${c[0].toRadixString(16)}, expected 00');
      return false;
    }
    if (c[1] != 0xA4) {
      debugPrint(
          '[_isSelectFile] INS mismatch: got ${c[1].toRadixString(16)}, expected A4');
      return false;
    }
    if (c[2] != 0x00) {
      debugPrint(
          '[_isSelectFile] P1 mismatch: got ${c[2].toRadixString(16)}, expected 00');
      return false;
    }
    if (!(c[3] == 0x00 || c[3] == 0x0C)) {
      debugPrint(
          '[_isSelectFile] P2 mismatch: got ${c[3].toRadixString(16)}, expected 00 or 0C');
      return false;
    }
    if (c[4] != 0x02) {
      debugPrint(
          '[_isSelectFile] Lc mismatch: got ${c[4].toRadixString(16)}, expected 02');
      return false;
    }
    if (c[5] != hi) {
      debugPrint(
          '[_isSelectFile] FileID hi mismatch: got ${c[5].toRadixString(16)}, expected ${hi.toRadixString(16)}');
      return false;
    }
    if (c[6] != lo) {
      debugPrint(
          '[_isSelectFile] FileID lo mismatch: got ${c[6].toRadixString(16)}, expected ${lo.toRadixString(16)}');
      return false;
    }
    debugPrint(
        '[_isSelectFile] Matched for FileID: ${hi.toRadixString(16)}${lo.toRadixString(16)}');
    return true;
  }

  static bool _isReadBinary(List<int> c) =>
      c.length >= 5 && c[0] == 0x00 && c[1] == 0xB0;

  static List<int> _slice(List<int> file, List<int> apdu) {
    final offset = (apdu[2] << 8) | apdu[3];
    final le = apdu.length > 4 ? (apdu[4] == 0 ? 256 : apdu[4]) : 256;
    if (offset >= file.length) return [];
    return file.sublist(offset, min(offset + le, file.length));
  }

  static List<int> _makeUriNdef(String text) {
    // Minimal NDEF text record
    final lang = 'en';
    final textBytes = utf8.encode(text);
    final langBytes = utf8.encode(lang);
    final payload = [langBytes.length, ...langBytes, ...textBytes];
    final recordHeader = [
      0xD1,
      0x01,
      payload.length,
      0x54
    ]; // Well-known, short, text
    final ndefMessage = [...recordHeader, ...payload];
    // According to NFC Forum Type 4 Tag spec, prepend 2-byte NLEN (NDEF length) to the message
    final nlen = ndefMessage.length;
    final ndefFile = [(nlen >> 8) & 0xFF, nlen & 0xFF, ...ndefMessage];
    return ndefFile;
  }

  static void _showBottomSheet(BuildContext ctx,
      {required String title,
      required IconData icon,
      required AnimationController controller,
      required VoidCallback onCancel}) {
    controller.repeat();
    showModalBottomSheet(
      context: ctx,
      isDismissible: false,
      enableDrag: false,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: Theme.of(ctx).textTheme.headlineSmall),
          SizedBox(height: 16),
          ScaleTransition(
            scale: controller.drive(
              Tween(begin: 0.8, end: 1.2)
                  .chain(CurveTween(curve: Curves.easeInOut)),
            ),
            child: Transform.rotate(
              angle: icon == Icons.contactless ? 270 * pi / 180 : 0,
              child:
                  Icon(icon, size: 80, color: Color.fromARGB(255, 11, 218, 81)),
            ),
          ),
          SizedBox(height: 24),
          Text('Tap your phone to the reader'),
          SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel'),
          ),
        ]),
      ),
    );
  }
}
