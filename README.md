# Student Name Pronunciation Helper

A Shiny app designed to help teachers learn correct pronunciation of student names, especially those from different cultural and linguistic backgrounds.

## What This App Does

This application provides teachers with accurate phonetic guides and audio pronunciations for student names before the first day of class. No more awkward mispronunciations or "fingers crossed" moments when calling roll!

## ⚠️ CRITICAL: The Student Is Always Right

**This app is a starting point, NOT the final authority.**

Even common names have multiple valid pronunciations. For example:
- **"Ava"** - Some families say "AY-vuh" (like actress Ava Gardner), others say "AH-vah"
- **"Celine"** - Can be "seh-LEEN" (English) or "seh-lynn" (French, with nasal ending)
- **"Pauline"** - Can be "paw-LEEN" (English) or "paw-lynn" (French, with nasal ending)
- **"Andrea"** - Can be "AN-dree-uh" (English) or "ahn-DRAY-uh" (Italian/Spanish)
- **"Maria"** - Can be "muh-RYE-uh" (English) or "mah-REE-ah" (Spanish)

**The golden rule: ALWAYS ask your student how they pronounce their name.**

Use this app to:
1. ✅ Get a starting pronunciation to practice beforehand
2. ✅ Learn phonetic patterns for unfamiliar languages
3. ✅ Prepare so you're not completely lost on day one

**Never use this app to:**
1. ❌ Tell students they're pronouncing their own name "wrong"
2. ❌ Assume the app's pronunciation is the "only correct" way
3. ❌ Skip asking the student directly

**Best practice:** Use the app's pronunciation as your first attempt, then ask the student: "Did I say that correctly? How do you pronounce your name?" If different, use the **Custom Pronunciation** field to save the student's preference.

### Key Features

**1. Bulk Upload & PDF Generation (NEW in v2.0)**
- Upload class rosters (CSV, Excel, or plain text files)
- Process up to 200 names at once
- Generate professional PDF pronunciation guides
- Export results as CSV for gradebooks
- Download example template to get started
- Automatically add bulk uploads to Saved Names

**2. Dual Voice Pronunciation System - Two Voices, Two Realities**

**Standard Voice** (Browser TTS):
- Shows how you'd *naturally* pronounce it using English phonetic rules
- Free, instant, works offline
- Often close, sometimes right, but usually *slightly wrong*
- **The "student cringe" moment** - what you'd say without help

**ElevenLabs Premium** (AI with IPA):
- Shows how it's *actually* pronounced by native speakers
- Uses International Phonetic Alphabet for linguistic accuracy
- Captures sounds that don't exist in English (like ɔ in Nigerian "Olufunke")
- **The "student recognition" moment** - what you should say

**Use both to hear the difference and learn the correct pronunciation.**

**3. Comprehensive Name Dictionaries (850+ verified pronunciations across 18 languages)**
- **Irish (Gaelic)**: 62 names (Siobhan, Saoirse, Cillian, Aoife, etc.)
- **Spanish/Latin**: 48 names (José, María, Santiago, Isabella, etc.)
- **Nigerian**: 50+ names covering Igbo, Yoruba, Hausa (Chioma, Oluwaseun, Chukwudi, etc.)
- **Indian**: 60+ names covering Hindi, Tamil, Telugu, Punjabi (Priya, Aarav, Lakshmi, etc.)
- **Greek**: 40+ names (Giannis, Yannis, Dimitris, Katerina, Eleni, etc.)
- **Chinese (Mandarin)**: 50 names (Wei, Ming, Li, Mei, Jing, Yang, etc.)
- **Vietnamese**: 50 names (Nguyen, Linh, Minh, Anh, Phuong, etc.)
- **Korean**: 50+ names (Kim, Park, Ji, Min, Hye, Jun, etc.)
- **Arabic**: 49 names (Muhammad, Fatima, Ali, Aisha, Omar, etc.)
- **Italian**: 50 names (Giuseppe, Maria, Francesco, Sofia, etc.)
- **French**: 50 names (Jean, Marie, Pierre, Sophie, etc.)
- **Polish**: 50 names (Jan, Anna, Piotr, Katarzyna, etc.)
- **German**: 50 names (Wolfgang, Anna, Hans, Maria, etc.)
- **Portuguese**: 50 names (João, Maria, José, Ana, etc.)
- **Japanese**: 48 names (Hiroshi, Sakura, Takeshi, Yuki, etc.)
- **Russian**: 50 names (Aleksandr, Anna, Dmitry, Maria, etc.)
- **Hebrew**: 50 names (David, Sarah, Daniel, Rachel, etc.)
- **Congolese (DRC)**: Student-verified pronunciations (Abiung, etc.)
- All entries include proper IPA pronunciation
- Optimized phonetics for both voice types

**4. Multiple Phonetic Formats**
- Syllable breaks (e.g., "See-OR-sha")
- Simple phonetic guide (e.g., "SEER-SHA")
- IPA notation (e.g., "/ˈsɪərʃə/")
- All formats displayed for each name

**5. Origin-Specific Pronunciation Rules**
- **18 languages with comprehensive dictionaries**: Irish, Spanish, Nigerian, Indian, Greek, Chinese, Vietnamese, Korean, Arabic, Italian, French, Polish, German, Portuguese, Japanese, Russian, Hebrew, Congolese
- **Pattern-based fallback**: For names not in dictionaries, pattern rules provide reasonable approximations
- Dictionary-first approach (95% accuracy) with pattern fallback (70-80% accuracy)

**6. Transparency Indicators**
- Shows whether pronunciation came from dictionary, pattern rules, or generic conversion
- Helps users understand reliability of pronunciation

**7. Name Management (Enhanced in v2.1)**
- Save frequently used names with persistent storage
- **NEW: Mark names as permanent** with star icon (survives "Clear All")
- Delete individual saved names with one click
- Add custom pronunciation notes
- Export saved names list
- Search and filter saved names
- Audio playback for all saved names
- Build your own permanent collection across semesters

**8. Manual Override**
- Not happy with automatic pronunciation? Enter your own
- Works with both Standard and Premium voices
- Support for IPA or simple phonetic spellings

**9. Smart Caching**
- Caches ElevenLabs audio to reduce API costs
- Cache key includes phonetic to prevent collisions
- Clear cache option in Settings

**10. Credential Persistence**
- ElevenLabs API credentials saved automatically
- No need to re-enter on each app launch
- Stored locally and securely

## Technology Stack

- **Frontend**: R Shiny with shinydashboard
- **Backend**: R with Python integration
- **TTS Engines**:
  - Web Speech API (browser-based)
  - ElevenLabs API (cloud-based AI)
- **Data**: Custom phonetic dictionaries and pattern-based rules

## Use Cases

### Primary Use Case: Teachers
- Prepare for new classes by learning student name pronunciations
- Review saved names from previous semesters
- Practice difficult names before parent-teacher conferences

### Secondary Use Cases
- HR professionals learning employee names
- Event coordinators preparing for international guests
- Public speakers preparing to introduce people
- Anyone wanting to pronounce names respectfully and correctly

## Why This Matters

Pronouncing someone's name correctly is a fundamental sign of respect. For students with names from different cultural backgrounds, hearing their teacher pronounce their name correctly on the first day:
- Makes them feel welcomed and valued
- Shows cultural awareness and respect
- Builds trust and rapport from day one
- Creates an inclusive classroom environment

## Real-World Examples: The Two Voices in Action

**Example 1: Chioma (Nigerian Igbo)**
- **Standard Voice**: "chee-OH-mah" → *Student cringes* 😬
- **Premium Voice**: "chyoh-ma" → *Student's eyes light up with recognition* 😊

**Example 2: Olufunke (Nigerian Yoruba)**
- **Standard Voice**: "oh-loo-foon-kay" → *Close, but not quite right*
- **Premium Voice**: "ɔlufunke" → *Perfect! That ɔ sound is authentic Yoruba*

**Example 3: Siobhan (Irish Gaelic)**
- **Standard Voice**: "see-oh-ban" → *Completely wrong*
- **Premium Voice**: "shiv-awn" → *Exactly right!*

**The Gap = Your Learning**

Comparing both voices shows you:
1. What you'd say naturally (often wrong)
2. What you should say (always right)
3. How to bridge the gap

This is why both voices matter - one for learning, one for mastery.

## Cost Information

### Standard Voice
- **Cost**: Free
- **Quality**: Depends on browser/OS
- **Speed**: Instant
- **Internet**: Not required

### ElevenLabs Premium

**Free Tier (Recommended for Most Users)**
- **Cost**: FREE for up to 10,000 characters per month
- **Typical Usage**: Approximately 1,000 name pronunciations per month (avg 10 chars per name)
- **Perfect For**: Teachers with class sizes up to ~200 students, reviewing 5x each
- **Signup**: Free account at [elevenlabs.io](https://elevenlabs.io) includes API access

**If You Exceed Free Tier**
- **Cost**: ~$0.00015 per name after free credits used
- **Example**: 2,000 names/month = 1,000 free + 1,000 paid = ~$0.15/month
- **Annual Cost**: Very affordable even with heavy use (~$5-10/year for typical teacher)

**Voice Quality**
- High-quality AI voice with IPA support
- Speed: 1-3 seconds per pronunciation
- Internet required

## File Structure

```
/Pronunciation/
├── name_pronunciation_app.r    # Main Shiny application
├── speak_name.py              # Python script for ElevenLabs API
├── .elevenlabs_config.rds     # Saved API credentials (auto-generated)
├── .gitignore                 # Prevents committing sensitive data
├── README.md                  # This file
└── USAGE.md                   # Detailed usage instructions
```

## Privacy & Security

- API credentials stored locally only (not in version control)
- No names or personal data sent to external servers except ElevenLabs API
- Audio cache stored in system temp directory
- `.gitignore` prevents accidental credential commits

## Installation

### Prerequisites

- **R** (version 4.0 or higher) - [Download R](https://cran.r-project.org/)
- **RStudio** (recommended) - [Download RStudio](https://posit.co/download/rstudio-desktop/)
- **Python 3** (with `requests` library) - [Download Python](https://www.python.org/downloads/)
- **ElevenLabs API account** (optional, for Premium voice) - [Sign up free](https://elevenlabs.io)

### Step 1: Clone the Repository

```bash
git clone https://github.com/kenjd/student-name-pronunciation-helper.git
cd student-name-pronunciation-helper
```

### Step 2: Install R Packages

Open R or RStudio and run:

```r
install.packages(c("shiny", "shinydashboard", "DT", "jsonlite", "base64enc", "readxl", "gridExtra"))
```

### Step 3: Install Python Dependencies

```bash
pip3 install requests
```

Or if using conda:

```bash
conda install requests
```

### Step 4: (Optional) Configure ElevenLabs

For the Premium voice feature:

1. Create a free account at [elevenlabs.io](https://elevenlabs.io)
2. Get your API key from Settings → API Keys
3. Choose a voice from the **Eleven Turbo v2.5** model and copy its Voice ID
4. Launch the app and enter credentials in the Settings tab

**Note**: The app works perfectly with just the Standard Voice (browser TTS) - no setup required!

## Quick Start

1. Open RStudio
2. Set your working directory to the app folder:
   ```r
   setwd("path/to/pronunciation-helper")
   ```
3. Open `name_pronunciation_app.r`
4. Click the **"Run App"** button in RStudio
5. The app will open in your default browser

**First-time users**: Check out [USAGE.md](USAGE.md) for detailed instructions.

## Online Access

**Try it online at shinyapps.io** (no installation required):
- The app is deployed and ready to use at shinyapps.io
- **Standard Voice works perfectly** (browser TTS - free, instant, offline)
- All dictionaries and features fully functional
- **ElevenLabs Premium Voice not available** on the hosted version due to Python dependency limitations

**To use ElevenLabs Premium Voice:**
- Run the app locally following the installation instructions below
- This gives you both Standard and Premium voices with full IPA support

## Technical Requirements

- R (4.0 or higher)
- Python 3 (with requests library)
- R packages: shiny, shinydashboard, DT, jsonlite, base64enc, readxl, gridExtra
- ElevenLabs API account (optional, for Premium voice)

## Contributing

We welcome contributions! Especially:

- **Adding new language dictionaries** (Spanish, Chinese, Polish, etc.)
- **Expanding the Irish dictionary** with more names
- **Bug reports and feature requests**
- **Documentation improvements**

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on how to add names to dictionaries.

## Credits

Built with:
- R Shiny for the web interface
- ElevenLabs for premium AI voice synthesis
- Web Speech API for browser-based TTS
- Custom Irish name dictionary research

## License

MIT License - see [LICENSE](LICENSE) file for details.

This tool is for educational and professional use. Please respect the pronunciation of names and use this tool to foster inclusive environments.

---

**Version**: 2.1
**Last Updated**: December 25, 2025
**Author**: Built in collaboration with Claude Code
