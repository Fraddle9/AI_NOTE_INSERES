#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter bulunamadı. Önce Flutter SDK kurun, sonra:"
  echo "  flutter create . --project-name ainote_mobile --org com.gmz.ainote --platforms android,ios"
  echo "  ./setup.sh"
  exit 1
fi

if [ ! -d android ] || [ ! -d ios ]; then
  flutter create . --project-name ainote_mobile --org com.gmz.ainote --platforms android,ios
fi

MANIFEST="$ROOT/android/app/src/main/AndroidManifest.xml"
if [ -f "$MANIFEST" ]; then
  python3 - "$MANIFEST" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text()
perms = (
    '    <uses-permission android:name="android.permission.INTERNET"/>\n'
    '    <uses-permission android:name="android.permission.RECORD_AUDIO"/>\n'
    '    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>\n'
)
if "android.permission.RECORD_AUDIO" not in text:
    insert_at = text.find("<application")
    if insert_at == -1:
        raise SystemExit("AndroidManifest.xml içinde <application> bulunamadı")
    text = text[:insert_at] + perms + text[insert_at:]
if "usesCleartextTraffic" not in text:
    text = text.replace("<application", '<application android:usesCleartextTraffic="true"', 1)
p.write_text(text)
print("AndroidManifest izinleri eklendi.")
PY
fi

PLIST="$ROOT/ios/Runner/Info.plist"
if [ -f "$PLIST" ]; then
  python3 - "$PLIST" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text()
changed = False
if "NSMicrophoneUsageDescription" not in text:
    text = text.replace(
        "<dict>",
        """<dict>
	<key>NSMicrophoneUsageDescription</key>
	<string>Görüşme kaydı almak ve yapay zeka ile analiz etmek için mikrofon erişimi gerekir.</string>""",
        1,
    )
    changed = True
if "NSAppTransportSecurity" not in text:
    text = text.replace(
        "</dict>\n</plist>",
        """	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoads</key>
		<true/>
	</dict>
</dict>
</plist>""",
        1,
    )
    changed = True
if changed:
    p.write_text(text)
    print("Info.plist mikrofon ve HTTP ayarları eklendi.")
PY
fi

PODFILE="$ROOT/ios/Podfile"
if [ -f "$PODFILE" ] && ! grep -q 'PERMISSION_MICROPHONE' "$PODFILE"; then
  python3 - "$PODFILE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text()
needle = "flutter_additional_ios_build_settings(target)"
extra = """
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_MICROPHONE=1',
      ]
    end
"""
if needle in text and "PERMISSION_MICROPHONE" not in text:
    text = text.replace(needle, needle + extra, 1)
    p.write_text(text)
    print("Podfile mikrofon izni eklendi.")
PY
fi

flutter pub get
echo "Kurulum tamam. Backend açıkken: flutter run"
