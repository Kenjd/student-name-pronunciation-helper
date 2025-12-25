# Changelog

All notable changes to the Student Name Pronunciation Helper will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.1.0] - 2025-12-25 (Feature Update & Deployment)

### Added

#### Persistent Saved Names Feature
- **"Keep Permanent" star icon** for saved names
  - Click star icon to mark names as permanent (gold star ★) or temporary (gray outline star ☆)
  - Permanent names survive when "Clear All Saved Names" is clicked
  - Gives teachers autonomy to build their own permanent collection across semesters
  - Default: New names are temporary (teachers explicitly star the ones they want to keep)
  - One-click toggle with immediate persistence
  - Confirmation notifications: "Marked [name] as permanent" or "Unmarked [name]"
- **Enhanced Clear All behavior**
  - Filters to keep permanent names instead of deleting everything
  - Shows informative message: "Cleared X temporary names. Kept Y permanent names."
  - Falls back to clearing all if no permanent names exist

#### Congolese Dictionary (DRC)
- **First dictionary entry**: Abiung (student-verified pronunciation)
  - Student reached out requesting representation
  - Verified pronunciation via audio recording: "A-bi-yung" (3 syllables)
  - Last syllable: "yung" (like start of "young" but clipped, NOT full "young")
  - Pattern-based fallback rules for other Congolese names
- **Added to origin dropdown**: "Congolese (DRC)"
- **Auto-detection** for Congolese names in dictionary
- **Total dictionaries**: Now 18 languages (was 17)

#### Enhanced Help Tab
- **Collapsible FAQ structure** using native HTML `<details>` tags
  - Quick Start (1-2 minutes) - 6-step walkthrough
  - Common Questions - 6 nested collapsibles covering frequent user questions
  - Troubleshooting - 4 nested collapsibles for technical issues
  - Advanced Features - 5 nested collapsibles for power users
- **Critical warning at top**: "The Student Is Always Right" - emphasizes app is starting point
- **Best Practices footer** with 6 key recommendations
- **Scannable design** with icons and color-coding
- **Mobile-friendly** - works on all devices
- **Documents new features**: Permanent stars, pagination fix, Congolese dictionary

#### Deployment Support
- **ShinyApps.io compatibility**
  - Dynamic Python path detection (supports deployment)
  - `requirements.txt` for Python dependencies
  - `runtime.txt` specifying Python version
  - `.rscignore` to exclude documentation files
- **Warning banner on shinyapps.io**
  - Auto-detects when running on shinyapps.io
  - Explains ElevenLabs limitation (Python dependencies not supported)
  - Directs users to GitHub for full functionality
  - Standard Voice works perfectly on shinyapps.io

### Fixed

#### Pagination Persistence
- **Fixed "star toggle resets to page 1" issue**
  - Implemented reactive trigger pattern to control table re-renders
  - Uses DT proxy with `replaceData(resetPaging = FALSE)` for star toggles
  - Table only fully re-renders when necessary (add/delete rows, clear all)
  - Star toggles now preserve current page, search state, and sort order
  - Eliminates unnecessary clicking when marking multiple names on page 2+

#### Python Path Resolution
- **Removed hardcoded Python path** (`/opt/miniconda3/bin/python3`)
- **Dynamic detection** using `Sys.which()` for deployment compatibility
- **Graceful error** when Python unavailable
- **No deployment warnings** - all paths are relative or dynamically resolved

### Changed

- **Help tab title** changed from "How to Use This App" to "Help & FAQ"
- **Help tab organization** completely restructured with collapsible sections
- **Settings tab** now shows warning banner when on shinyapps.io (ElevenLabs unavailable)

### Technical Details

**Files Added:**
- `requirements.txt` - Python dependencies for deployment
- `runtime.txt` - Python version specification
- `.rscignore` - Deployment file exclusions
- `deploy_clean/` directory - Clean deployment staging area

**Modified Files:**
- `name_pronunciation_app.r`:
  - Added `Keep_Permanent` column to saved names schema (~80 lines)
  - Added Congolese phonetic function (~50 lines)
  - Added reactive trigger for pagination fix (~15 lines)
  - Restructured Help tab with collapsible FAQ (~200 lines)
  - Added shinyapps.io detection warning (~25 lines)
  - Updated Python path detection (~10 lines modified)

**Performance:**
- No impact on load time or memory usage
- Pagination fix improves user experience with large saved name lists

### Deployment

**ShinyApps.io Status:**
- ✅ App successfully deployed to shinyapps.io
- ✅ Standard Voice (browser TTS) works perfectly
- ✅ All dictionaries and features work (except ElevenLabs Premium)
- ❌ ElevenLabs Premium unavailable (Python dependencies not supported for hybrid R+Python apps)
- **Solution**: Users directed to run locally for full ElevenLabs functionality

---

## [2.0.0] - 2025-12-23 (Major Feature Release)

### Added

#### Bulk Upload & PDF Generation (Major New Feature)
- **Bulk upload tab** for processing multiple names at once
  - Supports CSV, Excel (.xlsx, .xls), and plain text files
  - Process up to 200 names per upload
  - Auto-detects origin or uses provided origin column
- **PDF generation** creates professional pronunciation guides
  - Includes: Student Name, Phonetic Guide, IPA Notation, Origin/Language
  - Landscape letter-size format optimized for printing
  - Proper Unicode/IPA support using Cairo PDF device
  - Filename: `name_pronunciation_guide_YYYY-MM-DD.pdf`
- **CSV export** for spreadsheet integration
  - Same data as PDF in CSV format
  - Import into gradebooks or Google Sheets
  - Filename: `name_pronunciation_guide_YYYY-MM-DD.csv`
- **Template CSV download** for new users
  - Pre-filled example with 5 sample names
  - Shows correct format for uploads
  - Filename: `name_list_template.csv`
- **Save to Saved Names** integration
  - One-click to add all processed names to Saved Names table
  - Skips duplicates automatically
  - Adds note "Added via bulk upload"
- **Clear results button** to reset for new upload

#### Dictionary Expansion (850+ names across 17 languages)
- **Phase 1**: Added 4 Asian/Middle Eastern languages (200 names)
  - Chinese (Mandarin): 50 names
  - Vietnamese: 50 names
  - Korean: 50+ names
  - Arabic: 49 names
- **Phase 2**: Added 8 European/Global languages (398 names)
  - Italian: 50 names
  - French: 50 names
  - Polish: 50 names
  - German: 50 names
  - Portuguese (Brazilian): 50 names
  - Japanese (Romaji): 48 names
  - Russian (transliterated): 50 names
  - Hebrew (transliterated): 50 names
- **Total expansion**: From 220 names (5 languages) to 850+ names (17 languages)
- All dictionaries include dual phonetics (standard/premium) and IPA notation

#### Enhanced Name Management
- **Delete individual saved names** with trash icon
  - Confirmation dialog before deletion
  - Shows "Deleted: [name]" notification
  - No longer need to clear all names to remove one
- **Delete column** in Saved Names table

### Changed
- **IPA notation accuracy significantly improved**
  - Now uses `arpabet_to_ipa()` conversion for proper IPA symbols
  - Dictionary entries convert CMU Arpabet to true IPA (e.g., /ʃɪvɔn/ instead of /sio.bhän/)
  - Applies to all dictionary names and CMU lookups
- **PDF rendering** now uses Cairo device for proper Unicode display
  - Fixes IPA character rendering issues
  - No more "conversion failure" warnings
  - All special phonetic symbols display correctly
- **Bulk preview table** shows IPA column
- **Updated package dependencies**:
  - Added: `readxl` (Excel file reading)
  - Added: `gridExtra` (PDF table creation)
  - Added: `grid` (PDF graphics)

### Technical Details

**New Files:**
- Test files created: `test_names.csv`, `test_names.txt`

**Modified Files:**
- `name_pronunciation_app.r`: ~600 lines added
  - Bulk upload UI (80 lines)
  - File parsing function (80 lines)
  - Batch processing function (70 lines)
  - CSV/PDF download handlers (100 lines)
  - Observers for bulk operations (120 lines)
  - Delete functionality (30 lines)
  - IPA conversion fixes (10 lines)
  - Dictionary expansions (already present from Phase 1 & 2)

**Performance:**
- File size: 4,250 lines (was 3,775 in v1.0)
- Load time: No measurable impact
- Memory usage: Minimal (~90KB for all dictionaries)

### Fixed
- IPA notation now displays proper phonetic symbols instead of transliteration
- PDF Unicode rendering errors resolved
- Cairo PDF device eliminates "mbcsToSbcs" conversion warnings

---

## [1.0.0] - 2025-12-17 (Initial Release)

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
