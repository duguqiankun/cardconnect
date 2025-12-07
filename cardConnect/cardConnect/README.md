# iOS Gemini App Setup

This folder contains the source files for a basic iOS app that integrates with Google's Gemini API.

## Prerequisites

- Xcode 15.0 or later
- A Google AI Studio API Key

## Setup Instructions

1.  **Create a New Xcode Project**:
    - Open Xcode.
    - Select "Create New Project".
    - Choose "App" under iOS.
    - Name the project `CardConnect` (or match the folder name).
    - Ensure Interface is "SwiftUI" and Language is "Swift".

2.  **Add Dependencies**:
    - In Xcode, go to `File` > `Add Package Dependencies...`.
    - Search for the Google Generative AI SDK: `https://github.com/google/generative-ai-swift`.
    - Click "Add Package".

3.  **Add Source Files**:
    - Drag and drop the following files from this folder into your Xcode project navigator (make sure "Copy items if needed" is checked if you are moving them, or just reference them):
        - `CardConnectApp.swift` (Replace the default one)
        - `ContentView.swift` (Replace the default one)
        - `GeminiService.swift`

4.  **Configure API Key**:
    - Open `GeminiService.swift`.
    - Locate the `setupModel()` function.
    - Replace `"YOUR_API_KEY_HERE"` with your actual Google AI Studio API Key.
    - *Note: For production apps, consider more secure ways to store API keys, such as retrieving them from a secure backend.*

5.  **Run the App**:
    - Select a Simulator (e.g., iPhone 15).
    - Press Cmd+R to build and run.

## Usage

- Type a prompt in the text field at the bottom.
- Tap the send button.
- Wait for Gemini's response to appear on the screen.
