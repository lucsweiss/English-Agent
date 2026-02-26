# Deployment Guide - English Agent App

This guide explains how to build and deploy the English Agent app as a standalone macOS application with the Python backend bundled inside.

## Prerequisites

- macOS 13.0 or later
- Xcode 14.0 or later
- Python 3.9 or later
- OpenRouter API key

## Building the Standalone App

### Step 1: Build the Backend Server

The backend needs to be compiled into a standalone executable first:

```bash
cd backend

# Create virtual environment if not exists
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Build the server executable
./build_server.sh
```

This creates `backend/dist/english-agent-server` - a standalone executable containing the entire Python backend.

### Step 2: Add Backend to Xcode Project

1. Open `frontend/EnglishAgent/EnglishAgent.xcodeproj` in Xcode
2. Right-click on the `EnglishAgent` folder in the navigator
3. Select "Add Files to EnglishAgent"
4. Navigate to `backend/dist/english-agent-server`
5. **Important:** Check "Copy items if needed"
6. Click "Add"
7. Select the file in the project navigator
8. In File Inspector (right panel), verify it's checked under "Target Membership" for EnglishAgent
9. Go to Build Phases → Copy Bundle Resources
10. Verify `english-agent-server` is listed there

### Step 3: Add Environment File

Your `.env` file needs to be included in the app bundle:

1. In Xcode, right-click on `EnglishAgent` folder
2. Select "Add Files to EnglishAgent"
3. Navigate to `backend/.env`
4. **Important:** Check "Copy items if needed"
5. Click "Add"
6. Verify it appears in Build Phases → Copy Bundle Resources

**Security Note:** For production distribution, you should NOT bundle the `.env` file with your API key. Instead:
- The app will create a template `.env` in `~/Library/Application Support/EnglishAgent/`
- Users should add their own API key there
- See "Production Distribution" section below

### Step 4: Build the App

In Xcode:
1. Select `Product → Build` (⌘B)
2. Or select `Product → Archive` for distribution

The compiled app will be at:
```
~/Library/Developer/Xcode/DerivedData/EnglishAgent-*/Build/Products/Debug/EnglishAgent.app
```

### Step 5: Test the Standalone App

1. Quit any running instance of English Agent
2. Locate the `.app` in Finder
3. Double-click to launch
4. Check `/tmp/EnglishAgent_debug.log` to verify the server started:
   ```bash
   tail -f /tmp/EnglishAgent_debug.log
   ```
5. Look for:
   ```
   [BackendServer] Server process started
   [BackendServer] ✓ Server is ready and healthy
   ```
6. Try translating some text with ⌘⇧T

## Production Distribution

### Option 1: Manual Distribution

1. Build the app in Xcode
2. Copy `EnglishAgent.app` to `/Applications`
3. First-time users need to:
   - Right-click → Open (to bypass Gatekeeper)
   - Grant Accessibility permissions
   - Add their API key to `~/Library/Application Support/EnglishAgent/.env`

### Option 2: Code Signing & Notarization (Recommended)

For proper distribution outside the Mac App Store:

1. **Get Apple Developer Account** ($99/year)

2. **Configure Code Signing in Xcode:**
   - Select project in navigator
   - Go to Signing & Capabilities
   - Select your Team
   - Enable "Automatically manage signing"

3. **Create Archive:**
   ```bash
   xcodebuild -project frontend/EnglishAgent/EnglishAgent.xcodeproj \
              -scheme EnglishAgent \
              -configuration Release \
              clean archive \
              -archivePath EnglishAgent.xcarchive
   ```

4. **Export for Distribution:**
   - In Xcode: Window → Organizer
   - Select the archive
   - Click "Distribute App"
   - Choose "Developer ID"
   - Follow the notarization steps

5. **Create DMG (Optional):**
   ```bash
   # Install create-dmg
   brew install create-dmg

   # Create DMG
   create-dmg \
     --volname "English Agent" \
     --window-pos 200 120 \
     --window-size 600 400 \
     --icon-size 100 \
     --app-drop-link 450 150 \
     "EnglishAgent.dmg" \
     "EnglishAgent.app"
   ```

## Architecture

### App Structure
```
EnglishAgent.app/
├── Contents/
│   ├── MacOS/
│   │   └── EnglishAgent           # Swift executable
│   └── Resources/
│       ├── english-agent-server   # Python backend (bundled)
│       └── .env                   # API configuration (dev only)
```

### Runtime Behavior

1. **App Launch:**
   - Swift app starts
   - `BackendServerManager` locates bundled server
   - Copies `.env` to `~/Library/Application Support/EnglishAgent/`
   - Launches server subprocess on `http://127.0.0.1:8000`
   - Waits for `/health` endpoint to respond

2. **Translation:**
   - User presses ⌘⇧T
   - App captures selected text
   - Sends to local server at `localhost:8000/translate`
   - Server calls OpenRouter API
   - Response displayed in floating panel

3. **App Quit:**
   - `applicationWillTerminate` triggered
   - Server process terminated gracefully
   - Cleanup complete

### Backend Server Details

The bundled `english-agent-server` is a PyInstaller executable containing:
- FastAPI application
- Uvicorn ASGI server
- All Python dependencies (httpx, pydantic, etc.)
- Runs independently, doesn't need system Python

## Troubleshooting

### Server Won't Start

Check the debug log:
```bash
tail -f /tmp/EnglishAgent_debug.log
```

Common issues:
- **Port 8000 already in use:** Another service is using that port
  - Solution: Change port in `BackendServerManager.swift` and rebuild
- **Missing executable:** Server not bundled correctly
  - Solution: Rebuild backend and re-add to Xcode
- **Missing .env:** API key not configured
  - Solution: Create `~/Library/Application Support/EnglishAgent/.env`

### Translation Not Working

1. Check server is running:
   ```bash
   curl http://localhost:8000/health
   ```
   Should return: `{"status":"healthy"}`

2. Test translation endpoint:
   ```bash
   curl -X POST http://localhost:8000/translate \
     -H "Content-Type: application/json" \
     -d '{"text":"Bonjour"}'
   ```

3. Verify API key in:
   ```bash
   cat ~/Library/Application\ Support/EnglishAgent/.env
   ```

### Accessibility Not Working

1. Go to System Settings → Privacy & Security → Accessibility
2. Find "EnglishAgent" in the list
3. Toggle it off and on
4. Restart the app

## Development vs Production

### Development Mode
- Server executable at: `backend/dist/english-agent-server`
- `.env` in `backend/` directory
- Manual server start for testing

### Production Mode (Bundled)
- Server in app bundle: `EnglishAgent.app/Contents/Resources/`
- `.env` in: `~/Library/Application Support/EnglishAgent/.env`
- Auto-start when app launches

## Updating the App

When you make changes:

1. **Backend changes:**
   ```bash
   cd backend
   ./build_server.sh
   # In Xcode: delete old server, add new one
   ```

2. **Frontend changes:**
   - Just rebuild in Xcode

3. **Full rebuild:**
   ```bash
   cd backend && ./build_server.sh
   cd ../frontend/EnglishAgent
   xcodebuild clean build
   ```

## Security Considerations

- **Never commit `.env` with real API keys**
- For distribution, bundle a template `.env` with placeholder
- Consider implementing in-app API key management
- Store API keys in macOS Keychain (future enhancement)
- Sign your app with Developer ID to avoid Gatekeeper warnings

## Support

For issues, check:
1. `/tmp/EnglishAgent_debug.log` - detailed logging
2. Console.app - system logs
3. Xcode debugger output during development
