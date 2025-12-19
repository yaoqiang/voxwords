# 💎 VoxWords - Master Design & Implementation Plan

This is the master plan for VoxWords, prioritizing **"Silky" UX** and **Native-First Performance**.

## 🎨 Phase 1: The "Feel" (Interaction Design & Research)
**Goal**: Define the physics and micro-interactions that make the app feel "alive".

### 1.1 The "Voice Core" Interaction
*   **Objective**: Replicate the "immediate" feel of WeChat/Telegram voice messaging.
*   **Interaction Model**:
    *   **Idle**: Button breathes slowly (scale 1.0 -> 1.05).
    *   **Touch Down**: Instant shrink (scale 0.9) + Haptic Impact (Light) + Sound "Pop".
    *   **Recording**: Bloom effect + 60fps Waveform visualization (using `TimelineView` + `Canvas`).
    *   **Release**: Spring expand (scale 1.2 -> 1.0) + "Success" Sound.
*   **Technical Implementation**:
    *   Use `AVAudioEngine` tap for raw audio data.
    *   Process FFT with `Accelerate` framework for the visualizer.
    *   Use `TimelineView` for silk-smooth UI updates.

### 1.2 "Magic" Card Reveal (Progressive Disclosure)
*   **Objective**: Manage latency (2-5s) gracefully.
*   **Strategy**:
    *   **Step 1 (0ms)**: User stops speaking -> Show "Ghost Card" (Skeleton).
    *   **Step 2 (100ms)**: `SFSpeechRecognizer` returns final text -> Fill text.
    *   **Step 3 (2s)**: LLM returns refinement -> Update text/translation.
    *   **Step 4 (5s)**: Image Gen returns -> Cross-dissolve image in.

---

## 🛠️ Phase 2: Technical Validation (The "Hard" Stuff)

### 2.1 Pronunciation & Assessment Strategy
*   **Findings**: Native `SFSpeechRecognizer` does **not** provide phoneme-level scoring.
*   **Hybrid Approach**:
    *   **Native**: Use `SFVoiceAnalytics` (if available) or raw audio analysis for **Fluency** (speech rate, pause duration, jitter).
    *   **Cloud (Future)**: Use OpenAI Audio API for detailed pronunciation scoring if needed later.
    *   **Decision**: For MVP Phase 1, focus on **Recognition Accuracy** and **Fluency** rather than strict "Scoring". We will gamify the "Confidence" level returned by speech recognition.

---

## 🚀 Phase 3: The "Tracer Bullet" (MVP Code)

### 3.1 Foundation
- [ ] **Project Setup**: SwiftUI App, Permissions (Mic, Speech).
- [ ] **HapticManager**: Singleton for consistent feedback.
- [ ] **SoundManager**: For UI sound effects (Pop, Success).

### 3.2 The "Ear" (Input)
- [ ] **AudioInputManager**: Handle `AVAudioEngine` for *both* visualization data and Speech Recognition stream.
- [ ] **VisualizerView**: Pure SwiftUI `Canvas` drawing the waveform.

### 3.3 The "Core Loop"
- [ ] **RecordButton**: The "Soul" of the app. Custom gesture handling.
- [ ] **MainView**: Layout with Progressive Reveal Card.

### 3.4 Intelligence Layer
- [ ] **OpenAIService**: Refined prompt for children's speech extraction.
- [ ] **ImageService**: DALL-E 3 connection.
