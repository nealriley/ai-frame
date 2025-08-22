Absolutely — here’s a fully expanded version of your instructions with the following structure:

* **Stated Aim**
* **Outcome**
* **Expectations**
* **Encouraged Creativity**
* **Immovable Requirements**

---

### 📌 **Stated Aim**

The goal is to create a WebXR capture system that:
1. Captures video frames, canvas renders, audio, and text input from AR/VR devices
2. Provides visible triggers/shortcuts accessible in immersive mode
3. Sends captured media to a configurable API endpoint
4. Later: Polls for and renders AR objects that users can interact with

This system bridges the gap between immersive experiences and AI processing, allowing users to capture their AR/VR environment and receive AI-generated content back as interactive 3D objects.

---

### ✅ **Expected Outcome**

By the end of this exercise, you should be able to:

1. **Initialize** a clean working environment (e.g. in `tmux`, GitHub Codespaces, or your IDE of choice).
2. **Configure** the necessary CLI tools, runtimes, and APIs that power your AI agent or application.
3. **Develop** a minimal but complete walkthrough (ideally in `.md`, `.sh`, or `.py`/`.ts`) that:

   * Implements video capture from WebXR devices,
   * Captures canvas renders/screenshots on demand,
   * Records audio clips with start/stop controls,
   * Handles text input from virtual keyboards,
   * Packages and sends media to configured API endpoint.
4. **Test** and validate your interaction model using mock data, debug output, or real endpoints.
5. **Capture** and log any challenges, surprises, or design tradeoffs you encountered.

---

### 🎯 **Clear Expectations**

* **Technical clarity**: Be explicit about which languages and versions are being used (e.g. `node@20`, `python@3.11`, etc.).
* **Environment consistency**: Document all required tools (e.g. `ffmpeg`, `curl`, `jq`, `ngrok`) and how they’re installed in your dev environment.
* **CLI fluency**: Reference relevant `man` pages, GitHub repos, or official docs. Keep links near your commands or function definitions.
* **Build narrative**: Frame your work like a README or onboarding script — not just for you, but for someone else picking it up cold.

---

### 🎨 **Encouraged Creativity**

You are **encouraged** to:

* **Invent your own metaphors** or naming conventions (e.g., "capsule," "skillset," "canvas" for bundled code + action).
* **Design interaction patterns** that feel natural — audio triggers, image generation, WebXR capture, etc.
* **Design AR/VR-native interactions** — gesture-based triggers, spatial menus, voice commands
* **Create immersive feedback** — visual indicators for recording, progress animations, haptic feedback
* **Experiment with media formats** — different compression levels, streaming vs. batch upload
* **Reframe the interface** — think about how someone else might want to "talk to their own data" or "send what they see."

> This is your sandbox — if the thing you build makes you smile, surprises you, or feels like something only you could’ve done, you’re on the right track.

---

### 🚫 **Immovable Requirements**

These are non-negotiable constraints:

1. **Must run in a documented terminal workflow** — no opaque magic. Use `tmux`, `bash`, `zsh`, etc., and note which shell and OS you’re using.
2. **No GUI dependencies unless explicitly served via browser** (e.g. WebXR experiments via Quest browser are fine).
3. **Use only open APIs or self-hosted tools** unless credentials and access are explicitly documented.
4. **Output must be human-readable** and logged to disk or stdout — e.g. captured images, JSON responses, etc.
5. **All dependencies must be listed**, ideally in a setup script (`setup.sh`, `requirements.txt`, or `Dockerfile`).

---

### 🔁 Summary Prompt (for reuse in project docs)

Here’s a version you can paste into your `.vibe/README.md` or similar file:

```md
## Aim
Build a WebXR capture system that collects video, canvas renders, audio, and text from AR/VR environments and sends them to a configurable API for AI processing.

## Outcome
A working WebXR application that:
- Captures multiple media types from AR/VR devices
- Provides accessible triggers in immersive mode
- Sends media to configured API endpoints
- (Future) Receives and renders AR objects for user interaction

## Requirements
- Must be executable in a CLI or lightweight browser
- Must document language/runtime/tool versions
- Must include links to all API and CLI documentation
- Must produce human-readable output
- Must log errors and unexpected behavior

## Encouraged Creativity
- Custom naming and metaphors
- Layered or nested agent behavior
- Experimenting with multimodal formats
- Elegant terminal UI/UX (e.g. colored logs, dynamic menus)
```

---

Let me know if you’d like this turned into a shell script, markdown template, or GitHub Codespaces container configuration — or if you’re ready to start building the prototype and want the first scaffold.
