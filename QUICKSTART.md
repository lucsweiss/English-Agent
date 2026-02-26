# Quick Start - Adding Backend to Xcode

The backend server has been built! Now follow these steps to complete your standalone app.

## Step 1: Add the Server Executable to Xcode

1. **Open your Xcode project:**
   ```
   frontend/EnglishAgent/EnglishAgent.xcodeproj
   ```

2. **Add the server file:**
   - In Xcode's Project Navigator (left sidebar), right-click on the "EnglishAgent" folder
   - Select "Add Files to EnglishAgent..."
   - Navigate to: `backend/dist/english-agent-server`
   - **IMPORTANT:** Check the box "Copy items if needed"
   - Click "Add"

3. **Verify it's in the bundle:**
   - Click on your project name at the top of the navigator
   - Select the "EnglishAgent" target
   - Go to "Build Phases" tab
   - Expand "Copy Bundle Resources"
   - Verify `english-agent-server` is listed there
   - If not, click the "+" button and add it

## Step 2: Add the .env File (For Development)

For development testing, add your .env file:

1. In Xcode, right-click on "EnglishAgent" folder
2. Select "Add Files to EnglishAgent..."
3. Navigate to: `backend/.env`
4. **Check:** "Copy items if needed"
5. Click "Add"
6. Verify it's in "Copy Bundle Resources"

**Important:** For production distribution, DON'T bundle your API key! The app will create a template .env file in `~/Library/Application Support/EnglishAgent/` where users can add their own key.

## Step 3: Build and Run

1. In Xcode, select `Product → Build` (⌘B)
2. Select `Product → Run` (⌘R)

The app should:
- Launch automatically
- Start the backend server in the background
- Show the menu bar icon
- Be ready to translate!

## Step 4: Test It

1. Open any application (Safari, Notes, etc.)
2. Select some text in another language
3. Press **⌘⇧T**
4. See the translation appear in the floating panel!

## Verifying the Server is Running

Check the debug log to see if everything is working:

```bash
tail -f /tmp/EnglishAgent_debug.log
```

You should see:
```
[BackendServer] Server process started (PID: ...)
[BackendServer] ✓ Server is ready and healthy
```

## Troubleshooting

### "Server not found" error

The app can't find the bundled server. Make sure:
- `english-agent-server` is in "Copy Bundle Resources" (Build Phases)
- You did a clean build (Product → Clean Build Folder)

### "Server failed to start" error

Check `/tmp/EnglishAgent_debug.log` for details. Common issues:
- Port 8000 already in use (stop other servers)
- Missing .env file (add your OpenRouter API key)

### Translation fails with API error

Verify your API key:
```bash
# If using bundled .env:
cat backend/.env

# If app created the template:
cat ~/Library/Application\ Support/EnglishAgent/.env
```

Make sure `OPENROUTER_API_KEY` is set to your actual API key.

## What's New?

Your app now includes:

1. **BackendServerManager.swift** - Automatically manages the Python server
2. **Bundled backend** - No need to manually start the server
3. **Darker panel** - Transparent black background instead of gray
4. **Updated AppDelegate** - Starts/stops server on launch/quit

## Building for Distribution

When you're ready to share your app:

1. **Archive the app:**
   - Product → Archive
   - This creates a signed, distributable build

2. **Export:**
   - Window → Organizer
   - Select your archive
   - Click "Distribute App"
   - Choose "Developer ID" for distribution outside App Store

See `DEPLOYMENT.md` for complete distribution instructions including code signing and notarization.

## Next Steps

Your app is now standalone! You can:

1. Copy it to `/Applications`
2. Quit Xcode
3. Launch the app from Applications
4. It works without any terminal commands!

## File Structure

Your completed project now looks like this:

```
EnglishAgent.app/
├── Contents/
│   ├── MacOS/
│   │   └── EnglishAgent              # Swift app
│   └── Resources/
│       ├── english-agent-server      # Python backend (bundled!)
│       ├── .env                      # API config (dev mode)
│       └── ... (other resources)
```

When the app runs:
- Swift launches the `english-agent-server` subprocess
- Server runs on `localhost:8000`
- App communicates with local server
- Translation happens entirely on your Mac
- No external services except OpenRouter API

---

**Congratulations!** You now have a professional, standalone macOS app. 🎉
