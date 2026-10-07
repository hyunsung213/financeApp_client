# finance_client

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Sign-in (Supabase Auth)

Real sign-in needs the Supabase project passed at build time; the backend then
identifies the user from the session's access token (sent as
`Authorization: Bearer`). Only the anon key is built into the app.

```sh
flutter run --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

Without these two values a debug build keeps the dev-only mock sign-in, which
only works against a local backend started with `DEV_AUTH_BYPASS=true`; a
release build refuses to sign in. `DEMO_MODE=true` never contacts a backend.
