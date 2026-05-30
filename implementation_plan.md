# Clahan Academy V2 Implementation Plan

This document outlines the detailed system architecture, database schema, API contracts, microservices structure, Docker Compose configuration, and user flows for Clahan Academy V2.

## System Architecture

```mermaid
graph TD
    Client[React Frontend] -->|HTTP/WS| Gateway[API Gateway / Nginx]
    Gateway --> Auth[Auth Service]
    Gateway --> Admin[Admin Service]
    Gateway --> Student[Student Service]
    Gateway --> Exam[Exam Service]
    Gateway --> Proctor[Proctoring Service]
    Gateway --> Notify[Notification Service]
    Gateway --> AI[AI Service]

    Proctor -->|Realtime Alerts| WS[Socket.IO Server]
    WS --> Client

    AI --> Ollama[Ollama Service - Phi-3]
    AI --> YOLO[YOLOv8 Service]
    AI --> InsightFace[InsightFace Service]
    AI --> Tesseract[Tesseract OCR]
    AI --> Judge0[Judge0 Execution Engine]

    Auth & Admin & Student & Exam & Proctor --> DB[(PostgreSQL)]
    Auth & Proctor & Notify --> Cache[(Redis Cache / Queue)]
```

## Service Breakdown

| Service | Port | Description | Tech Stack |
| :--- | :--- | :--- | :--- |
| **frontend-service** | 5173 | UI for Admin and Students | React, Vite, TS, TailwindCSS, ShadCN UI |
| **auth-service** | 4001 | Auth, JWT, OTP, Refresh Tokens | Node.js, Express, TS, PostgreSQL, Redis |
| **admin-service** | 4002 | College, Dept, Student Import, Analytics | Node.js, Express, TS, PostgreSQL |
| **student-service** | 4003 | Profile management, Dashboard | Node.js, Express, TS, PostgreSQL |
| **exam-service** | 4004 | Exam lifecycle, MCQs, Coding, Test execution | Node.js, Express, TS, PostgreSQL, Redis |
| **proctoring-service**| 4005 | Live monitoring, Websockets, Fraud rules | Node.js, Express, TS, Socket.IO, Redis |
| **notification-service**|4006 | Email queue, SMTP worker, templates | Node.js, Express, TS, Redis, Nodemailer |
| **ai-service** | 8000 | Gateway for Ollama, YOLO, OCR, Face | Python, FastAPI, Requests |

---

## Database Schema

```mermaid
erDiagram
    COLLEGES ||--o{ DEPARTMENTS : contains
    COLLEGES ||--o{ USERS : has
    DEPARTMENTS ||--o{ USERS : has
    USERS ||--o{ EXAM_ATTEMPTS : attempts
    EXAMS ||--o{ EXAM_ATTEMPTS : has
    EXAMS ||--o{ MCQ_QUESTIONS : contains
    EXAMS ||--o{ CODING_QUESTIONS : contains
    EXAM_ATTEMPTS ||--o{ MCQ_RESPONSES : records
    EXAM_ATTEMPTS ||--o{ CODING_RESPONSES : records
    EXAM_ATTEMPTS ||--o{ PROCTORING_LOGS : generates

    COLLEGES {
        uuid id PK
        string name
        timestamp created_at
    }
    DEPARTMENTS {
        uuid id PK
        uuid college_id FK
        string name
        timestamp created_at
    }
    USERS {
        uuid id PK
        string email
        string password_hash
        string role "admin | student"
        string full_name
        string phone
        string roll_number
        uuid college_id FK
        uuid department_id FK
        string year "1st | 2nd | 3rd | 4th"
        string status "pending | active | suspended"
        string github_profile
        string linkedin_profile
        string profile_photo_url
        string otp_secret
        boolean email_verified
        timestamp created_at
    }
    EXAMS {
        uuid id PK
        string name
        string description
        string exam_type "mcq | coding | both"
        integer duration_minutes
        integer cutoff_percentage
        integer allowed_attempts
        timestamp schedule_date
        uuid college_id FK
        uuid department_id FK
        string year
        boolean is_published
        timestamp created_at
    }
```

---

## Verification & Validation Sequence (Pre-Exam)

```mermaid
sequenceDiagram
    participant Student as Student UI
    participant Server as Exam Service
    participant AI as AI Proctoring Service

    Student->>Server: Start Verification
    Server->>Student: Request Permissions (Camera/Microphone/Fullscreen)
    Student->>Student: Check Browser Compatibility
    Student->>Student: Validate Fullscreen State
    Student->>AI: Capture Webcam Frame for Face Verification
    AI-->>Student: Confirm Face Match (InsightFace)
    Student->>Server: Verification Handshake Approved
    Server->>Student: Launch Exam Environment
```

---

## Key Technical Decisions
1. **Monorepo Structure**: Keep all code organized in a single repository for easy local building and Docker Compose orchestration.
2. **Robust Email Queueing**: Using Redis as a message queue to prevent SMTP bottlenecks during bulk student imports or result notifications.
3. **Judge0 Integration**: Dockerized local instance of Judge0 for running C++, Java, JS, and Python test cases with CPU/memory constraints.
4. **FastAPI for AI Orchestration**: Acts as a lightweight proxy and preprocesses image files before sending them to specialized YOLOv8 or InsightFace containers.
