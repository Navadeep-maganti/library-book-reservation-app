# Library Management System

A full-stack library management app built with a Flutter frontend and a Django REST backend. The project supports student and librarian flows for book discovery, circulation, reservations, fines, announcements, and notifications.

## Highlights

- Role-based authentication for `student` and `librarian` users
- Login with username or student ID
- Book catalog with search and availability checks
- Borrow, renew, and return workflows
- Reservation queue with pickup windows and queue management
- Fine tracking with demo UPI payment flow
- Announcements and in-app notifications
- Optional Firebase push notifications for Android and iOS

## Tech Stack

- Frontend: Flutter, Dart
- Backend: Django 5, Django REST Framework, token authentication
- Database: SQLite
- Notifications: Firebase Cloud Messaging, flutter_local_notifications, Workmanager

## Repository Structure

```text
.
|-- backend/
|   `-- server/         # Django project, API apps, SQLite database
|-- frontend/           # Flutter application
|-- run_dev.ps1         # Windows helper to run backend + frontend together
`-- README.md
```

## Core Features

### Student experience

- Browse books and check live availability
- View currently borrowed books and due dates
- Renew eligible books
- Join and manage reservation queues
- Review borrowing history
- Track fines and mark demo payments as paid
- Read announcements and notifications

### Librarian and system capabilities

- Role-aware routing in the Flutter app
- Book issue and return APIs
- Automatic overdue fine calculation
- Reservation promotion when copies become available
- Push device registration endpoints for mobile notifications

## Local Development

PowerShell examples below assume you are in the repository root.

### Prerequisites

- Python 3.10+
- Flutter SDK
- Android Studio / Android SDK if you want to run on Android
- Optional: Firebase project credentials for push notifications

### Backend setup

```powershell
cd .\backend\server
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python manage.py migrate
python manage.py seed_data
python manage.py runserver 0.0.0.0:8000
```

Notes:

- The backend exposes the API at `http://127.0.0.1:8000/api/`
- The repo currently includes `backend/server/db_role_based.sqlite3` for local demo use
- `python manage.py seed_data` creates sample books, students, fines, reservations, announcements, and notifications

### Frontend setup

```powershell
cd .\frontend
flutter pub get
flutter run
```

The app resolves the backend URL like this:

- Web and desktop: `http://127.0.0.1:8000`
- Android emulator: `http://10.0.2.2:8000`
- Real Android device: pass your computer's LAN IP with `--dart-define`

Example for a real device:

```powershell
cd .\frontend
flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000
```

### One-command Windows dev flow

If you are on Windows and want to launch both services together:

```powershell
.\run_dev.ps1
```

This script starts Django on `127.0.0.1:8000`, runs `flutter run`, and configures `adb reverse` when `adb` is available.

## Demo Accounts

After running `python manage.py seed_data`, the following student accounts are available:

- `student1` / `student1`
- `student2` / `student2`
- `student3` / `student3`
- `student4` / `student4`
- `student5` / `student5`

Students can also log in with their student IDs:

- `202400001`
- `202400002`
- `202400003`
- `202400004`
- `202400005`

If you need a librarian account, create one with Django and set the user's `role` to `librarian`.

## API Overview

Base URL: `http://127.0.0.1:8000/api/`

Auth:

- `POST /auth/login/`
- `POST /auth/logout/`

Books and circulation:

- `GET /books/`
- `GET /books/search/`
- `GET /books/{id}/availability/`
- `GET /borrowing/my_books/`
- `POST /borrowing/issue/`
- `POST /borrowing/{id}/renew/`
- `POST /borrowing/{id}/return_book/`

Student services:

- `GET /history/my_history/`
- `GET /reservations/`
- `POST /reservations/reserve/`
- `POST /reservations/{id}/cancel/`
- `GET /fines/`
- `GET /fines/summary/`
- `POST /fines/{id}/pay/`
- `GET /alerts/upcoming/`
- `GET /notifications/`
- `GET /notifications/unread_count/`
- `POST /notifications/mark_all_read/`
- `POST /notifications/{id}/mark_read/`
- `GET /dashboard/summary/`

Notifications:

- `POST /push-devices/`
- `POST /push-devices/unregister/`

All API routes except login require:

```http
Authorization: Token <your_token>
```

## Optional Firebase Push Notifications

The app already includes Firebase client setup files in the Flutter project. To enable backend-triggered push notifications locally, provide Firebase service account credentials before starting Django.

```powershell
$env:FIREBASE_SERVICE_ACCOUNT_PATH="C:\path\to\firebase-service-account.json"
python manage.py runserver 0.0.0.0:8000
```

You can also use:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\firebase-service-account.json"
```

If you need to regenerate Flutter Firebase config:

```powershell
cd .\frontend
flutterfire configure
```

## Notes

- Fine amounts are handled in INR and demo UPI deep links are used in the Flutter app
- CORS is enabled for local development
- This repository is set up for local/demo use and is not production hardened

