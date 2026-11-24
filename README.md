# 📞 IntraCom — Complete Project Plan
### Independent Communication Platform for Bangladesh

---

## 1. Vision & Core Concept

IntraCom is a **fully self-hosted, independent communication platform** — no Twilio, no Firebase Cloud Messaging relay, no Agora, no third-party calling SDKs. Every component runs on **your own Oracle Cloud infrastructure**.

**Core Features:**
- 🎙️ One-to-one Audio Calling
- 📹 One-to-one Video Calling
- 💬 Real-time Chat & Messaging (text, images, files, voice notes)
- 🏠 Hangouts — Discord-style persistent voice rooms (hubs)
- 📇 Contacts with district-based numbering
- 🌍 Cross-platform: Android, iOS, Windows, macOS

> [!IMPORTANT]
> **No third-party communication services.** The entire real-time stack — signaling, media relay, NAT traversal, group conferencing — is self-hosted on Oracle Cloud. We use **WebRTC as the open W3C/IETF protocol** (it's a standard built into every OS, not a paid service) with fully self-hosted infrastructure.

---

## 2. IntraCom Numbering System

Every user gets a unique number in the format: **`+AreaCode-XXXXXXX`**

### 2.1 Area Codes (64 Districts of Bangladesh)

| Code | জেলা (District) | বিভাগ (Division) |
|------|-----------------|-------------------|
| +1 | ঢাকা (Dhaka) | Dhaka |
| +2 | নরসিংদী (Narsingdi) | Dhaka |
| +3 | ব্রাহ্মণবাড়িয়া (Brahmanbaria) | Chattogram |
| +4 | কিশোরগঞ্জ (Kishoreganj) | Dhaka |
| +5 | গাজীপুর (Gazipur) | Dhaka |
| +6 | মানিকগঞ্জ (Manikganj) | Dhaka |
| +7 | মুন্সিগঞ্জ (Munshiganj) | Dhaka |
| +8 | নারায়ণগঞ্জ (Narayanganj) | Dhaka |
| +9 | টাঙ্গাইল (Tangail) | Dhaka |
| +10 | ফরিদপুর (Faridpur) | Dhaka |
| +11 | গোপালগঞ্জ (Gopalganj) | Dhaka |
| +12 | মাদারীপুর (Madaripur) | Dhaka |
| +13 | রাজবাড়ী (Rajbari) | Dhaka |
| +14 | শরীয়তপুর (Shariatpur) | Dhaka |
| +15 | চট্টগ্রাম (Chattogram) | Chattogram |
| +16 | কুমিল্লা (Cumilla) | Chattogram |
| +17 | চাঁদপুর (Chandpur) | Chattogram |
| +18 | কক্সবাজার (Cox's Bazar) | Chattogram |
| +19 | ফেনী (Feni) | Chattogram |
| +20 | লক্ষ্মীপুর (Lakshmipur) | Chattogram |
| +21 | নোয়াখালী (Noakhali) | Chattogram |
| +22 | রাঙ্গামাটি (Rangamati) | Chattogram |
| +23 | খাগড়াছড়ি (Khagrachhari) | Chattogram |
| +24 | বান্দরবান (Bandarban) | Chattogram |
| +25 | রাজশাহী (Rajshahi) | Rajshahi |
| +26 | নওগাঁ (Naogaon) | Rajshahi |
| +27 | নাটোর (Natore) | Rajshahi |
| +28 | চাঁপাইনবাবগঞ্জ (Chapainawabganj) | Rajshahi |
| +29 | পাবনা (Pabna) | Rajshahi |
| +30 | বগুড়া (Bogura) | Rajshahi |
| +31 | জয়পুরহাট (Joypurhat) | Rajshahi |
| +32 | সিরাজগঞ্জ (Sirajganj) | Rajshahi |
| +33 | খুলনা (Khulna) | Khulna |
| +34 | বাগেরহাট (Bagerhat) | Khulna |
| +35 | সাতক্ষীরা (Satkhira) | Khulna |
| +36 | যশোর (Jessore) | Khulna |
| +37 | মাগুরা (Magura) | Khulna |
| +38 | নড়াইল (Narail) | Khulna |
| +39 | ঝিনাইদহ (Jhenaidah) | Khulna |
| +40 | কুষ্টিয়া (Kushtia) | Khulna |
| +41 | চুয়াডাঙ্গা (Chuadanga) | Khulna |
| +42 | মেহেরপুর (Meherpur) | Khulna |
| +43 | বরিশাল (Barishal) | Barishal |
| +44 | পটুয়াখালী (Patuakhali) | Barishal |
| +45 | ভোলা (Bhola) | Barishal |
| +46 | পিরোজপুর (Pirojpur) | Barishal |
| +47 | ঝালকাঠি (Jhalokati) | Barishal |
| +48 | বরগুনা (Barguna) | Barishal |
| +49 | সিলেট (Sylhet) | Sylhet |
| +50 | মৌলভীবাজার (Moulvibazar) | Sylhet |
| +51 | হবিগঞ্জ (Habiganj) | Sylhet |
| +52 | সুনামগঞ্জ (Sunamganj) | Sylhet |
| +53 | রংপুর (Rangpur) | Rangpur |
| +54 | দিনাজপুর (Dinajpur) | Rangpur |
| +55 | ঠাকুরগাঁও (Thakurgaon) | Rangpur |
| +56 | পঞ্চগড় (Panchagarh) | Rangpur |
| +57 | নীলফামারী (Nilphamari) | Rangpur |
| +58 | লালমনিরহাট (Lalmonirhat) | Rangpur |
| +59 | কুড়িগ্রাম (Kurigram) | Rangpur |
| +60 | গাইবান্ধা (Gaibandha) | Rangpur |
| +61 | ময়মনসিংহ (Mymensingh) | Mymensingh |
| +62 | জামালপুর (Jamalpur) | Mymensingh |
| +63 | শেরপুর (Sherpur) | Mymensingh |
| +64 | নেত্রকোনা (Netrokona) | Mymensingh |

### 2.2 Number Format Examples

```
+1-3847291    →  Dhaka user, ID 3847291
+2-1000001    →  Narsingdi user, ID 1000001
+15-5529103   →  Chattogram user, ID 5529103
+49-2200718   →  Sylhet user, ID 2200718
```

### 2.3 Registration & Verification Flow

```mermaid
flowchart TD
    A["📱 User Opens IntraCom"] --> B["📝 Registration Screen"]
    B --> C["Enter Name, Email/Phone, Password"]
    C --> D["🗺️ Select District (Zilla)"]
    D --> E["📧 OTP Verification (SMS/Email)"]
    E --> F{"Verified?"}
    F -->|Yes| G["🔢 System Assigns Unique 7-digit ID"]
    G --> H["✅ Account Created: +AreaCode-XXXXXXX"]
    F -->|No| E
```

> [!NOTE]
> The 7-digit ID allows up to **9,999,999 unique users per district** (IDs range from `1000000` to `9999999`). With 64 districts, the theoretical system capacity is **~640 million users**.

---

## 3. System Architecture

```mermaid
flowchart TB
    subgraph Clients["📱💻 Cross-Platform Clients (Flutter)"]
        Android["🤖 Android"]
        iOS["🍎 iOS"]
        Windows["🪟 Windows"]
        macOS["🍏 macOS"]
    end

    subgraph OracleCloud["☁️ Oracle Cloud Infrastructure"]
        subgraph Gateway["🚪 API Gateway (Nginx/Caddy)"]
            LB["Load Balancer + TLS Termination"]
        end

        subgraph CoreServices["⚙️ Core Services"]
            API["🌐 REST API Server\n(Go / Fiber)\nPort 8080"]
            WS["🔌 WebSocket Signaling Server\n(Go / Gorilla WS)\nPort 8081"]
            Media["🎬 SFU Media Server\n(Pion WebRTC - Go)\nPort 8082"]
        end

        subgraph RTCInfra["📡 RTC Infrastructure"]
            TURN["🔄 TURN/STUN Server\n(coturn)\nPort 3478/5349"]
        end

        subgraph DataLayer["💾 Data Layer"]
            PG["🐘 PostgreSQL\n(Users, Messages, Contacts, Hangouts)"]
            Redis["⚡ Redis\n(Sessions, Presence, Pub/Sub, Call State)"]
            Minio["📦 MinIO / Object Storage\n(Media Files, Avatars, Attachments)"]
        end
    end

    Android & iOS & Windows & macOS <--> LB
    LB <--> API
    LB <--> WS
    Android & iOS & Windows & macOS <-.->|"WebRTC Media\n(SRTP/DTLS)"| Media
    Android & iOS & Windows & macOS <-.->|"ICE Candidates"| TURN
    WS <--> Redis
    API <--> PG
    API <--> Redis
    API <--> Minio
    Media <--> Redis
    WS <--> Media
```

---

## 4. Technology Stack

### 4.1 Backend (All Self-Hosted on Oracle Cloud)

| Component | Technology | Why |
|-----------|-----------|-----|
| **REST API** | Go + Fiber framework | Ultra-fast, low memory, perfect for real-time |
| **WebSocket Signaling** | Go + Gorilla WebSocket | Handles 100K+ concurrent connections |
| **SFU Media Server** | **Pion WebRTC** (pure Go) | Open-source, self-hosted WebRTC SFU — no third party |
| **TURN/STUN** | coturn | Industry standard, self-hosted NAT traversal |
| **Database** | PostgreSQL 16 | Reliable, ACID, full-text search for messages |
| **Cache/Pub-Sub** | Redis 7 | Presence tracking, session store, real-time pub/sub |
| **Object Storage** | MinIO | Self-hosted S3-compatible, for media files |
| **Reverse Proxy** | Caddy | Auto TLS, HTTP/3, WebSocket proxy |
| **Auth** | JWT + Argon2 hashing | Secure, stateless authentication |
| **Push Notifications** | FCM (Android), APNs (iOS) | Only external dependency — required by OS |

> [!TIP]
> **Pion WebRTC** is a 100% Go implementation of WebRTC. It's not a third-party service — it's an open-source library that runs entirely on YOUR server. This gives you full control over media routing, recording, and processing. No external calls ever leave your infrastructure.

### 4.2 Frontend (Cross-Platform)

| Component | Technology |
|-----------|-----------|
| **Framework** | Flutter 3.x (single codebase → Android, iOS, Windows, macOS) |
| **WebRTC Client** | `flutter_webrtc` package (uses native OS WebRTC engine) |
| **State Management** | Riverpod 2.0 |
| **Local Database** | Drift (SQLite) for offline message cache |
| **WebSocket Client** | `web_socket_channel` |
| **Notifications** | `flutter_local_notifications` + platform push |
| **Audio** | `just_audio` for ringtones, `permission_handler` for mic/camera |

---

## 5. App UI Design (iPhone Dialer Style)

### 5.1 Bottom Navigation Bar (5 Tabs)

```
┌──────────────────────────────────────────────────┐
│                                                  │
│              [ Main Content Area ]                │
│                                                  │
├──────────┬──────────┬──────────┬──────────┬──────┤
│    📇    │    📞    │    💬    │    👤    │  🏠  │
│ Contacts │  Dialer  │ Messages │ Profile  │Hangout│
└──────────┴──────────┴──────────┴──────────┴──────┘
```

### 5.2 Screen Breakdown

#### 📇 Contacts Tab
- Alphabetically sorted contact list with avatars
- Search bar at top
- Each contact shows: Name, IntraCom Number (+Code-XXXXXXX), Online status (green dot)
- Tap → Contact detail (call, video call, message buttons)
- FAB → Add contact by IntraCom number

#### 📞 Dialer Tab (iPhone-style)
```
┌─────────────────────────────┐
│                             │
│      +2-384_ _ _ _          │  ← Number display
│                             │
│   ┌─────┬─────┬─────┐      │
│   │  1  │  2  │  3  │      │
│   │     │ ABC │ DEF │      │
│   ├─────┼─────┼─────┤      │
│   │  4  │  5  │  6  │      │
│   │ GHI │ JKL │ MNO │      │
│   ├─────┼─────┼─────┤      │
│   │  7  │  8  │  9  │      │
│   │PQRS │ TUV │WXYZ │      │
│   ├─────┼─────┼─────┤      │
│   │  *  │  0  │  #  │      │
│   │     │  +  │     │      │
│   └─────┴─────┴─────┘      │
│                             │
│        ( 📞 Call )          │  ← Green call button
│                             │
│   Recent calls list below   │
└─────────────────────────────┘
```

#### 💬 Messages Tab
- Chat list (WhatsApp-style) sorted by recent
- Each row: Avatar, Name, Last message preview, Timestamp, Unread badge
- Tap → Full chat screen (text, image, file, voice note)
- Chat bubbles: Sent (right, blue), Received (left, grey)
- Message status: Sent ✓, Delivered ✓✓, Read ✓✓ (blue)

#### 👤 Profile Tab
- User avatar (editable)
- Display name
- IntraCom Number (read-only, copyable)
- District badge
- Settings: Notifications, Privacy, Theme (Dark/Light), Account, About

#### 🏠 Hangout Tab (Discord-style Voice Channels)
```
┌─────────────────────────────┐
│  🏠 Hangouts                │
│                             │
│  ┌───────────────────────┐  │
│  │ 🎙️ Developers Hub      │  │
│  │ 👤 Zim (speaking 🔊)  │  │
│  │ 👤 Rafiq               │  │
│  │ 👤 Karim (muted 🔇)   │  │
│  │ [+ Invite]  [🔊 Join] │  │
│  └───────────────────────┘  │
│                             │
│  ┌───────────────────────┐  │
│  │ 🎙️ Gaming Lounge       │  │
│  │ 👤 Sakib (speaking 🔊)│  │
│  │ 👤 Tanvir             │  │
│  │ [+ Invite]  [🔊 Join] │  │
│  └───────────────────────┘  │
│                             │
│  ( + Create New Hangout )   │
└─────────────────────────────┘
```

**Hangout Features:**
- Create a Hangout hub (name, description, optional password)
- Invite users by IntraCom number
- Join/Leave voice channel freely (like Discord)
- Mute/Unmute self
- Speaker indicator (voice activity detection)
- Hub owner can: kick, mute others, delete hub
- Persistent hubs (stay alive even when empty)
- Optional: Screen share in hangout

---

## 6. Backend Architecture Detail

### 6.1 REST API Endpoints

```
Auth & Registration:
  POST   /api/v1/auth/register          → Register (name, phone, district, password, optional email)
  POST   /api/v1/auth/verify-otp        → Verify OTP
  POST   /api/v1/auth/login             → Login → JWT token pair
  POST   /api/v1/auth/refresh           → Refresh access token
  POST   /api/v1/auth/logout            → Invalidate session

User:
  GET    /api/v1/users/me               → Get own profile
  PUT    /api/v1/users/me               → Update profile (name, avatar)
  GET    /api/v1/users/:number          → Lookup user by IntraCom number
  PUT    /api/v1/users/me/avatar        → Upload avatar image

Contacts:
  GET    /api/v1/contacts               → List contacts
  POST   /api/v1/contacts               → Add contact by IntraCom number
  DELETE /api/v1/contacts/:id           → Remove contact
  GET    /api/v1/contacts/search?q=     → Search contacts

Messages:
  GET    /api/v1/conversations                     → List conversations
  GET    /api/v1/conversations/:id/messages        → Get messages (paginated)
  POST   /api/v1/conversations/:id/messages        → Send message
  PUT    /api/v1/conversations/:id/messages/:mid   → Edit message
  DELETE /api/v1/conversations/:id/messages/:mid   → Delete message
  POST   /api/v1/conversations/:id/media           → Upload media attachment

Call History:
  GET    /api/v1/calls/history          → Recent calls
  GET    /api/v1/calls/:id              → Call detail

Hangouts:
  GET    /api/v1/hangouts               → List hangouts
  POST   /api/v1/hangouts               → Create hangout hub
  GET    /api/v1/hangouts/:id           → Get hangout details & participants
  PUT    /api/v1/hangouts/:id           → Update hangout (name, description)
  DELETE /api/v1/hangouts/:id           → Delete hangout
  POST   /api/v1/hangouts/:id/invite    → Invite user
  POST   /api/v1/hangouts/:id/join      → Join hangout
  POST   /api/v1/hangouts/:id/leave     → Leave hangout
  POST   /api/v1/hangouts/:id/kick      → Kick participant (owner only)
```

### 6.2 WebSocket Signaling Protocol

The WebSocket server at `wss://intracom.server/ws` handles all real-time events:

```json
// === Connection & Presence ===
{ "type": "auth", "token": "jwt..." }
{ "type": "presence", "status": "online|away|offline" }
{ "type": "user_status", "number": "+1-3847291", "status": "online" }

// === 1:1 Calling (Audio/Video) ===
{ "type": "call_offer",   "to": "+2-1000001", "sdp": "...", "callType": "audio|video" }
{ "type": "call_answer",  "to": "+1-3847291", "sdp": "..." }
{ "type": "call_ice",     "to": "+2-1000001", "candidate": { ... } }
{ "type": "call_reject",  "to": "+1-3847291" }
{ "type": "call_hangup",  "to": "+2-1000001" }
{ "type": "call_ringing", "to": "+1-3847291" }

// === Messaging (Real-time delivery) ===
{ "type": "message",    "conversationId": "...", "text": "...", "mediaUrl": "..." }
{ "type": "typing",     "conversationId": "...", "isTyping": true }
{ "type": "msg_status", "messageId": "...", "status": "delivered|read" }

// === Hangout (Voice Room) ===
{ "type": "hangout_join",    "hangoutId": "...", "sdp": "..." }
{ "type": "hangout_leave",   "hangoutId": "..." }
{ "type": "hangout_offer",   "hangoutId": "...", "participantId": "...", "sdp": "..." }
{ "type": "hangout_answer",  "hangoutId": "...", "participantId": "...", "sdp": "..." }
{ "type": "hangout_ice",     "hangoutId": "...", "participantId": "...", "candidate": {} }
{ "type": "hangout_mute",    "hangoutId": "...", "muted": true }
{ "type": "hangout_speaking","hangoutId": "...", "participantId": "...", "level": 0.7 }
```

### 6.3 Call Flow (1:1 Audio/Video)

```mermaid
sequenceDiagram
    participant A as 📱 Caller (+1-3847291)
    participant S as 🔌 Signaling Server
    participant T as 🔄 TURN/STUN (coturn)
    participant B as 📱 Receiver (+2-1000001)

    A->>S: call_offer (SDP + callType)
    S->>B: call_offer (push notification if offline)
    B->>S: call_ringing
    S->>A: call_ringing (shows "Ringing...")

    Note over B: User taps Accept

    B->>S: call_answer (SDP)
    S->>A: call_answer (SDP)

    A->>T: ICE candidate gathering
    B->>T: ICE candidate gathering
    A->>S: call_ice (candidates)
    S->>B: call_ice (candidates)
    B->>S: call_ice (candidates)
    S->>A: call_ice (candidates)

    Note over A,B: 🔒 DTLS/SRTP P2P Media Stream Established

    A<-->B: Encrypted Audio/Video (direct P2P or via TURN relay)

    A->>S: call_hangup
    S->>B: call_hangup
```

### 6.4 Hangout (Group Voice Room) Flow

```mermaid
sequenceDiagram
    participant U1 as 👤 User 1
    participant SFU as 🎬 Pion SFU
    participant U2 as 👤 User 2
    participant U3 as 👤 User 3

    U1->>SFU: Join Hangout (publish audio track)
    SFU->>U1: OK (room state: empty)

    U2->>SFU: Join Hangout (publish audio track)
    SFU->>U1: New participant (subscribe to U2's audio)
    SFU->>U2: Existing participant (subscribe to U1's audio)

    U3->>SFU: Join Hangout (publish audio track)
    SFU->>U1: New participant (subscribe to U3's audio)
    SFU->>U2: New participant (subscribe to U3's audio)
    SFU->>U3: Existing participants (subscribe to U1 & U2 audio)

    Note over U1,U3: All participants hear each other via SFU relay

    U2->>SFU: Mute
    SFU->>U1: U2 muted
    SFU->>U3: U2 muted

    U2->>SFU: Leave Hangout
    SFU->>U1: U2 left
    SFU->>U3: U2 left
```

> [!NOTE]
> **SFU (Selective Forwarding Unit)** is used for Hangouts instead of P2P mesh. In P2P mesh, each participant would need to send their audio to every other participant (N×N connections). With SFU, each participant sends audio once to the server, and the server forwards it to everyone else — much more efficient for group calls.

---

## 7. Database Schema

```mermaid
erDiagram
    USERS {
        uuid id PK
        varchar area_code "District code (1-64)"
        varchar user_number "7-digit unique ID"
        varchar full_number "'+area_code-user_number' (unique, indexed)"
        varchar display_name
        varchar email "unique"
        varchar phone "unique, for OTP"
        varchar password_hash "Argon2id"
        varchar avatar_url
        varchar district_name
        varchar fcm_token "Push notifications"
        varchar apns_token "iOS push"
        timestamp last_seen
        varchar status "online, away, offline"
        timestamp created_at
        timestamp updated_at
    }

    CONTACTS {
        uuid id PK
        uuid owner_id FK
        uuid contact_user_id FK
        varchar nickname "optional custom name"
        boolean is_blocked
        timestamp created_at
    }

    CONVERSATIONS {
        uuid id PK
        varchar type "direct, group"
        timestamp last_message_at
        timestamp created_at
    }

    CONVERSATION_MEMBERS {
        uuid conversation_id FK
        uuid user_id FK
        timestamp joined_at
        timestamp last_read_at
    }

    MESSAGES {
        uuid id PK
        uuid conversation_id FK
        uuid sender_id FK
        varchar content_type "text, image, file, voice_note, system"
        text content "text content or media URL"
        varchar media_url "MinIO object path"
        varchar status "sent, delivered, read"
        uuid reply_to "optional, for reply threading"
        boolean is_edited
        boolean is_deleted
        timestamp created_at
        timestamp updated_at
    }

    CALL_HISTORY {
        uuid id PK
        uuid caller_id FK
        uuid receiver_id FK
        varchar call_type "audio, video"
        varchar status "completed, missed, rejected, no_answer"
        integer duration_seconds
        timestamp started_at
        timestamp ended_at
    }

    HANGOUTS {
        uuid id PK
        uuid owner_id FK
        varchar name
        varchar description
        varchar password_hash "optional, for private hangouts"
        boolean is_persistent "stays alive when empty"
        integer max_participants "default 25"
        timestamp created_at
    }

    HANGOUT_MEMBERS {
        uuid hangout_id FK
        uuid user_id FK
        varchar role "owner, moderator, member"
        boolean is_muted
        boolean is_active "currently in voice channel"
        timestamp joined_at
    }

    USERS ||--o{ CONTACTS : "has"
    USERS ||--o{ CONVERSATION_MEMBERS : "participates"
    CONVERSATIONS ||--o{ CONVERSATION_MEMBERS : "has"
    CONVERSATIONS ||--o{ MESSAGES : "contains"
    USERS ||--o{ MESSAGES : "sends"
    USERS ||--o{ CALL_HISTORY : "caller"
    USERS ||--o{ CALL_HISTORY : "receiver"
    USERS ||--o{ HANGOUTS : "owns"
    HANGOUTS ||--o{ HANGOUT_MEMBERS : "has"
    USERS ||--o{ HANGOUT_MEMBERS : "joins"
```

---

## 8. Project Structure

### 8.1 Backend (Go)

```
intracom-server/
├── cmd/
│   └── server/
│       └── main.go                  # Entry point
├── internal/
│   ├── config/
│   │   └── config.go                # Env-based configuration
│   ├── auth/
│   │   ├── handler.go               # Register, Login, OTP
│   │   ├── jwt.go                   # JWT token generation/validation
│   │   └── middleware.go            # Auth middleware
│   ├── user/
│   │   ├── handler.go               # User CRUD
│   │   ├── model.go                 # User model
│   │   ├── repository.go            # DB queries
│   │   └── service.go               # Business logic
│   ├── contact/
│   │   ├── handler.go
│   │   ├── model.go
│   │   └── repository.go
│   ├── messaging/
│   │   ├── handler.go               # REST endpoints for messages
│   │   ├── model.go
│   │   ├── repository.go
│   │   └── service.go               # Message delivery logic
│   ├── calling/
│   │   ├── signaling.go             # WebSocket call signaling
│   │   ├── call_state.go            # In-memory call state (Redis-backed)
│   │   └── history.go               # Call history recording
│   ├── hangout/
│   │   ├── handler.go               # REST CRUD for hangouts
│   │   ├── model.go
│   │   ├── repository.go
│   │   ├── sfu.go                   # Pion SFU room management
│   │   └── service.go
│   ├── websocket/
│   │   ├── hub.go                   # Connection manager (all online users)
│   │   ├── client.go                # Per-connection handler
│   │   └── protocol.go             # Message type definitions
│   ├── media/
│   │   └── storage.go               # MinIO upload/download
│   ├── notification/
│   │   ├── fcm.go                   # Firebase Cloud Messaging
│   │   └── apns.go                  # Apple Push Notification Service
│   └── numbering/
│       ├── districts.go             # District code registry (1-64)
│       └── generator.go            # Unique 7-digit ID generation
├── migrations/
│   ├── 001_create_users.sql
│   ├── 002_create_contacts.sql
│   ├── 003_create_conversations.sql
│   ├── 004_create_messages.sql
│   ├── 005_create_call_history.sql
│   └── 006_create_hangouts.sql
├── go.mod
├── go.sum
├── Dockerfile
└── docker-compose.yml
```

### 8.2 Flutter App

```
intracom_app/
├── lib/
│   ├── main.dart
│   ├── app.dart                           # MaterialApp + Router
│   ├── config/
│   │   ├── theme.dart                     # iOS-style theme (dark/light)
│   │   ├── constants.dart                 # API URLs, etc.
│   │   └── routes.dart                    # GoRouter setup
│   ├── core/
│   │   ├── network/
│   │   │   ├── api_client.dart            # Dio HTTP client
│   │   │   ├── websocket_client.dart      # WS connection manager
│   │   │   └── interceptors.dart          # Auth token interceptor
│   │   ├── auth/
│   │   │   ├── auth_provider.dart         # Riverpod auth state
│   │   │   └── auth_service.dart
│   │   └── local_db/
│   │       └── database.dart              # Drift (SQLite) for offline cache
│   ├── features/
│   │   ├── contacts/
│   │   │   ├── screens/
│   │   │   │   ├── contacts_screen.dart   # Contact list
│   │   │   │   └── contact_detail.dart    # Contact detail + actions
│   │   │   ├── providers/
│   │   │   │   └── contacts_provider.dart
│   │   │   └── widgets/
│   │   │       └── contact_tile.dart
│   │   ├── dialer/
│   │   │   ├── screens/
│   │   │   │   └── dialer_screen.dart     # T9 dialer + recent calls
│   │   │   ├── providers/
│   │   │   │   └── call_history_provider.dart
│   │   │   └── widgets/
│   │   │       ├── dial_pad.dart          # Number pad widget
│   │   │       └── recent_call_tile.dart
│   │   ├── calling/
│   │   │   ├── screens/
│   │   │   │   ├── incoming_call.dart     # Incoming call screen (full screen)
│   │   │   │   ├── outgoing_call.dart     # Outgoing call screen
│   │   │   │   └── in_call_screen.dart    # Active call (mute, speaker, hangup)
│   │   │   ├── providers/
│   │   │   │   └── call_provider.dart     # WebRTC call state
│   │   │   ├── services/
│   │   │   │   ├── webrtc_service.dart    # WebRTC peer connection manager
│   │   │   │   └── call_service.dart      # Call signaling logic
│   │   │   └── widgets/
│   │   │       └── call_controls.dart     # Mute, speaker, video toggle, hangup
│   │   ├── messages/
│   │   │   ├── screens/
│   │   │   │   ├── conversations_screen.dart  # Chat list
│   │   │   │   └── chat_screen.dart           # Individual chat
│   │   │   ├── providers/
│   │   │   │   ├── conversations_provider.dart
│   │   │   │   └── chat_provider.dart
│   │   │   └── widgets/
│   │   │       ├── message_bubble.dart
│   │   │       ├── chat_input.dart
│   │   │       └── conversation_tile.dart
│   │   ├── hangout/
│   │   │   ├── screens/
│   │   │   │   ├── hangouts_screen.dart       # List of hangout hubs
│   │   │   │   ├── hangout_room.dart          # Inside a hangout (voice room)
│   │   │   │   └── create_hangout.dart        # Create new hangout
│   │   │   ├── providers/
│   │   │   │   └── hangout_provider.dart
│   │   │   └── widgets/
│   │   │       ├── hangout_card.dart
│   │   │       └── participant_tile.dart
│   │   └── profile/
│   │       ├── screens/
│   │       │   ├── profile_screen.dart
│   │       │   └── settings_screen.dart
│   │       └── providers/
│   │           └── profile_provider.dart
│   └── shared/
│       ├── widgets/
│       │   ├── bottom_nav_bar.dart             # 5-tab navigation
│       │   ├── avatar.dart
│       │   └── loading.dart
│       └── models/
│           ├── user.dart
│           ├── message.dart
│           ├── call_record.dart
│           └── hangout.dart
├── assets/
│   ├── sounds/
│   │   ├── ringtone.mp3
│   │   ├── dial_tone.mp3
│   │   └── hangup.mp3
│   └── images/
│       └── logo.png
├── android/
├── ios/
├── windows/
├── macos/
├── pubspec.yaml
└── analysis_options.yaml
```

---

## 9. Oracle Cloud Deployment

### 9.1 Infrastructure Requirements

| Resource | Specification | Purpose |
|----------|--------------|---------|
| **Compute Instance** | ARM Ampere A1 (4 OCPU, 24 GB RAM) | Main server — API, WS, SFU, DB |
| **Block Storage** | 200 GB | PostgreSQL data + MinIO media |
| **Public IP** | 1 reserved elastic IP | Stable server address |
| **Domain** | `intracom.app` (or similar) | TLS/SSL with Caddy auto-cert |

> [!TIP]
> Oracle Cloud's **Always Free Tier** includes 4 ARM Ampere A1 OCPUs + 24 GB RAM + 200 GB storage — enough to run the entire IntraCom backend for free during development and early production.

### 9.2 Ports to Open (Oracle Cloud Security List + iptables)

| Port | Protocol | Service |
|------|----------|---------|
| 443 | TCP | HTTPS (Caddy reverse proxy) |
| 80 | TCP | HTTP → redirect to HTTPS |
| 3478 | TCP+UDP | STUN/TURN (coturn) |
| 5349 | TCP | TURNS (TLS TURN) |
| 49152-65535 | UDP | TURN relay media range |

### 9.3 Docker Compose Layout

```yaml
version: "3.9"
services:
  caddy:
    image: caddy:2-alpine
    ports: ["80:80", "443:443"]
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data

  api:
    build: ./intracom-server
    environment:
      - DATABASE_URL=postgres://intracom:password@postgres:5432/intracom
      - REDIS_URL=redis://redis:6379
      - MINIO_ENDPOINT=minio:9000
      - JWT_SECRET=${JWT_SECRET}
    depends_on: [postgres, redis, minio]

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: intracom
      POSTGRES_USER: intracom
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    command: redis-server --requirepass ${REDIS_PASSWORD}

  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_USER}
      MINIO_ROOT_PASSWORD: ${MINIO_PASSWORD}
    volumes:
      - minio_data:/data

  coturn:
    image: coturn/coturn:latest
    network_mode: host
    volumes:
      - ./turnserver.conf:/etc/coturn/turnserver.conf

volumes:
  pgdata:
  minio_data:
  caddy_data:
```

---

## 10. Security Design

| Aspect | Implementation |
|--------|---------------|
| **Transport** | TLS 1.3 everywhere (Caddy auto-cert via Let's Encrypt) |
| **Media Encryption** | DTLS-SRTP (WebRTC default — all media encrypted end-to-end) |
| **Authentication** | JWT access tokens (15 min) + refresh tokens (30 days, stored in DB) |
| **Password Storage** | Argon2id hashing |
| **API Security** | Rate limiting (100 req/min per user), CORS, input validation |
| **WebSocket Auth** | First message must be `auth` with valid JWT, else disconnected |
| **Message Privacy** | Messages stored encrypted at rest (AES-256-GCM) |
| **File Uploads** | Pre-signed URLs from MinIO, virus scan on upload, file type whitelist |

---

## 11. Development Phases & Timeline

### Phase 1: Foundation (Week 1-2) 🔨
- [ ] Set up Oracle Cloud instance (new ARM instance)
- [ ] Docker Compose with PostgreSQL, Redis, MinIO, Caddy
- [ ] Go backend scaffold (Fiber + project structure)
- [ ] Database migrations
- [ ] Auth system (register, OTP, login, JWT)
- [ ] District-based numbering engine
- [ ] Flutter app scaffold with bottom navigation

### Phase 2: Contacts & Messaging (Week 3-4) 💬
- [ ] User lookup by IntraCom number
- [ ] Contacts CRUD
- [ ] WebSocket connection manager
- [ ] Real-time messaging (send, receive, delivery receipts)
- [ ] Offline message queue (deliver when user comes online)
- [ ] Media upload (images, files, voice notes)
- [ ] Chat UI (bubbles, timestamps, status indicators)
- [ ] Push notifications (FCM/APNs) for offline users

### Phase 3: Audio & Video Calling (Week 5-6) 📞
- [ ] WebRTC signaling via WebSocket
- [ ] coturn STUN/TURN deployment
- [ ] 1:1 audio calling (offer/answer/ICE)
- [ ] 1:1 video calling
- [ ] Call UI (incoming screen, in-call controls, dial pad)
- [ ] Call history recording
- [ ] Ringtone & call sounds
- [ ] iOS CallKit / Android ConnectionService integration

### Phase 4: Hangouts — Voice Rooms (Week 7-8) 🏠
- [ ] Pion SFU setup for multi-party audio
- [ ] Hangout CRUD (create, invite, join, leave)
- [ ] SFU room management (publish/subscribe tracks)
- [ ] Voice Activity Detection (VAD) indicators
- [ ] Mute/unmute, kick, moderator controls
- [ ] Hangout UI (participant list, speaking indicators)
- [ ] Persistent rooms (survive when empty)

### Phase 5: Polish & Launch (Week 9-10) 🚀
- [ ] iPhone-style dialer UI polish
- [ ] Dark/Light theme
- [ ] End-to-end encryption for messages (Signal Protocol, optional)
- [ ] Offline support (cached messages, contacts in SQLite)
- [ ] Performance optimization (lazy loading, pagination)
- [ ] Platform builds: Android APK, iOS IPA, Windows MSIX, macOS DMG
- [ ] Stress testing (100+ concurrent users)
- [ ] Production deployment with monitoring (Grafana + Prometheus)

---

## 12. Key Design Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Backend language | **Go** | Native concurrency (goroutines), Pion WebRTC SFU is Go-native, tiny Docker images |
| Frontend framework | **Flutter** | Single codebase for 4 platforms, great performance, rich UI |
| SFU for group calls | **Pion WebRTC** | Pure Go, fully self-hosted, battle-tested open-source |
| No external services | ✅ | Complete data sovereignty — everything on your Oracle Cloud |
| Numbering system | +Code-7digits | Familiar phone-number UX, district identity, 640M capacity |
| Protocol | WebRTC (open standard) | Built into OS, encrypted by default, P2P when possible |

> [!CAUTION]
> **FCM (Firebase Cloud Messaging) and APNs are the only external dependencies** — Android and iOS require their respective push notification services to wake the app for incoming calls when it's in the background. There is no way around this on mobile. All other communication is 100% self-hosted.
