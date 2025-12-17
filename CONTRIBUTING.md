# Contributing to Student Name Pronunciation Helper

Thank you for your interest in contributing! This guide will help you add names to dictionaries or improve the app.

## How You Can Contribute

1. **Add names to existing language dictionaries** (Irish, Spanish, Nigerian, Indian)
2. **Create new language dictionaries** (Chinese, Arabic, Polish, Portuguese, etc.)
3. **Report bugs** or pronunciation errors
4. **Suggest features** or improvements
5. **Improve documentation**

## Current Dictionaries

The app currently has **four comprehensive dictionaries with 220+ names**:
- **Irish (Gaelic)**: 62 names (Siobhan, Cillian, Saoirse, Aoife, etc.)
- **Spanish/Latin**: 48 names (José, María, Santiago, Isabella, Diego, etc.)
- **Nigerian**: 50+ names - Igbo, Yoruba, Hausa (Chioma, Oluwaseun, Chukwudi, etc.)
- **Indian**: 60+ names - Hindi, Tamil, Telugu, Punjabi (Priya, Aarav, Lakshmi, etc.)

---

## Adding Names to Dictionaries

### Understanding the Dictionary Structure

Each dictionary entry has **three phonetic fields**:

```r
"name" = list(
  standard = "simple-phonetic",   # For browser TTS (Web Speech API)
  premium = "sim-ple-pho-net-ic", # For ElevenLabs (with syllable breaks)
  ipa = "ˈsɪmpəl"                 # IPA notation for ElevenLabs
)
```

### Field Guidelines

#### 1. `standard` - For Browser TTS
- Use simple English spelling approximations
- No hyphens or special characters
- Optimized for Web Speech API voices
- Example: `"shevawn"` for Siobhan

#### 2. `premium` - For ElevenLabs (Text Mode)
- Use hyphens to separate syllables
- English-like spelling with syllable breaks
- Helps ElevenLabs pace the pronunciation
- Example: `"she-vawn"` for Siobhan

#### 3. `ipa` - For ElevenLabs (IPA Mode)
- Standard International Phonetic Alphabet notation
- Remove the surrounding slashes (no `/ʃɪˈvɔːn/`, just `ʃɪˈvɔːn`)
- Most accurate for complex pronunciations
- Use online IPA resources if needed (see Resources below)
- Example: `"ʃɪˈvɔːn"` for Siobhan

### Step-by-Step: Adding a Name to Irish Dictionary

**Location**: `name_pronunciation_app.r`, lines 21-87 (inside `irish_dictionary`)

1. **Test the pronunciation** first using the app's manual override feature
2. **Find the right spot** alphabetically in the dictionary
3. **Add the entry**:

```r
"cillian" = list(
  standard = "killian",
  premium = "kill-ian",
  ipa = "ˈkɪliən"
),
```

4. **Test it** by running the app and looking up the name
5. **Submit a pull request** (see below)

### Creating a New Language Dictionary

To add a new language (e.g., Spanish):

1. **Create the dictionary** after the Irish dictionary (around line 88):

```r
# Spanish Names Dictionary
spanish_dictionary <- list(
  "josé" = list(
    standard = "hoseh",
    premium = "ho-seh",
    ipa = "xoˈse"
  ),
  "maría" = list(
    standard = "mahreeah",
    premium = "mah-ree-ah",
    ipa = "maˈɾi.a"
  )
  # Add more names...
)
```

2. **Update the origin dropdown** (around line 129):

```r
selectInput("name_origin",
  "Name Origin (helps accuracy):",
  choices = c(
    "Other/Unknown" = "generic",
    "Irish (Gaelic)" = "irish",
    "Spanish" = "spanish",  # ADD THIS
    # ... other languages
  )
)
```

3. **Update the pronunciation logic** (around line 260):

```r
} else if (origin == "spanish" && name_lower %in% names(spanish_dictionary)) {
  phonetic_result <- spanish_dictionary[[name_lower]]
  origin_applied <- TRUE
  method_used <- "dictionary"
```

4. **Test thoroughly** with 5-10 names
5. **Submit a pull request**

---

## Testing Your Changes

Before submitting:

1. **Run the app** in RStudio
2. **Test both voices** (Standard and ElevenLabs Premium)
3. **Verify accuracy**:
   - Standard Voice pronounces it correctly
   - Premium Voice with IPA is accurate
   - Syllable breaks look natural
4. **Check edge cases**:
   - Names with accents
   - Very short names
   - Names with apostrophes or hyphens

---

## Submitting a Pull Request

1. **Fork the repository** on GitHub
2. **Create a branch** for your changes:
   ```bash
   git checkout -b add-spanish-dictionary
   ```
3. **Make your changes** and test them
4. **Commit with a clear message**:
   ```bash
   git commit -m "Add Spanish dictionary with 15 common names"
   ```
5. **Push to your fork**:
   ```bash
   git push origin add-spanish-dictionary
   ```
6. **Open a pull request** on GitHub with:
   - Clear description of what you added
   - Number of names added
   - Any testing notes

---

## Reporting Bugs

Found a pronunciation error or bug?

1. **Open an issue** on GitHub
2. **Include**:
   - The name that's mispronounced
   - Language/origin selected
   - Expected pronunciation (phonetic or description)
   - Actual pronunciation (what you heard)
   - Which voice (Standard or Premium)
3. **Bonus**: Suggest the correct IPA if you know it

---

## Resources

### IPA (International Phonetic Alphabet)

- [IPA Chart with Audio](https://www.ipachart.com/) - Interactive IPA reference
- [EasyPronunciation IPA Translator](https://easypronunciation.com/en/english-phonetic-transcription-converter) - English text to IPA
- [Wiktionary](https://en.wiktionary.org/) - Many entries include IPA pronunciations
- [Forvo](https://forvo.com/) - Pronunciation database (audio + IPA)

### Language-Specific Resources

**Irish (Gaelic)**:
- [Foclóir.ie](https://www.focloir.ie/) - Official Irish dictionary with pronunciations
- [Teanglann.ie](https://www.teanglann.ie/en/) - Irish dictionary with phonetics

**Spanish**:
- [WordReference](https://www.wordreference.com/) - Spanish dictionary with IPA
- [SpanishDict](https://www.spanishdict.com/) - Pronunciation guides

**General**:
- Name pronunciation websites like Pronounce Names or Behind the Name
- YouTube videos for specific cultural name pronunciations
- Ask native speakers!

---

## Code Style Guidelines

- **Indentation**: 2 spaces (not tabs)
- **Alphabetical order**: Keep dictionary entries alphabetically sorted
- **Comments**: Add comments for non-obvious pronunciation rules
- **Consistency**: Follow existing patterns in the code

---

## Questions?

Open an issue on GitHub with the tag `question` and we'll help you out!

---

**Thank you for helping make classrooms more inclusive!** Every name you add helps a teacher pronounce a student's name correctly on the first day of class.
