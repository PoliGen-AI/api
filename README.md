REST API in Dart (Shelf) with authentication, AI-powered image generation, and history.

## Quick Start with Docker 🐳

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

### Setup and Run

1. **Clone the repository and navigate to the project directory**

2. **Set up environment variables:**
   ```bash
   cp env.example .env
   # Edit .env and add your GEMINI_API_KEY
   ```

3. **Get your Gemini API key:**
   - Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
   - Create an API key
   - Add it to your `.env` file: `GEMINI_API_KEY=your_key_here`

4. **Start the application:**
   ```bash
   docker-compose up --build
   ```

5. **Access the API:**
   - API will be available at: `http://localhost:8080`
   - MongoDB will be available at: `localhost:27017`

### Docker Commands

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f app

# Rebuild after code changes
docker-compose up --build

# Debug authentication issues
./debug_auth.sh
```

## Traditional Run (without Docker)

### Run

```bash
dart run
```

Environment variables:

- `MONGO_URL` (default mongodb://localhost:27017/api_dart_db)
- `JWT_SECRET` (default dev-secret-change-me)
- `GEMINI_API_KEY` (required for AI image generation)

### Routes

- POST `/auth/register` { email, password, name }
- POST `/auth/login` { email, password } -> sets auth_token cookie
- POST `/auth/logout` -> clears auth_token cookie
- GET `/auth/me` -> returns current user info (Bearer token or auth_token cookie)
- POST `/image/generate` { prompt, width?, height? } (Bearer token or auth_token cookie)
- GET `/image/file/{id}` (Bearer token or auth_token cookie)
- GET `/history/me` (Bearer token or auth_token cookie)

### Quick test with Docker

```bash
# Make sure Docker containers are running
docker-compose ps

# Register a new user
curl -s -X POST http://localhost:8080/auth/register \
  -H 'content-type: application/json' \
  -d '{"name":"Test User","email":"test@example.com","password":"password123"}'

# Login (this sets the auth_token cookie)
curl -s -X POST http://localhost:8080/auth/login \
  -H 'content-type: application/json' \
  -c cookies.txt \
  -d '{"email":"test@example.com","password":"password123"}'

# Generate an AI-powered image (uses cookie for authentication)
curl -s -X POST http://localhost:8080/image/generate \
  -b cookies.txt -H 'content-type: application/json' \
  -d '{"prompt":"A beautiful sunset over mountains"}'

# Or use Bearer token method:
TOKEN=$(curl -s -X POST http://localhost:8080/auth/login \
  -H 'content-type: application/json' \
  -d '{"email":"test@example.com","password":"password123"}' | jq -r .token)

curl -s -X POST http://localhost:8080/image/generate \
  -H "authorization: Bearer $TOKEN" -H 'content-type: application/json' \
  -d '{"prompt":"A serene lake at dawn"}'

# Get current user info
curl -s -H "authorization: Bearer $TOKEN" http://localhost:8080/auth/me | jq

# View your image history
curl -s -H "authorization: Bearer $TOKEN" http://localhost:8080/history/me | jq

# Logout
curl -s -X POST http://localhost:8080/auth/logout \
  -b cookies.txt
```

### Docker Data Persistence

- MongoDB data is persisted in Docker volumes
- Images are stored in MongoDB GridFS within the containers
- To reset data: `docker-compose down -v`
