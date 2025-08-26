REST API in Dart (Shelf) with authentication, image generation, and history.

### Run

```bash
dart run
```

Environment variables:

- `PORT` (default 8080)
- `JWT_SECRET` (default dev-secret-change-me)

### Routes

- POST `/auth/register` { email, password }
- POST `/auth/login` { email, password } -> { token }
- POST `/image/generate` { prompt, width?, height? } (Bearer token)
- GET `/image/file/{id}` (Bearer token)
- GET `/history/me` (Bearer token)

### Quick test

```bash
curl -s -X POST http://localhost:8080/auth/register \
  -H 'content-type: application/json' \
  -d '{"email":"a@b.com","password":"pass"}'

TOKEN=$(curl -s -X POST http://localhost:8080/auth/login \
  -H 'content-type: application/json' \
  -d '{"email":"a@b.com","password":"pass"}' | jq -r .token)

curl -s -X POST http://localhost:8080/image/generate \
  -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' \
  -d '{"prompt":"sunset"}'

curl -s -H "authorization: Bearer $TOKEN" http://localhost:8080/history/me | jq
```

Images and JSON storage are created under `data/`.
