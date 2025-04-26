package com.callypiland.nfc_emulator;

import android.nfc.cardemulation.HostApduService;
import android.os.Bundle;
import android.util.Log;
import java.util.Arrays;

public class MyHostApduService extends HostApduService {
    // AID for NFC Forum Type 4 Tag
    private static final String TYPE4_AID = "D2760000850101";
    // File IDs for CC and NDEF
    private static final byte[] CC_FILE_ID = {(byte) 0xE1, 0x03};
    private static final byte[] NDEF_FILE_ID = {(byte) 0xE1, 0x04};

    // Capability Container (CC) file (15 bytes, standard for NDEF)
    private static final byte[] CC_FILE = {
        0x00, 0x0F, 0x20, 0x00, 0x3B, 0x00, 0x34,
        0x04, 0x06, (byte) 0xE1, 0x04, 0x00, (byte) 0xFF, 0x00, (byte) 0xFF
    };

    // Dynamic payload for NDEF emulation (set via platform channel)
    private static String currentPayload = "https://www.example.com";
    private static boolean isUrl = true;

    public static void setPayload(String payload, boolean url) {
        currentPayload = payload;
        isUrl = url;
        Log.d("MyHostApduService", "Payload set: " + payload + ", isUrl: " + url);
    }

    private static byte[] getNdefFile() {
        Log.d("MyHostApduService", "getNdefFile: payload=" + currentPayload + ", isUrl=" + isUrl);
        return isUrl ? makeNdefUri(currentPayload) : makeNdefText(currentPayload);
    }

    // Example NDEF message (URL record: https://www.example.com)
    // private static final byte[] NDEF_FILE = makeNdefUri("https://www.example.com");

    private static byte[] makeNdefUri(String url) {
        // Build a simple NDEF URI record with 2-byte NLEN prefix
        byte[] uriBytes = url.getBytes();
        byte[] ndefRecord = new byte[uriBytes.length + 5];
        ndefRecord[0] = (byte) 0xD1; // MB/ME/Short/Type=Well-known
        ndefRecord[1] = 0x01;        // Type Length
        ndefRecord[2] = (byte) (uriBytes.length + 1); // Payload Length
        ndefRecord[3] = 0x55;        // Type = 'U' (URI)
        ndefRecord[4] = 0x00;        // URI Prefix: none
        System.arraycopy(uriBytes, 0, ndefRecord, 5, uriBytes.length);

        int nlen = ndefRecord.length;
        byte[] ndefFile = new byte[nlen + 2];
        ndefFile[0] = (byte) ((nlen >> 8) & 0xFF);
        ndefFile[1] = (byte) (nlen & 0xFF);
        System.arraycopy(ndefRecord, 0, ndefFile, 2, nlen);
        return ndefFile;
    }

    private static byte[] makeNdefText(String text) {
        byte[] langBytes = "en".getBytes();
        byte[] textBytes = text.getBytes();
        byte[] payload = new byte[1 + langBytes.length + textBytes.length];
        payload[0] = (byte) langBytes.length;
        System.arraycopy(langBytes, 0, payload, 1, langBytes.length);
        System.arraycopy(textBytes, 0, payload, 1 + langBytes.length, textBytes.length);

        byte[] ndefRecord = new byte[4 + payload.length];
        ndefRecord[0] = (byte) 0xD1; // MB/ME/Short/Type=Well-known
        ndefRecord[1] = 0x01;        // Type Length
        ndefRecord[2] = (byte) payload.length;
        ndefRecord[3] = 0x54;        // Type = 'T' (Text)
        System.arraycopy(payload, 0, ndefRecord, 4, payload.length);

        int nlen = ndefRecord.length;
        byte[] ndefFile = new byte[nlen + 2];
        ndefFile[0] = (byte) ((nlen >> 8) & 0xFF);
        ndefFile[1] = (byte) (nlen & 0xFF);
        System.arraycopy(ndefRecord, 0, ndefFile, 2, nlen);
        return ndefFile;
    }

    private int currentFile = 0;

    @Override
    public byte[] processCommandApdu(byte[] apdu, Bundle extras) {
        // APDU command parsing (simplified for demo)
        if (isSelectAid(apdu)) {
            currentFile = 0;
            return success();
        } else if (isSelectFile(apdu, CC_FILE_ID)) {
            currentFile = 1;
            return fci();
        } else if (isSelectFile(apdu, NDEF_FILE_ID)) {
            currentFile = 2;
            return fci();
        } else if (isReadBinary(apdu)) {
            int offset = ((apdu[2] & 0xFF) << 8) | (apdu[3] & 0xFF);
            int le = apdu.length > 4 ? (apdu[4] == 0 ? 256 : apdu[4] & 0xFF) : 256;
            byte[] file = (currentFile == 1) ? CC_FILE : getNdefFile();
            if (offset >= file.length) return success();
            int end = Math.min(offset + le, file.length);
            byte[] out = Arrays.copyOfRange(file, offset, end);
            return concat(out, success());
        }
        return new byte[]{(byte) 0x6A, (byte) 0x82}; // File not found
    }

    @Override
    public void onDeactivated(int reason) {}

    private boolean isSelectAid(byte[] apdu) {
        return apdu.length >= 12 && apdu[1] == (byte) 0xA4 && apdu[2] == 0x04;
    }

    private boolean isSelectFile(byte[] apdu, byte[] fileId) {
        return apdu.length >= 7 && apdu[1] == (byte) 0xA4 && apdu[2] == 0x00
            && apdu[4] == 0x02 && apdu[5] == fileId[0] && apdu[6] == fileId[1];
    }

    private boolean isReadBinary(byte[] apdu) {
        return apdu.length >= 5 && apdu[1] == (byte) 0xB0;
    }

    private byte[] success() { return new byte[]{(byte) 0x90, 0x00}; }
    private byte[] fci() { return new byte[]{(byte) 0x62, 0x00, (byte) 0x90, 0x00}; }
    private byte[] concat(byte[] a, byte[] b) {
        byte[] out = Arrays.copyOf(a, a.length + b.length);
        System.arraycopy(b, 0, out, a.length, b.length);
        return out;
    }
}
