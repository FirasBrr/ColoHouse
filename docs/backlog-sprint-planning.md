# ColoHouse: Product Backlog and Sprint Planning

Status as of 25 November 2026. Sprints 1 and 2 are done (57 story points); Sprint 3 is in progress; Sprint 4 is planned.

## 1. Product vision

ColoHouse is an Android app that helps people find housing and compatible roommates.
Hosts publish rooms, seekers search them on a list or a map and send requests, and the app ranks compatible roommates from their lifestyle preferences.
Contact details stay private until a request is accepted.

**Stack:** Flutter (Riverpod, go_router, dio, flutter_map) · Django REST Framework · PostgreSQL · JWT (SimpleJWT) · Firebase (Authentication, Cloud Firestore, Cloud Messaging).

## 2. Scrum organisation

| Item | Choice |
|---|---|
| Method | Scrum, 4 sprints of 2 weeks |
| Roles | Product Owner, Scrum Master, Development team (backend developer, frontend developer); fill in the team members' names |
| Events | Sprint planning (start of sprint), daily check-in, sprint review with a demo on the Android emulator, retrospective |
| Estimation | Story points (Fibonacci: 1, 2, 3, 5, 8) |
| Priority | MoSCoW: Must, Should, Could, Won't |
| Tools | GitHub (code + history), VS Code, Android emulator, Django admin, Firebase console |

**Definition of Done**
- The code is on the `main` branch of the GitHub repository.
- Backend: automated tests pass (`python manage.py test`) and the API guide (`backend/README.md`) is updated.
- Frontend: the feature runs on the Android emulator, forms are validated, and loading, empty and error states are handled.
- The feature is shown at the sprint review.
- No secret is committed (Firebase key, passwords).

## 3. Epics

| Epic | Description |
|---|---|
| E1 Accounts & profile | Sign up, log in, profile, picture, preferences, settings |
| E2 Firebase authentication | Email/password and Google Sign-In through FirebaseAuth |
| E3 Housing listings | Publish, edit, pause, close listings with photos |
| E4 Search & map | Filters, distance search, map, listing details |
| E5 Housing requests | Send, accept, decline, cancel; privacy until acceptance |
| E6 Roommate matching | Hard filters, 0–100 score, breakdown, explanation |
| E7 Chat | 1-to-1 real-time chat in Cloud Firestore after acceptance |
| E8 Notifications | Push notifications (FCM) and in-app history |
| E9 App experience | Theme, languages (FR/EN/AR, RTL), navigation, animations, states |
| E10 Ads | AdMob banner and interstitial (test IDs) |
| E11 Administration | Verify users, approve/hide listings, suspend users |
| E12 AI assistant (bonus) | Natural-language search, match explanation |
| E13 Quality & release | Tests, API docs, security, release APK |
| E14 Bonus | Offline mode, sandbox payment |

## 4. Product backlog

| ID | Epic | User story | Priority | SP | Sprint | Status |
|---|---|---|---|---|---|---|
| US-01 | E1 | As a visitor, I want to create an account with my email and password so that I can use the app. | Must | 3 | S1 | Done |
| US-02 | E1 | As a user, I want to log in and stay logged in (automatic token refresh) so that I do not type my password every time. | Must | 3 | S1 | Done |
| US-03 | E1 | As a user, I want to edit my profile (name, phone, bio, institution, occupation, city) so that others know who I am. | Must | 3 | S1 | Done |
| US-04 | E1 | As a user, I want to upload a profile picture so that my profile is trustworthy. | Should | 2 | S1 | Done |
| US-05 | E1 | As a user, I want to set my lifestyle and housing preferences (budget, room type, move-in date, sleep schedule, noise, cleanliness, smoking) so that I get relevant matches. | Must | 5 | S1 | Done |
| US-06 | E1 | As a user, I want to choose which notifications I receive. | Should | 1 | S1 | Done |
| US-07 | E1 | As a user, I want to delete my account and my data. | Must | 1 | S1 | Done |
| US-08 | E1 | As a user, I want clear error messages under every form field. | Must | 2 | S1 | Done (validators still to add on 2 forms, S4) |
| US-09 | E2 | As a user, I want to sign up and log in with email and password through Firebase Authentication, with email verification. | Must | 5 | S3 | In progress (backend done) |
| US-10 | E2 | As a user, I want to log in with my Google account. | Must | 3 | S3 | In progress (backend done) |
| US-11 | E3 | As a host, I want to publish a listing (description, rent, deposit, room type, location on a map, availability, rules) so that people can find my room. | Must | 5 | S2 | Done |
| US-12 | E3 | As a host, I want to add and remove photos of my listing. | Must | 3 | S2 | Done (adding photos to an existing listing in the app, S4) |
| US-13 | E3 | As a host, I want to edit, pause, reactivate or close my listing. | Must | 3 | S2 | Done |
| US-14 | E3 | As a host, I want to see all my listings. | Should | 1 | S2 | Done |
| US-15 | E4 | As a seeker, I want to search listings with filters (text, city, room type, price, availability date, distance) so that I find a room that fits me. | Must | 5 | S2 | Done |
| US-16 | E4 | As a seeker, I want to see the listings on a map. | Must | 3 | S2 | Done |
| US-17 | E4 | As a seeker, I want to open a listing's details (photos, map, rules, host). | Must | 2 | S2 | Done |
| US-18 | E5 | As a seeker, I want to send a housing request with a message. | Must | 2 | S2 | Done |
| US-19 | E5 | As a host, I want to accept or decline a request, safely even if two actions happen at the same time. | Must | 3 | S2 | Done |
| US-20 | E5 | As a seeker, I want to see my sent requests and cancel one. | Should | 2 | S2 | Done |
| US-21 | E5 | As a user, I want the exact address and phone number to stay hidden until a request is accepted. | Must | 2 | S2 | Done |
| US-22 | E6 | As a person looking for a room, I want a ranked list of compatible roommates with a score from 0 to 100. | Must | 8 | S3 | To do |
| US-23 | E6 | As a person looking for a room, I want to see the score breakdown and a short explanation of each match. | Should | 3 | S3 | To do |
| US-24 | E7 | As a user, I want to chat in real time with the other person once a request is accepted. | Must | 8 | S3 | To do |
| US-25 | E8 | As a host, I want a push notification when I receive a request; as a seeker, when my request is accepted or declined (app in foreground or background). | Must | 5 | S3 | To do |
| US-26 | E8 | As a user, I want a tap on a notification to open the related screen. | Must | 2 | S3 | To do |
| US-27 | E8 | As a user, I want a notification history with an unread counter. | Should | 3 | S3 | To do |
| US-28 | E9 | As a user, I want to switch between light and dark theme and keep my choice when I reopen the app. | Must | 2 | S2 | Done |
| US-29 | E9 | As a user, I want the app in French, English and Arabic (right-to-left), with a language switch inside the app. | Must | 8 | S4 | To do |
| US-30 | E9 | As a user, I want clear navigation with a drawer, a bottom navigation bar and tabs. | Must | 2 | S4 | In progress (tabs done) |
| US-31 | E9 | As a user, I want smooth animations (Hero, AnimatedContainer, AnimatedOpacity, Lottie). | Must | 3 | S4 | In progress (AnimatedContainer done) |
| US-32 | E9 | As a user, I want loading indicators, empty states and clear error messages. | Must | 2 | S2 | Done (retry button on errors, S4) |
| US-33 | E10 | As the product owner, I want a banner ad and an interstitial ad (Google test IDs only). | Must | 3 | S4 | To do |
| US-34 | E11 | As an admin, I want to verify users and approve or hide listings. | Should | 2 | S2 | Done |
| US-35 | E11 | As an admin, I want to suspend a user and manage roles. | Should | 3 | S4 | To do |
| US-36 | E12 | As a seeker, I want to type my search in plain words ("cheap room near Tunis center") and get the matching filters. | Could | 5 | S4 | To do |
| US-37 | E12 | As a person looking for a room, I want an AI explanation of a match, with a simple template when the AI is unavailable. | Could | 3 | S4 | To do |
| US-38 | E13 | As the team, we want automated tests and an up-to-date API documentation (README, Swagger). | Must | 3 | S4 | In progress (95 backend + 14 Flutter tests) |
| US-39 | E13 | As the team, we want production security: secrets out of the code, DEBUG off, rate limiting, pagination. | Must | 3 | S4 | To do |
| US-40 | E13 | As the team, we want a signed release APK for the final demo. | Must | 2 | S4 | To do |
| US-41 | E14 | As a user, I want to browse my last results offline (local Hive cache). | Could | 5 | — | Not planned (bonus) |
| US-42 | E14 | As a seeker, I want to pay the deposit after acceptance (Stripe test mode, transactions saved in Firestore). | Could | 8 | — | Not planned (bonus) |

**Removed from scope (Won't, this release)**

| Feature | Reason |
|---|---|
| Favorites | Removed by the team to keep the scope realistic; can come back after Sprint 4 |
| Reviews and ratings, reports, moderators | Reduced trust & moderation scope; the admin covers verification and hiding |
| Campus model | Replaced by a generic City so the app is not limited to students |

## 5. Sprint planning

| Sprint | Weeks | Goal | Planned SP | Completed SP | Status |
|---|---|---|---|---|---|
| S1 Foundations | 1–2 | Sign up, log in and fill in the profile and preferences on the emulator | 20 | 20 | Done |
| S2 Housing | 3–4 | A host publishes a listing, a seeker finds it on the map, sends a request, the host accepts | 37 | 37 | Done |
| S3 Firebase & social | 5–6 | Firebase login, ranked roommates, chat after acceptance, push notifications | 37 | 0 (2 stories half done) | In progress |
| S4 Experience & release | 7–8 | Languages, ads, navigation and animations, admin, AI bonus, hardening, release APK | 35 | — | Planned |

Fill in the calendar dates of each sprint. The delivery log in section 6 gives the real dates from the git history.

### Initial plan (start of the project)

| Sprint | Theme | Demo at the end |
|---|---|---|
| 1 | Foundations, authentication, profile | Register, log in, fill in the profile and preferences on the emulator |
| 2 | Housing: listings, photos, search and filters, map, requests (send / accept / decline with transactions) | Host publishes a listing → seeker finds it on the map → sends a request → host accepts |
| 3 | Roommate matching (hard filters + weighted score + breakdown + template explanation), real-time chat (Django Channels, opened by an accepted request), notifications (in-app; push with FCM + Celery) | Ranked roommates with a score breakdown; chat after acceptance |
| 4 | Admin actions (approve and hide listings, suspend users), AI (natural-language search → filters; match explanation with template fallback), performance and security hardening, documentation, release APK | Full demo |

### Changes to the plan and why

The 4 sprints, their themes and their demos are kept. These changes came from the sprint reviews and from the course requirements:

| Change | Sprint | Reason |
|---|---|---|
| Firebase Authentication (email/password + Google) added | S3 | Mandatory course requirement; the Django JWT login is kept alongside it, so the rest of the API does not change |
| Chat in Cloud Firestore instead of Django Channels + Redis | S3 | Firestore is mandatory and real-time by default, so no Redis server or WebSocket layer is needed |
| Push notifications sent directly by Django with the Firebase Admin SDK, no Celery | S3 | Simpler: one notification per request event does not need a task queue |
| Languages (FR/EN/AR, RTL), ads, drawer and animations added | S4 | Mandatory course requirements |
| Approve / hide listings done early | S2 (planned S4) | Cheap as Django admin actions once the listing statuses existed |
| Distance search with the Haversine formula instead of PostGIS | S2 | PostGIS is hard to install on Windows; the formula in PostgreSQL is enough for the app's data size |
| Campus replaced by City; favorites, reviews and reports removed | S1–S2 | Generic app (not only students) and a realistic scope for 4 sprints |

### Sprint 1: Foundations, authentication, profile (Done)

**Goal:** a user can sign up, log in and fill in their profile and preferences on the Android emulator.
**Stories:** US-01 to US-08 (20 SP).

- Backend (Django)
    - Custom User model (email login, case-insensitive), City and RoommateProfile models.
    - Register endpoint, JWT login and refresh (SimpleJWT: access 30 min, refresh 7 days).
    - Profile (GET/PATCH/DELETE `/api/auth/me/`), multipart picture upload (max 5 MB), preferences endpoint, public city list.
    - Django admin for all models, PostgreSQL database, 27 automated tests.
- Frontend (Flutter)
    - Splash, login and register screens with validation; tokens in secure storage; automatic refresh on `401`.
    - Profile, edit profile (city dropdown, picture), preferences and settings screens; log out and delete account.

**Review:** sign up → log in → profile → preferences demonstrated on the emulator.

### Sprint 2: Housing (Done)

**Goal:** a host publishes a listing, a seeker finds it on the map and sends a request, and the host accepts it.
**Stories:** US-11 to US-21, US-28, US-32, US-34 (37 SP).

- Backend (Django)
    - `housing` app: HousingListing, ListingPhoto and HousingRequest (association class between a user and a listing).
    - Listing life cycle as allowed status changes (draft → active ⇄ paused → closed; hidden by an admin).
    - Search: text, city, room type, price range, availability, distance with the Haversine formula computed in the database, ordering; indexes for the filters.
    - Requests: accept/decline inside a database transaction with a row lock (`select_for_update`); one open request per person and listing (database constraint).
    - Privacy: address and phone hidden until acceptance, map coordinates rounded to about 1 km.
    - Admin actions: approve and hide listings; command to add 12 cities; 43 new tests.
- Frontend (Flutter)
    - Post a listing (map pin, photos), edit, pause, close, delete photos; my listings.
    - Search tab with a filter sheet and a list/map toggle (flutter_map + OpenStreetMap); listing details screen.
    - Requests inbox and sent requests (TabBar) with accept, decline and cancel; dark mode saved across restarts.

**Review:** host publishes → seeker finds it on the map → sends a request → host accepts → address and phone become visible.

### Sprint 3: Firebase, matching, chat, notifications (In progress)

**Goal:** users log in with FirebaseAuth, see ranked roommates, chat after an accepted request and receive push notifications.
**Stories:** US-09, US-10, US-22 to US-27 (37 SP).

- Backend (Django)
    - [x] Firebase login: the app sends its Firebase ID token to `POST /api/auth/firebase/`, the backend verifies it and returns its own JWT pair; existing accounts are linked only with a verified email (US-09, US-10).
    - [ ] Push notifications: device token and language on the user; a notification when a request is received, accepted or declined, with the target screen in the data (US-25, US-26).
    - [ ] Notification history: Notification model, list, unread counter, mark as read (US-27).
    - [ ] Chat: when a request is accepted, the backend creates the conversation in Cloud Firestore; Firestore security rules allow only the two participants (US-24).
    - [ ] Roommate matching: hard filters (looking for a room, smoker compatibility both ways, budget within ±20 %, move-in dates close, same area), weighted score (budget 25, sleep schedule 20, cleanliness 20, noise tolerance 15, smoking 10, distance 10), breakdown stored as JSON, template explanation (US-22, US-23).
- Frontend (Flutter)
    - [ ] Firebase setup (firebase_core, Gradle plugin); email/password sign-up with email verification; Google Sign-In button.
    - [ ] firebase_messaging: permission, foreground and background notifications, tap opens the related screen.
    - [ ] Chat list and chat thread screens on Firestore streams.
    - [ ] Roommates screen with score and breakdown; notifications screen.

**Review (planned):** Google login → ranked roommates with breakdown → request accepted → push notification → chat opens.

### Sprint 4: Experience, administration, AI, release (Planned)

**Goal:** the app meets every course requirement, is secured and ships as a release APK.
**Stories:** US-29 to US-31, US-33, US-35 to US-40 (35 SP), plus the small items carried over from S1 and S2.

- Backend (Django)
    - Translated API messages (French, Arabic) with `LocaleMiddleware`; push texts in the user's language (US-29).
    - Admin: suspend users, roles (US-35).
    - AI assistant behind an internal client: natural-language search → filters; match explanation with template fallback (US-36, US-37).
    - Security: secret key and passwords in environment variables, DEBUG off, rate limiting, pagination (US-39); Swagger documentation (US-38).
- Frontend (Flutter)
    - French/English/Arabic with ARB files, in-app language switch, right-to-left layout (US-29).
    - Drawer, standard bottom navigation bar; Hero, AnimatedOpacity and Lottie animations (US-30, US-31).
    - FutureBuilder and ListView.builder on at least one list, retry button on errors, validators on the preferences and edit-listing forms, add photos to an existing listing.
    - AdMob banner and interstitial with Google test IDs (US-33).
    - Release APK: INTERNET permission in the main manifest, final application id, release SHA-1 in Firebase (US-40).

**Review (planned):** full demo in French, English and Arabic, dark and light theme, ads, and the complete housing → request → chat flow.

## 6. Delivery log (from the git history)

| Date | Delivered |
|---|---|
| 2026-11-25 | Firebase login endpoint, account linking with verified email, security review fixes (not yet committed) |
| 2026-11-16 | Dark mode with saved choice |
| 2026-11-13 | Listing filters and map view |
| 2026-11-12 | Home screen and search tab |
| 2026-11-10 | Listing screens (details, edit, photos), requests inbox with accept/decline, sent requests |
| 2026-11-08 | Backend Sprint 2: housing models, listings/photos/search/requests API, tests, API guide |
| 2026-11-04 | Home screen update |
| 2026-10-15 | Flutter authentication screens and backend Sprint 1 (accounts, profile, preferences) |

## 7. Course requirements coverage

| Requirement | Backlog item | Status |
|---|---|---|
| Cloud Firestore | US-24 (chat), US-42 (bonus) | S3 |
| FirebaseAuth email/password + Google Sign-In | US-09, US-10 | S3, backend done |
| Forms with validation | US-08 | Done (2 forms to complete in S4) |
| Push notifications (foreground, background, tap opens a screen, triggered by an action) | US-25, US-26 | S3 |
| French, English, Arabic with RTL | US-29 | S4 |
| Light/dark theme saved | US-28 | Done |
| Drawer, BottomNavigationBar, TabBar | US-30 | TabBar done, rest S4 |
| At least 10 screens | All epics | Done (13 screens today) |
| Animations (Hero, AnimatedContainer, AnimatedOpacity, Lottie) | US-31 | AnimatedContainer done, rest S4 |
| State management | Riverpod, all sprints | Done |
| Named routes, arguments, nested navigation | go_router, all sprints | Done |
| REST API with dio, FutureBuilder, ListView.builder | Django API, S4 task | dio done; FutureBuilder/ListView.builder S4 |
| Loading, empty and error states | US-32 | Done (retry in S4) |
| Ads: banner + interstitial (test IDs) | US-33 | S4 |
| Bonus: payment, AI, offline database | US-42, US-36/US-37, US-41 | AI planned in S4; others not planned |
