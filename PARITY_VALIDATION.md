# Mobile dashboard parity validation

Reference: `../server-frontend/app` and `../server-backend`. All changes are confined to the Flutter project. No backend changes or deployment are required.

## Connection

The default REST base is `https://app.geonutria.ai/api`; support uses `wss://app.geonutria.ai/api`. Existing user identity, request fields, payment method values, streaming endpoints, and report schema v2 are preserved. Build-time overrides remain available through `API_BASE_URL`, `STATIC_BASE_URL`, and `WS_BASE_URL`.

## Changes

- Localized interface labels, validation, statuses, schedules, support quick replies, and export prompts; Arabic layout direction and Arabic/Persian numeric input handling.
- Explicit selected language for soil classification, crop recommendations, yield, consultant, automation advice, accounting advice, and advanced chat. Language changes reset affected AI views so previous-language answers are not shown as new-language answers.
- Device selection and account identity respected in IoT auto-fill and reports. Missing probes remain absent; valid zero readings remain available.
- Reports use actual results from this session, with availability gating, current-language AI content, history summaries, accounting, automation, satellite, and visited-device imagery. No fabricated example diagnoses or yields. Binary PDF responses are validated.
- PDF save cancellation is respected; native sharing attaches the PDF.
- Admin device/actuator inventory forms, assignments, user details, credits/feature settings, map locations, fleet map, MQTT diagnostics, analytics, and payment approval views use existing endpoints.
- Billing transfer details and submitted method values match the dashboard source.
- Support waits for the WebSocket handshake, preserves unsent drafts while offline, and offers explicit reconnection. Reconnection uses the backend's existing session charge.
- Authentication payload logging redacts sensitive fields; test credentials are not stored in source or test fixtures.

## Verification

- `flutter test --no-pub`: 28 tests pass, covering API/PDF contracts, language keys, AI language requests, Arabic numeric input, report data/account isolation, and English/Arabic phone layouts.
- Live sign-in against the deployed backend succeeded with the supplied test account. Dashboard device/schedule data loaded. English and Arabic navigation and Arabic crop-advisor rendering were inspected; a real header overflow was corrected.
- `flutter analyze --no-pub --no-fatal-infos`: passed with no errors or warnings; 66 informational style/deprecation notices remain.
- `flutter build web --no-pub --no-wasm-dry-run`: passed. Output: `build/web`.
- `flutter build apk --debug --no-pub`: passed. Output: `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: passed.
- Android 16 emulator smoke test: APK installed, Flutter engine started, and the existing session received responses from profile, devices, control, and hierarchy endpoints. The resource-constrained emulator showed slow frames and initial settings/auth bootstrap timeouts before recovering. This was a startup/network smoke test, not a complete native interaction test.

## Verification limits

This is not a claim that every dashboard interaction has been exhaustively exercised. Live device actuation, deletions, user permission changes, receipt uploads, and payment approval were not executed against the production server. AI request contracts were tested with controlled responses; all live paid AI models were not invoked. iOS execution requires an Apple build environment. Names, messages, addresses, and other user-entered content retain their original language; the app does not translate or rewrite user data.

Report results are held in memory for the current signed-in session. A fresh app launch requires running/loading a feature before its results can be included. If imagery cannot be fetched within the size/time limits, the report retains location metadata and marks that image unavailable.

## Advanced AI image follow-up

The reported high-traffic response appeared on an image question. The mobile upload omitted an image MIME type; a live synthetic PNG upload confirmed that `/v1/upload-media` returned `data:application/octet-stream;base64,...`. The dashboard bypasses that endpoint and sends an image data URL directly. Mobile now follows the dashboard approach, detecting JPEG/PNG/GIF/WebP from bytes and retaining the image MIME type. A live corrected PNG chat request returned a successful AI answer. No backend changes were made.

Failed requests also no longer shift subsequent conversation roles, and saved session API histories are copied rather than retaining a mutable list. Four regression tests cover Arabic/English multimodal payloads, failed-turn recovery, and saved history isolation. Provider-side temporary failures can still occur; this fix addresses the confirmed mobile image encoding mismatch.

The rebuilt browser app successfully answered a synthetic image attachment in Arabic. All 32 tests passed, and both web and Android debug builds succeeded. The thinking/reasoning label now uses the selected UI language.

A controlled live comparison confirmed the cause: the same synthetic PNG sent as `application/octet-stream` reproduced the exact reported high-traffic message, while `image/png` returned an answer. Final analysis passed with no errors or warnings (66 existing informational notices).

## Farm location and profile follow-up

- Crop Advisor's **Edit Context** location accepts manual text and offers the current user's farm names from the existing hierarchy in a dropdown. Empty farm lists leave manual entry available. Selection stores the farm name in the existing analysis `location` field when Save Context is pressed. The main farm context retains its original geographic-region dropdown; the editable farm-name control was moved out of that main context at the user's request.
- Profile phone editing separates the country calling code from the national number, with common countries and manual entry for other calling codes. Numeric input accepts Arabic/Persian digits, rejects letters, validates length (and Egyptian mobile prefixes), and sends the country code plus national number as digits only. Domestic trunk zero handling is applied for the listed countries, retaining Italy's significant zero. Existing phone values are not rewritten when unrelated profile fields change.
- Password changes show a disabled/loading submit action, explicit localized success or failure next to the form, preserve input on failure, and clear it only on success. Current passwords retain significant spaces. Missing sessions and repeated failures also produce explicit outcomes.
- Phone-width layout issues found in the expanded context header and profile heading were corrected.
- Full suite: 39 tests passed. The final phone/form subset (7 tests) passed after the unchanged-phone safeguard. Analysis passed with no errors or warnings; 68 informational notices remain. Password success/failure were exercised with controlled API responses; the live account password was not changed. Backend files were not edited.
- Live browser inspection confirmed that the location dropdown contains the account's farms and that the country selector uses Arabic country labels. Password action labels were translated and calling-code plus signs isolated for correct Arabic display; the final form/localization subset (9 tests) passed. The final web build succeeded.
- The final Android debug APK also built successfully with these changes.
- Location placement correction: six focused form tests pass in English and Arabic, including Crop Advisor farm-name selection/manual saving and the restored main-context region choices. The corrected web build passed.

## Release 1.0.0+2

- Full regression suite: 41 tests passed before release packaging.
- Android release signing still uses the repository's existing debug signing configuration. The release-mode APK is suitable for testing/sideloading; production publishing requires the application's production signing setup.

## Leaf Doctor removal

Removed the mobile Leaf Doctor screen, cubit, diagnosis repository methods, navigation entry, support shortcut, and report selection/capture. Report requests explicitly send `include_leaf_ai: false` because the unchanged backend defaults it to true. Shared soil classification, satellite palm counting, and general AI features remain available.

All 41 tests passed. Web and release APK builds succeeded for 1.0.0+3. Live browser inspection confirmed Leaf Doctor is absent from the bottom navigation and drawer. Release signing continues to use the existing debug key.
