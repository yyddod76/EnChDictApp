from fpdf import FPDF

class PDF(FPDF):
    def header(self):
        self.set_font("Helvetica", "B", 11)
        self.set_fill_color(55, 71, 79)
        self.set_text_color(255, 255, 255)
        self.cell(0, 10, "Release Plan - CE Dictionary Flutter App", fill=True,
                  new_x="LMARGIN", new_y="NEXT", align="C")
        self.set_text_color(0, 0, 0)
        self.ln(2)

    def footer(self):
        self.set_y(-12)
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(120, 120, 120)
        self.cell(0, 8, f"Page {self.page_no()}", align="C")

    def section_title(self, title, r=55, g=71, b=79):
        self.set_font("Helvetica", "B", 12)
        self.set_fill_color(r, g, b)
        self.set_text_color(255, 255, 255)
        self.cell(0, 8, title, fill=True, new_x="LMARGIN", new_y="NEXT")
        self.set_text_color(0, 0, 0)
        self.ln(1)

    def sub_title(self, title):
        self.set_font("Helvetica", "B", 10)
        self.set_text_color(55, 71, 79)
        self.cell(0, 7, title, new_x="LMARGIN", new_y="NEXT")
        self.set_text_color(0, 0, 0)

    def body(self, text):
        self.set_font("Helvetica", "", 9)
        self.multi_cell(0, 5, text)
        self.ln(1)

    def bullet(self, text, indent=6):
        self.set_font("Helvetica", "", 9)
        self.set_x(self.l_margin + indent)
        self.multi_cell(0, 5, "-  " + text)

    def code(self, text):
        self.set_font("Courier", "", 8)
        self.set_fill_color(240, 240, 240)
        for line in text.strip().split("\n"):
            self.set_x(self.l_margin + 6)
            self.cell(0, 5, line, fill=True, new_x="LMARGIN", new_y="NEXT")
        self.set_fill_color(255, 255, 255)
        self.ln(1)

    def table(self, headers, rows, col_widths):
        self.set_font("Helvetica", "B", 9)
        self.set_fill_color(207, 216, 220)
        for i, h in enumerate(headers):
            self.cell(col_widths[i], 7, h, border=1, fill=True, align="C")
        self.ln()
        self.set_font("Helvetica", "", 9)
        for row in rows:
            for i, cell in enumerate(row):
                self.cell(col_widths[i], 6, cell, border=1)
            self.ln()
        self.ln(3)

    def warning(self, text):
        self.set_font("Helvetica", "B", 9)
        self.set_fill_color(255, 243, 205)
        self.set_draw_color(255, 193, 7)
        self.set_text_color(102, 77, 3)
        self.multi_cell(0, 6, "  [!]  " + text, border=1, fill=True)
        self.set_draw_color(0, 0, 0)
        self.set_text_color(0, 0, 0)
        self.ln(2)

    def checklist_item(self, text):
        self.set_font("Helvetica", "", 9)
        self.set_x(self.l_margin + 6)
        self.cell(7, 6, "[ ]", border=0)
        self.multi_cell(0, 6, text)


pdf = PDF()
pdf.set_auto_page_break(auto=True, margin=15)
pdf.add_page()
pdf.set_left_margin(15)
pdf.set_right_margin(15)

pdf.body("Generated: 2026-03-16     Project: dict_ce_view_demo     Flutter 3.x")
pdf.ln(2)

# --------------------------------------------------------------------------
# PART 1 - GOOGLE PLAY
# --------------------------------------------------------------------------
pdf.section_title("PART 1 - Google Play Release (Android)")

pdf.sub_title("Step 1 - Fix App Identity  [REQUIRED]")
pdf.body("Your project still uses placeholder values that Google Play will reject:")
pdf.warning('applicationId = "com.example.*" is banned on Google Play. Must be changed before first upload.')
pdf.body("android/app/build.gradle.kts:")
pdf.code('applicationId = "com.yourcompany.dictceview"')
pdf.body("android/app/src/main/AndroidManifest.xml:")
pdf.code('android:label="CE Dictionary"')
pdf.body("pubspec.yaml - set a real version:")
pdf.code("version: 1.0.0+1    # versionName+versionCode")

pdf.sub_title("Step 2 - Generate Upload Keystore  [One-Time]")
pdf.warning("The keystore file is irreplaceable. Back it up securely. Losing it means you can never update the app on Google Play.")
pdf.body("Run in any terminal:")
pdf.code(
    "keytool -genkey -v -keystore ~/upload-keystore.jks \\\n"
    "  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \\\n"
    "  -alias upload"
)
pdf.body("You will be prompted for a password and your organization details.")

pdf.sub_title("Step 3 - Wire Keystore to the Build")
pdf.body("Create android/key.properties  (add to .gitignore - never commit it):")
pdf.code(
    "storePassword=<your store password>\n"
    "keyPassword=<your key password>\n"
    "keyAlias=upload\n"
    "storeFile=<absolute path to upload-keystore.jks>"
)
pdf.body("Update android/app/build.gradle.kts - add at the top, then update signingConfigs and buildTypes:")
pdf.code(
    "import java.util.Properties\n"
    "import java.io.FileInputStream\n"
    "\n"
    "val keyProperties = Properties()\n"
    "val keyPropertiesFile = rootProject.file(\"key.properties\")\n"
    "if (keyPropertiesFile.exists()) keyProperties.load(FileInputStream(keyPropertiesFile))\n"
    "\n"
    "// Inside android { ... }\n"
    "signingConfigs {\n"
    "    create(\"release\") {\n"
    "        keyAlias      = keyProperties[\"keyAlias\"] as String\n"
    "        keyPassword   = keyProperties[\"keyPassword\"] as String\n"
    "        storeFile     = file(keyProperties[\"storeFile\"] as String)\n"
    "        storePassword = keyProperties[\"storePassword\"] as String\n"
    "    }\n"
    "}\n"
    "buildTypes {\n"
    "    release { signingConfig = signingConfigs.getByName(\"release\") }\n"
    "}"
)

pdf.sub_title("Step 4 - Replace App Icon")
pdf.body("Replace ic_launcher files in all mipmap folders under android/app/src/main/res/.")
pdf.bullet("Prepare a 1024x1024 PNG source icon")
pdf.bullet("Use appicon.co or Android Studio Asset Studio to generate all sizes")
pdf.bullet("Sizes needed: mdpi(48), hdpi(72), xhdpi(96), xxhdpi(144), xxxhdpi(192)")
pdf.ln(2)

pdf.sub_title("Step 5 - Build Android App Bundle")
pdf.body("Google Play requires .aab format (not .apk). Run:")
pdf.code("flutter build appbundle --release")
pdf.body("Output: build/app/outputs/bundle/release/app-release.aab")
pdf.body("For a standalone APK (testing / sideloading only):")
pdf.code("flutter build apk --release --split-per-abi")

pdf.sub_title("Step 6 - Upload to Google Play Console")
pdf.bullet("Go to play.google.com/console (one-time $25 registration fee)")
pdf.bullet("Create app -> fill store listing: title, description, screenshots, 512x512 icon")
pdf.bullet("Production -> Create new release -> Upload app-release.aab")
pdf.bullet("Complete content rating questionnaire (IARC)")
pdf.bullet("Set pricing & distribution (free or paid, countries)")
pdf.bullet("Submit for review - typically 1-3 days for new apps")

pdf.ln(4)

# --------------------------------------------------------------------------
# PART 2 - iOS APP STORE
# --------------------------------------------------------------------------
pdf.add_page()
pdf.section_title("PART 2 - iOS App Store Release", r=25, g=118, b=210)

pdf.warning("macOS + Xcode is mandatory. iOS builds CANNOT be done on Windows. "
            "Use a Mac or a CI service (Codemagic, Bitrise, GitHub Actions with macos runner).")

pdf.sub_title("Step 1 - Apple Developer Program")
pdf.body("Enroll at developer.apple.com/programs - $99/year.")
pdf.bullet("Individual account: your personal name appears on the App Store")
pdf.bullet("Organization account: company name appears - requires D-U-N-S number (free, ~5 business days)")
pdf.ln(2)

pdf.sub_title("Step 2 - Fix Bundle Identifier")
pdf.body("Open ios/Runner.xcworkspace in Xcode -> Runner target -> General tab:")
pdf.code("Bundle Identifier: com.yourcompany.dictceview")
pdf.body("This must match the App ID you create in the Apple Developer portal.")

pdf.sub_title("Step 3 - Configure Signing in Xcode")
pdf.bullet("Signing & Capabilities tab -> select your Team")
pdf.bullet('Enable "Automatically manage signing"')
pdf.bullet("Xcode will create provisioning profiles and certificates automatically")
pdf.ln(2)

pdf.sub_title("Step 4 - Replace App Icon")
pdf.bullet("Replace assets in ios/Runner/Assets.xcassets/AppIcon.appiconset/")
pdf.bullet("Use appicon.co to generate all required iOS sizes from a 1024x1024 PNG")
pdf.bullet("App Store requires 1024x1024 marketing icon (no alpha channel)")
pdf.ln(2)

pdf.sub_title("Step 5 - Verify iOS Plugin Compatibility")
pdf.body("Your app uses these plugins - all have iOS support, but verify with:")
pdf.code("flutter pub get\ncd ios && pod install")
pdf.bullet("flutter_tts - uses AVSpeechSynthesizer, no extra permissions needed")
pdf.bullet("google_mobile_ads - requires SKAdNetwork entries in Info.plist (Google provides them)")
pdf.bullet("in_app_purchase - works with StoreKit; configure products in App Store Connect")
pdf.bullet("sqlite3_flutter_libs - works on iOS")
pdf.bullet("flutter_dotenv - ensure .env is added to iOS bundle resources in Xcode")
pdf.ln(2)

pdf.sub_title("Step 6 - Add Required Info.plist Entries")
pdf.body("Edit ios/Runner/Info.plist - add usage descriptions for any sensitive APIs:")
pdf.code(
    "<key>NSUserTrackingUsageDescription</key>\n"
    "<string>This identifier will be used to deliver personalized ads.</string>"
)
pdf.body("Also add SKAdNetworkItems for AdMob (see Google AdMob iOS setup guide).")

pdf.sub_title("Step 7 - Build IPA")
pdf.code("flutter build ipa --release")
pdf.body("Or via Xcode: Product -> Archive -> Distribute App -> App Store Connect")

pdf.sub_title("Step 8 - Submit via App Store Connect")
pdf.bullet("Upload IPA with Xcode Organizer or Transporter app")
pdf.bullet("Go to appstoreconnect.apple.com -> create new app")
pdf.bullet("Fill metadata: name, subtitle, description, keywords, screenshots")
pdf.bullet('Screenshots required for: 6.9" iPhone, 6.5" iPhone, 12.9" iPad (minimum)')
pdf.bullet("Set age rating, pricing, and availability")
pdf.bullet("Submit for review - typically 1-3 days, up to 7 for new apps")

pdf.ln(4)

# --------------------------------------------------------------------------
# PART 3 - COMPARISON & BLOCKERS
# --------------------------------------------------------------------------
pdf.add_page()
pdf.section_title("PART 3 - Comparison & Current Blockers")

pdf.sub_title("Platform Comparison")
pdf.table(
    headers=["", "Google Play", "App Store"],
    rows=[
        ["Registration cost",  "$25 one-time",          "$99/year"],
        ["Build machine",      "Windows / Mac / Linux", "macOS only"],
        ["Release format",     ".aab (App Bundle)",     ".ipa archive"],
        ["Review time",        "1-3 days",              "1-7 days"],
        ["Signing",            "Self-managed keystore", "Xcode-managed certs"],
        ["In-app purchases",   "Google Play Billing",   "StoreKit / App Store Connect"],
        ["Biggest risk",       "Losing keystore file",  "macOS dependency"],
    ],
    col_widths=[52, 68, 68],
)

pdf.sub_title("Immediate Blockers in This Project")
pdf.warning(
    '1. applicationId = "com.example.dict_ce_view_demo"  -  Google Play REJECTS com.example.* packages. '
    "Must be changed before first upload and CANNOT be changed after first publish."
)
pdf.warning(
    "2. No release signing config  -  build.gradle.kts currently uses the debug key for release builds. "
    "Generates a valid AAB but signed with an untrusted key."
)
pdf.warning(
    '3. android:label = "dict_ce_view_demo"  -  This is the name users see on their device and Play Store. '
    "Set a proper display name before submission."
)

pdf.sub_title("Recommended Release Checklist")
items = [
    "Change applicationId to a unique reverse-domain identifier",
    "Update android:label to the real app display name",
    "Set version in pubspec.yaml (e.g. 1.0.0+1)",
    "Generate upload keystore and configure key.properties",
    "Update signingConfig in build.gradle.kts to use release key",
    "Replace default Flutter app icon in all mipmap folders",
    "Build .aab with: flutter build appbundle --release",
    "Create Google Play Console account ($25) and upload .aab",
    "[iOS] Enroll in Apple Developer Program ($99/year)",
    "[iOS] Fix bundle identifier in Xcode",
    "[iOS] Add Info.plist entries (tracking, AdMob SKAdNetwork)",
    "[iOS] Verify pod install succeeds on macOS",
    "[iOS] Build .ipa and upload via Xcode Organizer",
]
for item in items:
    pdf.checklist_item(item)

pdf.ln(4)
pdf.set_font("Helvetica", "I", 8)
pdf.set_text_color(120, 120, 120)
pdf.multi_cell(0, 5, "Generated by Claude Code  -  dict_ce_view_demo Flutter project  -  2026-03-16")

pdf.output("release plan.pdf")
print("Done: release plan.pdf")
