# SCADA System (Flutter)

A comprehensive SCADA (Supervisory Control and Data Acquisition) application built with Flutter and Riverpod state management.

## Features

### 🎛️ Widgets (21 types)
- **Indicators**: Gauge, Level, Temperature, Pressure, Digital Display, Text Display
- **Controls**: Switch, Slider, Relay Output, LED, Status Indicator
- **Vessels & Equipment**: Vertical Tank, Horizontal Tank, Fan (animated), Motor
- **Valves**: Gate Valve (open/closed/partial/unknown states), Control Valve
- **Charts & Bars**: Graph (line chart), Chart (bar chart), Vertical Bar, Horizontal Bar

All widgets are rendered using Flutter's `CustomPainter` and wrapped in `RepaintBoundary` for optimal performance.

### 🎨 Designer
- Drag & drop widgets from palette onto canvas
- Move widgets by dragging
- 8-directional resize handles (corners + edges)
- Property panel with 4 tabs:
  - **General**: label, unit, position, size, min/max, zero/span/offset/multiplier, state
  - **Data**: protocol selection (MQTT / Modbus TCP / Simulation) with full parameter config
  - **Alarm**: enable/disable, high/low/HH/LL thresholds, configurable colors
  - **Style**: primary/secondary/background/text/active/inactive colors, animation
- Copy and delete selected widget
- Toggle design/view mode
- 5 themes

### 🚨 Alarm System
- Configurable high/low thresholds per widget
- Color changes when threshold exceeded
- Real-time alarm detection
- Alarm panel with acknowledge functionality
- Local + server-side alarm logging

### 📡 Data Sources
- **MQTT**: broker, topic, port
- **Modbus TCP**: host, port, unit ID, register, register type
- **Simulation**: built-in simulated data
- Connection status indicator per widget
- Poll interval configuration

### 🔐 Authentication & Authorization
- Register/Login with JWT
- Three roles: Viewer, Designer, Admin
- Admin panel for user management
- Session persistence with SharedPreferences

### 📄 Pages
- Browse pages with visual cards
- Create, edit, delete pages
- Save/load from backend
- Background color/image support
- Real-time server time and connection status

## Architecture

```
lib/
├── main.dart              # App entry, session restore
├── config/
│   └── app_config.dart    # Configuration constants
├── models/
│   ├── enums.dart         # All enums
│   ├── widget_model.dart  # ScadaWidget model
│   ├── page_model.dart    # ScadaPage, PageSummary
│   ├── user_model.dart    # User, AuthResponse
│   └── alarm_model.dart   # AlarmLog
├── providers/
│   └── providers.dart     # Riverpod providers
├── services/
│   ├── api_service.dart   # REST API client (Dio)
│   └── data_service.dart  # Data simulation
├── widgets/
│   ├── painters.dart      # All CustomPainters
│   └── widget_view.dart   # Widget wrapper with RepaintBoundary
├── screens/
│   ├── auth_screen.dart       # Login/Register
│   ├── pages_screen.dart      # Page browser + Admin dialog
│   ├── workspace.dart         # Main designer/viewer
│   ├── widget_palette.dart    # Widget palette (draggable)
│   ├── property_panel.dart    # Property editor
│   └── alarm_panel.dart       # Alarm log panel
└── utils/
    └── constants.dart     # Units, themes, color utils
```

## Getting Started

1. Install Flutter (3.2.0+)
2. Configure backend URL in `lib/config/app_config.dart`
3. Run:
   ```bash
   flutter pub get
   flutter run
   ```

## Backend

The app connects to a Node.js backend with the following endpoints:
- POST /api/auth/login
- POST /api/auth/register
- GET /api/auth/me
- GET /api/pages
- POST /api/pages
- GET /api/pages/:id
- PUT /api/pages/:id
- DELETE /api/pages/:id
- GET /api/alarms
- POST /api/alarms
- POST /api/alarms/acknowledge
- GET /api/admin/users
- PUT /api/admin/users

## Deployment

- **Web**: `flutter build web`
- **Windows**: `flutter build windows`
- **Android**: `flutter build apk`
- **iOS**: `flutter build ios`
- **macOS**: `flutter build macos`
- **Linux**: `flutter build linux`

## Requirements

The platform requires a running SCADA backend server. See the Next.js backend in the parent directory.
