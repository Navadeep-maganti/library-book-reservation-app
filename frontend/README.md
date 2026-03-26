# library_app

A new Flutter project.

cd c:\Users\uppug\library_app\frontend
flutter run --dart-define=API_BASE_URL=http://172.180.13.8:8000


cd C:\Users\uppug\library_app\backend\server
>> $env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\firebase-service-account.json"
>> python manage.py runserver 0.0.0.0:8000

## Push Notifications

For lock-screen and fully-closed-app notifications, configure Firebase Cloud Messaging.

Firebase project bootstrap:

```powershell
cd C:\Users\uppug\library_app\frontend
& "C:\Users\uppug\AppData\Local\Pub\Cache\bin\flutterfire.bat" configure --project=library-app-b5849
```

After `flutterfire configure`, the project uses `lib/firebase_options.dart`.

Flutter run example:

```powershell
flutter run `
  --dart-define=API_BASE_URL=http://192.168.1.100:8000
```

Backend environment:

```powershell
$env:FIREBASE_SERVICE_ACCOUNT_PATH="C:\path\to\firebase-service-account.json"
python manage.py runserver 0.0.0.0:8000
```

You can also use:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\firebase-service-account.json"
```

