# Changelog

All notable changes to the Student Name Pronunciation Helper will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2025-12-17 (Ready for Release)

### Added
- **Spanish/Latin name dictionary** with 48 names
  - Spanish names from Spain, Mexico, and Latin America
  - Female names (María, Sofía, Isabella, Valentina, Camila, etc.)
  - Male names (José, Juan, Carlos, Miguel, Diego, Santiago, etc.)
  - Includes both accented and non-accented versions
  - Verified IPA pronunciations for all entries
- **Nigerian name dictionary** with 50+ names
  - Igbo names (Chioma, Chukwudi, Ngozi, Emeka, etc.)
  - Yoruba names (Oluwaseun, Adeola, Babatunde, Temitope, etc.)
  - Hausa names (Aisha, Fatima, Muhammad, Ibrahim, etc.)
  - Verified IPA pronunciations for all entries
- **Indian name dictionary** with 60+ names
  - Hindi/Sanskrit names (Priya, Aarav, Ananya, Rohan, etc.)
  - Tamil names (Arun, Deepak, Lakshmi, Karthik, etc.)
  - Telugu names (Srinivas, Venkat, Ramya, Suresh, etc.)
  - Punjabi names (Harpreet, Simran, Gurpreet, etc.)
  - Verified IPA pronunciations for all entries
- Updated origin dropdown with "Spanish", "Nigerian (Igbo/Yoruba/Hausa)", and "Indian (Hindi/Tamil/Punjabi)"
- Pattern-based pronunciation rules for Spanish, Nigerian, and Indian names

#### Core Features
- **Dual voice pronunciation system**
  - Web Speech API (browser TTS) - free, instant, offline
  - ElevenLabs Premium API - high-quality AI voice with IPA support
- **Speed control** for both voice types (0.5x to 1.5x)
- **220+ names across 4 comprehensive dictionaries** (Irish, Spanish, Nigerian, Indian)
  - All entries include verified IPA pronunciations
  - Optimized phonetics for both TTS engines
- **Origin selection** supporting 15+ languages
  - Full dictionary support: Irish (Gaelic), Spanish, Nigerian (Igbo/Yoruba/Hausa), Indian (Hindi/Tamil/Telugu/Punjabi)
  - Pattern-based support: Chinese (Mandarin), Italian, German, Polish, Vietnamese, Korean, Japanese, Arabic, Portuguese, Russian, French, Greek
- **Transparency indicators** showing pronunciation method
  - Dictionary match (✓)
  - Pattern-based rules (⚠)
  - Generic phonetics (⚠)
- **Manual phonetic override** for custom pronunciations
  - Works with both Standard and Premium voices
  - Supports IPA or simple phonetic spellings

#### Name Management
- **Save names** with custom notes for future reference
- **Searchable saved names table** with audio playback
- **Export saved names** to CSV
- **Audio playback buttons** in saved names table

#### Settings & Configuration
- **Credential persistence** - API keys saved automatically
- **Auto-load settings** on app startup
- **Test API connection** button to verify ElevenLabs setup
- **Clear audio cache** functionality
- **Smart caching** by phonetic (not just name) to prevent collisions

#### Documentation
- Comprehensive README.md with installation instructions
- Detailed USAGE.md with step-by-step guides
- CONTRIBUTING.md for community contributions
- In-app help tab with troubleshooting

#### Technical Implementation
- **R-Python integration** for ElevenLabs API calls
- **UTF-8 encoding** for proper IPA character handling
- **Plain IPA text** to ElevenLabs (not SSML) for best accuracy
- **Base64 audio encoding** for browser playback
- **Reactive UI** with instant feedback
- **Error handling** with user-friendly messages
- **Security**: .gitignore for credentials, no hardcoded secrets

### Technical Details

**Languages**: R (Shiny), Python 3, JavaScript
**Key Packages**: shiny, shinydashboard, DT, jsonlite, base64enc, digest
**APIs**: ElevenLabs Turbo v2.5, Web Speech API
**Python Dependencies**: requests

### Known Issues
- Web Speech API voice quality depends on browser/OS
- ElevenLabs requires internet connection
- Pattern-based pronunciations may not be 100% accurate for all names

### Notes
- ElevenLabs offers **10,000 free characters/month** (~1,000 names)
- App works fully offline with Standard Voice only
- No credit card required for ElevenLabs free tier

---

## Future Considerations

Potential features for future releases (not committed):

- Additional language dictionaries (Spanish, Chinese, Polish, etc.)
- Bulk import from CSV (class roster upload)
- Phonetic practice mode with repetition
- Mobile-responsive design improvements
- Offline IPA generation (remove Python dependency)
- Integration with learning management systems (LMS)
- Audio recording for comparing your pronunciation

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to contribute names or features.

---

**Legend**:
- `Added` - New features
- `Changed` - Changes to existing functionality
- `Deprecated` - Soon-to-be removed features
- `Removed` - Removed features
- `Fixed` - Bug fixes
- `Security` - Vulnerability fixes
