# Software Requirements Specification (SRS)
## HealthDoc - Home Health Documentation Platform

**Version:** 1.0  
**Date:** 2024  
**Project:** Mobile App (iOS) + Web Dashboard  
**Technology Stack:** Flutter (iOS first), Node.js + MongoDB Backend

---

## 1. Executive Summary

HealthDoc is a HIPAA-compliant mobile and web platform designed for Physical Therapists (PTs) to document home health visits. The system records audio during visits, transcribes the audio, and automatically generates structured Google Doc forms using AI processing.

### 1.1 Project Scope
- **Mobile App:** Flutter-based iOS application (Android-ready architecture)
- **Web Dashboard:** Simple patient list and document management interface
- **Backend:** Custom Node.js API with MongoDB database
- **Key Features:** Offline-first audio recording, AI transcription, automated form generation

### 1.2 Compliance Requirements
- HIPAA compliant with end-to-end encryption
- BAAs required for: AssemblyAI, Anthropic, AWS, Backend Provider
- Audit logging and access controls
- Data retention policies enforced

---

## 2. System Overview

### 2.1 User Roles
- **Physical Therapist (PT):** Primary mobile app user
- **Admin:** Web dashboard access for document management

### 2.2 Core Workflow
1. PT opens mobile app and authenticates
2. PT starts a new visit session
3. PT selects form type(s) (1-4 forms)
4. PT enters patient identifier
5. PT records visit audio (works offline)
6. Audio saves locally, auto-uploads when online
7. System transcribes audio via AssemblyAI
8. AI processes transcript and extracts structured data
9. Google Docs generated from templates
10. Documents accessible via web dashboard

---

## 3. Functional Requirements

### 3.1 Authentication (Milestone 1)
**FR-001:** User Authentication
- **Description:** Users must authenticate before accessing the app
- **Priority:** High
- **Acceptance Criteria:**
  - Login screen with email and password fields
  - Secure authentication via backend API
  - Session management with 30-minute timeout
  - Token-based authentication
  - Secure token storage on device

**FR-002:** Session Management
- **Description:** App must handle session expiration and renewal
- **Priority:** High
- **Acceptance Criteria:**
  - Auto-logout after 30 minutes of inactivity
  - Token refresh mechanism
  - Secure session storage

### 3.2 Audio Recording (Milestone 1)
**FR-003:** Offline Audio Recording
- **Description:** App must record audio even when offline
- **Priority:** High
- **Acceptance Criteria:**
  - Record audio in high quality (minimum 16kHz, mono)
  - Record duration tracking
  - Pause/resume capability
  - Stop recording functionality
  - Visual feedback during recording

**FR-004:** Encrypted Local Storage
- **Description:** Audio files must be encrypted before local storage
- **Priority:** High
- **Acceptance Criteria:**
  - AES-256 encryption for audio files
  - Secure key management
  - Encrypted metadata storage
  - Files stored in app's secure directory

**FR-005:** Background Upload with Retry
- **Description:** Audio files must upload automatically when online
- **Priority:** High
- **Acceptance Criteria:**
  - Background upload service
  - Automatic retry on failure (exponential backoff)
  - Upload progress tracking
  - Network state monitoring
  - Queue management for multiple files

**FR-006:** Local File Retention
- **Description:** Local audio files auto-delete after 30 days
- **Priority:** Medium
- **Acceptance Criteria:**
  - 30-day retention policy
  - Files only deleted after successful upload
  - Background cleanup job

### 3.3 Form Selection (Milestone 2)
**FR-007:** Multi-Select Form Types
- **Description:** User can select 1-4 form types per visit
- **Priority:** High
- **Acceptance Criteria:**
  - Form type selection screen
  - Support for: PT Oasis, PT Discharge, PT Evaluation, PT Oasis Discharge
  - Multi-select interface
  - Minimum 1 form required
  - Maximum 4 forms allowed

**FR-008:** Patient Identifier Input
- **Description:** User must enter patient identifier for each visit
- **Priority:** High
- **Acceptance Criteria:**
  - Free text input field
  - Validation (non-empty)
  - Patient identifier stored with recording

### 3.4 Audio Processing (Milestone 2)
**FR-009:** S3 Audio Upload
- **Description:** Audio files must upload to AWS S3 securely
- **Priority:** High
- **Acceptance Criteria:**
  - Secure S3 upload via presigned URLs
  - TLS 1.3 encryption in transit
  - Upload progress tracking
  - Error handling and retry logic

**FR-010:** Transcription Integration
- **Description:** Audio files must be transcribed via AssemblyAI
- **Priority:** High
- **Acceptance Criteria:**
  - Automatic transcription trigger after upload
  - HIPAA-compliant transcription service
  - Transcript storage in database
  - Error handling for transcription failures

### 3.5 AI Processing (Milestone 3)
**FR-011:** Claude AI Integration
- **Description:** Transcripts processed via Claude Sonnet for field extraction
- **Priority:** High
- **Acceptance Criteria:**
  - Structured JSON output per form type
  - Field mapping based on form configuration
  - Error handling for AI processing failures
  - HIPAA-compliant API usage

**FR-012:** Google Docs Generation
- **Description:** Google Docs created from templates with extracted data
- **Priority:** High
- **Acceptance Criteria:**
  - Template-based document creation
  - Placeholder replacement with JSON data
  - Documents saved to specified Drive folder
  - Folder structure: /PT Name/Date/FormType.gdoc
  - Document links stored in database

### 3.6 Web Dashboard (Milestone 4)
**FR-013:** Patient List View
- **Description:** Dashboard displays list of all patients and visits
- **Priority:** High
- **Acceptance Criteria:**
  - Patient identifier displayed
  - Visit date (ordered descending)
  - Form types generated
  - Links to Google Docs (one per form type)
  - Responsive design

**FR-014:** Dashboard Authentication
- **Description:** Web dashboard requires authentication
- **Priority:** High
- **Acceptance Criteria:**
  - Login screen
  - Session management
  - Role-based access (Admin)

### 3.7 Data Retention (Milestone 4)
**FR-015:** Server-Side Audio Retention
- **Description:** Audio files deleted after 14 days on server
- **Priority:** Medium
- **Acceptance Criteria:**
  - Automated cleanup job
  - 14-day retention policy
  - Deletion only after document generation
  - Audit log entry for deletions

**FR-016:** Transcript Retention
- **Description:** Transcripts retained per policy
- **Priority:** Medium
- **Acceptance Criteria:**
  - Configurable retention policy
  - Audit logging

### 3.8 Audit Logging (Milestone 4)
**FR-017:** HIPAA Audit Trails
- **Description:** All access and actions must be logged
- **Priority:** High
- **Acceptance Criteria:**
  - User login/logout events
  - Audio recording events
  - Document access events
  - Data deletion events
  - Timestamp and user identification
  - Immutable log storage

---

## 4. Non-Functional Requirements

### 4.1 Performance
**NFR-001:** Audio Recording Performance
- Record audio with minimal latency
- Support recordings up to 2 hours
- Efficient battery usage during recording

**NFR-002:** Upload Performance
- Background uploads should not impact app performance
- Efficient queue management for multiple files
- Resume capability for interrupted uploads

### 4.2 Security
**NFR-003:** Encryption
- End-to-end encryption (TLS 1.3) for all network communication
- Encryption at rest (AES-256) for local storage
- Secure key management

**NFR-004:** Authentication Security
- Secure token storage
- Token expiration and refresh
- Session timeout enforcement

**NFR-005:** Data Protection
- No sensitive data in logs
- Secure deletion of local files
- HIPAA-compliant data handling

### 4.3 Reliability
**NFR-006:** Offline Functionality
- App must function fully offline for recording
- Graceful degradation when offline
- Automatic sync when online

**NFR-007:** Error Handling
- Comprehensive error handling
- User-friendly error messages
- Automatic retry for transient failures

### 4.4 Usability
**NFR-008:** User Interface
- Intuitive and clean design
- Follow HealthDoc design guidelines
- Accessible UI components
- Clear visual feedback

**NFR-009:** Mobile Experience
- iOS-first design
- Responsive layouts
- Touch-friendly controls
- Clear recording indicators

---

## 5. Technical Architecture

### 5.1 Mobile App Architecture
**Pattern:** Clean Architecture with Offline-First Design

**Layers:**
- **Presentation Layer:** UI components, screens, state management
- **Domain Layer:** Business logic, use cases, entities
- **Data Layer:** Repositories, data sources (local + remote), models

**Key Components:**
- Authentication Service
- Audio Recording Service
- Local Storage Service (encrypted)
- Upload Service (background)
- Network Service
- Configuration Service

### 5.2 State Management
- **Approach:** Provider or Riverpod (TBD)
- **Offline State:** Local database (SQLite/Hive)
- **Sync State:** Queue-based upload system

### 5.3 Local Storage
- **Database:** SQLite (via Drift) or Hive
- **File Storage:** Encrypted audio files in app directory
- **Key Storage:** Secure storage for encryption keys

### 5.4 Network Layer
- **API Client:** Dio or HTTP package
- **Authentication:** JWT tokens
- **Error Handling:** Centralized error handling
- **Retry Logic:** Exponential backoff

### 5.5 Background Processing
- **Package:** Workmanager or similar
- **Upload Queue:** Persistent queue in local database
- **Network Monitoring:** Connectivity monitoring

---

## 6. Data Models

### 6.1 User
```json
{
  "id": "string",
  "email": "string",
  "name": "string",
  "role": "PT" | "Admin",
  "createdAt": "datetime",
  "updatedAt": "datetime"
}
```

### 6.2 Recording Session
```json
{
  "id": "string",
  "userId": "string",
  "patientIdentifier": "string",
  "formTypes": ["PT Oasis", "PT Discharge", ...],
  "audioFilePath": "string",
  "audioFileUrl": "string",
  "duration": "number",
  "status": "recording" | "uploading" | "processing" | "completed" | "failed",
  "uploadedAt": "datetime",
  "createdAt": "datetime",
  "localRetentionUntil": "datetime"
}
```

### 6.3 Transcription
```json
{
  "id": "string",
  "recordingId": "string",
  "transcript": "string",
  "status": "pending" | "processing" | "completed" | "failed",
  "assemblyAiJobId": "string",
  "createdAt": "datetime",
  "completedAt": "datetime"
}
```

### 6.4 Generated Document
```json
{
  "id": "string",
  "recordingId": "string",
  "formType": "string",
  "googleDocId": "string",
  "googleDocUrl": "string",
  "extractedData": "object",
  "status": "pending" | "processing" | "completed" | "failed",
  "createdAt": "datetime"
}
```

---

## 7. API Specifications

### 7.1 Authentication Endpoints
- `POST /api/auth/login` - User login
- `POST /api/auth/logout` - User logout
- `POST /api/auth/refresh` - Refresh token
- `GET /api/auth/me` - Get current user

### 7.2 Recording Endpoints
- `POST /api/recordings` - Create recording session
- `POST /api/recordings/:id/upload` - Upload audio file
- `GET /api/recordings` - List recordings
- `GET /api/recordings/:id` - Get recording details

### 7.3 Document Endpoints
- `GET /api/documents` - List generated documents
- `GET /api/documents/:id` - Get document details

---

## 8. Milestone Breakdown

### Milestone 1: Core Foundation & Audio Pipeline (Week 1)
**Deliverables:**
- Backend setup (Node.js + MongoDB)
- Authentication system
- Database schema
- Flutter app foundation
- Audio recording functionality
- Encrypted local storage
- Background upload with retry

**Acceptance Criteria:**
- ✅ App can record audio offline
- ✅ Audio securely stored locally and uploaded when online
- ✅ User authentication working end-to-end

### Milestone 2: Forms, Uploads & Transcription (Week 2)
**Deliverables:**
- Multi-select form type support
- Patient identifier workflow
- Secure S3 upload pipeline
- AssemblyAI transcription integration

**Acceptance Criteria:**
- ✅ User can select form type(s)
- ✅ Audio uploads to S3 successfully
- ✅ Transcriptions generated automatically

### Milestone 3: AI Processing & Document Generation (Week 3)
**Deliverables:**
- Claude Sonnet integration
- JSON-based field extraction
- Google Docs templates
- Google Drive API integration

**Acceptance Criteria:**
- ✅ Transcripts processed via AI
- ✅ Structured JSON output generated
- ✅ Google Docs created automatically

### Milestone 4: Dashboard, Security & Final Delivery (Week 4)
**Deliverables:**
- Web dashboard
- Patient list view
- Document links
- Retention rules & auto-deletion
- HIPAA audit logging
- Security hardening
- TestFlight build
- Documentation

**Acceptance Criteria:**
- ✅ Dashboard fully functional
- ✅ Data retention policies enforced
- ✅ Audit logs accessible
- ✅ App ready for TestFlight

---

## 9. Design Guidelines

### 9.1 Brand Identity
- **App Name:** HealthDoc
- **Tagline:** Home Health Documentation Platform
- **Logo:** Document icon with three horizontal lines + "HealthDoc" text

### 9.2 Color Palette
- **Primary:** Dark Blue/Charcoal (#1E3A5F or similar)
- **Secondary:** Light Gray (#F5F5F5)
- **Accent:** Blue (#007AFF or similar)
- **Text Primary:** Dark Gray (#333333)
- **Text Secondary:** Light Gray (#999999)
- **Background:** Light Gray (#F5F5F5)
- **Card Background:** White (#FFFFFF)

### 9.3 Typography
- **Primary Font:** Sans-serif, bold for headings
- **Body Font:** Sans-serif, regular weight
- **Font Sizes:** Responsive sizing

### 9.4 UI Components
- Rounded corners on cards and buttons
- Icons for input fields (mail, padlock)
- Clean, modern design
- Clear visual hierarchy
- Touch-friendly button sizes

---

## 10. Testing Requirements

### 10.1 Unit Testing
- Business logic tests
- Service layer tests
- Utility function tests

### 10.2 Integration Testing
- API integration tests
- Database operations tests
- Audio recording tests

### 10.3 E2E Testing
- Complete user flows
- Offline/online scenarios
- Error handling scenarios

---

## 11. Deployment

### 11.1 Mobile App
- **Platform:** iOS (TestFlight)
- **Minimum iOS Version:** iOS 13.0+
- **Build Configuration:** Release builds with proper signing

### 11.2 Backend
- **Environment:** Production server
- **Database:** MongoDB (production instance)
- **Storage:** AWS S3 bucket
- **Monitoring:** Error tracking and logging

---

## 12. Documentation Deliverables

- API documentation
- Setup and installation guide
- User manual
- Developer documentation
- Deployment guide
- Security documentation

---

## 13. Assumptions and Constraints

### 13.1 Assumptions
- Users have stable internet connection for initial setup
- Users have sufficient device storage for local recordings
- Backend API will be provided by client
- Form templates will be provided by client

### 13.2 Constraints
- iOS-first development (Android-ready architecture)
- HIPAA compliance requirements
- 30-day local retention policy
- 14-day server audio retention
- Offline-first requirement

---

## 14. Risk Management

### 14.1 Technical Risks
- Audio recording quality issues
- Background upload reliability
- Large file handling
- Battery consumption

### 14.2 Compliance Risks
- HIPAA compliance gaps
- Data breach vulnerabilities
- Audit logging completeness

### 14.3 Mitigation Strategies
- Comprehensive testing
- Security audits
- Regular compliance reviews
- Error monitoring and alerting

---

**Document Status:** Draft  
**Next Review:** After Milestone 1 completion
