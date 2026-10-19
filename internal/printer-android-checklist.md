# Internal: Android printer and release checklist

Use this checklist on the actual Android release build and representative printer hardware. Record the device, Android version, printer model, connection type, and build identifier with the test results.

## Build and app identity

- [ ] Confirm the release build uses `applicationId` `com.solutivostudio.caltax` and namespace `com.solutivostudio.caltax`.
- [ ] Confirm the launcher manifest entry resolves to `com.solutivostudio.caltax.MainActivity`.
- [ ] Confirm `ANDROID_PACKAGE_NAME` in Supabase exactly matches the Play Console app package/application ID.
- [ ] Confirm the correct signing configuration and version code/name for the intended release.
- [ ] Install and launch the release-signed build on a clean Android device.

## Printer validation

- [ ] Pair a Bluetooth SPP printer in Android **Settings → Bluetooth**, then discover, select, connect, and print from BuildEra.
- [ ] Print a receipt containing a product name with an em dash (—) and curly quotation marks (“ ”); confirm the glyphs remain readable.
- [ ] Print 30 or more items on 58 mm paper using the 32-character line width; verify wrapping, totals, and readable output.
- [ ] Print 30 or more items on 80 mm paper using the 48-character line width; verify wrapping, totals, and readable output.
- [ ] Try to print while the printer is powered off and while it is connected to another device; verify a clear error appears and the transaction is preserved.
- [ ] Print with `autoCut` enabled and disabled; verify the expected cutter/feed behavior in both cases.
- [ ] On Android 12 and later, verify the Nearby Devices permission prompt and retry path. Also test Bluetooth printing on Android 10 and 11.
- [ ] Confirm BLE-only printers do not appear in the supported SPP printer list; BLE-only printing is not currently supported.

## Google Play and backend configuration

- [ ] Confirm Play Console's package name is exactly `com.solutivostudio.caltax`.
- [ ] Review every `package_name` in `android/app/google-services.json`; configure `ANDROID_PACKAGE_NAME` to the exact Play Console application ID, not another JSON entry.
- [ ] Confirm the configured Play subscription product IDs are `buildera_monthly` and `buildera_yearly`.
- [ ] Confirm Supabase secrets, RTDN push URL, and reconcile request header are configured without exposing secret values in test evidence.
- [ ] Verify a test subscription through the deployed verify function and confirm the expected status is visible in the app.
- [ ] Deliver a Pub/Sub test notification and verify the RTDN endpoint's response and function logs.
- [ ] Invoke reconciliation with the secret header and verify the returned counters and relevant function logs.

## Evidence and sign-off

- [ ] Record test date, tester, build/version, device/Android version, printer model/connection, pass/fail, and sanitized logs.
- [ ] Resolve or document failures before release approval.
