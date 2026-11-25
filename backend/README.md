# Colohouse Backend (Django REST API)

Django + Django REST Framework + JWT (SimpleJWT) + PostgreSQL, with Firebase (FirebaseAuth login, FCM/Firestore later).

## What is done

**Sprint 1: accounts**
- Sign up, log in with JWT, refresh the token
- Log in with **FirebaseAuth** (email/password or Google): the app sends its Firebase ID token, the backend answers with the same JWT tokens
- Profile: name, phone, bio, profile picture, institution, occupation, city, verification badge (set by an admin)
- Lifestyle & housing preferences: budget, room type, move-in date, max distance to the city center, sleep schedule, noise tolerance, cleanliness, smoking, "looking for a room"
- Notification settings, delete account
- List of cities (for a dropdown)

**Sprint 2: housing**
- Listings: publish, edit, pause / reactivate / close, my listings
- Listing photos: upload (max 8 per listing, 5 MB each), delete
- Search: text, city, room type, price range, availability date, distance (radius around a point or a city center), ordering
- Map: every listing has `latitude` / `longitude` (rounded to ~1 km until a request is accepted)
- Housing requests: send, cancel, accept, decline (accept/decline run in a DB transaction with a row lock)
- Privacy: the exact address and the phone numbers are only visible after a request is accepted

**Sprint 3: notifications, chat, matching (backend)**
- Push notifications (Firebase Cloud Messaging) + notification history with unread counter:
  new request (to the host), request accepted / declined (to the sender), new chat message
- Texts in the user's language (`language`: `en`, `fr`, `ar`)
- Chat: a conversation is opened when a request is accepted; messages are written by the app in Cloud Firestore
  (real time), protected by `firestore.rules`
- Roommate matching: hard filters, score 0–100 with a breakdown per criterion and a short explanation

Everything is also manageable in the Django admin (`/admin`): verify users, approve / hide listings.

## Project structure

```
backend/
├── manage.py
├── requirements.txt
├── firestore.rules   # Firestore security rules for the chat (publish them in the Firebase console)
├── Colohouse/        # the Django project (settings.py, urls.py)
├── accounts/         # User, City, RoommateProfile, Firebase login (firebase.py) + serializers, views, urls, tests
├── housing/          # HousingListing, ListingPhoto, HousingRequest + search.py, views, urls, tests
├── notifications/    # Notification + services.py (history + push), texts.py (en/fr/ar)
├── chat/             # Conversation + firestore.py (Firestore documents)
└── matching/         # MatchResult + engine.py (filters, score, explanation)
```

## Run the backend on your PC

**1. Install packages (once)**
```powershell
cd backend
python -m venv my_env
my_env\Scripts\activate
pip install -r requirements.txt
```

**2. Create the PostgreSQL user and database (once)**

PostgreSQL must be installed. Run this and enter your `postgres` password:
```powershell
& "C:\Program Files\PostgreSQL\17\bin\psql.exe" -U postgres -h localhost -c "CREATE USER colohouse WITH PASSWORD 'colohouse' CREATEDB;" -c "CREATE DATABASE colohouse OWNER colohouse;"
```
(Or in pgAdmin: create role `colohouse` / password `colohouse` with "Create databases", then a database `colohouse` owned by it.)

**3. Firebase key (once)**

Firebase console → ⚙ Project settings → Service accounts → **Generate new private key**, and save the file as `backend/firebase-key.json`.
It is in `.gitignore`: **never commit it or send it in a chat**, it gives admin access to the Firebase project.
Without it everything works except `POST /api/auth/firebase/` (it answers `503`).

**4. Create the tables, add the cities and start the server**
```powershell
python manage.py migrate
python manage.py seed_cities        # adds 12 cities (safe to run again)
python manage.py createsuperuser    # for /admin
python manage.py runserver
```

**After every `git pull`:** run `pip install -r requirements.txt` and `python manage.py migrate` again.

**5. Firestore rules (once, and again when `firestore.rules` changes)**

Firebase console → Firestore Database → **Rules** → paste the content of `backend/firestore.rules` → **Publish**.
Without them the app cannot read or write the chat (the database is in production mode: everything is closed).

Run the tests with `python manage.py test` (accounts, housing, notifications, chat, matching).

## Base URL for the Flutter app

| Where the app runs | Base URL |
|---|---|
| Android emulator | `http://10.0.2.2:8000/api` |
| Chrome (`flutter run -d chrome`) | `http://127.0.0.1:8000/api` (CORS is enabled for development) |

## API

Requests and responses are JSON (`Content-Type: application/json`), except picture/photo uploads (multipart).
Every endpoint marked 🔒 needs the header `Authorization: Bearer <access>`, otherwise it returns `401`.
A `400` returns the errors per field, e.g. `{ "phone": ["Enter a valid phone number."] }`: show them under the inputs.
Errors that are not about one field come as `{ "non_field_errors": ["..."] }`.
`403` = not allowed (e.g. editing someone else's listing), `404` = not found or not visible to you.

### Accounts

| Method | URL | What it does |
|---|---|---|
| POST | `/api/auth/register/` | Sign up |
| POST | `/api/auth/login/` | Log in → tokens |
| POST | `/api/auth/firebase/` | Log in with FirebaseAuth (email/password or Google) → tokens |
| POST | `/api/auth/token/refresh/` | New access token |
| GET 🔒 | `/api/auth/me/` | My profile |
| PATCH 🔒 | `/api/auth/me/` | Edit my profile / upload picture / notification settings |
| DELETE 🔒 | `/api/auth/me/` | Delete my account |
| GET 🔒 | `/api/auth/me/preferences/` | My lifestyle & housing preferences |
| PATCH 🔒 | `/api/auth/me/preferences/` | Edit my preferences |
| GET | `/api/cities/` | List of cities |

### Housing

| Method | URL | What it does |
|---|---|---|
| GET 🔒 | `/api/listings/` | Search active listings (filters below) |
| POST 🔒 | `/api/listings/` | Publish a listing |
| GET 🔒 | `/api/listings/mine/` | My listings (all statuses) |
| GET 🔒 | `/api/listings/<id>/` | Listing details |
| PATCH 🔒 | `/api/listings/<id>/` | Edit my listing / pause / reactivate / close |
| POST 🔒 | `/api/listings/<id>/photos/` | Add a photo to my listing (multipart) |
| DELETE 🔒 | `/api/listings/<id>/photos/<photo_id>/` | Delete a photo |
| POST 🔒 | `/api/listings/<id>/requests/` | Send a housing request |
| GET 🔒 | `/api/requests/sent/` | Requests I sent |
| GET 🔒 | `/api/requests/received/` | Requests on my listings |
| POST 🔒 | `/api/requests/<id>/accept/` | Accept (listing owner) |
| POST 🔒 | `/api/requests/<id>/decline/` | Decline (listing owner) |
| POST 🔒 | `/api/requests/<id>/cancel/` | Cancel (sender) |

### Notifications

| Method | URL | What it does |
|---|---|---|
| POST 🔒 | `/api/notifications/device/` | This phone receives my pushes (`{ "fcm_token": "..." }`) |
| DELETE 🔒 | `/api/notifications/device/` | Stop pushes to my phone (on log out) |
| GET 🔒 | `/api/notifications/` | My notification history (newest first, last 100; `?unread=true`) |
| GET 🔒 | `/api/notifications/unread-count/` | `{ "unread": 3 }` for the badge |
| POST 🔒 | `/api/notifications/<id>/read/` | Mark one as read |
| POST 🔒 | `/api/notifications/read-all/` | Mark all as read |

### Chat

| Method | URL | What it does |
|---|---|---|
| GET 🔒 | `/api/conversations/` | My chats (most recent message first) |
| GET 🔒 | `/api/conversations/<id>/` | Open a chat (prepares the Firestore document) |
| POST 🔒 | `/api/conversations/<id>/message-sent/` | Tell the server I wrote a message in Firestore (`{ "message_id": "..." }`) |

### Roommate matching

| Method | URL | What it does |
|---|---|---|
| GET 🔒 | `/api/matches/` | Compatible roommates, best first (`?limit=20`, `?min_score=60`) |
| GET 🔒 | `/api/matches/<user_id>/` | Compatibility with one person (even if not compatible) |

---

## Accounts in detail

### Sign up
`POST /api/auth/register/`
```json
{ "email": "student@colohouse.com", "first_name": "Student", "last_name": "Test", "password": "StrongPass123!" }
```
- `201` → `{ "id": 1, "email": "student@colohouse.com", "first_name": "Student", "last_name": "Test" }`
- `400` → e.g. `{ "email": ["An account with this email already exists."], "password": ["This password is too short..."] }`

### Log in
`POST /api/auth/login/`
```json
{ "email": "student@colohouse.com", "password": "StrongPass123!" }
```
- `200` → `{ "access": "<token>", "refresh": "<token>" }`
- `401` → `{ "detail": "No active account found with the given credentials" }`

### Log in with FirebaseAuth (email/password or Google)
The app signs the user in with `firebase_auth` (`signInWithEmailAndPassword`, `createUserWithEmailAndPassword` or Google Sign-In),
gets the Firebase ID token, and exchanges it for our tokens:

`POST /api/auth/firebase/`
```json
{ "id_token": "<await FirebaseAuth.instance.currentUser!.getIdToken()>", "first_name": "Student", "last_name": "Test" }
```
- `first_name` / `last_name` are optional and only used when the account is created (send them after an email/password sign-up; Google already gives the name).
- `201` → new account: `{ "access": "<token>", "refresh": "<token>", "created": true }` → show the profile setup screens.
- `200` → existing account: same body with `"created": false` → go to home.
- From here everything is the same as the normal login: save `access` / `refresh`, use `/api/auth/token/refresh/`, etc.
- `400` → `{ "non_field_errors": ["Verify your email address (check your inbox), then log in again."] }`:
  the Firebase email is not verified yet (see the email/password flow below). Google accounts are always verified.
- `401` → `{ "detail": "Invalid or expired Firebase token. Log in again." }` (or `"This account is disabled."`)
- `503` → Firebase is not configured on the server (missing or wrong `backend/firebase-key.json`).

**Email/password sign-up flow** (the backend only accepts verified emails):
1. `createUserWithEmailAndPassword(email, password)` then `await credential.user!.sendEmailVerification()`.
2. Show a "check your inbox" screen with an "I verified my email" button.
3. On that button: `await FirebaseAuth.instance.currentUser!.reload();` then
   `final idToken = await FirebaseAuth.instance.currentUser!.getIdToken(true);` (`true` forces a fresh token,
   the cached one still says "not verified" for up to 1 hour), then `POST /api/auth/firebase/` with the names.
4. Next logins: `signInWithEmailAndPassword` → `getIdToken()` → `POST /api/auth/firebase/` (no names needed).

How accounts are matched: same Firebase account → same user. The first time, an existing user with the same (verified) email
is linked to the Firebase account and **its old Django password is removed** (it was never verified, so whoever registered
that email first must not keep access); its old tokens stop working too. Otherwise a new user is created.
Users from Firebase have no Django password, so they always log in through Firebase (`/auth/login/` answers `401` for them).
An admin can unlink a user (Django admin → Users → "Firebase" → empty the field), e.g. if the Firebase user was deleted and created again.

### Refresh the access token
`POST /api/auth/token/refresh/` with `{ "refresh": "<refresh token>" }`
- `200` → `{ "access": "<new token>" }`
- `401` → refresh token expired, the user must log in again

**Token lifetimes:** access = 30 minutes, refresh = 7 days.
When any 🔒 call returns `401` during a session, call refresh, save the new `access` and retry the call once.

### My profile 🔒
`GET /api/auth/me/` → `200`
```json
{
  "id": 1,
  "email": "student@colohouse.com",
  "first_name": "Student",
  "last_name": "Test",
  "phone": "+21612345678",
  "profile_picture": "http://10.0.2.2:8000/media/profile_pictures/avatar.png",
  "bio": "Calm student, likes cooking.",
  "institution": "Test University",
  "occupation": "Computer Science student",
  "city": { "id": 1, "name": "Tunis", "region": "Tunis", "address": "", "latitude": 36.8065, "longitude": 10.1815 },
  "is_verified": false,
  "push_enabled": true,
  "notify_requests": true,
  "notify_messages": true,
  "language": "en",
  "date_joined": "2026-10-14T15:49:13Z"
}
```
Empty values come back as `""` (text) or `null` (`profile_picture`, `city`).
`is_verified` is read-only: only an admin can verify a user (Django admin → Users → action "Mark as verified").

### Edit my profile 🔒
`PATCH /api/auth/me/`: send **only the fields you change**:
```json
{ "phone": "+21612345678", "bio": "...", "institution": "...", "occupation": "...", "city_id": 1 }
```
- `city_id`: the `id` from `/api/cities/` (send `null` to remove it). The response returns the full `city` object.
- `phone`: digits only, optional `+` at the start, 8–15 digits.
- `email` and `is_verified` cannot be changed.
- Notification settings use the same endpoint: `{ "push_enabled": false, "notify_requests": true, "notify_messages": false }`
- Language: `{ "language": "fr" }` (`en`, `fr` or `ar`). Send it **after every login** and whenever the app language changes:
  push notifications and match explanations are written in this language.
- Returns `200` with the full updated profile.

### Upload a profile picture 🔒
`PATCH /api/auth/me/` as **multipart/form-data** with a file field `profile_picture` (an image, max 5 MB).
Returns `200`, and `profile_picture` is a full URL you can show with `Image.network(...)`.
To remove the picture: `PATCH` JSON `{ "profile_picture": null }`.

### Delete my account 🔒
`DELETE /api/auth/me/` → `204`. The user, their preferences, listings and requests are deleted. Then delete the saved tokens and go to the login screen.

### My preferences 🔒
`GET /api/auth/me/preferences/` → `200` (the first time, everything is empty)
```json
{
  "budget": 450,
  "preferred_room_type": "private",
  "move_in_date": "2026-11-01",
  "max_distance_to_center": 3.5,
  "sleep_schedule": "late",
  "noise_tolerance": 2,
  "cleanliness": 5,
  "smoker": false,
  "accepts_smokers": false,
  "looking_for_room": true,
  "updated_at": "2026-10-14T15:49:14Z"
}
```
`PATCH /api/auth/me/preferences/`: send only the fields you change. Allowed values:

| Field | Values |
|---|---|
| `budget` | whole number per month, e.g. `450` (or `null`) |
| `preferred_room_type` | `"private"`, `"shared"`, `"studio"`, or `""` = no preference |
| `move_in_date` | `"YYYY-MM-DD"` (or `null`) |
| `max_distance_to_center` | km from the city center, e.g. `3.5` (or `null`), not negative |
| `sleep_schedule` | `"early"` (early bird), `"normal"`, `"late"` (night owl), or `""` |
| `noise_tolerance` | `1`–`5` (1 = needs quiet, 5 = noise is fine) |
| `cleanliness` | `1`–`5` (1 = relaxed, 5 = very tidy) |
| `smoker` | `true` / `false` (do I smoke) |
| `accepts_smokers` | `true` / `false` (OK to live with a smoker) |
| `looking_for_room` | `true` / `false` (show me as looking for a room) |

### Cities
`GET /api/cities/` (no token needed) → `200`
```json
[ { "id": 1, "name": "Tunis", "region": "Tunis", "address": "", "latitude": 36.8065, "longitude": 10.1815 } ]
```

---

## Housing in detail

### A listing (what every listing endpoint returns)
```json
{
  "id": 3,
  "owner": {
    "id": 2, "first_name": "Host", "last_name": "Test",
    "profile_picture": null, "bio": "", "institution": "", "occupation": "", "is_verified": true
  },
  "title": "Studio in Tunis",
  "description": "Quiet studio, 10 min from the center.",
  "rent": 550,
  "deposit": 550,
  "room_type": "studio",
  "city": { "id": 1, "name": "Tunis", "region": "Tunis", "address": "", "latitude": 36.8065, "longitude": 10.1815 },
  "address": null,
  "latitude": 36.81,
  "longitude": 10.18,
  "distance_km": 1.24,
  "available_from": "2026-12-01",
  "rules": "No parties.",
  "status": "active",
  "photos": [ { "id": 7, "image": "http://10.0.2.2:8000/media/listing_photos/room.png", "order": 0 } ],
  "contact_visible": false,
  "owner_phone": null,
  "my_request": { "id": 12, "status": "pending" },
  "created_at": "2026-11-08T15:41:00Z",
  "updated_at": "2026-11-08T15:41:00Z"
}
```
- **Privacy:** `contact_visible` is `true` only for the owner and for a user whose request was **accepted**.
  When it is `false`: `address` and `owner_phone` are `null`, and `latitude`/`longitude` are rounded (~1 km), which is fine for a map pin.
- `distance_km` is only filled when the search uses a distance (see below), otherwise `null`.
- `my_request` = my latest request on this listing (`null` if I never sent one). Use it to show "Request sent" / "Accepted" instead of the "Send request" button.
- Use `photos[0].image` as the cover picture (photos are sorted by `order`).
- `status`: `draft`, `pending_review`, `active`, `paused`, `closed`, `hidden` (hidden = by an admin).

### Search listings 🔒
`GET /api/listings/?<filters>` → `200` with a list of listings (only `active` ones). All filters are optional and can be combined:

| Param | Example | Meaning |
|---|---|---|
| `q` | `studio` | text in the title or description |
| `city` | `1` | city id from `/api/cities/` |
| `room_type` | `private` | `private`, `shared`, `studio` |
| `min_rent` / `max_rent` | `200` / `500` | price range |
| `available_by` | `2026-12-01` | available on or before this date |
| `lat` + `lng` | `36.80` + `10.18` | a point (e.g. the phone's position or a map tap); always send both |
| `radius_km` | `5` | only listings within this distance (0.1–100). Needs `lat`+`lng` **or** `city` (then the city center is used) |
| `ordering` | `distance` | `newest` (default), `rent`, `-rent`, `distance` (needs `lat`+`lng` or `city`) |

Examples:
- Cheap private rooms in Tunis: `/api/listings/?city=1&room_type=private&max_rent=400`
- Map around me, closest first: `/api/listings/?lat=36.80&lng=10.18&radius_km=5&ordering=distance`

Wrong values return `400`, e.g. `{ "lat": ["A valid number is required."] }`.

### Publish a listing 🔒
`POST /api/listings/`
```json
{
  "title": "Studio in Tunis",
  "description": "Quiet studio, 10 min from the center.",
  "rent": 550,
  "deposit": 550,
  "room_type": "studio",
  "city_id": 1,
  "address": "5 Liberty avenue",
  "latitude": 36.81,
  "longitude": 10.18,
  "available_from": "2026-12-01",
  "rules": "No parties."
}
```
- Required: `title`, `description`, `rent` (≥ 1), `room_type`, `address`, `latitude` (-90..90), `longitude` (-180..180), `available_from`.
- Optional: `deposit` (default 0), `city_id`, `rules`, `status` (`"active"` by default, or `"draft"` to save without publishing).
- `201` → the listing. Then upload the photos one by one (next section).

### Add / delete photos 🔒 (owner only)
- Add: `POST /api/listings/<id>/photos/` as **multipart/form-data** with a file field `image` (max 5 MB, max 8 photos) → `201` `{ "id": 7, "image": "http://...", "order": 0 }`
- Delete: `DELETE /api/listings/<id>/photos/<photo_id>/` → `204`

### Edit / pause / close my listing 🔒 (owner only)
`PATCH /api/listings/<id>/` with only the fields you change, e.g. `{ "rent": 500 }`.
Change the status with the same endpoint, e.g. `{ "status": "paused" }`. Allowed changes:

| From | To |
|---|---|
| `draft` | `active`, `closed` |
| `active` | `paused`, `closed` |
| `paused` | `active`, `closed` |
| `closed`, `hidden`, `pending_review` | nothing (closed is final; hidden / pending are decided by an admin) |

A listing cannot be deleted: close it instead (the request history is kept).
Paused / closed listings disappear from the search, and their details are only visible to the owner (and to users with an accepted request).

### My listings 🔒
`GET /api/listings/mine/` → all my listings, every status.

### Housing requests

**A request (what every request endpoint returns)**
```json
{
  "id": 12,
  "listing": { "id": 3, "title": "Studio in Tunis", "rent": 550, "room_type": "studio", "city": "Tunis", "status": "active", "photo": "http://..." },
  "sender": { "id": 5, "first_name": "Student", "last_name": "Test", "profile_picture": null, "bio": "", "institution": "", "occupation": "", "is_verified": false },
  "owner": { "id": 2, "first_name": "Host", "last_name": "Test", "profile_picture": null, "bio": "", "institution": "", "occupation": "", "is_verified": true },
  "message": "Hello, is the room still free?",
  "status": "pending",
  "contact": null,
  "conversation_id": null,
  "created_at": "2026-11-08T16:00:00Z",
  "updated_at": "2026-11-08T16:00:00Z"
}
```
- `status`: `pending`, `accepted`, `declined`, `cancelled`, `completed`.
- `conversation_id`: the chat opened when the request was accepted (`null` before) → `GET /api/conversations/<id>/`.
- `contact` is `null` until the request is **accepted**, then:
  `{ "address": "5 Liberty avenue", "latitude": 36.8102, "longitude": 10.1803, "owner_phone": "+216...", "sender_phone": "+216..." }`

**Send:** `POST /api/listings/<id>/requests/` with `{ "message": "..." }` (message optional) → `201`.
- `400` if it is your own listing or you already have a pending/accepted request for it.
- `404` if the listing is not active.

**Lists:**
- `GET /api/requests/sent/`: requests I sent (optional `?status=pending`)
- `GET /api/requests/received/`: requests on my listings (optional `?status=pending` and `?listing=<id>`)

**Answer (listing owner):** `POST /api/requests/<id>/accept/` or `POST /api/requests/<id>/decline/` (no body) → `200` with the updated request.
**Cancel (sender):** `POST /api/requests/<id>/cancel/` → `200`.
- Only `pending` requests can be accepted / declined / cancelled, otherwise `400` `{ "non_field_errors": ["This request is already accepted."] }`.
- Accept only works while the listing is `active`.
- After a cancel or a decline, the student can send a new request.
- Sending a request notifies the host; accepting or declining notifies the sender (next section). Accepting also opens the chat.

---

## Notifications in detail

### Register the phone for pushes 🔒
After login (and each time `FirebaseMessaging.instance.onTokenRefresh` fires):
1. `await FirebaseMessaging.instance.requestPermission();` (Android 13+ shows nothing without it;
   also add `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` to the main AndroidManifest).
2. `POST /api/notifications/device/` with `{ "fcm_token": "<await FirebaseMessaging.instance.getToken()>" }` → `200`.
- One phone = one account: if another account was logged in on this phone before, it stops receiving its pushes.
- On log out: `DELETE /api/notifications/device/` with `{ "fcm_token": "<this phone's token>" }` → `204`
  (only this phone stops; the user's other phone keeps its pushes), then `await FirebaseMessaging.instance.deleteToken();`
  even if the call failed (offline), then delete the saved tokens.

### When a push is sent

| Event | Who gets it | `type` | `data` (to open the right screen) |
|---|---|---|---|
| New housing request | listing owner | `housing_request` | `screen: "received_requests"`, `request_id` |
| Request accepted | sender | `request_accepted` | `screen: "conversation"`, `request_id`, `conversation_id` |
| Request declined | sender | `request_declined` | `screen: "sent_requests"`, `request_id` |
| New chat message | the other person | `new_message` | `screen: "conversation"`, `conversation_id` |

- Texts are in the receiver's `language` (e.g. "Nouvelle demande de logement").
- A push is only sent when `push_enabled` is on and `notify_requests` (requests) / `notify_messages` (messages) is on.
  The notification is always saved in the history.
- Every push carries `data.type`, `data.screen`, the ids above and `data.notification_id` (all values are strings).
  On tap (`FirebaseMessaging.onMessageOpenedApp` / `getInitialMessage()`), read `data.screen` and navigate;
  you can also call `POST /api/notifications/<notification_id>/read/`.
- Android: create a notification channel with id **`colohouse_default`** (e.g. with `flutter_local_notifications`),
  and show foreground messages yourself (`FirebaseMessaging.onMessage`): Android does not display them while the app is open.
  Pass `jsonEncode(message.data)` as the local notification `payload`, and in `onDidReceiveNotificationResponse`
  decode it and navigate with the same `data.screen` logic as a background tap.
  Skip the local notification when `data.conversation_id` is the chat currently open.
- Several messages of the same chat are merged into one unread notification (same Android `tag`).
  Opening that chat (`GET /api/conversations/<id>/`) marks them as read.

### Notification history 🔒
`GET /api/notifications/` → `200`
```json
[
  {
    "id": 7,
    "type": "request_accepted",
    "title": "Request accepted",
    "body": "Host accepted your request for \"Studio in Tunis\". You can now chat.",
    "data": { "screen": "conversation", "request_id": 12, "conversation_id": 3 },
    "is_read": false,
    "created_at": "2026-11-25T18:00:00Z"
  }
]
```
(In this list, `data` keeps real numbers; only the push data is converted to strings.)

---

## Chat in detail

The messages are stored in **Cloud Firestore** so the app gets them in real time; Django only opens the chat,
lists the conversations and sends the "new message" notification.

```
Firestore
conversations/{firestore id}                 ← written by Django only (a random UUID, see firestore_path)
    participants: [<firebase uid>, <firebase uid>]   (active accounts only)
    participant_ids: [<user id>, <user id>]
    request_id, listing_id, listing_title, created_at
conversations/{firestore id}/messages/{auto id}      ← written by the app
    sender_uid: <my firebase uid>
    text: "Hello"              (1–2000 characters)
    sent_at: serverTimestamp()
    read: false                (only the receiver can set it to true)
```

The chat needs a **Firebase login** (the rules check `request.auth.uid`), so log in with `/api/auth/firebase/`.

**1. List my chats:** `GET /api/conversations/` → `200`
```json
[
  {
    "id": 3,
    "request_id": 12,
    "listing": { "id": 3, "title": "Studio in Tunis", "rent": 550, "room_type": "studio", "city": "Tunis", "status": "active", "photo": "http://..." },
    "other_user": { "id": 2, "first_name": "Host", "last_name": "Test", "profile_picture": null, "bio": "", "institution": "", "occupation": "", "is_verified": true },
    "last_message": "Is the room still free?",
    "last_message_at": "2026-11-25T18:00:00Z",
    "last_sender_id": 5,
    "firestore_path": "conversations/51fa588d-6c1e-4d3b-9a0f-2b7c1e9d4f10",
    "created_at": "2026-11-25T17:55:00Z"
  }
]
```
Use `id` for the API calls and `firestore_path` for Firestore (never build the Firestore path from `id`).

**2. Open a chat:** `GET /api/conversations/<id>/` (same object) → then listen to Firestore:
`FirebaseFirestore.instance.collection('${chat.firestorePath}/messages').orderBy('sent_at').snapshots()`.
- `400` if I am not logged in with Firebase, `404` if it is not my chat, `503` if Firestore is down (after ~10 s at most).
- Opening the chat also marks its "new message" notifications as read.
- Your own message has `sent_at == null` until the server sets the time: show it at the bottom meanwhile.

**3. Send a message:** add it in Firestore, then tell the server:
```dart
final ref = await FirebaseFirestore.instance.collection('${chat.firestorePath}/messages').add({
  'sender_uid': FirebaseAuth.instance.currentUser!.uid,
  'text': text,
  'sent_at': FieldValue.serverTimestamp(),
  'read': false,
});
await dio.post('/conversations/${chat.id}/message-sent/', data: {'message_id': ref.id});
```
The server reads the message in Firestore (it cannot be faked), updates `last_message` and notifies the other person.
- `{"notified": false}` when the message was already handled or is older than the last one (safe to retry).
- `403` if the message was not sent by me; `400` if it does not exist.

**4. Mark as read:** when the receiver sees a message: `update({'read': true})` on its document.

---

## Roommate matching in detail

**How the score works**
1. **Hard filters** (people who fail one are not in the list): looking for a room, smoking OK in both directions
   (`smoker` vs `accepts_smokers`), budgets at most 30 % apart, move-in dates at most 60 days apart.
2. **Score from 0 to 100**:

| Criterion | Points | Full points when |
|---|---|---|
| `budget` | 25 | same budget (0 at 30 % apart) |
| `sleep_schedule` | 20 | same schedule (half for early/normal or normal/late) |
| `cleanliness` | 20 | same level (1–5) |
| `noise_tolerance` | 15 | same level (1–5) |
| `smoking` | 10 | both smoke or both don't (half otherwise) |
| `distance` | 10 | same city (0 at twice my `max_distance_to_center`, default 10 km) |

A missing value (preference not filled) counts as half the points.

**List:** `GET /api/matches/` → `200`, best score first (default 20, `?limit=` up to 50, `?min_score=`)
```json
[
  {
    "user": { "id": 8, "first_name": "Sami", "last_name": "Test", "profile_picture": null, "bio": "", "institution": "", "occupation": "", "is_verified": false },
    "city": "Tunis",
    "score": 86,
    "breakdown": {
      "budget": { "points": 20.8, "max": 25, "known": true, "you": 500, "them": 475 },
      "sleep_schedule": { "points": 20.0, "max": 20, "known": true, "you": "late", "them": "late" },
      "cleanliness": { "points": 15.0, "max": 20, "known": true, "you": 4, "them": 3 },
      "noise_tolerance": { "points": 15.0, "max": 15, "known": true, "you": 2, "them": 2 },
      "smoking": { "points": 10.0, "max": 10, "known": true, "you": false, "them": false },
      "distance": { "points": 5.0, "max": 10, "known": false, "km": null }
    },
    "explanation": "Good match on budget, sleep schedule, cleanliness.",
    "computed_at": "2026-11-25T18:00:00Z"
  }
]
```
- Show `score` as a gauge and `breakdown` as bars (`points` / `max`); `known: false` = not filled by one of you.
- `explanation` is in my `language`.

**One person:** `GET /api/matches/<user_id>/` → same fields plus `"compatible": true/false` and
`"reasons": ["smoking", "budget", "move_in_date"]` (the failed hard filters).
- Useful on a received request, to see if the sender would be a good roommate.
- Only visible for people who appear in matching (`looking_for_room: true`) **or** who share a housing request with me
  (in either direction). Anyone else → `404`, like myself or an unknown user (privacy).
- Someone who never filled in their preferences still gets a result: every criterion is `known: false` (half points).

## How the app should use it

1. **Sign up / log in with FirebaseAuth** (email/password or Google) → `POST /api/auth/firebase/` with the Firebase ID token.
   (The old `/auth/register/` + `/auth/login/` still work too.)
2. **Save** `access` and `refresh` (`flutter_secure_storage`). On log out, also call `FirebaseAuth.instance.signOut()`.
3. **First login** (`"created": true`) → profile setup: `PATCH /me/` (city dropdown from `/api/cities/`), picture, then lifestyle (`PATCH /me/preferences/`).
4. **Any 🔒 call returns `401`** → call `/api/auth/token/refresh/`, save the new `access`, retry; if refresh fails → login screen.
5. **Search tab** → `GET /api/listings/` with the filters; the map uses `latitude`/`longitude` of each result.
6. **Post tab** → `POST /api/listings/`, then `POST /api/listings/<id>/photos/` for each picture.
7. **Listing details** → "Send request" button unless `my_request` is pending/accepted; show address + phone when `contact_visible` is `true`.
8. **My requests / requests received** → accept / decline / cancel buttons on `pending` requests.
9. **Settings** → notification switches and language (`PATCH /me/`), log out (`DELETE /notifications/device/` with
   this phone's token, `FirebaseMessaging.instance.deleteToken()`, delete the tokens, `FirebaseAuth.instance.signOut()`),
   delete account.
10. **After login** → `PATCH /me/` with the current `language`, `requestPermission()`, then `POST /api/notifications/device/`
    with the FCM token; handle taps with `data.screen`.
11. **Bell icon** → badge from `/api/notifications/unread-count/`, list from `/api/notifications/`.
12. **Chat tab** → `/api/conversations/`; open one → `/api/conversations/<id>/` + Firestore messages; after sending → `message-sent`.
13. **Roommates** → `/api/matches/` (score + breakdown); on a received request → `/api/matches/<sender id>/`.

## Dart examples (`dio`)

```dart
final dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:8000/api'));

// FirebaseAuth login with Google -> our tokens (google_sign_in 7.x + firebase_auth)
// Once at startup (serverClientId = the "web" OAuth client, client_type 3 in google-services.json):
await GoogleSignIn.instance.initialize(
  serverClientId: '647651381595-mjrfh82hqbt0sbp7urh9jefu6gghf6b4.apps.googleusercontent.com',
);
// On the "Continue with Google" button:
final account = await GoogleSignIn.instance.authenticate();
final cred = await FirebaseAuth.instance.signInWithCredential(
  GoogleAuthProvider.credential(idToken: account.authentication.idToken),
);
final idToken = await cred.user!.getIdToken();
final tokens = await dio.post('/auth/firebase/', data: {'id_token': idToken});
// tokens.data = {"access": "...", "refresh": "...", "created": true/false}
// Needs: firebase_core + Firebase.initializeApp(), the google-services Gradle plugin,
// and the PC's debug SHA-1 added in Firebase console → Project settings → Your apps.

dio.options.headers['Authorization'] = 'Bearer ${tokens.data['access']}';

// Search
final res = await dio.get('/listings/', queryParameters: {
  'city': 1, 'max_rent': 500, 'ordering': 'rent',
});

// Publish + 1 photo
final listing = await dio.post('/listings/', data: {...});
await dio.post(
  '/listings/${listing.data['id']}/photos/',
  data: FormData.fromMap({'image': await MultipartFile.fromFile(path)}),
);

// Profile picture
await dio.patch('/auth/me/', data: FormData.fromMap({
  'profile_picture': await MultipartFile.fromFile(path),
}));

// Send / accept a request
await dio.post('/listings/3/requests/', data: {'message': 'Hello!'});
await dio.post('/requests/12/accept/');
```

You can also test every endpoint in the browser (open the URL, DRF shows a form) or in Postman (Authorization → Bearer Token).
