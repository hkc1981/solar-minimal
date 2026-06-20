# Solar Minimal - Garmin Connect IQ Watch Face

Welcome to your first custom Garmin watch face! **Solar Minimal** is a highly optimized, battery-saving digital watch face developed in Monkey C.

---

## 📂 Project Structure

This directory is organized according to Garmin's standard build layout:

```
├── manifest.xml           # Application definitions, IDs, supported devices, and permissions
├── monkey.jungle          # Build paths and device resource overrides
├── README.md              # Setup and development guide (this file)
├── resources/             # Static application assets
│   ├── drawables/
│   │   ├── drawables.xml  # Image resource mappings
│   │   └── launcher_icon.png # App icon in the watch launcher (40x40 px)
│   ├── layouts/
│   │   └── layout.xml     # Declarative UI Layout XML (Unused, programmatically drawn for efficiency)
│   └── strings/
│       └── strings.xml    # Translatable user-facing strings (AppName)
└── source/                # Monkey C source code
    ├── SolarMinimalApp.mc  # Main entry point (extends Application.AppBase)
    └── SolarMinimalView.mc # Watch Face rendering & state manager (extends WatchUi.WatchFace)
```

---

## 🛠️ Environment Setup Guide

To build and run this application, you will need the following tools:

### 1. Java Development Kit (JDK)
Garmin’s compiler and simulator tools run on Java.
* **Mac (Homebrew):** `brew install openjdk`
* Ensure `java -version` is accessible from your terminal.

### 2. Connect IQ SDK Manager
1. Download the **Connect IQ SDK Manager** from the [Garmin Developer Portal](https://developer.garmin.com/connect-iq/sdk/).
2. Run the SDK Manager to download the latest **Connect IQ SDK** and your target device simulators (e.g., *Fenix 7*, *Epix Gen 2*, *Forerunner 965*).

### 3. Visual Studio Code & Monkey C Extension
1. Install **Visual Studio Code**.
2. Open VS Code and install the official **Monkey C extension** (developed by Garmin).
3. Open VS Code Settings (`Cmd + ,`), search for `Monkey C`, and set the path to your downloaded Connect IQ SDK if it was not auto-detected.

### 4. Create a Developer Key
Garmin requires all apps to be signed with a cryptographic key, even for simulator testing.
* Open VS Code, press `Cmd + Shift + P` to open the Command Palette.
* Search for **`Monkey C: Generate Developer Key`** and follow the instructions to save your `developer_key.der` file.
* Make sure you configure the extension to use this key.

---

## 🚀 Running the App

1. Open this directory (`/Users/hkc1981/.gemini/antigravity/scratch/solar-minimal`) in **VS Code**.
2. Recommendation: Set this folder as your active workspace.
3. Open the command palette (`Cmd + Shift + P`) and run **`Monkey C: Verify Installation`** to make sure everything is green.
4. Press `F5` or go to **Run and Debug** -> **Start Debugging**.
5. Select a device simulator (e.g., `fenix7`).
6. The simulator will boot up and display the Solar Minimal watch face!
   - In the Simulator menu, go to **Simulation -> FIT Data -> Simulate Data** to see heart rate updates.
   - Go to **Settings -> Set Solar Intensity** to test the solar charging bar.

---

## 💡 Monkey C Language Cheat Sheet

Monkey C is an object-oriented, strongly-typed language built specifically for low-power Garmin devices. Here are the key language features you'll use:

### 1. Strong vs. Duck Typing
Since API level 4.0.0, Monkey C supports strict type-checking using the `as` syntax:
```monkeyc
// Static Typing
var age as Number = 30;
var name as String = "Garmin";

// Dynamic/Duck Typing (when a variable can hold multiple types)
var data as Number or String or Null = null;
```

### 2. Canvas Drawing (Programmatic UI)
For maximum battery efficiency, Solar Minimal draws directly onto the Device Context (`dc`) inside the `onUpdate` method:
```monkeyc
function onUpdate(dc as Graphics.Dc) as Void {
    // Clear screen to black
    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
    dc.clear();
    
    // Draw text
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
    dc.drawText(centerX, centerY, Graphics.FONT_LARGE, "10:45:12", Graphics.TEXT_JUSTIFY_CENTER);
}
```

### 3. Battery Optimizations
* **MIP Displays:** Black background yields maximum high-contrast sunlight readability.
* **Sleeping Mode:** In low-power state, 1Hz updates of seconds are achieved using `onPartialUpdate` with clipping areas to preserve battery life.

---

## 📚 Official Documentation & APIs
* [Garmin Connect IQ Developer Site](https://developer.garmin.com/connect-iq/)
* [Monkey C Language Reference Guide](https://developer.garmin.com/connect-iq/monkey-c/)
* [Connect IQ API Documentation](https://developer.garmin.com/connect-iq/api-docs/)
