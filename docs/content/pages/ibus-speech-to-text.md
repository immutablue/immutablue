---
title: "IBus Speech-to-Text"
weight: 15
---

# IBus Speech-to-Text

The IBus Speech-to-Text package provides a way to use speech recognition in GNOME applications.

## Installation

The `ibus-speech-to-text` package is included in Immutablue's package list. If you need to install it manually:

```bash
sudo rpm-ostree install ibus-speech-to-text
```

## Configuration

### Enabling the Input Method

1. Log out and log back in to ensure IBus services are running properly.

2. Open GNOME Settings and navigate to "Keyboard" → "Input Sources".

3. Click the "+" button to add a new input source.

4. Scroll down to find "Other" or search for "Speech To Text".

5. Select "Speech To Text" and click "Add".

### Using Speech Dictation

1. After adding the input method, you can switch between input methods using Super+Space or your configured keyboard shortcut.

2. When the Speech-to-Text input method is active, you'll see an indicator in your system tray.

3. To start dictation:
   - Click on any text field where you want to input text
   - Press the dictation key (default: Ctrl+Space)
   - The microphone indicator will change to show it's recording
   - Speak clearly into your microphone
   - Press the dictation key again to stop recording

4. For continuous dictation mode:
   - Go to the IBus Speech-to-Text settings
   - Enable "Continuous mode"
   - Dictation will automatically stop after a pause in speech

5. Common dictation commands:
   - "New line" - Creates a new line
   - "New paragraph" - Creates a new paragraph
   - "Period" or "Full stop" - Adds a period
   - "Question mark" - Adds a question mark
   - "Comma" - Adds a comma

### Speech Recognition Models

IBus Speech-to-Text supports several speech recognition models with different characteristics:

1. **Whisper Tiny** (default)
   - Small file size (~75MB)
   - Fast recognition
   - Lower accuracy
   - Good for basic dictation

2. **Whisper Base**
   - Medium file size (~140MB)
   - Balanced speed and accuracy
   - Recommended for most users

3. **Whisper Small**
   - Larger file size (~460MB)
   - Slower recognition
   - Higher accuracy
   - Better for technical terminology

4. **Whisper Medium**
   - Very large file size (~1.5GB)
   - Slowest recognition
   - Highest accuracy
   - Best for complex dictation

To change the model:
1. Open IBus Speech-to-Text settings
2. Select "Recognition Model"
3. Choose your preferred model
4. Restart the IBus service for changes to take effect

### Customizing Settings

You can customize the Speech-to-Text settings:

1. Open GNOME Settings.

2. Navigate to "Region & Language".

3. Click on "Input Sources".

4. Select "Speech To Text" and click the gear icon to access settings.

Available settings include:
- Recognition model selection
- Microphone input device
- Dictation key shortcut
- Continuous mode toggle
- Language selection
- Punctuation auto-correction
- Text formatting options

## Troubleshooting

- If speech recognition isn't working, ensure your microphone is properly configured in GNOME Settings under "Sound".

- Check that the IBus daemon is running:
  ```bash
  systemctl --user status ibus-daemon
  ```

- If you experience issues, restart the IBus daemon:
  ```bash
  ibus restart
  ```

- For slow recognition, try switching to a smaller model or ensure your CPU has enough resources available.

- If specific words are consistently misrecognized, try speaking more clearly or using the custom dictionary feature to add specialized terms.

## Performance Considerations

- Speech recognition is CPU-intensive, especially with larger models
- For best performance:
  - Close unnecessary applications
  - Ensure good microphone quality and positioning
  - Use a smaller model on lower-powered systems
  - Consider using offline processing mode in noisy environments

## Additional Resources

- [IBus Project Homepage](https://github.com/ibus/ibus)
- [Speech-to-Text IBus Engine Documentation](https://github.com/IBus-Speech-To-Text/ibus-speech-to-text)
- [Whisper Speech Recognition Models](https://github.com/openai/whisper)