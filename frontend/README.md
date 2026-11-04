# ColoHouse Flutter app

## Run on a physical Android phone over USB

The phone must have Developer options and USB debugging enabled. From the
repository root, open two PowerShell windows.

### 1. Start the Django API

```powershell
cd backend
python -m pip install -r requirements.txt
python manage.py migrate
python manage.py runserver 127.0.0.1:8000
```

The backend is configured for PostgreSQL, so PostgreSQL must be running with the
database and credentials in `backend/Colohouse/settings.py`.

### 2. Connect and run Flutter

In the second window:

```powershell
cd frontend
flutter pub get
adb devices
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Accept the USB debugging prompt on the phone if it appears. `adb reverse`
forwards the phone's `127.0.0.1:8000` to the computer's port 8000, so the phone
does not need to be on the same Wi-Fi network.

If `adb` is not recognized, run it using the Android SDK path, for example:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
```

The Android emulator uses the default API URL `http://10.0.2.2:8000/api`;
the physical-phone command above overrides it only for that run.
