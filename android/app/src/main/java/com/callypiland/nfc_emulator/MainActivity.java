package com.callypiland.nfc_emulator;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.plugin.common.MethodChannel;
import androidx.annotation.NonNull;
import com.callypiland.nfc_emulator.MyHostApduService;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "nfc_emulator_channel";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler(
                (call, result) -> {
                    if (call.method.equals("setNdefPayload")) {
                        String payload = call.argument("payload");
                        Boolean isUrl = call.argument("isUrl");
                        MyHostApduService.setPayload(payload, isUrl != null && isUrl);
                        result.success(null);
                    } else {
                        result.notImplemented();
                    }
                }
            );
    }
}