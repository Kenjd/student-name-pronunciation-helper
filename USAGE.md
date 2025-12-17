# Usage Instructions: Student Name Pronunciation Helper

Complete guide to using the app effectively.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [First-Time Setup](#first-time-setup)
3. [Looking Up a Name](#looking-up-a-name)
4. [Using Audio Pronunciation](#using-audio-pronunciation)
5. [Saving Names](#saving-names)
6. [Managing Saved Names](#managing-saved-names)
7. [Settings & Configuration](#settings--configuration)
8. [Troubleshooting](#troubleshooting)
9. [Tips & Best Practices](#tips--best-practices)

---

## Getting Started

### Launching the App

1. Open RStudio
2. Set working directory to the Pronunciation folder
3. Open `name_pronunciation_app.r`
4. Click "Run App" button in RStudio
5. The app will open in your default browser

---

## First-Time Setup

### Initial Configuration (Optional but Recommended)

If you want to use the **ElevenLabs Premium Voice** (highly recommended for accurate international names):

**Good News**: ElevenLabs offers a **free tier with 10,000 characters/month** (API access included)!
- This is approximately 1,000 name pronunciations per month - completely free
- Perfect for most teachers
- No credit card required for free tier

**Setup Steps**:
1. Go to [ElevenLabs](https://elevenlabs.io) and create a **free account**
2. Navigate to Settings → API Keys
3. Copy your API key (starts with `sk_...`)
4. **Select a voice** (IMPORTANT - follow these steps carefully):
   - Browse the voice library
   - **Make sure you're in the "Eleven Turbo v2.5" model** (NOT v3)
   - v3 models are for emotional interpretation, NOT phonetic accuracy
   - Listen to voices and pick one you like (e.g., "Adam", "Alice", "Bill")
   - Click the **three dots (...)** menu next to your chosen voice
   - Select **"Copy voice ID"** from the menu
   - The Voice ID will be copied to your clipboard

### Configuring ElevenLabs in the App

1. Click the **Settings** tab in the app sidebar
2. Paste your **API Key** in the "ElevenLabs API Key" field
3. Paste your **Voice ID** in the "Voice ID" field
4. Click **"Save Settings"** (green button)
5. Click **"Test API Connection"** to verify it works
6. You'll see "✓ Success!" if configured correctly

**Note**: Your credentials are saved automatically and will load next time you open the app.

---

## Looking Up a Name

### Basic Name Lookup

1. Click the **Name Lookup** tab
2. Enter the student's name in the "Enter Student Name" field
3. **(Optional but Recommended)** Select the name's origin from the dropdown
   - Example: "Irish (Gaelic)" for names like Siobhan, Cillian
   - Example: "German" for names like Lachenmann
   - Select "Other/Unknown" if not in the list
4. Click **"Get Pronunciation"**

### Understanding the Results

After clicking "Get Pronunciation", you'll see:

**Method Indicator:**
- `✓ Found in [Language] Dictionary` - Name found in built-in dictionary (most reliable)
- `⚠ Using [Language] pattern-based rules` - Applied language rules but not in dictionary
- `⚠ Using generic phonetics` - No origin selected, basic phonetic conversion

**Pronunciation Formats:**
- **Original name**: The name as entered
- **With syllable breaks**: Shows natural syllable divisions (e.g., "See-OR-sha")
- **For Standard Voice**: Simplified phonetic for browser TTS
- **For ElevenLabs Premium**: IPA (International Phonetic Alphabet) notation
- **Phonetic Key**: Reference guide for reading phonetics

---

## Using Audio Pronunciation

### Standard Voice (Browser TTS)

1. After looking up a name, find the "Audio Pronunciation" section
2. Adjust the **"Standard Voice Speed"** slider if needed (0.5x to 1.5x)
3. Click **"Speak Name"** button
4. The browser will pronounce the name using your computer's built-in voice

**Pros**: Free, instant, works offline
**Cons**: Quality depends on your browser/OS, may not handle complex names well

### ElevenLabs Premium Voice

1. Make sure you've configured your API credentials (see [First-Time Setup](#first-time-setup))
2. After looking up a name, find the "ElevenLabs Premium (IPA)" section
3. Adjust the **"Speed"** slider if needed (0.5x to 1.5x)
4. Click **"Use ElevenLabs Premium"** button
5. Wait 1-3 seconds while audio generates
6. Audio plays automatically

**Pros**: High quality, accurate for international names, uses IPA directly, free for most users (10,000 chars/month)
**Cons**: Requires internet, requires API setup, small cost if exceeding free tier

### Speed Control

- **0.5x**: Very slow, good for learning difficult names
- **0.85x**: Default for Standard Voice - slightly slower for clarity
- **1.0x**: Default for Premium - natural speed
- **1.5x**: Faster, good for review/practice

---

## Saving Names

### When to Save Names

Save names you'll need to reference later:
- All students in your class roster
- Names you're still practicing
- Names with custom pronunciations

### How to Save a Name

1. After looking up a name and hearing the pronunciation
2. Click **"Save This Name"** button (green)
3. **(Optional)** Add notes in the "Add your own pronunciation notes" field
   - Example: "Stress first syllable"
   - Example: "Like 'shiv-on' but softer"
4. The name is saved with:
   - Original spelling
   - Syllable breaks
   - Phonetic guide
   - IPA notation
   - Selected origin
   - Your custom notes
   - Date saved

---

## Managing Saved Names

### Viewing Saved Names

1. Click the **Saved Names** tab
2. View table with all saved names
3. Each row shows: Name, Syllables, Phonetic, IPA, Origin, Notes, Date

### Playing Saved Names

- Click the **speaker icon (🔊)** next to any saved name
- Audio plays using Standard Voice (browser TTS)
- Quick way to review pronunciations

### Searching Saved Names

- Use the search box above the table
- Searches across all columns (name, origin, notes, etc.)

### Clearing All Saved Names

1. Click **"Clear All Saved Names"** button (orange warning button)
2. Confirm in the popup dialog
3. All saved names are permanently deleted

**Warning**: This action cannot be undone!

---

## Settings & Configuration

### Accessing Settings

Click the **Settings** tab (gear icon) in the sidebar

### Available Settings

**1. API Credentials**
- Enter/update ElevenLabs API Key and Voice ID
- Click "Save Settings" to persist credentials

**2. Test API Connection**
- Verifies your API key and voice ID are working
- Generates a test pronunciation of "Test"

**3. Clear Audio Cache**
- Deletes all cached ElevenLabs pronunciations
- Forces regeneration of audio on next request
- Useful if you:
  - Updated a name's pronunciation
  - Want to free up disk space
  - Experience playback issues

---

## Troubleshooting

### Standard Voice Not Working

**Problem**: Browser voice doesn't speak or gives error

**Solutions**:
1. Check your device volume is turned up
2. Try a different browser (Chrome, Safari, Edge work best)
3. Some browsers require user interaction before playing audio - click the button again
4. Use ElevenLabs Premium as alternative

---

### ElevenLabs Premium Not Working

**Problem**: "API key not set" or "Premium voice error"

**Solutions**:
1. Go to Settings tab
2. Verify API Key and Voice ID are entered correctly
3. Click "Test API Connection" - should show "✓ Success!"
4. If test fails:
   - Check API key hasn't expired on ElevenLabs website
   - Verify Voice ID is correct (copy/paste from ElevenLabs)
   - Ensure you have credits/subscription on ElevenLabs

**Problem**: Wrong pronunciation but test succeeds

**Solutions**:
1. Go to Settings → Click "Clear Audio Cache"
2. Try the pronunciation again (forces fresh generation)
3. Check the IPA shown - if it's wrong, use Manual Override (see below)

---

### Incorrect Pronunciation

**Problem**: Neither voice pronounces the name correctly

**Solutions**:

**Option 1**: Select the correct origin
- Make sure you selected the name's language origin from dropdown
- Irish names especially need "Irish (Gaelic)" selected

**Option 2**: Use Manual Override
1. After looking up the name, expand "Manual Phonetic Override" section
2. For Standard Voice: Type simple phonetic like "kill-ian" or "shiv-on"
3. For ElevenLabs Premium: Type IPA like "kɪliən" or simplified spelling
4. Click the voice button again - uses your custom pronunciation

**Option 3**: Check if name is in dictionary
- Look for "✓ Found in [Language] Dictionary" indicator
- If using pattern-based rules, pronunciation may be less accurate
- Consider submitting name for dictionary inclusion

---

### App Crashes or Freezes

**Solutions**:
1. Refresh the browser page
2. Close and relaunch the app from RStudio
3. Check R console for error messages
4. Verify Python is installed and accessible
5. Ensure all required R packages are installed

---

## Tips & Best Practices

### For Teachers

**Before First Day of Class:**
1. Get your class roster early
2. Look up all student names in advance
3. Save them in the app with notes
4. Practice pronunciation of difficult names
5. Review the day before class starts

**During Semester:**
- Use Saved Names tab to quickly review pronunciations
- Add notes about preferences (e.g., "prefers 'Sean' over 'Shawn'")
- Save names of parents/guardians for conferences

### Getting Best Pronunciation Quality

1. **Always select origin** if you know it - dramatically improves accuracy
2. **Use ElevenLabs Premium** for complex international names
3. **Check the IPA** - if it looks wrong, use manual override
4. **Adjust speed** - slower helps you hear each syllable clearly
5. **Listen multiple times** - repetition helps learning

### Understanding the Method Indicator

- **Dictionary match (✓)**: Highest confidence - pronunciation is verified
- **Pattern-based (⚠)**: Medium confidence - follows language rules
- **Generic (⚠)**: Lowest confidence - basic phonetic guess

When you see ⚠, consider:
- Trying both voice types to compare
- Using manual override if available
- Asking the student directly for confirmation

### Cost Management (ElevenLabs)

**Great News: Free Tier Available!**
- ElevenLabs offers **10,000 free characters per month** on their free plan (includes API access)
- This equals approximately **1,000 name pronunciations per month** (avg 10 chars per name)
- Perfect for most teachers - you can use Premium voice completely free!
- Example: 200 students × 5 reviews each = 1,000 pronunciations (all free!)

**To stay within free tier:**
1. Use Standard Voice for simple English names
2. Reserve Premium for complex/international names
3. Cache is automatic - same name won't cost twice
4. Monitor your usage on the ElevenLabs dashboard

**If you exceed 10,000 chars/month:**
- Names cost ~$0.00015 each beyond free tier
- Still very affordable: 2,000 names/month = ~$0.15/month extra
- Heavy usage: ~$5-10/year even with large class sizes

### Privacy Considerations

- **Don't commit** `.elevenlabs_config.rds` to version control (already in .gitignore)
- **Be aware** that ElevenLabs receives the name and IPA for pronunciation
- **Saved names** are local only (not sent anywhere)
- **No personal data** besides names is collected or transmitted

---

## Keyboard Shortcuts

- `Tab` - Navigate between fields
- `Enter` - Submit form (after typing name)
- `Esc` - Close modal dialogs

---

## Getting Help

### Error Messages

The app provides clear error messages:
- "Please click 'Get Pronunciation' first" - Look up name before using voice
- "ElevenLabs API key not set" - Configure credentials in Settings
- "Name cannot be empty" - Enter a name before clicking buttons

### Common Questions

**Q: Do I need ElevenLabs for the app to work?**
A: No! Standard Voice (browser TTS) works without any setup. ElevenLabs is optional for higher quality, but highly recommended - and it's FREE for up to 10,000 characters/month (~1,000 names).

**Q: Is ElevenLabs really free?**
A: Yes! Their free tier includes 10,000 characters/month with API access (no credit card required). That's enough for ~1,000 name pronunciations per month, perfect for most teachers.

**Q: Can I use this offline?**
A: Standard Voice works offline. ElevenLabs Premium requires internet.

**Q: How accurate is the pronunciation?**
A: For names in the dictionary (✓): Very accurate. For pattern-based (⚠): Usually good. For generic (⚠): May need manual correction.

**Q: Can I add my own names to the dictionary?**
A: Currently not via the UI, but you can edit the R code to add entries to the Irish dictionary or create new language dictionaries.

**Q: What languages are supported?**
A: Full dictionary support for Irish. Pattern-based support for 15+ languages. Any language can work with manual override.

---

## Advanced Features

### Manual Phonetic Override

Use when automatic pronunciation is wrong:

**For Standard Voice:**
- Use simple spellings: "kill-ian", "shiv-on", "seer-sha"
- Hyphens help indicate syllable breaks
- Avoid special characters

**For ElevenLabs Premium:**
- Can use IPA characters: "kɪliən", "ʃɪˈvɔːn"
- Or simple spellings also work
- IPA is more accurate for complex sounds

### Multiple Origins

If a name exists in multiple cultures:
1. Try each origin to hear differences
2. Ask the student which pronunciation they prefer
3. Save with notes indicating their preference

### Batch Processing

For processing multiple names:
1. Look up first name, save it
2. Look up second name, save it
3. Continue for all names
4. Use Saved Names tab to review all at once
5. Practice by clicking speaker icons

---

## Support & Feedback

For issues, suggestions, or contributions:
- Check this documentation first
- Review error messages in the app
- Check R console for technical errors
- For pronunciation accuracy improvements, note which names need better handling

---

**Happy Teaching!** May all your name pronunciations be respectful and accurate. 🎓
