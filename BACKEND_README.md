# HealthDoc Backend - Node.js + MongoDB API

## Project Overview

HealthDoc is a **HIPAA-compliant** home health documentation platform that allows Physical Therapists (PTs) to record patient visits, transcribe audio, and automatically generate Google Doc forms using AI.

This is the **backend API** built with **Node.js** and **MongoDB** that serves the Flutter mobile app.

---

## What This Backend Does

### Current Scope (Milestone 1)
1. **User Authentication** - Login, signup, token management
2. **Audio File Upload** - Receive and store audio recordings from mobile app
3. **Session Management** - JWT-based authentication with 30-minute sessions
4. **Secure File Storage** - Store audio files securely (AWS S3 or local)

### Future Scope (Milestones 2-4)
- Audio transcription via AssemblyAI
- AI processing via Claude API
- Google Docs generation
- Web dashboard API
- Automated file cleanup (14-day retention)

---

## Technology Stack

- **Runtime:** Node.js (v18+ recommended)
- **Framework:** Express.js (or your preferred framework)
- **Database:** MongoDB
- **Authentication:** JWT (JSON Web Tokens)
- **File Storage:** AWS S3 (recommended) or local filesystem
- **Security:** bcrypt (password hashing), TLS 1.3

---

## Project Structure (Recommended)

```
backend/
├── src/
│   ├── config/
│   │   ├── database.js          # MongoDB connection
│   │   ├── jwt.js               # JWT configuration
│   │   └── aws.js                # AWS S3 configuration
│   ├── controllers/
│   │   ├── authController.js    # Authentication logic
│   │   └── recordingController.js # Recording upload logic
│   ├── models/
│   │   ├── User.js               # User model
│   │   └── Recording.js          # Recording model
│   ├── routes/
│   │   ├── authRoutes.js         # Auth endpoints
│   │   └── recordingRoutes.js   # Recording endpoints
│   ├── middleware/
│   │   ├── authMiddleware.js     # JWT validation
│   │   ├── errorHandler.js       # Error handling
│   │   └── uploadMiddleware.js  # File upload handling
│   ├── utils/
│   │   ├── logger.js             # Logging utility
│   │   └── validators.js         # Input validation
│   └── server.js                 # Express app setup
├── .env                          # Environment variables
├── .gitignore
├── package.json
└── README.md
```

---

## Required API Endpoints

### Base URL
All endpoints are prefixed with `/api`

Example: `POST /api/auth/login`

---

### 1. Authentication Endpoints

#### `POST /api/auth/login`
User login with email and password.

**Request:**
```json
{
  "email": "pt@example.com",
  "password": "password123"
}
```

**Success Response (200):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "507f1f77bcf86cd799439011",
    "email": "pt@example.com",
    "name": "John Doe",
    "role": "PT"
  }
}
```

**Error Response (401):**
```json
{
  "error": true,
  "message": "Invalid email or password"
}
```

---

#### `POST /api/auth/signup`
Register a new user.

**Request:**
```json
{
  "name": "John Doe",
  "email": "pt@example.com",
  "password": "password123"
}
```

**Success Response (201):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "507f1f77bcf86cd799439011",
    "email": "pt@example.com",
    "name": "John Doe",
    "role": "PT"
  }
}
```

**Error Response (400):**
```json
{
  "error": true,
  "message": "Email already exists"
}
```

---

#### `POST /api/auth/logout`
Logout user (invalidate token).

**Headers:** `Authorization: Bearer {token}`

**Success Response (200):**
```json
{
  "message": "Logged out successfully"
}
```

---

#### `GET /api/auth/me`
Get current authenticated user.

**Headers:** `Authorization: Bearer {token}`

**Success Response (200):**
```json
{
  "id": "507f1f77bcf86cd799439011",
  "email": "pt@example.com",
  "name": "John Doe",
  "role": "PT"
}
```

**Error Response (401):**
```json
{
  "error": true,
  "message": "Unauthorized"
}
```

---

#### `POST /api/auth/refresh`
Refresh access token using refresh token.

**Request:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Success Response (200):**
```json
{
  "token": "new_access_token_here"
}
```

---

### 2. Recording Upload Endpoint

#### `POST /api/recordings/:sessionId/upload`
Upload audio recording file.

**Headers:**
- `Authorization: Bearer {token}`
- `Content-Type: multipart/form-data`

**Form Data:**
- `audio`: File (audio file - .m4a, .aac, or .mp3)
- `patientIdentifier`: String (e.g., "Patient-123")
- `formTypes`: String (comma-separated, e.g., "PT Oasis,PT Evaluation")

**Success Response (200/201):**
```json
{
  "message": "Recording uploaded successfully",
  "sessionId": "1705312500000",
  "audioFileUrl": "https://s3.amazonaws.com/bucket/audio_1705312500000.m4a",
  "recording": {
    "id": "507f1f77bcf86cd799439012",
    "sessionId": "1705312500000",
    "userId": "507f1f77bcf86cd799439011",
    "patientIdentifier": "Patient-123",
    "formTypes": ["PT Oasis", "PT Evaluation"],
    "audioFileUrl": "https://s3.amazonaws.com/bucket/audio_1705312500000.m4a",
    "duration": 300,
    "status": "uploaded",
    "uploadedAt": "2024-01-15T10:30:00.000Z",
    "createdAt": "2024-01-15T10:25:00.000Z"
  }
}
```

**Error Responses:**
- `401` - Unauthorized (missing/invalid token)
- `400` - Missing required fields / Invalid file format
- `413` - File too large (max 100MB)
- `500` - Server error

---

## Database Schema

### Users Collection
```javascript
{
  _id: ObjectId("507f1f77bcf86cd799439011"),
  email: "pt@example.com",           // unique, indexed
  password: "$2b$10$hashed...",      // bcrypt hashed
  name: "John Doe",
  role: "PT",                         // enum: ["PT", "Admin"]
  createdAt: ISODate("2024-01-01T00:00:00.000Z"),
  updatedAt: ISODate("2024-01-01T00:00:00.000Z"),
  lastLoginAt: ISODate("2024-01-15T10:00:00.000Z")
}
```

**Indexes:**
- `email` (unique)

---

### Recordings Collection
```javascript
{
  _id: ObjectId("507f1f77bcf86cd799439012"),
  sessionId: "1705312500000",         // unique, indexed
  userId: ObjectId("507f1f77bcf86cd799439011"), // ref: User, indexed
  patientIdentifier: "Patient-123",
  formTypes: ["PT Oasis", "PT Evaluation"],
  audioFileUrl: "https://s3.amazonaws.com/bucket/audio_1705312500000.m4a",
  duration: 300,                      // seconds
  status: "uploaded",                 // enum: ["uploaded", "processing", "transcribed", "completed", "failed"]
  uploadedAt: ISODate("2024-01-15T10:30:00.000Z"),
  createdAt: ISODate("2024-01-15T10:25:00.000Z"),
  updatedAt: ISODate("2024-01-15T10:30:00.000Z")
}
```

**Indexes:**
- `sessionId` (unique)
- `userId`
- `createdAt` (for sorting)

---

## Authentication Implementation

### JWT Token Structure

**Access Token:**
- **Expiration:** 30 minutes
- **Payload:**
  ```json
  {
    "userId": "507f1f77bcf86cd799439011",
    "email": "pt@example.com",
    "role": "PT",
    "iat": 1705312500,
    "exp": 1705314300
  }
  ```
- **Algorithm:** HS256 (or RS256 for production)

**Refresh Token:**
- **Expiration:** 7 days
- **Payload:**
  ```json
  {
    "userId": "507f1f77bcf86cd799439011",
    "tokenId": "unique_token_id",
    "iat": 1705312500,
    "exp": 1705917300
  }
  ```
- **Storage:** Store in database for revocation capability

### Middleware
Create an authentication middleware that:
1. Extracts token from `Authorization: Bearer {token}` header
2. Validates token signature and expiration
3. Attaches user info to `req.user`
4. Returns `401 Unauthorized` if invalid

---

## Security Requirements

### Password Security
- Use **bcrypt** with 10-12 salt rounds
- Never return password in API responses
- Minimum 6 characters (enforced by client, but validate on backend too)

### File Upload Security
- **Validate file type:** Only accept `.m4a`, `.aac`, `.mp3`
- **Validate file size:** Max 100MB
- **Sanitize filename:** Remove special characters, use sessionId
- **Store securely:** Use S3 with encryption or local secure directory

### API Security
- **HTTPS only** (TLS 1.3)
- **Input validation** on all endpoints
- **Rate limiting:** 100 requests/minute per IP (recommended)
- **CORS:** Allow only Flutter app origin
- **JWT secret:** Use strong random string (32+ characters)

### HIPAA Compliance (Basic)
- **Encryption at rest:** MongoDB encryption or S3 server-side encryption
- **Encryption in transit:** TLS 1.3
- **Access logging:** Log all API requests with timestamp, user, endpoint
- **Audit trails:** Track user actions (login, upload, etc.)

---

## File Storage Options

### Option 1: AWS S3 (Recommended)
1. Create S3 bucket with encryption enabled
2. Configure IAM user with S3 upload permissions
3. Upload files to: `s3://bucket-name/recordings/{sessionId}.{ext}`
4. Return public URL or presigned URL
5. Set lifecycle policy for 14-day deletion (future)

**Example:**
```javascript
const s3 = new AWS.S3();
const uploadParams = {
  Bucket: 'healthdoc-audio-files',
  Key: `recordings/${sessionId}.m4a`,
  Body: fileBuffer,
  ContentType: 'audio/m4a',
  ServerSideEncryption: 'AES256'
};
const result = await s3.upload(uploadParams).promise();
// result.Location is the file URL
```

### Option 2: Local Storage (Development)
1. Store in `uploads/recordings/` directory
2. Generate URL: `https://api.domain.com/uploads/recordings/{filename}`
3. Serve files via Express static middleware
4. Implement cleanup job for old files

---

## Environment Variables

Create a `.env` file:

```env
# Server
PORT=3000
NODE_ENV=development

# Database
MONGODB_URI=mongodb://localhost:27017/healthdoc
MONGODB_DB_NAME=healthdoc

# JWT
JWT_SECRET=your-very-strong-secret-key-minimum-32-characters
JWT_EXPIRES_IN=30m
JWT_REFRESH_SECRET=your-refresh-secret-key-different-from-main
JWT_REFRESH_EXPIRES_IN=7d

# AWS S3 (if using S3)
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=us-east-1
AWS_S3_BUCKET_NAME=healthdoc-audio-files

# CORS
CORS_ORIGIN=http://localhost:3000

# File Upload
MAX_FILE_SIZE=104857600
ALLOWED_FILE_TYPES=m4a,aac,mp3
UPLOAD_DIR=./uploads/recordings
```

---

## Error Handling

### Standard Error Response Format
```json
{
  "error": true,
  "message": "Error message here",
  "code": "ERROR_CODE"
}
```

### HTTP Status Codes
- `200` - Success
- `201` - Created
- `400` - Bad Request (validation errors)
- `401` - Unauthorized (invalid/missing token)
- `403` - Forbidden (insufficient permissions)
- `404` - Not Found
- `413` - Payload Too Large
- `500` - Internal Server Error

---

## Testing Checklist

### Authentication Tests
- [ ] Login with valid credentials → Returns token and user
- [ ] Login with invalid email → Returns 401
- [ ] Login with invalid password → Returns 401
- [ ] Signup with new email → Creates user, returns token
- [ ] Signup with existing email → Returns 400
- [ ] Get current user with valid token → Returns user
- [ ] Get current user with invalid token → Returns 401
- [ ] Refresh token with valid refresh token → Returns new access token
- [ ] Logout → Invalidates token

### Upload Tests
- [ ] Upload with valid token → Returns recording data
- [ ] Upload without token → Returns 401
- [ ] Upload with invalid file type → Returns 400
- [ ] Upload with file too large → Returns 413
- [ ] Upload with missing patientIdentifier → Returns 400
- [ ] Upload with missing formTypes → Returns 400

---

## Flutter App Integration

The Flutter app expects:
- **Base URL:** `https://api.healthdoc.example.com/api` (update in Flutter app config)
- **Authentication:** Bearer token in `Authorization` header
- **File Upload:** Multipart form data

The Flutter app will:
1. Call `/api/auth/login` on login
2. Store token and include in all subsequent requests
3. Call `/api/recordings/:sessionId/upload` when uploading audio
4. Handle 401 errors by redirecting to login

---

## Priority Implementation Order

1. **Setup Project**
   - Initialize Node.js project
   - Install dependencies (Express, MongoDB driver, JWT, bcrypt, multer)
   - Setup folder structure

2. **Database Setup**
   - Connect to MongoDB
   - Create User and Recording models/schemas
   - Create indexes

3. **Authentication**
   - Implement login endpoint
   - Implement signup endpoint
   - Implement JWT token generation
   - Create auth middleware
   - Implement `/api/auth/me` and `/api/auth/refresh`

4. **File Upload**
   - Setup file upload middleware (multer)
   - Implement `/api/recordings/:sessionId/upload`
   - Integrate S3 or local storage
   - Save recording to database

5. **Security & Error Handling**
   - Add input validation
   - Add error handling middleware
   - Add rate limiting
   - Add CORS configuration
   - Add logging

6. **Testing**
   - Write unit tests
   - Write integration tests
   - Test all endpoints

---

## Dependencies (package.json example)

```json
{
  "dependencies": {
    "express": "^4.18.2",
    "mongoose": "^7.5.0",
    "jsonwebtoken": "^9.0.2",
    "bcryptjs": "^2.4.3",
    "multer": "^1.4.5-lts.1",
    "aws-sdk": "^2.1450.0",
    "dotenv": "^16.3.1",
    "cors": "^2.8.5",
    "express-rate-limit": "^6.10.0",
    "express-validator": "^7.0.1"
  },
  "devDependencies": {
    "nodemon": "^3.0.1",
    "jest": "^29.7.0",
    "supertest": "^6.3.3"
  }
}
```

---

## Next Steps After Milestone 1

- Transcription integration (AssemblyAI API)
- AI processing (Claude API)
- Google Docs generation
- Web dashboard endpoints
- Automated file cleanup (14-day retention)

---

## Questions?

If you need clarification on any requirement, refer to:
- `SRS.md` - Full Software Requirements Specification
- `BACKEND_REQUIREMENTS_MILESTONE1.md` - Detailed endpoint specifications
- Flutter app code - See how endpoints are called

---

**Status:** Ready for implementation. All requirements are clearly defined.
