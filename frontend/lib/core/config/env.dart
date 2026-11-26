class Env {
  // Android emulator reaches your PC at 10.0.2.2
  static const String apiBaseUrl = 'http://10.0.2.2:8000/api';

  // Language of the app, sent to the backend after login so pushes use it.
  // Sprint 4 (FR/EN/AR) will make it follow the language chosen in the app.
  static const String language = 'en';
  //for browser 
   // static const String apiBaseUrl = 'http://localhost:8000/api';

}