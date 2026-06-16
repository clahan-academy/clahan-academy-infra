# Clahan Academy Online Exam Platform — Complete System Description

> [!NOTE]
> Clahan Academy V2 is an enterprise-grade, highly decoupled microservice-based online examination platform. It is engineered to support high throughput (10,000+ simultaneous students) and features real-time web/video proctoring, local AI-assisted evaluation, and isolated compiler sandboxing.

---

## 🗺️ 1. System Architecture & Components

The application is built using a highly decoupled microservices architecture. It separates the presentation layer (React Frontend SPA) from domain-specific APIs (backed by PostgreSQL and Redis) and specialized machine learning/compilation backend nodes (FastAPI, Ollama, YOLO, Judge0).

### High-Level Architecture Flow

1. **Frontend Client / SPA**: Renders the React interface on the student/administrator side. It communicates with backend services through direct API routing or proxies.
2. **API Router / Gateway Proxy**: The frontend service proxies API traffic under `/api/*` to the respective backend microservices:
   * `/api/auth` routes to **Auth Service** (Port 4001)
   * `/api/admin` routes to **Admin Service** (Port 4002)
   * `/api/student` routes to **Student Service** (Port 4003)
   * `/api/exams` routes to **Exam Service** (Port 4004)
   * `/api/proctor` and WebSockets route to **Proctoring Service** (Port 4005)
   * `/api/notifications` routes to **Notification Service** (Port 4006)
3. **Data Layer**:
   * **PostgreSQL Database**: Serves as the primary relational database. Auth, Admin, Student, Exam, and Proctoring services query PostgreSQL directly to read and write application states.
   * **Redis Cache & Queue**: Auth, Admin, and Proctoring services use Redis for caching and session state. The Notification Service uses Redis as a job queue (via BullMQ) to pull asynchronous email dispatch jobs.
4. **AI & Execution Subsystem**:
   * The **Exam Service** communicates with the **AI Service Hub** (Port 8000) for subjective answer grading and the **Judge0 API** (Port 2358) for sandboxed code compilation.
   * The **Proctoring Service** streams client webcam feeds to the **AI Service Hub** for real-time object detection and facial verification.
   * The **AI Service Hub** acts as an orchestration gateway routing requests to:
     * **Ollama Service** (Port 11434) to query local Large Language Models (e.g., Phi-3).
     * **YOLO v8 Service** to perform object detection (detecting cell phones, books, etc.).
     * **InsightFace Service** to run facial comparison and identity verification.
     * **Tesseract OCR Service** to convert hand-written or scanned answers into text.

---

## 📦 2. Microservices Breakdown & Tech Stack

The system consists of **8 custom services** alongside supporting machine learning engines and database components.

### Custom Microservices Directory

* **`frontend-service`** (React, Vite, TypeScript, TailwindCSS)
  * *Responsibilities*: Renders the dashboards for students, teachers, and admins; captures and letterboxes webcam streams; manages exam state, code editors, and MCQ interfaces.
  * *Exposed Port*: `5173`
* **`auth-service`** (Node.js, Express, TypeScript)
  * *Responsibilities*: Manages user registration, logins, profile updates, and JWT Access/Refresh tokens; seeds default credentials; generates OTP secrets.
  * *Exposed Port*: `4001`
  * *Dependencies*: PostgreSQL, Redis
* **`admin-service`** (Node.js, Express, TypeScript)
  * *Responsibilities*: Manages colleges and departments, imports candidate lists via CSV parser, aggregates metrics, resets passwords.
  * *Exposed Port*: `4002`
  * *Dependencies*: PostgreSQL, Redis
* **`student-service`** (Node.js, Express, TypeScript)
  * *Responsibilities*: Fetches active/upcoming exams, manages student profile edits, and loads study histories.
  * *Exposed Port*: `4003`
  * *Dependencies*: PostgreSQL
* **`exam-service`** (Node.js, Express, TypeScript)
  * *Responsibilities*: Handles exam creation and configuration, question banking (MCQ and coding questions), compile executions via Judge0, and grading runs.
  * *Exposed Port*: `4004`
  * *Dependencies*: PostgreSQL, Redis, `ai-service`, `judge0-api`
* **`proctoring-service`** (Node.js, Express, Socket.IO, TypeScript)
  * *Responsibilities*: Manages active Socket.IO connection rooms; receives and processes streamed webcam frames; processes proctoring violation rules; writes warning logs to PostgreSQL.
  * *Exposed Port*: `4005`
  * *Dependencies*: PostgreSQL, Redis, `ai-service`
* **`notification-service`** (Node.js, TypeScript, Worker process)
  * *Responsibilities*: Functions as an asynchronous job worker; processes email notification events (OTP, registrations, grades) out of a Redis BullMQ; delivers styled emails via SMTP.
  * *Exposed Port*: `4006`
  * *Dependencies*: Redis, SMTP Server (Gmail/SendGrid)
* **`ai-service`** (Python, FastAPI, Uvicorn)
  * *Responsibilities*: Exposes REST endpoints for model inference; pre-processes images (resizing/letterboxing); communicates with downstream YOLO, InsightFace, Tesseract, and Ollama containers.
  * *Exposed Port*: `8000`
  * *Dependencies*: `ollama-service`

### Supporting Infrastructure & ML Nodes

* **`ollama-service`**: Runs the local Ollama docker image (`ollama/ollama:latest`) on port `11434` to serve model weight files (e.g., Phi-3) for evaluation and prompt grading.
* **`judge0-db` & `judge0-redis`**: Isolated PostgreSQL and Redis cache instances dedicated entirely to the Judge0 compiler engine.
* **`judge0-api` & `judge0-worker`**: Execution API and sandbox workers running on port `2358` to securely compile and execute user code inside temporary, resource-constrained container environments.

---

## 🗄️ 3. Database Schema & Architecture

The database structures are designed to link colleges, departments, users, exams, and candidate results securely. Below is a detailed listing of all tables, their attributes, types, and relations.

### Table: `colleges`
* **id** (UUID, Primary Key): Unique identifier for the college.
* **name** (String): Official name of the college.
* **created_at** (Timestamp): Date and time when the record was created.

### Table: `departments`
* **id** (UUID, Primary Key): Unique identifier for the department.
* **college_id** (UUID, Foreign Key referencing `colleges.id`): Links the department to a parent college.
* **name** (String): Name of the department (e.g., "Computer Science").
* **created_at** (Timestamp): Date and time when the record was created.

### Table: `users`
* **id** (UUID, Primary Key): Unique user identifier.
* **email** (String, Unique): E-mail address used for logins.
* **password_hash** (String): BCrypt password hash.
* **role** (String): Determines permissions (`admin` or `student`).
* **full_name** (String): User's legal name.
* **phone** (String): User's phone contact.
* **roll_number** (String): Candidate registration/roll number.
* **college_id** (UUID, Foreign Key referencing `colleges.id`): College affiliation.
* **department_id** (UUID, Foreign Key referencing `departments.id`): Department affiliation.
* **year** (String): Grade year (`1st Year`, `2nd Year`, `3rd Year`, `4th Year`).
* **status** (String): User status (`pending`, `active`, `suspended`).
* **github_profile** (String): Optional GitHub profile link.
* **linkedin_profile** (String): Optional LinkedIn profile link.
* **profile_photo_url** (String): Link to the candidate's base reference photo (used for face verification).
* **otp_secret** (String): Secret key used for email OTP validation.
* **email_verified** (Boolean): Specifies if the email has been verified.
* **created_at** (Timestamp): Date and time of user registration.

### Table: `exams`
* **id** (UUID, Primary Key): Unique exam identifier.
* **name** (String): Title of the examination.
* **description** (Text): Information about exam rules.
* **exam_type** (String): Exam format (`mcq`, `coding`, or `both`).
* **duration_minutes** (Integer): Allowed duration in minutes.
* **cutoff_percentage** (Integer): Minimum percentage required to pass.
* **allowed_attempts** (Integer): Maximum number of times a student can take this exam.
* **schedule_date** (Timestamp): Date/time when the exam window opens.
* **college_id** (UUID, Foreign Key referencing `colleges.id`): Target college constraint.
* **department_id** (UUID, Foreign Key referencing `departments.id`): Target department constraint.
* **year** (String): Targeted academic year.
* **is_published** (Boolean): Indicates whether the exam is visible to students.
* **created_at** (Timestamp): Creation timestamp.

### Table: `exam_attempts`
* **id** (UUID, Primary Key): Unique attempt identifier.
* **user_id** (UUID, Foreign Key referencing `users.id`): Identifies the student.
* **exam_id** (UUID, Foreign Key referencing `exams.id`): Identifies the exam taken.
* **status** (String): Progress state (`started`, `completed`, `terminated`).
* **score** (Integer): Calculated score upon completion.
* **started_at** (Timestamp): Exam start timestamp.
* **ended_at** (Timestamp): Exam submission or termination timestamp.

### Table: `mcq_questions`
* **id** (UUID, Primary Key): MCQ question identifier.
* **exam_id** (UUID, Foreign Key referencing `exams.id`): Parent exam.
* **question_text** (Text): Question description.
* **option_a** (String): Option A.
* **option_b** (String): Option B.
* **option_c** (String): Option C.
* **option_d** (String): Option D.
* **correct_option** (String): Correct answer key (`a`, `b`, `c`, or `d`).
* **marks** (Integer): Points assigned to this question.

### Table: `coding_questions`
* **id** (UUID, Primary Key): Coding question identifier.
* **exam_id** (UUID, Foreign Key referencing `exams.id`): Parent exam.
* **title** (String): Title of the coding problem.
* **description** (Text): Question prompt, input/output formats, and constraints.
* **template_code** (Text): Default starter code codeblock.
* **test_cases** (Text/JSON): Structured array of inputs and expected outputs for automatic test compilation.
* **marks** (Integer): Points assigned to this question.

### Table: `mcq_responses`
* **id** (UUID, Primary Key): Unique response identifier.
* **attempt_id** (UUID, Foreign Key referencing `exam_attempts.id`): Associated attempt.
* **question_id** (UUID, Foreign Key referencing `mcq_questions.id`): Question reference.
* **selected_option** (String): Student's selected option.
* **is_correct** (Boolean): Validation flag.
* **marks_obtained** (Integer): Marks awarded.

### Table: `coding_responses`
* **id** (UUID, Primary Key): Unique response identifier.
* **attempt_id** (UUID, Foreign Key referencing `exam_attempts.id`): Associated attempt.
* **question_id** (UUID, Foreign Key referencing `coding_questions.id`): Question reference.
* **submitted_code** (Text): Code typed by the student.
* **status** (String): Status code returned by Judge0 (e.g., "Accepted", "Wrong Answer").
* **compile_outputs** (Text): Runtime stdout/stderr capture.
* **marks_obtained** (Integer): Marks awarded based on passed test cases.

### Table: `proctoring_logs`
* **id** (UUID, Primary Key): Log identifier.
* **attempt_id** (UUID, Foreign Key referencing `exam_attempts.id`): Associated attempt.
* **violation_type** (String): Type of violation (`NO_FACE_DETECTED`, `MOBILE_PHONE_DETECTED`, etc.).
* **details** (Text): Context data (e.g., confidence percentages, duration, tab names).
* **timestamp** (Timestamp): Time the infraction occurred.

---

## 🔄 4. Core Application Workflows

### A. Pre-Exam Verification Handshake
To prevent proxy test-taking, candidates must verify their identity before starting an exam.

1. **Permission Request**: The client SPA requests browser access to the webcam and microphone, then triggers HTML5 Fullscreen mode.
2. **Identity Verification**: The frontend captures a frame from the webcam feed and sends it via POST to the `/api/proctor/verify-face` endpoint.
3. **Model Validation**: The `proctoring-service` forwards the frame to the `ai-service` endpoint. The service runs **InsightFace** to match the webcam frame against the base reference photo stored in `users.profile_photo_url`.
4. **Validation Check**: If exactly **one face** is detected and matches the user's profile photo (with no other objects present), the verification handshake is approved. The backend updates the session token and permits the client to unlock and display exam questions.
5. **Fallback Loop**: Detections are retried automatically every 2 seconds for up to 30 seconds. If a timeout occurs, a manual retry button is displayed.

---

### B. Real-Time Proctoring & Violation Rules Engine
During the exam, the system monitors candidate behavior using real-time inputs.

* **Letterboxing Preprocessing**: To prevent aspect ratio distortion (which degrades YOLOv8 confidence scores), frames captured by the client are resized to fit a square `640x640` canvas and padded with neutral grey borders before evaluation.
* **WebSocket Streaming**: Preprocessed webcam frames are sent over a Socket.IO connection to the `proctoring-service` every few seconds.
* **Violation Evaluation**: The `proctoring-service` forwards the frames to `ai-service` which runs YOLOv8. The service tracks infraction occurrences across consecutive frames using the following rules:

1. **`NO_FACE_DETECTED`**
   * *Mechanism*: Haar Cascade Classifiers and YOLO check for frontal and profile facial shapes.
   * *Escalation*:
     * **10 continuous seconds**: A warning overlay appears on the student's screen.
     * **20 continuous seconds**: An infraction log is saved to the database.
     * **30 continuous seconds**: The exam attempt is terminated.
2. **`MULTIPLE_FACES_DETECTED`**
   * *Mechanism*: Checks if the frame contains $\ge 2$ human faces.
   * *Escalation*:
     * **1st frame**: Emits a warning overlay and logs the infraction.
     * **5th consecutive frame**: Terminates the exam.
3. **`MOBILE_PHONE_DETECTED`**
   * *Mechanism*: YOLOv8 checks for class index `67` (cell phone).
   * *Escalation*:
     * **1 to 4 frames (with confidence $> 0.80$)**: Emits warnings and logs to the database.
     * **5th consecutive frame**: Terminates the exam.
4. **`BOOK_DETECTED`**
   * *Mechanism*: YOLOv8 checks for class index `73` (book).
   * *Escalation*:
     * **1 to 7 frames (with confidence $> 0.40$)**: Emits warnings.
     * **8th consecutive frame**: Terminates the exam.
5. **`TAB_SWITCH`**
   * *Mechanism*: Listens to browser `window.blur` and HTML5 Page Visibility API events.
   * *Escalation*:
     * **1st and 2nd occurrence**: Displays a warning overlay and locks the screen until dismissed.
     * **3rd cumulative occurrence**: Terminates the exam.
6. **`FULLSCREEN_EXIT`**
   * *Mechanism*: Listens to HTML5 Fullscreen API exit events.
   * *Escalation*:
     * **1st and 2nd occurrence**: Displays a warning overlay and locks the screen until dismissed.
     * **3rd cumulative occurrence**: Terminates the exam.

---

### C. AI-Assisted Subjective Grading
This workflow handles automatic evaluation of descriptive or subjective answers.

1. **Submission**: The student submits their responses.
2. **Grading Request**: The `exam-service` gathers the question text, the grading rubric, and the student's answer, then calls the `ai-service` endpoint.
3. **LLM Evaluation**: The `ai-service` formats this data into a prompt and calls the `ollama-service` API.
4. **Model Execution**: The local LLM (e.g., Phi-3) processes the prompt to generate a score and qualitative feedback.
5. **Response Storage**: The `ai-service` parses this output and returns the score and feedback text to `exam-service`, which saves them to PostgreSQL and updates the student's attempt record.

---

### D. Coding Question Sandbox Execution
When a student compiles or runs code inside the editor workspace:

1. **Submission Routing**: The client sends the source code and target language ID (e.g., Python, C++, Java) to the `exam-service`.
2. **Sandbox Execution**: The `exam-service` sends the execution job to the `judge0-api` container.
3. **Isolation and Testing**: The `judge0-worker` compiles the code and runs it against the question's test suites in an isolated sandbox. It enforces CPU/memory usage constraints via Linux cgroups.
4. **Feedback Output**: Judge0 returns execution metrics (stdout, runtime duration, memory consumption, compile logs, status codes) to `exam-service`, which forwards the result to the client's output console.

---

## 🛠️ 5. Deployment Configurations

### Local Concurrent Development Mode
To start all services locally for development:

1. **Install Dependencies**: Run the install command in each service directory:
   ```bash
   cd auth-service && npm install
   cd ../admin-service && npm install
   cd ../student-service && npm install
   cd ../exam-service && npm install
   cd ../proctoring-service && npm install
   cd ../notification-service && npm install
   cd ../frontend-service && npm install
   ```
2. **Dependencies**: Run PostgreSQL and Redis locally or inside basic Docker containers.
3. **Execution**: Start the microservices concurrently:
   ```bash
   npm run dev
   ```

### Production Container Stack (Docker Compose)
To deploy the application stack in a production environment:

1. Run the build command from the root workspace:
   ```bash
   docker-compose up --build -d
   ```
2. **Automatic Database Seeding**: When the database is initialized, the `auth-service` automatically seeds default administrator credentials:
   * **Admin Email**: `admin@clahan.com`
   * **Admin Password**: `Admin@123`
3. **SMTP Email Configurations**: Update the environment variables in `docker-compose.yml` with your SMTP configurations (e.g., Gmail App Passwords or SendGrid API Keys) to enable transaction emails and OTP deliveries.

---

## ⚙️ 6. Service Environment Configurations

Each microservice is configured using service-specific `.env` files. Below is a reference matrix of the environment variables used across the system:

| Service | Environment Variable | Example Default Value | Description |
| :--- | :--- | :--- | :--- |
| **`auth-service`** | `PORT` | `4001` | Server listener port |
| | `DATABASE_URL` | `postgresql://postgres:postgres@postgres:5432/clahan?sslmode=disable` | Database connection string |
| | `REDIS_URL` | `redis://redis:6379` | Redis connection URL |
| | `JWT_ACCESS_SECRET` | `super_secret_access_token_key` | Secret key used to sign access tokens |
| | `JWT_REFRESH_SECRET` | `super_secret_refresh_token_key` | Secret key used to sign refresh tokens |
| | `RATE_LIMIT_MAX` | `10000` | Rate limiter threshold |
| **`admin-service`** | `PORT` | `4002` | Server listener port |
| | `DATABASE_URL` | `postgresql://postgres:postgres@postgres:5432/clahan?sslmode=disable` | Database connection string |
| | `REDIS_URL` | `redis://redis:6379` | Redis connection URL |
| | `JWT_ACCESS_SECRET` | `super_secret_access_token_key` | Secret key used to validate access tokens |
| | `RATE_LIMIT_MAX` | `10000` | Rate limiter threshold |
| **`student-service`**| `PORT` | `4003` | Server listener port |
| | `DATABASE_URL` | `postgresql://postgres:postgres@postgres:5432/clahan?sslmode=disable` | Database connection string |
| | `JWT_ACCESS_SECRET` | `super_secret_access_token_key` | JWT access token secret |
| | `RATE_LIMIT_MAX` | `10000` | Rate limiter threshold |
| **`exam-service`** | `PORT` | `4004` | Server listener port |
| | `DATABASE_URL` | `postgresql://postgres:postgres@postgres:5432/clahan?sslmode=disable` | Database connection string |
| | `REDIS_URL` | `redis://redis:6379` | Redis connection URL |
| | `JWT_ACCESS_SECRET` | `super_secret_access_token_key` | JWT access token secret |
| | `AI_SERVICE_URL` | `http://ai-service:8000` | Python AI service endpoint |
| | `JUDGE0_URL` | `http://judge0-api:2358` | Judge0 compiler endpoint |
| | `RATE_LIMIT_MAX` | `10000` | Rate limiter threshold |
| **`proctoring-service`**| `PORT` | `4005` | Server listener port |
| | `DATABASE_URL` | `postgresql://postgres:postgres@postgres:5432/clahan?sslmode=disable` | Database connection string |
| | `REDIS_URL` | `redis://redis:6379` | Redis connection URL |
| | `JWT_ACCESS_SECRET` | `super_secret_access_token_key` | JWT access token secret |
| | `AI_SERVICE_URL` | `http://ai-service:8000` | Python AI service endpoint |
| | `TAB_SWITCH_LIMIT` | `3` | Maximum allowed tab switches |
| | `MOBILE_PHONE_LIMIT`| `5` | Consecutive frames allowed before phone violation |
| | `BOOK_LIMIT` | `8` | Consecutive frames allowed before book violation |
| | `MULTIPLE_FACES_LIMIT`| `5` | Consecutive frames allowed before multiple faces violation |
| | `NO_FACE_TIMEOUT_MS`| `10000` | Timeout threshold (ms) for face absence |
| | `FULLSCREEN_EXIT_LIMIT`| `3` | Maximum allowed fullscreen exits |
| **`notification-service`**| `PORT` | `4006` | Server listener port |
| | `REDIS_URL` | `redis://redis:6379` | Redis connection URL |
| | `SMTP_HOST` | `smtp.gmail.com` | SMTP outgoing host |
| | `SMTP_PORT` | `465` | SMTP port |
| | `SMTP_USER` | `aiexamplatform123@gmail.com` | SMTP authentication username |
| | `SMTP_PASS` | `zmso iaml jdkh wpxn` | SMTP App Password |
| | `SMTP_FROM` | `aiexamplatform123@gmail.com` | Default sender email |
| | `FRONTEND_URL` | `https://clahanacademy.com` | Front door URL for notifications |
| | `SENDGRID_API_KEY` | *(Optional)* | Twilio SendGrid API Key |
| | `SENDGRID_FROM` | *(Optional)* | SendGrid verified sender email |
| **`ai-service`** | `PORT` | `8000` | Python server listener port |
| | `OLLAMA_URL` | `http://ollama-service:11434` | Ollama service endpoint |
