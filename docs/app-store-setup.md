# App Store one-time setup

These steps prepare fastlane to build, sign and upload the iPhone/iPad and Mac
apps to TestFlight and the App Store, from a Mac or from GitHub Actions. You only
do them once. Steps 1 and 2 happen in Apple's web pages; the rest is terminal work.

For the day-to-day releases, see the [release process](release-process.md).

## Before you start

- A paid Apple Developer Program membership.
- Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
- Ruby 3.2 or later (`.ruby-version` asks for 3.2.0), then `bundle install`.
- `Support/iOS/Local.xcconfig` with your team (see "Build and run on iPhone and iPad"
  in the README):

  ```
  DEVELOPMENT_TEAM = ABCDE12345
  ```

## Step 1: Register the bundle ID and create the app record

Register the App ID first. match can't create it, and App Store Connect only
offers bundle IDs that already exist.

**1a. Register the App ID**

1. Go to developer.apple.com → Account → **Certificates, Identifiers & Profiles**
   → **Identifiers** → **+**.
2. Choose **App IDs** → **App** → Continue.
3. Description: `Middle C`. Bundle ID: **Explicit**, `com.liskovlabs.middlec`.
4. Leave the capabilities unticked, then Continue → Register.

The bundle ID is permanent once an app uses it. To use a different one, set
`APP_BUNDLE_ID` in `Support/iOS/Local.xcconfig` before you start; both the Xcode
project and the Fastfile read it from there.

**1b. Create the app**

1. Go to appstoreconnect.apple.com → **Apps** → **+** → **New App**.
2. Platforms: tick **both iOS and macOS**. This makes one record with universal
   purchase.
3. Name: `Middle C`. Store names are unique worldwide; if it's taken, use something
   like `Middle C – Piano Lessons`. The name under the icon on the device doesn't
   change.
4. Primary language: your choice. Bundle ID: pick `com.liskovlabs.middlec` from the list.
5. SKU: any internal string, e.g. `middlec`. User access: Full Access.

If the app already exists with only iOS, open it and use **Add macOS App** (the
platform **+** in the left sidebar).

## Step 2: Create the App Store Connect API key

1. Go to App Store Connect → **Users and Access** → **Integrations** →
   **App Store Connect API** → **Team Keys**.
   If this is the team's first key, the Account Holder has to click
   **Request Access** once.
2. Click **+**. Name: `fastlane`. Access: **Admin** (match needs it to create
   certificates). Generate.
3. Note two values on that page:
   - **Issuer ID**: the UUID at the top of the page.
   - **Key ID**: about 10 characters, shown in the key's row.
4. Click **Download API Key**. Apple lets you download it **only once**.
5. Move it to where the Fastfile looks for it:

   ```bash
   mkdir -p ~/.appstoreconnect/private_keys
   mv ~/Downloads/AuthKey_XXXXXXXXXX.p8 ~/.appstoreconnect/private_keys/
   chmod 600 ~/.appstoreconnect/private_keys/AuthKey_*.p8
   ```

   To keep it somewhere else, set `ASC_KEY_PATH` in `fastlane/.env`.

Once the certificates exist (after step 4), you can create a second key with
**App Manager** access for everyday releases and CI, and revoke the Admin one.

## Step 3: Create the private signing repository

[match](https://docs.fastlane.tools/actions/match/) keeps the certificates and
profiles in a git repository, encrypted with a passphrase. Create a **private**
and **completely empty** repository (no README, no license):

```bash
gh repo create piano-tutor-certificates --private
```

Then choose the passphrase:

```bash
openssl rand -base64 24
```

Save it in a password manager. If it is lost, the certificates have to be revoked
(`bundle exec fastlane match nuke distribution`) and created again.

## Step 4: Local settings and certificates

```bash
cp fastlane/.env.example fastlane/.env
```

Fill in `fastlane/.env` (it is ignored by git):

```
ASC_KEY_ID=XXXXXXXXXX                                   # Key ID from step 2
ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx      # Issuer ID from step 2
MATCH_GIT_URL=git@github.com:<github-user>/piano-tutor-certificates.git
MATCH_PASSWORD=<passphrase from step 3>
```

On your Mac the SSH URL works with your usual GitHub SSH key. `TEAM_ID` can stay
unset; it is read from `Support/iOS/Local.xcconfig`.

Create the certificates and profiles:

```bash
bundle exec fastlane ios certificates
bundle exec fastlane mac certificates
```

- The iOS lane creates an **Apple Distribution** certificate and an App Store
  profile for iOS.
- The Mac lane creates a macOS App Store profile and a **Mac Installer
  Distribution** certificate.
- Both are encrypted and pushed to the signing repository, and installed in your
  login keychain. macOS may ask for your login password to allow this.
- "Maximum number of certificates" means the team has reached Apple's limit on
  distribution certificates. Revoke an unused one under Certificates, Identifiers
  & Profiles → Certificates and run the lane again.

**Check it worked:** `bundle exec fastlane ios build` should produce a signed
`.ipa` in `build/fastlane` without uploading anything (`mac build` does the same
with a `.pkg`). Then `bundle exec fastlane ios beta` sends a build to TestFlight.

## Step 5: GitHub Actions secrets (only for CI releases)

`.github/workflows/release.yml` needs read access to the signing repository.
Create a **fine-grained personal access token** (GitHub → Settings → Developer
settings → Personal access tokens):

- Repository access: only `piano-tutor-certificates`.
- Permissions: **Contents: Read-only**.

Then add the repository secrets:

```bash
gh secret set ASC_KEY_ID --body "XXXXXXXXXX"
gh secret set ASC_ISSUER_ID --body "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
gh secret set ASC_KEY_P8 < ~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8
gh secret set MATCH_GIT_URL --body "https://github.com/<github-user>/piano-tutor-certificates.git"
gh secret set MATCH_PASSWORD --body "<passphrase>"
gh secret set MATCH_GIT_BASIC_AUTHORIZATION --body "$(echo -n '<github-user>:<token>' | base64)"
gh secret set TEAM_ID --body "<DEVELOPMENT_TEAM from Local.xcconfig>"
```

On CI, `MATCH_GIT_URL` must be the **HTTPS** URL, not the SSH one from your `.env`.

Let Release Please open its release PR (Settings → Actions → General → **Allow
GitHub Actions to create and approve pull requests**), or from the terminal:

```bash
gh api -X PUT repos/<github-user>/piano-tutor/actions/permissions/workflow \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true
```

From then on, every push to `main` that changes the app sends both apps to
TestFlight, and merging the Release Please PR uploads the new version to the App
Store. See the [release process](release-process.md).
