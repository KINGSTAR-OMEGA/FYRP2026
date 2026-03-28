# EduAI — AI-Powered Adaptive Education Platform

> **Final Year Research Project (FYRP) 2026**
> A Flutter-based mobile application that leverages Artificial Intelligence to deliver personalised, adaptive learning experiences for students.

---

## Table of Contents

- [Overview](#overview)
- [Research Objectives](#research-objectives)
- [Key Features](#key-features)
- [System Architecture](#system-architecture)
- [User Roles](#user-roles)
- [Screen Flow](#screen-flow)
- [Data Models](#data-models)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [AI Integration Roadmap](#ai-integration-roadmap)
- [Future Work](#future-work)

---

## Overview

**EduAI** is a cross-platform mobile application built with Flutter that reimagines how students learn through video-based lessons enhanced by AI. The system provides two distinct portals:

| Portal | User | Purpose |
|--------|------|---------|
| Admin | Instructor / Educator | Upload lessons, structure course content, monitor student progress |
| Student | Learner | Watch lessons sequentially, interact with AI tutor, answer phase checkpoints |

The project investigates whether AI-driven, phase-based checkpoints embedded within video lessons can improve learning retention compared to traditional passive video consumption.

---

## Research Objectives

1. Design and implement a mobile learning platform that integrates AI-driven tutoring into video lessons.
2. Evaluate the effectiveness of phase-based question overlays in reinforcing learning during video playback.
3. Demonstrate a scalable architecture for AI service integration (API-ready stub pattern).
4. Analyse student engagement and progress data through an admin analytics dashboard.

---

## Key Features

### Student Side
- **Sequential lesson unlocking** — students progress lesson by lesson, enforcing structured learning paths.
- **Integrated AI Chat Panel** — persistent side panel during video playback for in-context Q&A with an AI tutor.
- **Phase-based Question Overlays** — timed popup questions mid-video that test comprehension at defined checkpoints.
- **Progress Tracking** — persistent local tracking of completed lessons and quiz scores.

### Admin Side
- **Course & Lesson Management** — create courses, upload local video files, and attach transcription text per lesson.
- **Phase Editor** — define timestamp-triggered question phases within each lesson with customisable MCQ questions.
- **Student Analytics Dashboard** — view per-student progress, scores, and lesson completion rates.

---

## System Architecture

```
┌─────────────────────────────────────────────────────┐
│                   Flutter App (UI Layer)              │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐ │
│  │   Screens   │  │   Widgets    │  │    Theme    │ │
│  └──────┬──────┘  └──────┬───────┘  └─────────────┘ │
│         │                │                           │
│  ┌──────▼────────────────▼──────────────────────┐   │
│  │            Provider (State Management)        │   │
│  │  AuthProvider │ CourseProvider │ ProgressProv │   │
│  └──────────────────────┬───────────────────────┘   │
│                         │                           │
│  ┌──────────────────────▼───────────────────────┐   │
│  │              Service Layer                    │   │
│  │  StorageService (SharedPrefs / JSON)          │   │
│  │  AIService (stub → future LLM API)            │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

- **State Management:** Provider pattern — clean separation between UI and business logic.
- **Local Persistence:** `SharedPreferences` storing serialised JSON for users, courses, lessons, progress.
- **AI Service:** Decoupled stub (`ai_service.dart`) designed for drop-in replacement with a real LLM API (e.g., Claude, Gemini, OpenAI).
- **Video Playback:** `video_player` + `chewie` for full-featured local video playback with controls.

---

## User Roles

### Admin
- Logs in via a fixed admin credential.
- Can create and manage multiple courses.
- Uploads local video files as lessons and adds transcription text.
- Configures phase checkpoints (timestamp + MCQ questions) per lesson.
- Views per-student analytics (scores, progress %).

### Student
- Registers and logs in with a student account (persisted locally).
- Browses enrolled courses and continues from last position.
- Watches lessons with an AI chat panel alongside the video.
- Encounters phase question overlays at defined lesson checkpoints.
- Cannot skip to the next lesson until the current one is completed.

---

## Screen Flow

```
SplashScreen
    └──> RoleSelectionScreen
              ├──> AdminLoginScreen
              │         └──> AdminShell
              │                   ├── Dashboard (stats, recent activity)
              │                   ├── Courses  (list → CreateCourse → LessonEditor → PhaseEditor)
              │                   └── Students (per-student analytics)
              │
              └──> StudentLoginScreen
                        └──> StudentShell
                                  ├── Home (dashboard, continue learning)
                                  └── Courses (list → CourseDetail → VideoLearningScreen)
                                                                              ├── Video Player (chewie)
                                                                              ├── AI Chat Panel
                                                                              └── Phase Question Overlay
```

---

## Data Models

| Model | Key Fields | Purpose |
|-------|-----------|---------|
| `UserModel` | id, name, email, role | Admin or Student identity |
| `CourseModel` | id, title, description, lessonIds | Top-level course container |
| `LessonModel` | id, title, videoPath, transcript, phases | Individual video lesson |
| `PhaseModel` | id, triggerTime, questions | Timed checkpoint within a lesson |
| `QuestionModel` | id, text, options, correctIndex | MCQ question for a phase |
| `ProgressModel` | studentId, courseId, completedLessons, scores | Student learning progress |
| `ChatMessageModel` | id, text, sender, timestamp | AI chat history per session |

---

## Tech Stack

| Category | Technology | Version |
|----------|-----------|---------|
| Framework | Flutter | SDK ^3.9.2 |
| Language | Dart | ^3.x |
| State Management | Provider | ^6.1.2 |
| Local Storage | SharedPreferences | ^2.2.3 |
| Video Playback | video_player + chewie | ^2.8.3 / ^1.7.5 |
| File Selection | file_picker | ^8.0.3 |
| Fonts | google_fonts (Outfit) | ^6.2.1 |
| Animations | flutter_animate | ^4.5.0 |
| Utilities | uuid, intl, path_provider | latest stable |

---

## Project Structure

```
edu_ai/
├── lib/
│   ├── main.dart                        # App entry point
│   ├── app.dart                         # MaterialApp + provider setup
│   ├── models/
│   │   ├── user_model.dart
│   │   ├── course_model.dart
│   │   ├── lesson_model.dart
│   │   ├── phase_model.dart
│   │   ├── question_model.dart
│   │   ├── progress_model.dart
│   │   └── chat_message_model.dart
│   ├── providers/
│   │   ├── auth_provider.dart           # Login, register, session
│   │   ├── course_provider.dart         # CRUD for courses & lessons
│   │   └── progress_provider.dart       # Student progress tracking
│   ├── services/
│   │   ├── storage_service.dart         # SharedPreferences JSON layer
│   │   └── ai_service.dart              # AI stub (ready for LLM API)
│   ├── screens/
│   │   ├── splash_screen.dart
│   │   ├── role_selection_screen.dart
│   │   ├── auth/
│   │   │   ├── admin_login_screen.dart
│   │   │   └── student_login_screen.dart
│   │   ├── admin/
│   │   │   ├── admin_shell.dart
│   │   │   ├── admin_dashboard_screen.dart
│   │   │   ├── admin_courses_screen.dart
│   │   │   ├── admin_create_course_screen.dart
│   │   │   ├── admin_lesson_editor_screen.dart
│   │   │   └── admin_student_analytics_screen.dart
│   │   └── student/
│   │       ├── student_shell.dart
│   │       ├── student_dashboard_screen.dart
│   │       ├── student_courses_screen.dart
│   │       ├── student_course_detail_screen.dart
│   │       └── video_learning_screen.dart
│   ├── widgets/
│   │   ├── common/
│   │   │   ├── app_button.dart
│   │   │   └── stat_card.dart
│   │   ├── admin/
│   │   │   └── phase_editor_widget.dart
│   │   └── student/
│   │       ├── ai_chat_panel.dart
│   │       └── phase_question_overlay.dart
│   └── utils/
│       └── theme.dart                   # App-wide colours, typography
├── android/
├── pubspec.yaml
└── README.md
```

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) — version 3.x or higher
- Android Studio / VS Code with Flutter & Dart extensions
- Android Emulator or physical device (Android 6.0+)

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/KINGSTAR-OMEGA/FYRP2026.git
cd FYRP2026/edu_ai

# 2. Install dependencies
flutter pub get

# 3. Run the app
flutter run
```

### Default Admin Login

```
Email:    admin@eduai.com
Password: admin123
```

> Student accounts are created via the registration screen on first launch.

---

## AI Integration Roadmap

The current AI service is a **decoupled stub** at `lib/services/ai_service.dart`. It is architected for a drop-in replacement with any LLM API.

| Phase | Status | Description |
|-------|--------|-------------|
| Stub / Mock responses | Done | Returns pre-set responses for any student query |
| Claude API integration | Planned | Plug in Anthropic Claude via REST API for tutoring |
| Context-aware chat | Planned | Pass lesson transcript + phase context to the LLM prompt |
| Automated question generation | Planned | Auto-generate phase MCQs from lesson transcript using LLM |
| Adaptive difficulty | Research | Adjust question difficulty based on student performance history |

---

## Future Work

- **Backend / Cloud Storage** — migrate from SharedPreferences to a cloud database (Firebase / Supabase) for multi-device support.
- **Real-time Analytics** — expand the admin dashboard with time-series graphs and cohort comparisons.
- **LLM-powered Question Generation** — use the lesson transcript to automatically generate phase questions via an AI model.
- **Gamification** — badges, streaks, and leaderboards to improve student motivation.
- **Web & iOS support** — extend beyond Android to the full Flutter multi-platform target set.

---

## Author

**KINGSTAR-OMEGA**
Final Year Research Project — 2026
