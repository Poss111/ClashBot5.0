# Flutter environment defines

These values are provided via `--dart-define` (or env in the helper scripts) and consumed inside Flutter. Defaults shown are from code.

| Define | Default | Used in | Purpose |
| --- | --- | --- | --- |
| `APP_ENV` | `dev` | `lib/services/api_config.dart`, `lib/services/websocket_config.dart` | Chooses stage segment in URLs (`/dev` or `/prod`). |
| `CLOUDFRONT_ORIGIN` | `` | `lib/services/api_config.dart` | Optional HTTPS origin override (non-web builds) when not mocking. |
| `CLOUDFRONT_WS_ORIGIN` | `` | `lib/services/websocket_config.dart` | Optional WSS origin override (non-web builds) when not mocking. |
| `MOCK_API_ORIGIN` | `` | `lib/services/api_config.dart` | Forces REST base origin (e.g., `http://localhost:4000`) instead of deployed API. |
| `MOCK_WS_ORIGIN` | `` | `lib/services/websocket_config.dart` | Forces WS base origin (e.g., `ws://localhost:4001`) instead of deployed gateway. |
| `MOCK_AUTH` | `false` | `lib/services/auth_service.dart` | When true, skip Google sign-in and inject mock token/role. |
| `MOCK_TOKEN` | `mock-jwt-token` | `lib/services/auth_service.dart` | Backend token used when `MOCK_AUTH=true`. |
| `MOCK_ROLE` | `GENERAL_USER` | `lib/services/auth_service.dart` | Backend role used when `MOCK_AUTH=true`. |

Scripts that set these:
- `scripts/build_release.sh` / `scripts/build_all.sh`: set `APP_ENV` and optional `CLOUDFRONT_*`.
- `scripts/run_mock.sh`: enables all `MOCK_*` and points to local mock services.

