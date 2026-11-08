# Colohouse Backend (Django REST API)

Django + Django REST Framework + JWT (SimpleJWT) + PostgreSQL.

## What is done

**Sprint 1: accounts**
- Sign up, log in with JWT, refresh the token
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

Everything is also manageable in the Django admin (`/admin`): verify users, approve / hide listings.

## Project structure

```
backend/
├── manage.py
├── requirements.txt
├── Colohouse/        # the Django project (settings.py, urls.py)
├── accounts/         # User, City, RoommateProfile + serializers, views, urls, tests
└── housing/          # HousingListing, ListingPhoto, HousingRequest + search.py, views, urls, tests
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

**3. Create the tables, add the cities and start the server**
```powershell
python manage.py migrate
python manage.py seed_cities        # adds 12 cities (safe to run again)
python manage.py createsuperuser    # for /admin
python manage.py runserver
```

**After every `git pull`:** run `pip install -r requirements.txt` and `python manage.py migrate` again.

Run the tests with `python manage.py test` (accounts + housing).

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
  "created_at": "2026-11-08T16:00:00Z",
  "updated_at": "2026-11-08T16:00:00Z"
}
```
- `status`: `pending`, `accepted`, `declined`, `cancelled`, `completed`.
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

## How the app should use it

1. **Sign up** → on `201`, call login with the same email/password.
2. **Log in** → save `access` and `refresh` (`flutter_secure_storage`).
3. **After the first login** → profile setup: `PATCH /me/` (city dropdown from `/api/cities/`), picture, then lifestyle (`PATCH /me/preferences/`).
4. **Any 🔒 call returns `401`** → call `/api/auth/token/refresh/`, save the new `access`, retry; if refresh fails → login screen.
5. **Search tab** → `GET /api/listings/` with the filters; the map uses `latitude`/`longitude` of each result.
6. **Post tab** → `POST /api/listings/`, then `POST /api/listings/<id>/photos/` for each picture.
7. **Listing details** → "Send request" button unless `my_request` is pending/accepted; show address + phone when `contact_visible` is `true`.
8. **My requests / requests received** → accept / decline / cancel buttons on `pending` requests.
9. **Settings** → notification switches (`PATCH /me/`), log out (delete the tokens), delete account.

## Dart examples (`dio`)

```dart
final dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2:8000/api'));
dio.options.headers['Authorization'] = 'Bearer $access';

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
