# Audio Recording Feature - Testing Guide

## What This Feature Does

This is the **core audio recording functionality** for Milestone 1. It allows Physical Therapists (PTs) to:
- Record audio during home health visits **offline** (no internet required)
- Pause and resume recordings during long sessions
- See real-time recording duration
- Save recordings locally to the device
- Handle microphone permissions gracefully

**Purpose:** PTs record patient visits, and these recordings will later be:
1. Encrypted and stored locally
2. Uploaded to the server when internet is available
3. Transcribed using AI
4. Used to auto-fill Google Doc forms

---

## Normal Flow Testing

### ✅ Happy Path Test
1. **Launch app** → Navigate to Home screen
2. **Tap "Start New Recording"** → Should navigate to Recording screen
3. **Grant microphone permission** (if first time) → Dialog should appear
4. **Tap "Start Recording"** → Should see:
   - Red recording icon (circle with dot)
   - Timer starts counting (00:00, 00:01, 00:02...)
   - Status shows "Recording..."
   - Pause and Stop buttons appear
5. **Speak into microphone** for 10-15 seconds
6. **Tap "Pause"** → Should see:
   - Icon changes to pause symbol
   - Timer stops counting
   - Status shows "Recording Paused"
   - Button changes to "Resume"
7. **Tap "Resume"** → Should see:
   - Recording continues
   - Timer resumes from where it paused
   - Status shows "Recording..."
8. **Tap "Stop"** → Should see:
   - Recording stops
   - Green success message: "Recording saved: [file path]"
   - Returns to "Ready to Record" state
   - Timer resets to 00:00

**Expected Result:** Recording file should be saved in app's documents directory as `recording_[timestamp].aac`

---

## Edge Cases & Error Scenarios

### 🔴 Permission Edge Cases

#### Test 1: First Launch (Permission Not Requested)
- **Setup:** Delete app completely, reinstall fresh
- **Action:** Navigate to Recording screen
- **Expected:** 
  - Error message: "Microphone permission is required..."
  - "Request Permission" button visible
  - Permission dialog appears when tapped
  - After granting, recording can start

#### Test 2: Permission Denied (Not Permanent)
- **Setup:** Deny permission when first asked
- **Action:** Try to start recording
- **Expected:**
  - Error message shows
  - "Request Permission" button appears
  - Can request again (iOS allows multiple attempts)

#### Test 3: Permission Permanently Denied
- **Setup:** 
  1. Deny permission multiple times OR
  2. Go to Settings → HealthDoc → Microphone → Turn OFF
- **Action:** Try to start recording
- **Expected:**
  - Error: "Microphone permission is permanently denied..."
  - "Open Settings" button appears
  - Tapping it opens iOS Settings app
  - After enabling in Settings, app should detect permission granted

#### Test 4: Permission Revoked While Recording
- **Setup:** Start recording, then go to Settings and revoke permission
- **Action:** Try to pause/resume/stop
- **Expected:** App should handle gracefully (may show error, but shouldn't crash)

---

### 🔴 Recording State Edge Cases

#### Test 5: Start Recording Without Permission
- **Setup:** Deny permission
- **Action:** Tap "Start Recording" button
- **Expected:** 
  - Permission request dialog appears
  - If denied, error message shows
  - Recording doesn't start

#### Test 6: Multiple Rapid Start/Stop
- **Action:** Quickly tap Start → Stop → Start → Stop (5 times rapidly)
- **Expected:** 
  - No crashes
  - Each recording saves properly
  - Timer resets correctly each time

#### Test 7: Pause Before Starting
- **Action:** Try to pause when not recording
- **Expected:** Pause button shouldn't be visible (only shows when recording)

#### Test 8: Stop While Paused
- **Setup:** Start recording, then pause
- **Action:** Tap Stop
- **Expected:** 
  - Recording stops
  - File saves correctly
  - Timer resets

#### Test 9: Resume Without Pausing
- **Action:** Try to resume when not paused
- **Expected:** Resume button shouldn't be visible (only shows when paused)

---

### 🔴 Long Recording Tests

#### Test 10: Very Long Recording (30+ minutes)
- **Action:** Record continuously for 30+ minutes
- **Expected:**
  - Timer shows hours:minutes:seconds format (e.g., "00:30:15")
  - No memory leaks
  - Recording quality maintained
  - File size reasonable

#### Test 11: Multiple Pause/Resume Cycles
- **Action:** Start → Pause → Resume → Pause → Resume (repeat 10 times)
- **Expected:**
  - Timer continues correctly
  - No audio gaps in final file
  - App remains responsive

---

### 🔴 App Lifecycle Edge Cases

#### Test 12: Background While Recording
- **Setup:** Start recording
- **Action:** Press home button (app goes to background)
- **Expected:**
  - Recording continues (iOS handles this)
  - When returning to app, timer should reflect correct duration
  - Recording state preserved

#### Test 13: Phone Call During Recording
- **Setup:** Start recording
- **Action:** Receive/make phone call
- **Expected:**
  - Recording pauses or stops (iOS behavior)
  - App handles interruption gracefully
  - No crash

#### Test 14: App Killed While Recording
- **Setup:** Start recording
- **Action:** Force quit app (swipe up in app switcher)
- **Expected:**
  - Recording may be lost (expected behavior)
  - App doesn't crash on next launch
  - Can start new recording

#### Test 15: Navigate Away While Recording
- **Setup:** Start recording
- **Action:** Tap back button or navigate to another screen
- **Expected:**
  - Recording should continue (or stop gracefully)
  - No crash
  - Can return and see recording state

---

### 🔴 File System Edge Cases

#### Test 16: Low Storage Space
- **Setup:** Fill device storage to < 100MB free
- **Action:** Try to start recording
- **Expected:**
  - Error message about insufficient storage
  - No crash
  - Clear error message

#### Test 17: Invalid File Path
- **Note:** Hard to test directly, but verify error handling exists
- **Expected:** If file path is invalid, error message shows, no crash

---

### 🔴 UI/UX Edge Cases

#### Test 18: Screen Rotation
- **Setup:** Start recording
- **Action:** Rotate device (if allowed)
- **Expected:**
  - UI adapts correctly
  - Recording continues
  - Timer doesn't reset

#### Test 19: Multiple Screen Instances
- **Action:** Open recording screen, go back, open again
- **Expected:**
  - Previous recording state cleared
  - Can start fresh recording
  - No memory leaks

#### Test 20: Button States
- **Verify:**
  - Start button only shows when not recording
  - Pause/Resume only shows when recording
  - Stop only shows when recording
  - Buttons are properly enabled/disabled

---

### 🔴 Audio Quality Tests

#### Test 21: Silent Recording
- **Action:** Start recording, don't speak (record silence for 10 seconds)
- **Expected:**
  - Recording saves successfully
  - File size is minimal but valid
  - No errors

#### Test 22: Very Loud Audio
- **Action:** Record very loud sounds (near max volume)
- **Expected:**
  - No distortion/clipping
  - Recording quality maintained
  - No crash

#### Test 23: Background Noise
- **Action:** Record with background noise (TV, fan, etc.)
- **Expected:**
  - Recording captures audio
  - Quality is acceptable
  - No crashes

---

## Verification Checklist

After each test, verify:
- [ ] No app crashes
- [ ] Error messages are clear and actionable
- [ ] Recording files are saved correctly
- [ ] Timer is accurate
- [ ] UI state matches recording state
- [ ] Permission handling works correctly
- [ ] No memory leaks (check with Xcode Instruments if possible)

---

## How to Verify Recording Files

1. **Using Xcode:**
   - Window → Devices and Simulators
   - Select your device/simulator
   - Select app → Download Container
   - Navigate to: `AppData/Documents/`
   - Look for `recording_[timestamp].aac` files

2. **Using Terminal (Simulator):**
   ```bash
   xcrun simctl get_app_container booted com.healthdoc.healthdocMobile data
   # Then navigate to Documents folder
   ```

3. **Check File Properties:**
   - File should exist
   - File size > 0 bytes
   - File extension: `.aac`
   - Can be played back (verify audio quality)

---

## Known Limitations (Current Implementation)

1. **No encryption yet** - Files are saved unencrypted (will be added in next phase)
2. **No upload yet** - Files only save locally (upload service coming)
3. **No metadata** - Patient ID, form types not captured yet (coming in next milestone)
4. **No file management** - Can't view/list recordings yet
5. **No deletion** - Files accumulate (cleanup coming)

---

## Quick Test Script

Run these in sequence for a quick smoke test:

```
1. Fresh install → Grant permission → Record 5 seconds → Stop ✅
2. Start → Pause → Resume → Stop ✅
3. Deny permission → See error → Grant in Settings → Record ✅
4. Start recording → Background app → Return → Stop ✅
5. Rapid start/stop 3 times ✅
```

If all pass, core functionality is working! 🎉
