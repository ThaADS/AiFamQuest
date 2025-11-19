# APK Build Diagnose & Oplossingen

## 🔴 Probleem Geïdentificeerd

De APK build faalt door **geheugen tekort** op het systeem:

```
System Memory: 7.6GB total
Available Memory: 525MB free (6.9%)
JVM Crash: OutOfMemoryError during Gradle build
```

### Root Cause
- **Te weinig vrij RAM**: Slechts 525MB beschikbaar van 7.6GB
- **Gradle daemon crash**: JVM kan niet genoeg geheugen alloceren
- **Build proces**: Android build vereist ~2-4GB vrij geheugen

## ✅ Geteste Oplossingen

### 1. Geheugen Configuratie Aanpassingen ❌
```properties
# Geprobeerd: 4GB, 2GB, 1.5GB heap
org.gradle.jvmargs=-Xmx1536m -XX:MaxMetaspaceSize=512m
```
**Resultaat**: JVM blijft crashen door onvoldoende systeem RAM

### 2. Flutter Doctor Check ✅
```bash
Flutter (Channel stable, 3.35.3) ✓
Android toolchain (SDK 35.0.0) ⚠️
```
**Bevinding**: Flutter en Android SDK correct geïnstalleerd

### 3. Configuratie Controle ✅
- ✓ `build.gradle.kts` correct geconfigureerd
- ✓ Dependencies up-to-date
- ✓ Firebase/Supabase plugins correct
- ✓ Android namespace ingesteld

## 💡 Aanbevolen Oplossingen

### **Optie A: Systeem RAM Vrijmaken (Aanbevolen)**

1. **Sluit grote applicaties**:
   ```bash
   # Sluit browser tabs, IDE's, etc.
   # Controleer Task Manager
   ```

2. **Herstart systeem**:
   ```bash
   # Verse start met meer beschikbaar geheugen
   ```

3. **Probeer opnieuw**:
   ```bash
   cd flutter_app
   flutter build apk --debug
   ```

### **Optie B: Cloud Build (Alternatief)**

Gebruik **Codemagic** of **GitHub Actions** voor remote build:

#### GitHub Actions Workflow
```yaml
name: Build Android APK
on: [push, workflow_dispatch]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.3'
      - name: Install dependencies
        run: |
          cd flutter_app
          flutter pub get
      - name: Build APK
        run: |
          cd flutter_app
          flutter build apk --debug
      - name: Upload APK
        uses: actions/upload-artifact@v3
        with:
          name: app-debug.apk
          path: flutter_app/build/app/outputs/flutter-apk/app-debug.apk
```

**Voordelen**:
- ✓ 7GB RAM beschikbaar
- ✓ Snellere build (SSD + multi-core)
- ✓ Geen lokale resource gebruik

### **Optie C: Split APK per ABI**

Bouw alleen voor één architectuur (minder geheugen):

```bash
cd flutter_app
flutter build apk --debug --split-per-abi --target-platform android-arm64
```

**Resultaat**: Kleinere APK (20-30MB) met minder geheugen gebruik

### **Optie D: Web Build (Direct Testbaar)**

Als alternatief voor snelle testing:

```bash
cd flutter_app
flutter build web --profile
```

**Voordelen**:
- ✓ Geen geheugen issues
- ✓ Direct testbaar in browser
- ✓ Snelle iteratie cyclus

## 🎯 Aanbevolen Aanpak (Stap voor Stap)

### **Fase 1: Snelle Test (5 min)**
```bash
# Web build voor directe functionaliteit test
cd flutter_app
flutter run -d chrome --profile
```

### **Fase 2: Lokale APK (15 min)**
```bash
# 1. Sluit alle apps, herstart systeem
# 2. Bouw split APK (minder geheugen)
flutter build apk --debug --split-per-abi --target-platform android-arm64

# Output: build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk
```

### **Fase 3: Cloud Build (20 min, eenmalig setup)**
```bash
# 1. Kopieer .github/workflows/build-android.yml
# 2. Push naar GitHub
# 3. Download APK van Actions tab
```

## 📊 APK Verwachte Output

### Debug APK
```
Locatie: flutter_app/build/app/outputs/flutter-apk/
Bestanden:
  - app-debug.apk (~50-70MB)
  - app-arm64-v8a-debug.apk (~20-30MB, split)
  - app-armeabi-v7a-debug.apk (~20-30MB, split)
  - app-x86_64-debug.apk (~25-35MB, split)
```

### Release APK (na signing)
```
Locatie: flutter_app/build/app/outputs/flutter-apk/
Bestanden:
  - app-release.apk (~30-40MB, minified + obfuscated)
```

## 🧪 Test Checklist (Na Succesvolle Build)

### Installatie Test
```bash
# Via ADB
adb install build/app/outputs/flutter-apk/app-debug.apk

# Of via browser (op Android device)
# Upload APK naar Google Drive / Dropbox
# Download op telefoon
```

### Functionaliteit Test
- [ ] App opent zonder crash
- [ ] Login scherm toont (SSO buttons)
- [ ] Navigatie werkt (bottom nav)
- [ ] Kalender laadt
- [ ] Taken lijst toont
- [ ] Foto upload werkt
- [ ] Push notificaties (FCM)
- [ ] Offline mode (airplane mode test)

## 🚨 Bekende Issues & Workarounds

### Issue 1: Firebase Setup
```bash
# Als Firebase config ontbreekt:
# Download google-services.json van Firebase Console
# Plaats in: flutter_app/android/app/google-services.json
```

### Issue 2: Sign in with Apple (alleen iOS)
```yaml
# Android ondersteunt geen native Apple Sign In
# Workaround: Web-based OAuth flow (redirect)
```

### Issue 3: Supabase .env bestand
```bash
# Zorg dat .env bestaat met:
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

## 📈 Next Steps

### Na Succesvolle APK Build
1. **Test op echte device** (niet alleen emulator)
2. **Logging inschakelen** (Firebase Crashlytics)
3. **Performance profiling** (Flutter DevTools)
4. **Release build maken** met signing keys
5. **Uploaden naar Play Store** (Internal Testing track)

### Signing Setup (voor Release)
```bash
# 1. Generate keystore
keytool -genkey -v -keystore famquest-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias famquest

# 2. Create key.properties
# flutter_app/android/key.properties:
storePassword=<password>
keyPassword=<password>
keyAlias=famquest
storeFile=../../famquest-release.jks

# 3. Build release
flutter build apk --release
```

## 🔗 Resources

- [Flutter Android Build](https://docs.flutter.dev/deployment/android)
- [Gradle Memory Optimization](https://docs.gradle.org/current/userguide/build_environment.html)
- [Codemagic Flutter CI/CD](https://codemagic.io/start/)
- [GitHub Actions for Flutter](https://github.com/subosito/flutter-action)

---

**Laatste Update**: 2025-11-19 20:50
**Status**: Diagnose compleet, oplossingen gedocumenteerd
