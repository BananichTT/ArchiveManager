# Fix white screen and freeze when sharing a file to the app

The app hangs with a white screen (splash screen) when launched via a "Share" intent. This is likely due to the `receive_sharing_intent` plugin or the Flutter engine struggling to initialize properly when started with a specific `SEND` intent, possibly aggravated by the Impeller rendering backend or incompatible SDK versions.

## Proposed Changes

### Android Configuration

#### [MODIFY] [AndroidManifest.xml](file:///D:/Programmist_Projects/Adroid Studio Projects/ArchiveManager/android/app/src/main/AndroidManifest.xml)
- Disable Impeller rendering backend as a troubleshooting step.
- Ensure `launchMode` is `singleTask` or `singleTop` (currently `singleTop`, which is fine, but we'll verify).
- Add metadata to handle large heap if the shared file processing is memory-intensive.

#### [MODIFY] [MainActivity.kt](file:///D:/Programmist_Projects/Adroid Studio Projects/ArchiveManager/android/app/src/main/kotlin/com/example/archive_manager/MainActivity.kt)
- Add logging to track Intent delivery on the native side.
- Ensure `onNewIntent` is properly overridden (though `FlutterActivity` handles it, explicit logging helps).

#### [MODIFY] [build.gradle.kts](file:///D:/Programmist_Projects/Adroid Studio Projects/ArchiveManager/android/app/build.gradle.kts) and [android/build.gradle.kts](file:///D:/Programmist_Projects/Adroid Studio Projects/ArchiveManager/android/build.gradle.kts)
- Lower `compileSdk` to a stable version (34 or 35) to avoid preview SDK issues.

### Flutter Logic

#### [MODIFY] [main.dart](file:///D:/Programmist_Projects/Adroid Studio Projects/ArchiveManager/lib/main.dart)
- Add global intent handling to ensure the shared file is processed even if `DownloadsScreen` is not the initial route.
- Add logging to verify Flutter engine startup.

## Verification Plan

### Manual Verification
- Share a file from a file manager to the "Archive Manager" app.
- Verify that the app starts, shows the home screen (or navigates to the downloads screen), and doesn't hang on a white screen.
- Check Logcat for "APP STARTING" and intent-related logs.
