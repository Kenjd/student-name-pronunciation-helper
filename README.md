# Student Name Pronunciation Helper

A Shiny app designed to help teachers learn correct pronunciation of student names, especially those from different cultural and linguistic backgrounds.

## What This App Does

This application provides teachers with accurate phonetic guides and audio pronunciations for student names before the first day of class. No more awkward mispronunciations or "fingers crossed" moments when calling roll!

### Key Features

**1. Dual Voice Pronunciation System - Two Voices, Two Realities**

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

**2. Comprehensive Name Dictionaries**
- **Irish (Gaelic)**: 62 common names (Siobhan, Saoirse, Cillian, Aoife, etc.)
- **Spanish/Latin**: 48 names from Spain, Mexico, and Latin America (José, María, Santiago, Isabella, etc.)
- **Nigerian**: 50+ names covering Igbo, Yoruba, and Hausa (Chioma, Oluwaseun, Chukwudi, etc.)
- **Indian**: 60+ names covering Hindi, Tamil, Telugu, Punjabi (Priya, Aarav, Lakshmi, etc.)
- All entries include proper IPA pronunciation
- Optimized phonetics for both voice types

**3. Multiple Phonetic Formats**
- Syllable breaks (e.g., "See-OR-sha")
- Simple phonetic guide (e.g., "SEER-SHA")
- IPA notation (e.g., "/ˈsɪərʃə/")
- All formats displayed for each name

**4. Origin-Specific Pronunciation Rules**
- Select from 15+ language origins (Irish, Spanish, Chinese, Italian, German, Polish, etc.)
- Pattern-based phonetic conversion for languages
- Dictionary-first approach with pattern fallback

**5. Transparency Indicators**
- Shows whether pronunciation came from dictionary, pattern rules, or generic conversion
- Helps users understand reliability of pronunciation

**6. Name Management**
- Save frequently used names
- Add custom pronunciation notes
- Export saved names list
- Search and filter saved names

**7. Manual Override**
- Not happy with automatic pronunciation? Enter your own
- Works with both Standard and Premium voices
- Support for IPA or simple phonetic spellings

**8. Smart Caching**
- Caches ElevenLabs audio to reduce API costs
- Cache key includes phonetic to prevent collisions
- Clear cache option in Settings

**9. Credential Persistence**
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
install.packages(c("shiny", "shinydashboard", "DT", "jsonlite", "base64enc", "digest"))
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

## Technical Requirements

- R (4.0 or higher)
- Python 3 (with requests library)
- R packages: shiny, shinydashboard, DT, jsonlite, base64enc, digest
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

**Version**: 1.0
**Last Updated**: December 2025
**Author**: Built with Claude Code
