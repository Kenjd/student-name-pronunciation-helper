

# Required Libraries
library(shiny)
library(shinydashboard)
library(DT)
library(jsonlite)
library(base64enc)  # For encoding audio files
library(readxl)      # For Excel file reading
library(gridExtra)   # For PDF table creation
library(grid)        # For PDF grid graphics

# ============================================================================
# CMU PRONOUNCING DICTIONARY SUPPORT
# ============================================================================

# Load and cache CMU dictionary (only loads once per session)
CMU_DICT <- NULL

load_cmu_dictionary <- function() {
  if (!is.null(CMU_DICT)) {
    return(CMU_DICT)
  }

  dict_path <- file.path(getwd(), "cmudict-0.7b.txt")

  if (!file.exists(dict_path)) {
    warning("CMU dictionary not found. English name pronunciation will be limited.")
    return(NULL)
  }

  tryCatch({
    # Read the dictionary file
    lines <- readLines(dict_path, warn = FALSE)

    # Filter out comments and empty lines
    lines <- lines[nchar(lines) > 0 & !startsWith(lines, ";;;")]

    # Vectorized parsing: split each line on first space
    first_spaces <- regexpr(" ", lines)
    valid_lines <- first_spaces > 0

    words <- tolower(substr(lines[valid_lines], 1, first_spaces[valid_lines] - 1))
    phonemes <- trimws(substr(lines[valid_lines], first_spaces[valid_lines] + 1, nchar(lines[valid_lines])))

    # Remove variant numbers like (2), (3) from words
    words <- gsub("\\([0-9]\\)", "", words)

    # Create named list (fast vectorized approach)
    dict <- setNames(as.list(phonemes), words)

    CMU_DICT <<- dict
    message(sprintf("Loaded CMU dictionary with %d entries", length(dict)))
    return(dict)
  }, error = function(e) {
    warning(sprintf("Error loading CMU dictionary: %s", e$message))
    return(NULL)
  })
}

# Convert ARPAbet to IPA (International Phonetic Alphabet)
arpabet_to_ipa <- function(arpabet) {
  # ARPAbet to IPA mapping
  # Reference: https://en.wikipedia.org/wiki/ARPABET

  arpabet_map <- list(
    # Vowels (remove stress markers 0,1,2)
    "AA" = "ɔ",     # John    JH AA1 N (using ɔ for better TTS pronunciation)
    "AE" = "æ",     # at      AE T
    "AH" = "ʌ",     # hut     HH AH T (stressed)
    "AO" = "ɔ",     # ought   AO T
    "AW" = "aʊ",    # cow     K AW
    "AY" = "aɪ",    # hide    HH AY D
    "EH" = "ɛ",     # Ed      EH D
    "ER" = "ɝ",     # hurt    HH ER T
    "EY" = "eɪ",    # ate     EY T
    "IH" = "ɪ",     # it      IH T
    "IY" = "i",     # eat     IY T
    "OW" = "oʊ",    # oat     OW T
    "OY" = "ɔɪ",    # toy     T OY
    "UH" = "ʊ",     # hood    HH UH D
    "UW" = "u",     # two     T UW

    # Consonants
    "B" = "b",
    "CH" = "tʃ",
    "D" = "d",
    "DH" = "ð",     # then    DH EH N
    "F" = "f",
    "G" = "g",
    "HH" = "h",
    "JH" = "dʒ",    # gee     JH IY
    "K" = "k",
    "L" = "l",
    "M" = "m",
    "N" = "n",
    "NG" = "ŋ",     # ping    P IH NG
    "P" = "p",
    "R" = "r",
    "S" = "s",
    "SH" = "ʃ",     # she     SH IY
    "T" = "t",
    "TH" = "θ",     # theta   TH EY T AH
    "V" = "v",
    "W" = "w",
    "Y" = "j",
    "Z" = "z",
    "ZH" = "ʒ"      # seizure S IY ZH ER
  )

  # Split into phonemes
  phonemes <- strsplit(arpabet, " ")[[1]]
  vowels <- c("AA", "AE", "AH", "AO", "AW", "AY", "EH", "ER", "EY", "IH", "IY", "OW", "OY", "UH", "UW")

  # First pass: find syllable boundaries (vowels mark syllables)
  # Find the position before which to place stress markers
  syllable_starts <- c(1)  # First phoneme starts first syllable
  for (i in 2:length(phonemes)) {
    prev_base <- gsub("[0-2]$", "", phonemes[i-1])
    curr_base <- gsub("[0-2]$", "", phonemes[i])

    # New syllable starts when we hit a vowel after a consonant
    if (curr_base %in% vowels && !(prev_base %in% vowels)) {
      # Find where this syllable actually starts (go back to find consonant cluster start)
      syl_start <- i
      for (j in (i-1):max(1, i-3)) {
        check_base <- gsub("[0-2]$", "", phonemes[j])
        if (check_base %in% vowels) {
          break
        }
        syl_start <- j
      }
      syllable_starts <- c(syllable_starts, syl_start)
    }
  }

  # Second pass: identify where stress markers should go (at syllable starts)
  stress_at_position <- rep(NA, length(phonemes))
  for (i in seq_along(phonemes)) {
    phoneme_base <- gsub("[0-2]$", "", phonemes[i])
    if (phoneme_base %in% vowels) {
      if (grepl("1$", phonemes[i])) {
        # Find the start of this syllable
        syl_start <- syllable_starts[max(which(syllable_starts <= i))]
        stress_at_position[syl_start] <- "primary"
      } else if (grepl("2$", phonemes[i])) {
        syl_start <- syllable_starts[max(which(syllable_starts <= i))]
        stress_at_position[syl_start] <- "secondary"
      }
    }
  }

  # Third pass: build IPA string
  ipa_result <- ""
  for (i in seq_along(phonemes)) {
    # Add stress marker if this position marks a stressed syllable start
    if (!is.na(stress_at_position[i])) {
      if (stress_at_position[i] == "primary") {
        ipa_result <- paste0(ipa_result, "ˈ")
      } else if (stress_at_position[i] == "secondary") {
        ipa_result <- paste0(ipa_result, "ˌ")
      }
    }

    # Convert phoneme to IPA
    phoneme_base <- gsub("[0-2]$", "", phonemes[i])
    if (!is.null(arpabet_map[[phoneme_base]])) {
      # Special handling for unstressed AH -> schwa (ə)
      if (phoneme_base == "AH" && grepl("0$", phonemes[i])) {
        ipa_result <- paste0(ipa_result, "ə")
      } else {
        ipa_result <- paste0(ipa_result, arpabet_map[[phoneme_base]])
      }
    } else {
      # Unknown phoneme, keep as-is
      ipa_result <- paste0(ipa_result, phoneme_base)
    }
  }

  return(paste0("/", ipa_result, "/"))
}

# Convert ARPAbet to clean respelling for ElevenLabs (no stress markers)
arpabet_to_respelling <- function(arpabet) {
  # Simpler conversion that ElevenLabs can handle
  # Group into syllables and capitalize stressed syllables

  respelling_map <- list(
    # Vowels (more natural English spelling)
    "AA" = "aw",
    "AE" = "a",
    "AH" = "uh",
    "AO" = "aw",
    "AW" = "ow",
    "AY" = "eye",
    "EH" = "eh",
    "ER" = "er",
    "EY" = "ay",
    "IH" = "ih",
    "IY" = "ee",
    "OW" = "oh",
    "OY" = "oy",
    "UH" = "uh",
    "UW" = "oo",

    # Consonants
    "B" = "b",
    "CH" = "ch",
    "D" = "d",
    "DH" = "th",
    "F" = "f",
    "G" = "g",
    "HH" = "h",
    "JH" = "j",
    "K" = "k",
    "L" = "l",
    "M" = "m",
    "N" = "n",
    "NG" = "ng",
    "P" = "p",
    "R" = "r",
    "S" = "s",
    "SH" = "sh",
    "T" = "t",
    "TH" = "th",
    "V" = "v",
    "W" = "w",
    "Y" = "y",
    "Z" = "z",
    "ZH" = "zh"
  )

  # Vowels that mark syllable centers
  vowels <- c("AA", "AE", "AH", "AO", "AW", "AY", "EH", "ER", "EY", "IH", "IY", "OW", "OY", "UH", "UW")

  # Split into phonemes
  phonemes <- strsplit(arpabet, " ")[[1]]

  # Build syllables: group consonants with following vowel
  syllables <- list()
  current_syllable <- list(phonemes = c(), stressed = FALSE)

  for (i in seq_along(phonemes)) {
    phoneme <- phonemes[i]
    phoneme_base <- gsub("[0-2]$", "", phoneme)
    is_vowel <- phoneme_base %in% vowels
    is_stressed <- grepl("1$", phoneme)

    # Add phoneme to current syllable
    current_syllable$phonemes <- c(current_syllable$phonemes, phoneme)

    if (is_vowel) {
      current_syllable$stressed <- is_stressed

      # Look ahead: if next phoneme is consonant followed by vowel, end syllable here
      if (i < length(phonemes)) {
        next_phoneme_base <- gsub("[0-2]$", "", phonemes[i + 1])
        next_is_vowel <- next_phoneme_base %in% vowels

        # If next is consonant, check if there's a vowel after it
        if (!next_is_vowel && i + 1 < length(phonemes)) {
          after_next_base <- gsub("[0-2]$", "", phonemes[i + 2])
          after_next_is_vowel <- after_next_base %in% vowels

          # End syllable after this vowel if next phoneme starts new syllable
          if (after_next_is_vowel) {
            syllables[[length(syllables) + 1]] <- current_syllable
            current_syllable <- list(phonemes = c(), stressed = FALSE)
          }
        } else if (next_is_vowel) {
          # Next is vowel, so end syllable here
          syllables[[length(syllables) + 1]] <- current_syllable
          current_syllable <- list(phonemes = c(), stressed = FALSE)
        }
      }
    }
  }

  # Add final syllable if not empty
  if (length(current_syllable$phonemes) > 0) {
    syllables[[length(syllables) + 1]] <- current_syllable
  }

  # Convert syllables to respelling
  result_parts <- c()
  for (syl in syllables) {
    syl_text <- ""
    for (phoneme in syl$phonemes) {
      phoneme_base <- gsub("[0-2]$", "", phoneme)
      if (!is.null(respelling_map[[phoneme_base]])) {
        syl_text <- paste0(syl_text, respelling_map[[phoneme_base]])
      }
    }

    # Capitalize if stressed
    if (syl$stressed) {
      syl_text <- toupper(syl_text)
    }

    result_parts <- c(result_parts, syl_text)
  }

  return(paste(result_parts, collapse = "-"))
}

# Lookup name in CMU dictionary
cmu_lookup <- function(name) {
  dict <- load_cmu_dictionary()
  if (is.null(dict)) {
    return(NULL)
  }

  name_lower <- tolower(trimws(name))

  # Direct lookup
  if (!is.null(dict[[name_lower]])) {
    arpabet <- dict[[name_lower]]
    return(list(
      arpabet = arpabet,
      ipa = arpabet_to_ipa(arpabet),
      respelling = arpabet_to_respelling(arpabet),
      from_cmu = TRUE
    ))
  }

  return(NULL)
}

# ============================================================================
# Language-specific phonetic conversion functions
# ============================================================================

# Irish (Gaelic) phonetic rules
# Returns BOTH standard and premium voice optimized spellings
apply_irish_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE IRISH NAME DICTIONARY
  # Each entry: standard = browser TTS optimized, premium = Fish Audio optimized
  # Standard: natural flow, minimal hyphens | Premium: clear syllable breaks

  irish_dictionary <- list(
    # Common Female Names
    "siobhan" = list(standard = "shevawn", premium = "she-vawn", ipa = "SH IH1 V AO0 N"),
    "saoirse" = list(standard = "seersha", premium = "seer-sha", ipa = "S IH1 R SH AH0"),
    "niamh" = list(standard = "neev", premium = "neev", ipa = "N IY1 V"),
    "aoife" = list(standard = "eefa", premium = "ee-fa", ipa = "IY1 F AH0"),
    "caoimhe" = list(standard = "keeva", premium = "kee-va", ipa = "K W IY1 V AH0"),
    "sinead" = list(standard = "shinaid", premium = "shi-nade", ipa = "SH IH1 N EY0 D"),
    "roisin" = list(standard = "rosheen", premium = "ro-sheen", ipa = "R OW1 SH IY0 N"),
    "aisling" = list(standard = "ashling", premium = "ash-ling", ipa = "AE1 SH L IH0 NG"),
    "ciara" = list(standard = "keera", premium = "keer-a", ipa = "K IH1 R AH0"),
    "grainne" = list(standard = "grawnye", premium = "grawn-ya", ipa = "G R AO1 N Y AH0"),
    "orla" = list(standard = "orla", premium = "or-la", ipa = "AO1 R L AH0"),
    "maeve" = list(standard = "mayve", premium = "mayve", ipa = "M EY1 V"),
    "brigid" = list(standard = "breejid", premium = "bree-jid", ipa = "B R IH1 JH IH0 D"),
    "eimear" = list(standard = "eemer", premium = "ee-mer", ipa = "IY1 M ER0"),
    "clodagh" = list(standard = "cloda", premium = "klo-da", ipa = "K L OW1 D AH0"),
    "mairead" = list(standard = "maraid", premium = "ma-raid", ipa = "M OY1 R AH0"),
    "nuala" = list(standard = "noola", premium = "noo-la", ipa = "N UW1 L AH0"),
    "oonagh" = list(standard = "oona", premium = "oo-na", ipa = "UW1 N AH0"),
    "deirdre" = list(standard = "deerdra", premium = "deer-dra", ipa = "D IH1 R D R AH0"),
    "sorcha" = list(standard = "sorka", premium = "sor-ka", ipa = "S AO1 R K AH0"),
    "treasa" = list(standard = "trassa", premium = "tras-sa", ipa = "T R AE1 S AH0"),
    "fionnuala" = list(standard = "finnoola", premium = "fin-noo-la", ipa = "F IH1 N UW0 L AH0"),
    "sadhbh" = list(standard = "sive", premium = "sive", ipa = "S AY1 V"),
    "orlaith" = list(standard = "orla", premium = "or-la", ipa = "AO1 R L AH0"),
    "meadhbh" = list(standard = "mayve", premium = "mayve", ipa = "M EY1 V"),
    "brid" = list(standard = "breed", premium = "breed", ipa = "B R IY1 D"),
    "siofra" = list(standard = "sheefra", premium = "shee-fra", ipa = "SH IY1 F R AH0"),
    "laoise" = list(standard = "leesha", premium = "lee-sha", ipa = "L IY1 SH AH0"),
    "muireann" = list(standard = "mweerun", premium = "mweer-an", ipa = "M W IY1 R AH0 N"),
    "aine" = list(standard = "awnya", premium = "awn-ya", ipa = "AO1 N Y AH0"),
    "eilis" = list(standard = "aylish", premium = "ay-lish", ipa = "EY1 L IH0 SH"),
    "eabha" = list(standard = "ayva", premium = "ay-va", ipa = "EY1 V AH0"),
    "cliona" = list(standard = "kleena", premium = "klee-na", ipa = "K L IY1 OW0 N AH0"),

    # Common Male Names
    "cian" = list(standard = "keeun", premium = "kee-an", ipa = "K IY1 AH0 N"),
    "eoin" = list(standard = "owen", premium = "oh-in", ipa = "OW1 IH0 N"),
    "tadgh" = list(standard = "tieg", premium = "tie-g", ipa = "T AY1 G"),
    "tadhg" = list(standard = "tieg", premium = "tie-g", ipa = "T AY1 G"),
    "oisin" = list(standard = "usheen", premium = "uh-sheen", ipa = "AH0 SH IY1 N"),
    "niall" = list(standard = "nile", premium = "nile", ipa = "N IY1 AH0 L"),
    "padraig" = list(standard = "pawdrig", premium = "paw-drig", ipa = "P AE1 T R IH0 K"),
    "seamus" = list(standard = "shaymuss", premium = "shay-mus", ipa = "SH EY1 M AH0 S"),
    "ciaran" = list(standard = "keerun", premium = "keer-an", ipa = "K IH1 R AO0 N"),
    "darragh" = list(standard = "darra", premium = "dar-ra", ipa = "D AA1 R AH0"),
    "ronan" = list(standard = "ronan", premium = "ro-nan", ipa = "R OW1 N AH0 N"),
    "colm" = list(standard = "collum", premium = "col-um", ipa = "K OW1 L M"),
    "cathal" = list(standard = "cahal", premium = "ka-hal", ipa = "K AA1 HH AH0 L"),
    "fionn" = list(standard = "finn", premium = "finn", ipa = "F IH1 N"),
    "cormac" = list(standard = "cormack", premium = "cor-mack", ipa = "K AO1 R M AE0 K"),
    "donal" = list(standard = "donal", premium = "do-nal", ipa = "D OW1 N AH0 L"),
    "fergal" = list(standard = "fergul", premium = "fer-gal", ipa = "F ER1 G AH0 L"),
    "killian" = list(standard = "killian", premium = "kill-ian", ipa = "K IH1 L IY0 AH0 N"),
    "lorcan" = list(standard = "lorkan", premium = "lor-kan", ipa = "L AO1 R K AH0 N"),
    "micheal" = list(standard = "meehawl", premium = "mee-hawl", ipa = "M AY1 K AH0 L"),
    "ruairi" = list(standard = "rory", premium = "rory", ipa = "R AO1 R IY0"),
    "ruaidri" = list(standard = "rory", premium = "rory", ipa = "R AO1 R IY0"),
    "sean" = list(standard = "shawn", premium = "shawn", ipa = "SH AO1 N"),
    "declan" = list(standard = "decklan", premium = "deck-lan", ipa = "D EH1 K L AH0 N"),
    "aidan" = list(standard = "ayden", premium = "ay-den", ipa = "EY1 D AH0 N"),
    "brendan" = list(standard = "brendan", premium = "bren-dan", ipa = "B R EH1 N D AH0 N"),
    "conor" = list(standard = "conner", premium = "con-ner", ipa = "K AA1 N ER0"),
    "liam" = list(standard = "leeam", premium = "lee-am", ipa = "L IY1 AH0 M"),
    "fiachra" = list(standard = "feekra", premium = "fee-kra", ipa = "F IY1 K R AH0"),
    "diarmuid" = list(standard = "deermid", premium = "deer-mid", ipa = "D IH1 R M IH0 D"),
    "eoghan" = list(standard = "owen", premium = "oh-an", ipa = "OW1 AH0 N"),
    "donnacha" = list(standard = "dunnaka", premium = "dun-na-ka", ipa = "D UH1 N AH0 K AH0"),
    "cillian" = list(standard = "killian", premium = "kill-ian", ipa = "K IH1 L IY0 AH0 N"),
    "patrick" = list(standard = "patrick", premium = "pat-rick", ipa = "P AE1 T R IH0 K"),
    "finn" = list(standard = "finn", premium = "finn", ipa = "F IH1 N"),
    "eamon" = list(standard = "aymon", premium = "ay-mon", ipa = "EY1 M AH0 N"),
    "dermot" = list(standard = "dermit", premium = "der-mit", ipa = "D ER1 M AH0 T"),
    "michael" = list(standard = "mykel", premium = "my-kel", ipa = "M AY1 K AH0 L"),
    "brian" = list(standard = "bryan", premium = "bry-an", ipa = "B R AY1 AH0 N"),
    "kevin" = list(standard = "kevin", premium = "kev-in", ipa = "K EH1 V IH0 N"),
    "ryan" = list(standard = "ryan", premium = "ry-an", ipa = "R AY1 AH0 N")
  )

  # Check dictionary first
  if (!is.null(irish_dictionary[[result]])) {
    dict_entry <- irish_dictionary[[result]]
    dict_entry$from_dictionary <- TRUE  # Mark as dictionary match
    return(dict_entry)
  }

  # Pattern-based rules for other names
  # Apply patterns and return both versions
  result_standard <- result
  result_premium <- result

  irish_patterns_standard <- list(
    "siobh" = "shiv",
    "sio" = "shuh",
    "si" = "sh",
    "caoi" = "kee",
    "aoi" = "ee",
    "eoi" = "oh",
    "oi" = "uh",
    "bh" = "v",
    "mh" = "v",
    "dh" = "g",
    "gh" = "",
    "ch" = "k",
    "th" = "h",
    "ao" = "ay",
    "ea" = "ah"
  )

  irish_patterns_premium <- list(
    "siobh" = "shiv",
    "sio" = "shuh",
    "si" = "sh",
    "caoi" = "kee",
    "aoi" = "ee",
    "eoi" = "oh",
    "oi" = "uh",
    "bh" = "v",
    "mh" = "v",
    "dh" = "g",
    "gh" = "",
    "ch" = "k",
    "th" = "h",
    "ao" = "ay",
    "ea" = "ah"
  )

  for (pattern in names(irish_patterns_standard)[order(nchar(names(irish_patterns_standard)), decreasing = TRUE)]) {
    result_standard <- gsub(pattern, irish_patterns_standard[[pattern]], result_standard, ignore.case = TRUE)
    result_premium <- gsub(pattern, irish_patterns_premium[[pattern]], result_premium, ignore.case = TRUE)
  }

  # For pattern-based names, don't generate fake CMU - it produces bad results
  # Let ElevenLabs use the phonetic respelling as plain text instead
  return(list(standard = result_standard, premium = result_premium, ipa = NULL, from_dictionary = FALSE))
}

# Nigerian phonetic rules (Igbo, Yoruba, Hausa)
# Returns BOTH standard and premium voice optimized spellings
apply_nigerian_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE NIGERIAN NAME DICTIONARY
  # Covers Igbo, Yoruba, and Hausa names
  nigerian_dictionary <- list(
    # Igbo Names (Female)
    "chioma" = list(standard = "chyohma", premium = "chyoh-ma", ipa = "CH IY0 OW1 M AH0"),
    "adaeze" = list(standard = "adayzay", premium = "a-day-zay", ipa = "AA0 D AA1 EH0 Z EH2"),
    "chiamaka" = list(standard = "chyahmaka", premium = "chyah-ma-ka", ipa = "CH IY0 AA0 M AA1 K AH0"),
    "chinwe" = list(standard = "cheenweh", premium = "cheen-weh", ipa = "CH IY1 N W EH2"),
    "ngozi" = list(standard = "engohzee", premium = "en-goh-zee", ipa = "NG OW1 Z IY2"),
    "ifeoma" = list(standard = "eefeohma", premium = "ee-feh-oh-ma", ipa = "IY0 F EH1 OW0 M AH0"),
    "uchenna" = list(standard = "oochayna", premium = "oo-chen-na", ipa = "UW0 CH EH1 N AH0"),
    "chidinma" = list(standard = "cheedeenma", premium = "chee-deen-ma", ipa = "CH IY0 D IY1 N M AH0"),
    "obioma" = list(standard = "obeohma", premium = "oh-bee-oh-ma", ipa = "OW0 B IY1 OW0 M AH0"),
    "amara" = list(standard = "amara", premium = "a-ma-ra", ipa = "AA0 M AA1 R AH0"),
    "amarachi" = list(standard = "amarachee", premium = "a-ma-ra-chee", ipa = "AA0 M AA0 R AA1 CH IY2"),
    "ebele" = list(standard = "ehbehleh", premium = "eh-beh-leh", ipa = "EH1 B EH0 L EH0"),
    "nkechi" = list(standard = "enkaychee", premium = "en-kay-chee", ipa = "NG K EH1 CH IY2"),
    "ada" = list(standard = "ahdah", premium = "ah-dah", ipa = "AA1 D AH0"),
    "adanna" = list(standard = "adahna", premium = "a-dah-na", ipa = "AA0 D AA1 N AH0"),

    # Igbo Names (Male)
    "chukwudi" = list(standard = "chookwoodee", premium = "chook-woo-dee", ipa = "CH UW0 K W UW1 D IY2"),
    "chinedu" = list(standard = "cheenaydoo", premium = "chee-nay-doo", ipa = "CH IY0 N EH1 D UW2"),
    "emeka" = list(standard = "aymeka", premium = "ay-me-ka", ipa = "EH0 M EH1 K AH0"),
    "ikenna" = list(standard = "eekena", premium = "ee-ken-na", ipa = "IY0 K EH1 N AH0"),
    "obinna" = list(standard = "obeena", premium = "oh-bee-na", ipa = "OW0 B IY1 N AH0"),
    "chidi" = list(standard = "cheedee", premium = "chee-dee", ipa = "CH IY1 D IY2"),
    "nnamdi" = list(standard = "namdee", premium = "nam-dee", ipa = "N AA1 M D IY2"),
    "chukwuemeka" = list(standard = "chookwooaymeka", premium = "chook-woo-ay-me-ka", ipa = "CH UW0 K W UW1 EH0 M EH1 K AH0"),
    "chibuike" = list(standard = "cheebueekey", premium = "chee-boo-ee-kay", ipa = "CH IY1 B UW0 IY1 K EY2"),
    "kelechi" = list(standard = "kelaychee", premium = "keh-lay-chee", ipa = "K EH0 L EH1 CH IY2"),
    "onyekachi" = list(standard = "onyehkachee", premium = "on-yeh-ka-chee", ipa = "OW0 N Y EH1 K AA0 CH IY2"),

    # Yoruba Names (Female)
    "adeola" = list(standard = "ahdayohla", premium = "ah-day-oh-la", ipa = "AA0 D EH1 OW0 L AH0"),
    "oluwaseun" = list(standard = "ohloowashaw", premium = "oh-loo-wa-shay", ipa = "OW0 L UW1 W AH0 SH EH2 UW0 N"),
    "olufemi" = list(standard = "ohloofaymee", premium = "oh-loo-fay-mee", ipa = "OW0 L UW1 F EH0 M IY2"),
    "ayodele" = list(standard = "ahyohdaylay", premium = "ah-yoh-day-lay", ipa = "AY0 OW1 D EH0 L EY2"),
    "olufunke" = list(standard = "ohloofoonkay", premium = "oh-loo-foon-kay", ipa = "OW0 L UW1 F UW2 N K EH0"),
    "funmilayo" = list(standard = "foonmilayo", premium = "foon-mee-lay-oh", ipa = "F UW1 N M IY0 L AY2 OW0"),
    "adesuwa" = list(standard = "ahdesoowan", premium = "ah-de-soo-wah", ipa = "AA0 D EH1 S UW0 W AH0"),
    "omolara" = list(standard = "ohmolara", premium = "oh-mo-lah-ra", ipa = "OW0 M OW0 L AA1 R AH0"),
    "titilayo" = list(standard = "teeteelahyoh", premium = "tee-tee-lah-yoh", ipa = "T IY1 T IY0 L AY2 OW0"),
    "abimbola" = list(standard = "abeembohla", premium = "ah-beem-boh-la", ipa = "AA0 B IY1 M B OW1 L AH0"),
    "folake" = list(standard = "fohlahkay", premium = "foh-lah-kay", ipa = "F OW1 L AA0 K EH2"),
    "yetunde" = list(standard = "yehtoonday", premium = "yeh-toon-day", ipa = "Y EH1 T UW0 N D EY2"),

    # Yoruba Names (Male)
    "oluwaseyi" = list(standard = "ohloowashayee", premium = "oh-loo-wa-shay-ee", ipa = "OW0 L UW1 W AH0 SH EY1 IY2"),
    "olumide" = list(standard = "ohloomeeday", premium = "oh-loo-mee-day", ipa = "OW0 L UW1 M IY0 D EH2"),
    "oluwatobi" = list(standard = "ohloowatobi", premium = "oh-loo-wa-toh-bee", ipa = "OW0 L UW1 W AH0 T OW1 B IY2"),
    "ayodeji" = list(standard = "ahyodejee", premium = "ah-yo-deh-jee", ipa = "AY0 OW1 D EH0 JH IY2"),
    "kehinde" = list(standard = "kehindeh", premium = "keh-heen-deh", ipa = "K EH0 HH IY1 N D EH2"),
    "taiwo" = list(standard = "tyewoh", premium = "tye-woh", ipa = "T AY1 W OW2"),
    "babatunde" = list(standard = "babatoonday", premium = "ba-ba-toon-day", ipa = "B AA0 B AA1 T UW2 N D EH0"),
    "adebayo" = list(standard = "ahdebayo", premium = "ah-deh-bay-oh", ipa = "AA0 D EH1 B AY2 OW0"),
    "oluwafemi" = list(standard = "ohloowafaymee", premium = "oh-loo-wa-fay-mee", ipa = "OW0 L UW1 W AH0 F EY1 M IY2"),
    "adekunle" = list(standard = "ahdaykoonlay", premium = "ah-day-koon-lay", ipa = "AA0 D EH1 K UW0 N L EY2"),
    "temitope" = list(standard = "tehmehtohpay", premium = "teh-mee-toh-pay", ipa = "T EH1 M IH0 T OW1 P EY2"),
    "adewale" = list(standard = "ahdaywalay", premium = "ah-day-wa-lay", ipa = "AA0 D EH1 W AA0 L EY2"),

    # Hausa Names
    "ibrahim" = list(standard = "ibraheam", premium = "ib-ra-heem", ipa = "IY0 B R AA1 HH IY2 M"),
    "musa" = list(standard = "moosa", premium = "moo-sah", ipa = "M UW1 S AH0"),
    "usman" = list(standard = "oosman", premium = "oos-man", ipa = "UW1 S M AA2 N"),
    "yusuf" = list(standard = "yoosuf", premium = "yoo-suf", ipa = "Y UW1 S UW2 F"),
    "abubakar" = list(standard = "abubakar", premium = "a-bu-ba-kar", ipa = "AA0 B UW1 B AA0 K AA2 R"),
    "aisha" = list(standard = "eyeesha", premium = "eye-ee-sha", ipa = "AY1 SH AH0"),
    "fatima" = list(standard = "fahteema", premium = "fah-tee-ma", ipa = "F AA0 T IY1 M AH0"),
    "zainab" = list(standard = "zaynahb", premium = "zay-nab", ipa = "Z AY1 N AA2 B"),
    "hauwa" = list(standard = "howwa", premium = "how-wah", ipa = "HH AW1 W AH0"),
    "maryam" = list(standard = "mahryam", premium = "mahr-yam", ipa = "M AA1 R Y AA2 M"),
    "amina" = list(standard = "ameena", premium = "a-mee-nah", ipa = "AA0 M IY1 N AH0"),
    "muhammad" = list(standard = "moohammad", premium = "moo-ha-mad", ipa = "M UW1 HH AA0 M AA1 D"),
    "abdullahi" = list(standard = "abdoolahee", premium = "ab-doo-lah-hee", ipa = "AA0 B D UW1 L AA0 HH IY2"),

    # Common English Names Used in Nigeria
    "blessing" = list(standard = "blessing", premium = "bles-sing", ipa = "B L EH1 S IH0 NG"),
    "grace" = list(standard = "grayss", premium = "grayss", ipa = "G R EY1 S"),
    "patience" = list(standard = "payshunss", premium = "pay-shuns", ipa = "P EY1 SH AH0 N S"),
    "precious" = list(standard = "preshuss", premium = "pre-shuss", ipa = "P R EH1 SH AH0 S"),
    "favour" = list(standard = "fayver", premium = "fay-ver", ipa = "F EY1 V ER0"),
    "faith" = list(standard = "fayth", premium = "fayth", ipa = "F EY1 TH")
  )

  # Check dictionary first
  if (!is.null(nigerian_dictionary[[result]])) {
    dict_entry <- nigerian_dictionary[[result]]
    dict_entry$from_dictionary <- TRUE
    return(dict_entry)
  }

  # Pattern-based rules for other Nigerian names
  result_standard <- result
  result_premium <- result

  nigerian_patterns_standard <- list(
    "chi" = "chee", "chu" = "choo", "nwa" = "nwa",
    "olu" = "ohloo", "ade" = "aday", "ayo" = "ayoh",
    "ng" = "eng", "nk" = "enk"
  )

  nigerian_patterns_premium <- list(
    "chi" = "chee", "chu" = "choo", "nwa" = "nwa",
    "olu" = "oh-loo", "ade" = "a-day", "ayo" = "a-yoh",
    "ng" = "eng", "nk" = "enk"
  )

  for (pattern in names(nigerian_patterns_standard)[order(nchar(names(nigerian_patterns_standard)), decreasing = TRUE)]) {
    result_standard <- gsub(pattern, nigerian_patterns_standard[[pattern]], result_standard, ignore.case = TRUE)
    result_premium <- gsub(pattern, nigerian_patterns_premium[[pattern]], result_premium, ignore.case = TRUE)
  }

  # For pattern-based names, don't generate fake CMU - it produces bad results
  # Let ElevenLabs use the phonetic respelling as plain text instead
  return(list(standard = result_standard, premium = result_premium, ipa = NULL, from_dictionary = FALSE))
}

# Congolese phonetic rules (Democratic Republic of Congo)
# Returns BOTH standard and premium voice optimized spellings
apply_congolese_phonetics <- function(name) {
  result <- tolower(name)

  # CONGOLESE NAME DICTIONARY (DRC)
  # Starting with first contributed entry from student
  congolese_dictionary <- list(
    # First entry: Student-verified pronunciation from Abiung
    # Verified by student audio recording: transcribed as "Abiyung"
    # Closest phonetic match: "ABEYOONG" (bypasses ElevenLabs "young" word recognition)
    "abiung" = list(standard = "AB-ee-yoong", premium = "ABEYOONG", ipa = "AE1 B IY0 UW1 NG")
  )

  # Check dictionary first
  if (!is.null(congolese_dictionary[[result]])) {
    dict_entry <- congolese_dictionary[[result]]
    dict_entry$from_dictionary <- TRUE
    return(dict_entry)
  }

  # Pattern-based rules for other Congolese names (to be expanded)
  # French influences: similar to French patterns
  result_standard <- result
  result_premium <- result

  # Basic French-influenced patterns common in DRC
  congolese_patterns_standard <- list(
    "ou" = "oo",  # French "ou" sound
    "eau" = "oh", # French "eau" sound
    "é" = "ay",   # French accented e
    "è" = "eh"
  )

  congolese_patterns_premium <- list(
    "ou" = "oo",
    "eau" = "oh",
    "é" = "ay",
    "è" = "eh"
  )

  for (pattern in names(congolese_patterns_standard)) {
    result_standard <- gsub(pattern, congolese_patterns_standard[[pattern]], result_standard, ignore.case = TRUE)
    result_premium <- gsub(pattern, congolese_patterns_premium[[pattern]], result_premium, ignore.case = TRUE)
  }

  # For pattern-based names, don't generate fake CMU
  return(list(standard = result_standard, premium = result_premium, ipa = NULL, from_dictionary = FALSE))
}

# Indian phonetic rules (Hindi, Tamil, Telugu, Punjabi, Sanskrit)
# Returns BOTH standard and premium voice optimized spellings
apply_indian_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE INDIAN NAME DICTIONARY
  # Covers Hindi, Tamil, Telugu, Punjabi, and Sanskrit origin names
  indian_dictionary <- list(
    # Hindi/Sanskrit Names (Female)
    "priya" = list(standard = "preeya", premium = "pree-ya", ipa = "P R IY1 Y AH0"),
    "ananya" = list(standard = "uhnunya", premium = "uh-nun-ya", ipa = "AA0 N AA1 N Y AH0"),
    "kavya" = list(standard = "kahvya", premium = "kahv-ya", ipa = "K AA1 V Y AH0"),
    "diya" = list(standard = "deeya", premium = "dee-ya", ipa = "D IY1 Y AH0"),
    "ishita" = list(standard = "isheetah", premium = "ish-ee-tah", ipa = "IH1 SH IY0 T AH0"),
    "aanya" = list(standard = "aanya", premium = "aan-ya", ipa = "AA1 N Y AH0"),
    "siya" = list(standard = "seeya", premium = "see-ya", ipa = "S IY1 Y AH0"),
    "pari" = list(standard = "paree", premium = "pa-ree", ipa = "P AA1 R IY2"),
    "anaya" = list(standard = "uhnaya", premium = "uh-na-ya", ipa = "AA0 N AY1 AH0"),
    "saanvi" = list(standard = "sahnvee", premium = "sahn-vee", ipa = "S AA1 N V IY2"),
    "navya" = list(standard = "nahvya", premium = "nahv-ya", ipa = "N AA1 V Y AH0"),
    "riya" = list(standard = "reeya", premium = "ree-ya", ipa = "R IY1 Y AH0"),
    "aaradhya" = list(standard = "arahdhya", premium = "aa-rahd-hya", ipa = "AA1 R AA0 DH Y AH0"),
    "myra" = list(standard = "myra", premium = "my-ra", ipa = "M AY1 Y AH0"),
    "kiara" = list(standard = "keeara", premium = "kee-aa-ra", ipa = "K IY1 AA0 R AH0"),
    "aditi" = list(standard = "uhditee", premium = "uh-di-tee", ipa = "AA0 D IH1 T IY0"),
    "nisha" = list(standard = "neeshuh", premium = "nee-sha", ipa = "N IY1 SH AH0"),
    "pooja" = list(standard = "poojah", premium = "poo-jah", ipa = "P UW1 JH AH0"),
    "sneha" = list(standard = "snayha", premium = "snay-ha", ipa = "S N EY1 HH AH0"),
    "shreya" = list(standard = "shrayah", premium = "shray-ah", ipa = "SH R EY1 AH0"),
    "aarti" = list(standard = "ahrtee", premium = "ahr-tee", ipa = "AA1 R T IY2"),
    "lakshmi" = list(standard = "lukshmi", premium = "luksh-mi", ipa = "L AA1 K SH M IY2"),
    "kavita" = list(standard = "kahvitah", premium = "kah-vee-tah", ipa = "K AA0 V IY1 T AH0"),
    "neha" = list(standard = "nayha", premium = "nay-ha", ipa = "N EY1 HH AH0"),
    "anjali" = list(standard = "ahnjali", premium = "ahn-jah-lee", ipa = "AA1 N JH AA0 L IY2"),
    "divya" = list(standard = "divya", premium = "div-ya", ipa = "D IH1 V Y AH0"),
    "rani" = list(standard = "rahnee", premium = "rah-nee", ipa = "R AA1 N IY2"),
    "sita" = list(standard = "seetah", premium = "see-tah", ipa = "S IY1 T AH0"),
    "radha" = list(standard = "rahdha", premium = "rahd-ha", ipa = "R AA1 DH AH0"),
    "maya" = list(standard = "maya", premium = "may-ya", ipa = "M AY1 Y AH0"),

    # Hindi/Sanskrit Names (Male)
    "aarav" = list(standard = "ahrahv", premium = "aa-rahv", ipa = "AA1 R AA0 V"),
    "arjun" = list(standard = "arjoon", premium = "ar-joon", ipa = "AA1 R JH UW2 N"),
    "rohan" = list(standard = "rohun", premium = "ro-hun", ipa = "R OW1 HH AA2 N"),
    "aditya" = list(standard = "uhditya", premium = "uh-dit-ya", ipa = "AA0 D IH1 T Y AH0"),
    "ishaan" = list(standard = "eeshahn", premium = "ee-shaan", ipa = "IY1 SH AA2 N"),
    "vivaan" = list(standard = "vivahn", premium = "vi-vaan", ipa = "V IH1 V AA2 N"),
    "ayaan" = list(standard = "eyahn", premium = "ay-aan", ipa = "AY1 AA2 N"),
    "aryan" = list(standard = "ahryan", premium = "ahr-yan", ipa = "AA1 R Y AH2 N"),
    "reyansh" = list(standard = "rayunsh", premium = "ray-unsh", ipa = "R EY1 AH0 N SH"),
    "shaurya" = list(standard = "shaurya", premium = "shaur-ya", ipa = "SH AW1 R Y AH0"),
    "atharv" = list(standard = "uhtuhrv", premium = "uh-tuhrv", ipa = "AA0 TH ER1 V"),
    "vihaan" = list(standard = "veehahn", premium = "vee-haan", ipa = "V IY1 HH AA2 N"),
    "arnav" = list(standard = "ahrnuv", premium = "ahr-nuv", ipa = "AA1 R N AH0 V"),
    "sai" = list(standard = "sigh", premium = "sigh", ipa = "S AY1"),
    "krishna" = list(standard = "krishnuh", premium = "krish-na", ipa = "K R IH1 SH N AH0"),
    "dev" = list(standard = "dave", premium = "dave", ipa = "D EY1 V"),
    "raj" = list(standard = "rahj", premium = "rahj", ipa = "R AA1 JH"),
    "aniket" = list(standard = "uhneekayt", premium = "uh-nee-kayt", ipa = "AA0 N IY1 K EY0 T"),
    "rahul" = list(standard = "rahool", premium = "ra-hool", ipa = "R AA1 HH UW2 L"),
    "amit" = list(standard = "uhmeet", premium = "uh-meet", ipa = "AA0 M IY1 T"),
    "vikram" = list(standard = "vikram", premium = "vik-ram", ipa = "V IH1 K R AA2 M"),
    "ram" = list(standard = "rahm", premium = "rahm", ipa = "R AA1 M"),

    # Tamil Names
    "arun" = list(standard = "ahroon", premium = "ah-roon", ipa = "AA1 R UW2 N"),
    "deepak" = list(standard = "deepuhk", premium = "deep-uck", ipa = "D IY1 P AH0 K"),
    "ganesh" = list(standard = "guhnaysh", premium = "guh-naysh", ipa = "G AA1 N EY0 SH"),
    "karthik" = list(standard = "kartik", premium = "kar-tik", ipa = "K AA1 R T IH0 K"),
    "meera" = list(standard = "meera", premium = "mee-ra", ipa = "M IH1 R AH0"),
    "selvi" = list(standard = "selvee", premium = "sel-vee", ipa = "S EH1 L V IY2"),
    "tamil" = list(standard = "tahmil", premium = "tah-mil", ipa = "T AA1 M IH0 L"),

    # Telugu Names
    "srinivas" = list(standard = "shreeneevahs", premium = "shree-nee-vahs", ipa = "SH R IY1 N IY0 V AA2 S"),
    "venkat" = list(standard = "venkaht", premium = "ven-kaht", ipa = "V EH1 NG K AA0 T"),
    "ramya" = list(standard = "rahmya", premium = "rahm-ya", ipa = "R AA1 M Y AH0"),
    "suresh" = list(standard = "suraysh", premium = "su-raysh", ipa = "S UW1 R EH2 SH"),

    # Punjabi Names
    "harpreet" = list(standard = "harpreet", premium = "har-preet", ipa = "HH AA1 R P R IY2 T"),
    "gurpreet" = list(standard = "gurpreet", premium = "gur-preet", ipa = "G UW1 R P R IY2 T"),
    "simran" = list(standard = "simrun", premium = "sim-run", ipa = "S IH1 M R AH0 N"),
    "jaspreet" = list(standard = "jaspreet", premium = "jas-preet", ipa = "JH AA1 S P R IY2 T"),
    "manpreet" = list(standard = "manpreet", premium = "man-preet", ipa = "M AA1 N P R IY2 T"),
    "navjot" = list(standard = "navjote", premium = "nav-jote", ipa = "N AA1 V JH OW2 T"),
    "kuldeep" = list(standard = "kuldeep", premium = "kul-deep", ipa = "K UW1 L D IY2 P")
  )

  # Check dictionary first
  if (!is.null(indian_dictionary[[result]])) {
    dict_entry <- indian_dictionary[[result]]
    dict_entry$from_dictionary <- TRUE
    return(dict_entry)
  }

  # Pattern-based rules for other Indian names
  result_standard <- result
  result_premium <- result

  indian_patterns_standard <- list(
    "aa" = "ah", "ee" = "ee", "oo" = "oo",
    "sh" = "sh", "ch" = "ch", "th" = "t",
    "dh" = "d", "bh" = "b", "ph" = "p",
    "ya" = "ya", "vi" = "vee", "va" = "vah"
  )

  indian_patterns_premium <- list(
    "aa" = "ah", "ee" = "ee", "oo" = "oo",
    "sh" = "sh", "ch" = "ch", "th" = "t",
    "dh" = "d", "bh" = "b", "ph" = "p",
    "ya" = "ya", "vi" = "vee", "va" = "vah"
  )

  for (pattern in names(indian_patterns_standard)[order(nchar(names(indian_patterns_standard)), decreasing = TRUE)]) {
    result_standard <- gsub(pattern, indian_patterns_standard[[pattern]], result_standard, ignore.case = TRUE)
    result_premium <- gsub(pattern, indian_patterns_premium[[pattern]], result_premium, ignore.case = TRUE)
  }

  # For pattern-based names, don't generate fake CMU - it produces bad results
  # Let ElevenLabs use the phonetic respelling as plain text instead
  return(list(standard = result_standard, premium = result_premium, ipa = NULL, from_dictionary = FALSE))
}

# Spanish/Latin phonetic rules
# Returns BOTH standard and premium voice optimized spellings
apply_spanish_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE SPANISH/LATIN NAME DICTIONARY
  # Covers Spanish, Mexican, and Latin American names
  spanish_dictionary <- list(
    # Female Names
    "maría" = list(standard = "mahreeah", premium = "mah-ree-ah", ipa = "M AA0 R IY1 AA0"),
    "maria" = list(standard = "mahreeah", premium = "mah-ree-ah", ipa = "M AA0 R IY1 AA0"),
    "sofía" = list(standard = "sofeea", premium = "so-fee-ah", ipa = "S OW0 F IY1 AA0"),
    "sofia" = list(standard = "sofeea", premium = "so-fee-ah", ipa = "S OW0 F IY1 AA0"),
    "isabella" = list(standard = "eesahbehya", premium = "ee-sah-beh-yah", ipa = "IY0 S AA0 B EH1 L AA0"),
    "valentina" = list(standard = "vahlenteena", premium = "vah-len-tee-nah", ipa = "V AA0 L EH0 N T IY1 N AA0"),
    "camila" = list(standard = "kahmeela", premium = "kah-mee-lah", ipa = "K AA0 M IY1 L AA0"),
    "lucía" = list(standard = "looseea", premium = "loo-see-ah", ipa = "L UW0 S IY1 AA0"),
    "lucia" = list(standard = "looseea", premium = "loo-see-ah", ipa = "L UW0 S IY1 AA0"),
    "martina" = list(standard = "marteena", premium = "mar-tee-nah", ipa = "M AA0 R T IY1 N AA0"),
    "elena" = list(standard = "ehlehnah", premium = "eh-leh-nah", ipa = "EH0 L EY1 N AA0"),
    "valeria" = list(standard = "vahlehreeah", premium = "vah-leh-ree-ah", ipa = "V AA0 L EH0 R IY1 AA0"),
    "daniela" = list(standard = "dahnyehlah", premium = "dah-nyeh-lah", ipa = "D AA0 N Y EH1 L AA0"),
    "gabriela" = list(standard = "gahbreehlah", premium = "gah-bree-eh-lah", ipa = "G AA0 B R IY0 EH1 L AA0"),
    "victoria" = list(standard = "veektohreeah", premium = "veek-toh-ree-ah", ipa = "V IY0 K T OR1 Y AA0"),
    "emilia" = list(standard = "ehmeelyah", premium = "eh-mee-lyah", ipa = "EH0 M IY1 L Y AA0"),
    "carmen" = list(standard = "karmen", premium = "kar-men", ipa = "K AA1 R M EH0 N"),
    "ana" = list(standard = "ahnah", premium = "ah-nah", ipa = "AA1 N AA0"),
    "rosa" = list(standard = "rohsah", premium = "roh-sah", ipa = "R OW1 S AA0"),
    "catalina" = list(standard = "kahtahleena", premium = "kah-tah-lee-nah", ipa = "K AA0 T AA0 L IY1 N AA0"),
    "guadalupe" = list(standard = "gwadahloopay", premium = "gwa-dah-loo-pay", ipa = "G W AA0 D AA0 L UW1 P EY0"),
    "ximena" = list(standard = "heemehnah", premium = "hee-meh-nah", ipa = "HH IY0 M EH1 N AA0"),
    "jimena" = list(standard = "heemehnah", premium = "hee-meh-nah", ipa = "HH IY0 M EH1 N AA0"),

    # Male Names
    "josé" = list(standard = "hoseh", premium = "ho-seh", ipa = "HH OW1 S EY1"),
    "jose" = list(standard = "hoseh", premium = "ho-seh", ipa = "HH OW1 S EY1"),
    "juan" = list(standard = "hwahn", premium = "hwahn", ipa = "HH W AA1 N"),
    "carlos" = list(standard = "karlohs", premium = "kar-lohs", ipa = "K AA1 R L OW0 S"),
    "miguel" = list(standard = "meegell", premium = "mee-gell", ipa = "M IY1 G EH0 L"),
    "diego" = list(standard = "deeaygo", premium = "dee-ay-go", ipa = "D Y EY1 G OW0"),
    "santiago" = list(standard = "sahntyahgo", premium = "sahn-tyah-go", ipa = "S AA0 N T Y AA1 G OW0"),
    "mateo" = list(standard = "mahtayo", premium = "mah-tay-o", ipa = "M AA0 T EY1 OW0"),
    "sebastián" = list(standard = "sehbahstyahn", premium = "seh-bahs-tyahn", ipa = "S EH0 B AA0 S T Y AA1 N"),
    "sebastian" = list(standard = "sehbahstyahn", premium = "seh-bahs-tyahn", ipa = "S EH0 B AA0 S T Y AA1 N"),
    "alejandro" = list(standard = "ahlehhandroe", premium = "ah-leh-han-dro", ipa = "AA0 L EH0 HH AA1 N D R OW0"),
    "manuel" = list(standard = "mahnwell", premium = "mahn-well", ipa = "M AA0 N W EH1 L"),
    "antonio" = list(standard = "ahntoenyoe", premium = "ahn-toe-nyo", ipa = "AA0 N T OW1 N Y OW0"),
    "francisco" = list(standard = "frahnseeskoe", premium = "frahn-sees-ko", ipa = "F R AA0 N S IY1 S K OW0"),
    "javier" = list(standard = "havyehr", premium = "hav-yehr", ipa = "HH AA0 V Y EH1 R"),
    "rafael" = list(standard = "rafahell", premium = "rah-fah-ell", ipa = "R AA0 F AA1 EH0 L"),
    "daniel" = list(standard = "dahnyell", premium = "dah-nyell", ipa = "D AA0 N Y EH1 L"),
    "gabriel" = list(standard = "gahbreeell", premium = "gah-bree-ell", ipa = "G AA0 B R IY1 EH0 L"),
    "fernando" = list(standard = "fernahndo", premium = "fer-nahn-do", ipa = "F EH0 R N AA1 N D OW0"),
    "ricardo" = list(standard = "reekardo", premium = "ree-kar-do", ipa = "R IY0 K AA1 R D OW0"),
    "andrés" = list(standard = "ahndrays", premium = "ahn-drays", ipa = "AA0 N D R EH1 S"),
    "andres" = list(standard = "ahndrays", premium = "ahn-drays", ipa = "AA0 N D R EH1 S"),
    "pablo" = list(standard = "pahblo", premium = "pah-blo", ipa = "P AA1 B L OW0"),
    "luis" = list(standard = "looees", premium = "loo-ees", ipa = "L UW1 IY0 S"),
    "jorge" = list(standard = "horhay", premium = "hor-hay", ipa = "HH OR1 HH EY1"),
    "pedro" = list(standard = "paydro", premium = "pay-dro", ipa = "P EY1 D R OW0"),
    "ramón" = list(standard = "rahmohn", premium = "rah-mohn", ipa = "R AA0 M OW1 N"),
    "ramon" = list(standard = "rahmohn", premium = "rah-mohn", ipa = "R AA0 M OW1 N")
  )

  # Check dictionary first
  if (!is.null(spanish_dictionary[[result]])) {
    dict_entry <- spanish_dictionary[[result]]
    dict_entry$from_dictionary <- TRUE
    return(dict_entry)
  }

  # Pattern-based rules for other Spanish names
  result_standard <- result
  result_premium <- result

  spanish_patterns_standard <- list(
    "ll" = "y", "ñ" = "ny", "j" = "h",
    "ge" = "he", "gi" = "hee",
    "que" = "keh", "qui" = "kee",
    "gue" = "geh", "gui" = "gee",
    "z" = "s", "ce" = "seh", "ci" = "see"
  )

  spanish_patterns_premium <- list(
    "ll" = "y", "ñ" = "ny", "j" = "h",
    "ge" = "he", "gi" = "hee",
    "que" = "keh", "qui" = "kee",
    "gue" = "geh", "gui" = "gee",
    "z" = "s", "ce" = "seh", "ci" = "see"
  )

  for (pattern in names(spanish_patterns_standard)[order(nchar(names(spanish_patterns_standard)), decreasing = TRUE)]) {
    result_standard <- gsub(pattern, spanish_patterns_standard[[pattern]], result_standard, ignore.case = TRUE)
    result_premium <- gsub(pattern, spanish_patterns_premium[[pattern]], result_premium, ignore.case = TRUE)
  }

  # For pattern-based names, don't generate fake CMU - it produces bad results
  # Let ElevenLabs use the phonetic respelling as plain text instead
  return(list(standard = result_standard, premium = result_premium, ipa = NULL, from_dictionary = FALSE))
}

# Chinese (Mandarin) phonetic rules
# Returns BOTH standard and premium voice optimized spellings
apply_chinese_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE CHINESE (MANDARIN) NAME DICTIONARY
  # Pinyin romanization with proper phonetic guides
  chinese_dictionary <- list(
    # Common Male Names
    "wei" = list(standard = "way", premium = "way", ipa = "W EY1"),
    "ming" = list(standard = "ming", premium = "ming", ipa = "M IH1 NG"),
    "li" = list(standard = "lee", premium = "lee", ipa = "L IY1"),
    "jing" = list(standard = "jing", premium = "jing", ipa = "JH IH1 NG"),
    "yang" = list(standard = "yahng", premium = "yahng", ipa = "Y AA1 NG"),
    "chen" = list(standard = "chen", premium = "chen", ipa = "CH EH1 N"),
    "wang" = list(standard = "wahng", premium = "wahng", ipa = "W AA1 NG"),
    "zhang" = list(standard = "jahng", premium = "jahng", ipa = "JH AA1 NG"),
    "liu" = list(standard = "lyoo", premium = "lyoo", ipa = "L Y UW1"),
    "huang" = list(standard = "hwahng", premium = "hwahng", ipa = "HH W AA1 NG"),
    "zhao" = list(standard = "jow", premium = "jow", ipa = "JH AW1"),
    "wu" = list(standard = "woo", premium = "woo", ipa = "W UW1"),
    "jun" = list(standard = "joon", premium = "joon", ipa = "JH UW1 N"),
    "feng" = list(standard = "fung", premium = "fung", ipa = "F AH1 NG"),
    "lei" = list(standard = "lay", premium = "lay", ipa = "L EY1"),
    "tao" = list(standard = "tow", premium = "tow", ipa = "T AW1"),
    "long" = list(standard = "long", premium = "long", ipa = "L AO1 NG"),
    "han" = list(standard = "hahn", premium = "hahn", ipa = "HH AA1 N"),
    "yong" = list(standard = "yong", premium = "yong", ipa = "Y AO1 NG"),
    "hao" = list(standard = "how", premium = "how", ipa = "HH AW1"),
    "xin" = list(standard = "shin", premium = "shin", ipa = "SH IH1 N"),
    "bin" = list(standard = "bin", premium = "bin", ipa = "B IY1 N"),
    "cheng" = list(standard = "chung", premium = "chung", ipa = "CH AH1 NG"),
    "kai" = list(standard = "kye", premium = "kye", ipa = "K AY1"),
    "bo" = list(standard = "bwo", premium = "bwo", ipa = "B OW1"),

    # Common Female Names
    "mei" = list(standard = "may", premium = "may", ipa = "M EY1"),
    "ling" = list(standard = "ling", premium = "ling", ipa = "L IH1 NG"),
    "yan" = list(standard = "yahn", premium = "yahn", ipa = "Y AA1 N"),
    "xiu" = list(standard = "shyo", premium = "shyo", ipa = "SH Y UW1"),
    "hua" = list(standard = "hwah", premium = "hwah", ipa = "HH W AA1"),
    "yun" = list(standard = "yoon", premium = "yoon", ipa = "Y UW1 N"),
    "qing" = list(standard = "ching", premium = "ching", ipa = "CH IH1 NG"),
    "fang" = list(standard = "fahng", premium = "fahng", ipa = "F AA1 NG"),
    "lan" = list(standard = "lahn", premium = "lahn", ipa = "L AA1 N"),
    "ping" = list(standard = "ping", premium = "ping", ipa = "P IH1 NG"),
    "jie" = list(standard = "jyeh", premium = "jyeh", ipa = "JH Y EH1"),
    "min" = list(standard = "min", premium = "min", ipa = "M IY1 N"),
    "xia" = list(standard = "shya", premium = "shya", ipa = "SH Y AA1"),
    "rong" = list(standard = "rong", premium = "rong", ipa = "R AO1 NG"),
    "shu" = list(standard = "shoo", premium = "shoo", ipa = "SH UW1"),
    "yu" = list(standard = "yoo", premium = "yoo", ipa = "Y UW1"),
    "juan" = list(standard = "jwan", premium = "jwan", ipa = "JH W AA1 N"),
    "ying" = list(standard = "ying", premium = "ying", ipa = "Y IH1 NG"),
    "zhen" = list(standard = "jen", premium = "jen", ipa = "JH EH1 N"),
    "nan" = list(standard = "nahn", premium = "nahn", ipa = "N AA1 N"),
    "hong" = list(standard = "hong", premium = "hong", ipa = "HH AO1 NG"),
    "hui" = list(standard = "hway", premium = "hway", ipa = "HH W EY1"),
    "qian" = list(standard = "chyen", premium = "chyen", ipa = "CH Y EH1 N"),
    "xue" = list(standard = "shweh", premium = "shweh", ipa = "SH W EH1"),
    "lin" = list(standard = "lin", premium = "lin", ipa = "L IY1 N")
  )

  # Check dictionary first
  if (!is.null(chinese_dictionary[[result]])) {
    dict_entry <- chinese_dictionary[[result]]
    dict_entry$from_dictionary <- TRUE
    return(dict_entry)
  }

  # Pattern-based rules for other Chinese names
  result_standard <- result
  result_premium <- result

  chinese_patterns_standard <- list(
    "xi" = "shee", "qi" = "chee", "zh" = "j", "q" = "ch",
    "x" = "sh", "c" = "ts"
  )

  chinese_patterns_premium <- list(
    "xi" = "shee", "qi" = "chee", "zh" = "j", "q" = "ch",
    "x" = "sh", "c" = "ts"
  )

  for (pattern in names(chinese_patterns_standard)[order(nchar(names(chinese_patterns_standard)), decreasing = TRUE)]) {
    result_standard <- gsub(pattern, chinese_patterns_standard[[pattern]], result_standard, ignore.case = TRUE)
    result_premium <- gsub(pattern, chinese_patterns_premium[[pattern]], result_premium, ignore.case = TRUE)
  }

  # For pattern-based names, don't generate fake CMU - it produces bad results
  # Let ElevenLabs use the phonetic respelling as plain text instead
  return(list(standard = result_standard, premium = result_premium, ipa = NULL, from_dictionary = FALSE))
}

# Vietnamese phonetic rules
# Returns BOTH standard and premium voice optimized spellings
apply_vietnamese_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE VIETNAMESE NAME DICTIONARY
  # Handles diacritics and Vietnamese phonology
  vietnamese_dictionary <- list(
    # Common Male Names
    "nguyen" = list(standard = "winn", premium = "win", ipa = "W IH1 N"),
    "minh" = list(standard = "min", premium = "min", ipa = "M IH1 N"),
    "anh" = list(standard = "ahng", premium = "ahng", ipa = "AA1 N"),
    "trung" = list(standard = "choong", premium = "choong", ipa = "CH UW1 NG"),
    "quan" = list(standard = "kwahn", premium = "kwahn", ipa = "K W AA1 N"),
    "duc" = list(standard = "dook", premium = "dook", ipa = "D UW1 K"),
    "hieu" = list(standard = "hyew", premium = "hyew", ipa = "HH Y UW1"),
    "hung" = list(standard = "hoong", premium = "hoong", ipa = "HH UW1 NG"),
    "duy" = list(standard = "dwee", premium = "dwee", ipa = "D W IY1"),
    "khoa" = list(standard = "kwah", premium = "kwah", ipa = "K W AA1"),
    "phong" = list(standard = "fong", premium = "fong", ipa = "F AO1 NG"),
    "thanh" = list(standard = "tahng", premium = "tahng", ipa = "T AA1 N"),
    "hai" = list(standard = "hye", premium = "hye", ipa = "HH AY1"),
    "tuan" = list(standard = "twan", premium = "twan", ipa = "T W AA1 N"),
    "vinh" = list(standard = "vin", premium = "vin", ipa = "V IH1 N"),
    "nam" = list(standard = "nahm", premium = "nahm", ipa = "N AA1 M"),
    "thang" = list(standard = "tahng", premium = "tahng", ipa = "T AA1 NG"),
    "son" = list(standard = "shon", premium = "shon", ipa = "S AA1 N"),
    "tai" = list(standard = "tye", premium = "tye", ipa = "T AY1"),
    "khanh" = list(standard = "kahng", premium = "kahng", ipa = "K AA1 N"),
    "tien" = list(standard = "tyen", premium = "tyen", ipa = "T Y EH1 N"),
    "long" = list(standard = "long", premium = "long", ipa = "L AO1 NG"),
    "hoang" = list(standard = "hwahng", premium = "hwahng", ipa = "HH W AA1 NG"),
    "bao" = list(standard = "bow", premium = "bow", ipa = "B AW1"),
    "tu" = list(standard = "too", premium = "too", ipa = "T UW1"),

    # Common Female Names
    "linh" = list(standard = "lin", premium = "lin", ipa = "L IH1 N"),
    "lan" = list(standard = "lahn", premium = "lahn", ipa = "L AA1 N"),
    "phuong" = list(standard = "foong", premium = "foong", ipa = "F W AO1 NG"),
    "mai" = list(standard = "mye", premium = "mye", ipa = "M AY1"),
    "thu" = list(standard = "too", premium = "too", ipa = "T UW1"),
    "trang" = list(standard = "chahng", premium = "chahng", ipa = "CH AA1 NG"),
    "huong" = list(standard = "hoong", premium = "hoong", ipa = "HH W AO1 NG"),
    "hoa" = list(standard = "hwah", premium = "hwah", ipa = "HH W AA1"),
    "thao" = list(standard = "tow", premium = "tow", ipa = "T AW1"),
    "yen" = list(standard = "yen", premium = "yen", ipa = "Y EH1 N"),
    "ha" = list(standard = "hah", premium = "hah", ipa = "HH AA1"),
    "nhi" = list(standard = "nee", premium = "nee", ipa = "N IY1"),
    "kim" = list(standard = "keem", premium = "keem", ipa = "K IY1 M"),
    "my" = list(standard = "mee", premium = "mee", ipa = "M IY1"),
    "van" = list(standard = "vahn", premium = "vahn", ipa = "V AA1 N"),
    "thuy" = list(standard = "twee", premium = "twee", ipa = "T W IY1"),
    "ngoc" = list(standard = "ngok", premium = "ngok", ipa = "NG AO1 K"),
    "quynh" = list(standard = "kwin", premium = "kwin", ipa = "K W IH1 N"),
    "chi" = list(standard = "chee", premium = "chee", ipa = "CH IY1"),
    "hong" = list(standard = "hong", premium = "hong", ipa = "HH AO1 NG"),
    "tuyet" = list(standard = "tweet", premium = "tweet", ipa = "T W IY1 T"),
    "dung" = list(standard = "zoong", premium = "zoong", ipa = "Z UW1 NG"),
    "tam" = list(standard = "tahm", premium = "tahm", ipa = "T AA1 M"),
    "trinh" = list(standard = "chin", premium = "chin", ipa = "CH IH1 N"),
    "loan" = list(standard = "lwahn", premium = "lwahn", ipa = "L W AA1 N")
  )

  # Check dictionary first
  if (!is.null(vietnamese_dictionary[[result]])) {
    dict_entry <- vietnamese_dictionary[[result]]
    dict_entry$from_dictionary <- TRUE
    return(dict_entry)
  }

  # Pattern-based rules for other Vietnamese names
  result_standard <- result
  result_premium <- result

  vietnamese_patterns_standard <- list(
    "nguyen" = "winn",
    "ng" = "ng",
    "ph" = "f",
    "th" = "t",
    "tr" = "ch",
    "nh" = "n",
    "qu" = "kw"
  )

  vietnamese_patterns_premium <- list(
    "nguyen" = "win",
    "ng" = "ng",
    "ph" = "f",
    "th" = "t",
    "tr" = "ch",
    "nh" = "n",
    "qu" = "kw"
  )

  for (pattern in names(vietnamese_patterns_standard)[order(nchar(names(vietnamese_patterns_standard)), decreasing = TRUE)]) {
    result_standard <- gsub(pattern, vietnamese_patterns_standard[[pattern]], result_standard, ignore.case = TRUE)
    result_premium <- gsub(pattern, vietnamese_patterns_premium[[pattern]], result_premium, ignore.case = TRUE)
  }

  # For pattern-based names, don't generate fake CMU - it produces bad results
  # Let ElevenLabs use the phonetic respelling as plain text instead
  return(list(standard = result_standard, premium = result_premium, ipa = NULL, from_dictionary = FALSE))
}

# Italian phonetic rules
# Returns BOTH standard and premium voice optimized spellings
apply_italian_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE ITALIAN NAME DICTIONARY
  italian_dictionary <- list(
    # Common Male Names
    "giuseppe" = list(standard = "joozeppeh", premium = "joo-zep-peh", ipa = "JH UW0 Z EH1 P EH0"),
    "giovanni" = list(standard = "jovahni", premium = "jo-vah-nee", ipa = "JH OW0 V AA1 N IY0"),
    "antonio" = list(standard = "ahntonyo", premium = "ahn-ton-yo", ipa = "AA0 N T OW1 N Y OW0"),
    "mario" = list(standard = "mahryo", premium = "mahr-yo", ipa = "M AA1 R Y OW0"),
    "francesco" = list(standard = "frahnchesco", premium = "frahn-ches-ko", ipa = "F R AA0 N CH EH1 S K OW0"),
    "luigi" = list(standard = "looeejee", premium = "loo-ee-jee", ipa = "L UW0 IY1 JH IY0"),
    "angelo" = list(standard = "ahnjelo", premium = "ahn-jeh-lo", ipa = "AA1 N JH EH0 L OW0"),
    "vincenzo" = list(standard = "vinchentso", premium = "vin-chen-tso", ipa = "V IY1 N CH EH0 N T S OW0"),
    "lorenzo" = list(standard = "lorentso", premium = "lo-ren-tso", ipa = "L OW0 R EH1 N Z OW0"),
    "alessandro" = list(standard = "alessahndro", premium = "ah-les-sahn-dro", ipa = "AA0 L EH0 S AA1 N D R OW0"),
    "marco" = list(standard = "mahrko", premium = "mahr-ko", ipa = "M AA1 R K OW0"),
    "andrea" = list(standard = "ahndrayah", premium = "ahn-dreh-ah", ipa = "AA0 N D R EH1 AA0"),
    "matteo" = list(standard = "mahttayo", premium = "maht-teh-o", ipa = "M AA0 T EY1 OW0"),
    "luca" = list(standard = "lookah", premium = "loo-kah", ipa = "L UW1 K AA0"),
    "paolo" = list(standard = "paholo", premium = "pah-o-lo", ipa = "P AW1 L OW0"),
    "giorgio" = list(standard = "jorjo", premium = "jor-jo", ipa = "JH OR1 JH OW0"),
    "carlo" = list(standard = "kahrlo", premium = "kahr-lo", ipa = "K AA1 R L OW0"),
    "roberto" = list(standard = "roberto", premium = "ro-ber-to", ipa = "R OW0 B EH1 R T OW0"),
    "stefano" = list(standard = "stefahno", premium = "steh-fah-no", ipa = "S T EH0 F AA1 N OW0"),
    "enrico" = list(standard = "enreeko", premium = "en-ree-ko", ipa = "EH1 N R IY0 K OW0"),
    "fabio" = list(standard = "fahbyo", premium = "fah-byo", ipa = "F AA1 B Y OW0"),
    "riccardo" = list(standard = "reekardo", premium = "ree-kar-do", ipa = "R IY0 K AA1 R D OW0"),
    "davide" = list(standard = "dahveedeh", premium = "dah-vee-deh", ipa = "D AA0 V IY1 D EY0"),
    "simone" = list(standard = "seemoneh", premium = "see-mo-neh", ipa = "S IY0 M OW1 N EY0"),
    "domenico" = list(standard = "domeneeko", premium = "do-meh-nee-ko", ipa = "D OW0 M EH1 N IY0 K OW0"),

    # Common Female Names
    "maria" = list(standard = "mahreeah", premium = "mah-ree-ah", ipa = "M AA0 R IY1 AA0"),
    "anna" = list(standard = "ahnah", premium = "ahn-nah", ipa = "AA1 N AA0"),
    "giulia" = list(standard = "joolyah", premium = "joo-lyah", ipa = "JH UW1 L Y AA0"),
    "francesca" = list(standard = "frahncheskah", premium = "frahn-ches-kah", ipa = "F R AA0 N CH EH1 S K AA0"),
    "rosa" = list(standard = "rosah", premium = "ro-sah", ipa = "R OW1 S AA0"),
    "angela" = list(standard = "ahnjela", premium = "ahn-jeh-lah", ipa = "AA1 N JH EH0 L AA0"),
    "giovanna" = list(standard = "jovanah", premium = "jo-vahn-nah", ipa = "JH OW0 V AA1 N AA0"),
    "teresa" = list(standard = "teraysah", premium = "teh-ray-sah", ipa = "T EH0 R EY1 S AA0"),
    "lucia" = list(standard = "loocheah", premium = "loo-chee-ah", ipa = "L UW0 CH IY1 AA0"),
    "elena" = list(standard = "elaynah", premium = "eh-lay-nah", ipa = "EH0 L EY1 N AA0"),
    "chiara" = list(standard = "kyahrah", premium = "kyah-rah", ipa = "K Y AA1 R AA0"),
    "sara" = list(standard = "sahrah", premium = "sah-rah", ipa = "S AA1 R AA0"),
    "alessia" = list(standard = "alessyah", premium = "ah-les-syah", ipa = "AA0 L EH1 S Y AA0"),
    "sofia" = list(standard = "sofeah", premium = "so-fee-ah", ipa = "S OW0 F IY1 AA0"),
    "valentina" = list(standard = "valenteenah", premium = "vah-len-tee-nah", ipa = "V AA0 L EH0 N T IY1 N AA0"),
    "federica" = list(standard = "federeekah", premium = "feh-deh-ree-kah", ipa = "F EH0 D EH0 R IY1 K AA0"),
    "martina" = list(standard = "mahrteenah", premium = "mahr-tee-nah", ipa = "M AA0 R T IY1 N AA0"),
    "silvia" = list(standard = "seelvyah", premium = "seel-vyah", ipa = "S IY1 L V Y AA0"),
    "giorgia" = list(standard = "jorjah", premium = "jor-jah", ipa = "JH OR1 JH AA0"),
    "beatrice" = list(standard = "bayahtreecheh", premium = "beh-ah-tree-cheh", ipa = "B EY0 AA0 T R IY1 CH EY0"),
    "elisa" = list(standard = "eleesah", premium = "eh-lee-sah", ipa = "EH0 L IY1 S AA0"),
    "camilla" = list(standard = "kahmillah", premium = "kah-mil-lah", ipa = "K AA0 M IY1 L AA0"),
    "greta" = list(standard = "graytah", premium = "greh-tah", ipa = "G R EY1 T AA0"),
    "alice" = list(standard = "ahleecheh", premium = "ah-lee-cheh", ipa = "AA0 L IY1 CH EY0"),
    "vittoria" = list(standard = "veettoryah", premium = "veet-tor-yah", ipa = "V IY0 T OR1 Y AA0")
  )

  # Check dictionary first
  if (!is.null(italian_dictionary[[result]])) {
    dict_entry <- italian_dictionary[[result]]
    dict_entry$from_dictionary <- TRUE
    return(dict_entry)
  }

  # Pattern-based rules for other Italian names
  result_standard <- result
  result_premium <- result

  italian_patterns_standard <- list(
    "ghi" = "ghee", "ghe" = "gay", "chi" = "kee", "che" = "kay",
    "gia" = "jah", "gio" = "joh", "gi" = "jee",
    "gna" = "nyah", "gne" = "nyeh", "gni" = "nyee", "gno" = "nyoh",
    "gli" = "lyee", "glia" = "lyah", "glio" = "lyoh",
    "sc" = "sh", "z" = "ts"
  )

  italian_patterns_premium <- list(
    "ghi" = "ghee", "ghe" = "gay", "chi" = "kee", "che" = "kay",
    "gia" = "jah", "gio" = "joh", "gi" = "jee",
    "gna" = "nyah", "gne" = "nyeh", "gni" = "nyee", "gno" = "nyoh",
    "gli" = "lyee", "glia" = "lyah", "glio" = "lyoh",
    "sc" = "sh", "z" = "ts"
  )

  for (pattern in names(italian_patterns_standard)[order(nchar(names(italian_patterns_standard)), decreasing = TRUE)]) {
    result_standard <- gsub(pattern, italian_patterns_standard[[pattern]], result_standard, ignore.case = TRUE)
    result_premium <- gsub(pattern, italian_patterns_premium[[pattern]], result_premium, ignore.case = TRUE)
  }

  # For pattern-based names, don't generate fake CMU - it produces bad results
  # Let ElevenLabs use the phonetic respelling as plain text instead
  return(list(standard = result_standard, premium = result_premium, ipa = NULL, from_dictionary = FALSE))
}

# French phonetic rules
# Returns BOTH standard and premium voice optimized spellings
apply_french_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE FRENCH NAME DICTIONARY
  french_dictionary <- list(
    # Common Male Names (with proper IPA including stress marks)
    "jean" = list(standard = "zhahn", premium = "zhahn", ipa = "ZH AA1 N"),
    "pierre" = list(standard = "pyehr", premium = "pyehr", ipa = "P Y EH1 R"),
    "louis" = list(standard = "looee", premium = "loo-ee", ipa = "L UW1 IY0"),
    "jacques" = list(standard = "zhahk", premium = "zhahk", ipa = "ZH AA1 K"),
    "françois" = list(standard = "frahnswa", premium = "frahn-swa", ipa = "F R AA1 N S W AA0"),
    "andré" = list(standard = "ahndray", premium = "ahn-dray", ipa = "AA1 N D R EY0"),
    "michel" = list(standard = "meeshel", premium = "mee-shel", ipa = "M IY1 SH EH0 L"),
    "philippe" = list(standard = "feeleep", premium = "fee-leep", ipa = "F IY1 L IY0 P"),
    "alain" = list(standard = "ahlan", premium = "ah-lan", ipa = "AA1 L AE0 N"),
    "olivier" = list(standard = "oleevyay", premium = "o-lee-vyay", ipa = "AO1 L IY0 V Y EY0"),
    "bernard" = list(standard = "bernahr", premium = "ber-nahr", ipa = "B EH1 R N AA0 R"),
    "nicolas" = list(standard = "neekola", premium = "nee-ko-la", ipa = "N IY1 K AO0 L AA0"),
    "antoine" = list(standard = "ahntwan", premium = "ahn-twan", ipa = "AA1 N T W AA0 N"),
    "vincent" = list(standard = "vansahn", premium = "van-sahn", ipa = "V AE1 N S AA0 N"),
    "marc" = list(standard = "mahrk", premium = "mahrk", ipa = "M AA1 R K"),
    "pascal" = list(standard = "pahskahl", premium = "pahs-kahl", ipa = "P AA1 S K AA0 L"),
    "thierry" = list(standard = "tyehree", premium = "tyeh-ree", ipa = "T Y EH1 R IY0"),
    "laurent" = list(standard = "lohrahn", premium = "loh-rahn", ipa = "L AO1 R AA0 N"),
    "christophe" = list(standard = "kreestof", premium = "krees-tof", ipa = "K R IY1 S T AO0 F"),
    "patrice" = list(standard = "pahtrees", premium = "pah-trees", ipa = "P AA1 T R IY0 S"),
    "yves" = list(standard = "eev", premium = "eev", ipa = "IY1 V"),
    "gilles" = list(standard = "zheel", premium = "zheel", ipa = "ZH IY1 L"),
    "arnaud" = list(standard = "ahrno", premium = "ahr-no", ipa = "AA1 R N OW0"),
    "maxime" = list(standard = "mahkseem", premium = "mahk-seem", ipa = "M AA1 K S IY0 M"),
    "romain" = list(standard = "roman", premium = "ro-man", ipa = "R OW1 M AE0 N"),

    # Common Female Names (with proper IPA including stress marks)
    "marie" = list(standard = "mahree", premium = "mah-ree", ipa = "M AA1 R IY0"),
    "sophie" = list(standard = "sofee", premium = "so-fee", ipa = "S OW1 F IY0"),
    "nathalie" = list(standard = "natahlee", premium = "nah-tah-lee", ipa = "N AA1 T AA0 L IY0"),
    "isabelle" = list(standard = "eezahbel", premium = "ee-zah-bel", ipa = "IY1 Z AA0 B EH0 L"),
    "sylvie" = list(standard = "seelvee", premium = "seel-vee", ipa = "S IY1 L V IY0"),
    "catherine" = list(standard = "kahtreen", premium = "kah-treen", ipa = "K AA1 T R IY0 N"),
    "françoise" = list(standard = "frahnswahz", premium = "frahn-swahz", ipa = "F R AA1 N S W AA0 Z"),
    "monique" = list(standard = "moneek", premium = "mo-neek", ipa = "M OW1 N IY0 K"),
    "christine" = list(standard = "kreesteen", premium = "krees-teen", ipa = "K R IY1 S T IY0 N"),
    "véronique" = list(standard = "veyroneek", premium = "vey-ro-neek", ipa = "V EY1 R OW0 N IY0 K"),
    "brigitte" = list(standard = "breejeet", premium = "bree-jeet", ipa = "B R IY1 ZH IY0 T"),
    "claire" = list(standard = "klehr", premium = "klehr", ipa = "K L EH1 R"),
    "céline" = list(standard = "seyleen", premium = "say-lynn", ipa = "S EY1 L IH0 N"),
    "celine" = list(standard = "seyleen", premium = "say-lynn", ipa = "S EY1 L IH0 N"),
    "émilie" = list(standard = "aymelee", premium = "ay-mee-lee", ipa = "EY1 M IY0 L IY0"),
    "emilie" = list(standard = "aymelee", premium = "ay-mee-lee", ipa = "EY1 M IY0 L IY0"),
    "julie" = list(standard = "zhoolee", premium = "zhoo-lee", ipa = "ZH UW1 L IY0"),
    "camille" = list(standard = "kahmee", premium = "kah-mee", ipa = "K AA1 M IY0"),
    "charlotte" = list(standard = "shahrlot", premium = "shahr-lot", ipa = "SH AA1 R L AO0 T"),
    "léa" = list(standard = "layah", premium = "lay-ah", ipa = "L EY1 AA0"),
    "lea" = list(standard = "layah", premium = "lay-ah", ipa = "L EY1 AA0"),
    "manon" = list(standard = "mahnon", premium = "mah-non", ipa = "M AA1 N AO0 N"),
    "chloé" = list(standard = "kloh-ay", premium = "kloh-ay", ipa = "K L OW1 EY0"),
    "chloe" = list(standard = "kloh-ay", premium = "kloh-ay", ipa = "K L OW1 EY0"),
    "inès" = list(standard = "eeness", premium = "ee-ness", ipa = "IY1 N EH0 S"),
    "ines" = list(standard = "eeness", premium = "ee-ness", ipa = "IY1 N EH0 S"),
    "anaïs" = list(standard = "ahnahees", premium = "ah-nah-ees", ipa = "AA1 N AA0 IY0 S"),
    "anais" = list(standard = "ahnahees", premium = "ah-nah-ees", ipa = "AA1 N AA0 IY0 S"),
    "lucie" = list(standard = "loosee", premium = "loo-see", ipa = "L UW1 S IY0"),
    "pauline" = list(standard = "pohleen", premium = "po-lynn", ipa = "P AO1 L IH0 N"),
    "marine" = list(standard = "mahreen", premium = "mah-reen", ipa = "M AA1 R IY0 N")
  )

  # Check dictionary first
  if (!is.null(french_dictionary[[result]])) {
    dict_entry <- french_dictionary[[result]]
    dict_entry$from_dictionary <- TRUE
    return(dict_entry)
  }

  # Pattern-based rules for other French names
  result_standard <- result
  result_premium <- result

  french_patterns_standard <- list(
    "eau" = "oh", "ou" = "oo", "eu" = "uh", "oi" = "wah",
    "ç" = "s", "ch" = "sh", "gn" = "ny",
    "ille" = "ee", "eille" = "ay",
    "ain" = "an", "ein" = "an", "ien" = "yan"
  )

  french_patterns_premium <- list(
    "eau" = "oh", "ou" = "oo", "eu" = "uh", "oi" = "wah",
    "ç" = "s", "ch" = "sh", "gn" = "ny",
    "ille" = "ee", "eille" = "ay",
    "ain" = "an", "ein" = "an", "ien" = "yan"
  )

  for (pattern in names(french_patterns_standard)[order(nchar(names(french_patterns_standard)), decreasing = TRUE)]) {
    result_standard <- gsub(pattern, french_patterns_standard[[pattern]], result_standard, ignore.case = TRUE)
    result_premium <- gsub(pattern, french_patterns_premium[[pattern]], result_premium, ignore.case = TRUE)
  }

  # For pattern-based names, don't generate fake CMU - it produces bad results
  # Let ElevenLabs use the phonetic respelling as plain text instead
  return(list(standard = result_standard, premium = result_premium, ipa = NULL, from_dictionary = FALSE))
}

# Polish phonetic rules
# Returns BOTH standard and premium voice optimized spellings
apply_polish_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE POLISH NAME DICTIONARY
  polish_dictionary <- list(
    # Common Male Names
    "jan" = list(standard = "yahn", premium = "yahn", ipa = "Y AA1 N"),
    "piotr" = list(standard = "pyoter", premium = "pyo-ter", ipa = "P Y OW1 T R"),
    "andrzej" = list(standard = "ahndzhay", premium = "ahn-dzhay", ipa = "AA1 N JH EY1"),
    "krzysztof" = list(standard = "kshishtof", premium = "kshi-shtof", ipa = "K SH IH1 SH T AO1 F"),
    "stanisław" = list(standard = "stahneeslav", premium = "stah-nees-lav", ipa = "S T AA1 N IY0 S L AA1 V"),
    "tomasz" = list(standard = "tomahsh", premium = "to-mahsh", ipa = "T OW1 M AA1 SH"),
    "paweł" = list(standard = "pahvew", premium = "pah-vew", ipa = "P AA1 V EH0 W"),
    "michał" = list(standard = "meehaw", premium = "mee-haw", ipa = "M IY1 HH AW0"),
    "marcin" = list(standard = "mahrcheen", premium = "mahr-cheen", ipa = "M AA1 R CH IY1 N"),
    "grzegorz" = list(standard = "gzhegosh", premium = "gzhe-gosh", ipa = "G ZH EH1 G AO1 SH"),
    "wojciech" = list(standard = "voit chieh", premium = "voit-chieh", ipa = "V OY1 CH EH1 K"),
    "łukasz" = list(standard = "wookahsh", premium = "woo-kahsh", ipa = "W UW1 K AA1 SH"),
    "adam" = list(standard = "ahdam", premium = "ah-dam", ipa = "AA1 D AA1 M"),
    "jakub" = list(standard = "yahkoob", premium = "yah-koob", ipa = "Y AA1 K UW1 B"),
    "marek" = list(standard = "mahrek", premium = "mah-rek", ipa = "M AA1 R EH1 K"),
    "dariusz" = list(standard = "dahryoosh", premium = "dahr-yoosh", ipa = "D AA1 R Y UW1 SH"),
    "rafał" = list(standard = "rahfaw", premium = "rah-faw", ipa = "R AA1 F AW0"),
    "robert" = list(standard = "robert", premium = "ro-bert", ipa = "R OW1 B EH1 R T"),
    "zbigniew" = list(standard = "zbeeggnyev", premium = "zbee-ggnyev", ipa = "Z B IY1 G N Y EH1 V"),
    "szymon" = list(standard = "shimon", premium = "shi-mon", ipa = "SH IH1 M AO1 N"),
    "bartosz" = list(standard = "bahrtosh", premium = "bahr-tosh", ipa = "B AA1 R T AO1 SH"),
    "mateusz" = list(standard = "mahtayoosh", premium = "mah-tay-oosh", ipa = "M AA1 T EY1 UW1 SH"),
    "kamil" = list(standard = "kahmeel", premium = "kah-meel", ipa = "K AA1 M IY1 L"),
    "dawid" = list(standard = "dahveed", premium = "dah-veed", ipa = "D AA1 V IY1 D"),
    "jacek" = list(standard = "yahtsek", premium = "yah-tsek", ipa = "Y AA1 T S EH1 K"),

    # Common Female Names
    "anna" = list(standard = "ahnah", premium = "ah-nah", ipa = "AA1 N AA0"),
    "maria" = list(standard = "mahryah", premium = "mah-ryah", ipa = "M AA1 R IY0 AA0"),
    "katarzyna" = list(standard = "kahtahzhinah", premium = "kah-tah-zhi-nah", ipa = "K AA1 T AA0 ZH IY0 N AA0"),
    "małgorzata" = list(standard = "mawgozhatah", premium = "maw-go-zha-tah", ipa = "M AW1 G OW0 ZH AA0 T AA0"),
    "agnieszka" = list(standard = "ahgnyeshkah", premium = "ahg-nyesh-kah", ipa = "AA1 G N Y EH1 SH K AA0"),
    "barbara" = list(standard = "bahrbahrah", premium = "bahr-bah-rah", ipa = "B AA1 R B AA0 R AA0"),
    "ewa" = list(standard = "evah", premium = "e-vah", ipa = "EH1 V AA0"),
    "krystyna" = list(standard = "kristinah", premium = "kris-ti-nah", ipa = "K R IH1 S T IH0 N AA0"),
    "elżbieta" = list(standard = "elzhbyetah", premium = "elzh-bye-tah", ipa = "EH1 L ZH B Y EH1 T AA0"),
    "joanna" = list(standard = "yoanah", premium = "yo-ah-nah", ipa = "Y OW1 AA1 N AA0"),
    "magdalena" = list(standard = "mahgdalenah", premium = "mahg-da-le-nah", ipa = "M AA1 G D AA0 L EH0 N AA0"),
    "monika" = list(standard = "moneekah", premium = "mo-nee-kah", ipa = "M OW1 N IY0 K AA0"),
    "natalia" = list(standard = "nahtahlyah", premium = "nah-tahl-yah", ipa = "N AA1 T AA0 L Y AA0"),
    "dorota" = list(standard = "dorotah", premium = "do-ro-tah", ipa = "D OW1 R OW0 T AA0"),
    "zofia" = list(standard = "zofyah", premium = "zof-yah", ipa = "Z OW1 F Y AA0"),
    "aleksandra" = list(standard = "aleksahndrah", premium = "a-lek-sahn-drah", ipa = "AA1 L EH0 K S AA1 N D R AA0"),
    "karolina" = list(standard = "kahroleenah", premium = "kah-ro-lee-nah", ipa = "K AA1 R OW0 L IY0 N AA0"),
    "paulina" = list(standard = "powleenah", premium = "pow-lee-nah", ipa = "P AW1 L IY0 N AA0"),
    "justyna" = list(standard = "yoostinah", premium = "yoos-ti-nah", ipa = "Y UW1 S T IH0 N AA0"),
    "beata" = list(standard = "bayahtah", premium = "bay-ah-tah", ipa = "B EH1 AA0 T AA0"),
    "iwona" = list(standard = "eevonah", premium = "ee-vo-nah", ipa = "IY1 V OW0 N AA0"),
    "sylwia" = list(standard = "silvyah", premium = "sil-vyah", ipa = "S IH1 L V Y AA0"),
    "renata" = list(standard = "renahtah", premium = "re-nah-tah", ipa = "R EH1 N AA0 T AA0"),
    "weronika" = list(standard = "veroneekah", premium = "ve-ro-nee-kah", ipa = "V EH1 R OW0 N IY0 K AA0"),
    "patrycja" = list(standard = "pahtritzyah", premium = "pah-tri-tzyah", ipa = "P AA1 T R IH1 T S Y AA0")
  )

  # Check dictionary first
  if (!is.null(polish_dictionary[[result]])) {
    dict_entry <- polish_dictionary[[result]]
    dict_entry$from_dictionary <- TRUE
    return(dict_entry)
  }

  # Pattern-based rules for other Polish names
  result_standard <- result
  result_premium <- result

  polish_patterns_standard <- list(
    "cz" = "ch", "sz" = "sh", "rz" = "zh", "ż" = "zh", "ź" = "zh",
    "ł" = "w", "ć" = "ch", "ń" = "ny", "ś" = "sh"
  )

  polish_patterns_premium <- list(
    "cz" = "ch", "sz" = "sh", "rz" = "zh", "ż" = "zh", "ź" = "zh",
    "ł" = "w", "ć" = "ch", "ń" = "ny", "ś" = "sh"
  )

  for (pattern in names(polish_patterns_standard)[order(nchar(names(polish_patterns_standard)), decreasing = TRUE)]) {
    result_standard <- gsub(pattern, polish_patterns_standard[[pattern]], result_standard, ignore.case = TRUE)
    result_premium <- gsub(pattern, polish_patterns_premium[[pattern]], result_premium, ignore.case = TRUE)
  }

  # For pattern-based names, don't generate fake CMU - it produces bad results
  # Let ElevenLabs use the phonetic respelling as plain text instead
  return(list(standard = result_standard, premium = result_premium, ipa = NULL, from_dictionary = FALSE))
}

# German phonetic rules
# Returns BOTH standard and premium voice optimized spellings
apply_german_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE GERMAN NAME DICTIONARY
  german_dictionary <- list(
    # Common Male Names
    "wolfgang" = list(standard = "volfgahng", premium = "volf-gahng", ipa = "V OW1 L F G AA1 NG"),
    "hans" = list(standard = "hahnz", premium = "hahnz", ipa = "HH AA1 N Z"),
    "klaus" = list(standard = "klows", premium = "klows", ipa = "K L AW1 S"),
    "jürgen" = list(standard = "yurgen", premium = "yur-gen", ipa = "Y UH1 R G EH0 N"),
    "peter" = list(standard = "peyter", premium = "pey-ter", ipa = "P EY1 T ER0"),
    "michael" = list(standard = "meekayel", premium = "mee-kay-el", ipa = "M IY1 K AA0 EH0 L"),
    "thomas" = list(standard = "tomahss", premium = "to-mahss", ipa = "T OW1 M AA1 S"),
    "andreas" = list(standard = "ahndrayahs", premium = "ahn-dray-ahs", ipa = "AA1 N D R EY1 AA0 S"),
    "christian" = list(standard = "kristeahn", premium = "kris-tee-ahn", ipa = "K R IH1 S T Y AA0 N"),
    "stefan" = list(standard = "shtefahn", premium = "shteh-fahn", ipa = "SH T EH1 F AA1 N"),
    "matthias" = list(standard = "mateeahs", premium = "mah-tee-ahs", ipa = "M AA1 T IY0 AA0 S"),
    "alexander" = list(standard = "aleksahnder", premium = "a-lek-sahn-der", ipa = "AA1 L EH0 K S AA1 N D ER0"),
    "daniel" = list(standard = "dahnyel", premium = "dahn-yel", ipa = "D AA1 N IY0 EH0 L"),
    "sebastian" = list(standard = "zebasteahn", premium = "ze-bahs-tee-ahn", ipa = "Z EH1 B AA1 S T Y AA0 N"),
    "martin" = list(standard = "mahrteen", premium = "mahr-teen", ipa = "M AA1 R T IY1 N"),
    "markus" = list(standard = "mahrkoos", premium = "mahr-koos", ipa = "M AA1 R K UW1 S"),
    "tobias" = list(standard = "tobeeahs", premium = "to-bee-ahs", ipa = "T OW1 B IY0 AA0 S"),
    "jan" = list(standard = "yahn", premium = "yahn", ipa = "Y AA1 N"),
    "lukas" = list(standard = "lookahss", premium = "loo-kahss", ipa = "L UW1 K AA1 S"),
    "felix" = list(standard = "fayliks", premium = "fay-liks", ipa = "F EY1 L IH0 K S"),
    "maximilian" = list(standard = "maksimeeliahn", premium = "mak-si-mee-lee-ahn", ipa = "M AA1 K S IY0 M IY0 L Y AA1 N"),
    "jonas" = list(standard = "yonahss", premium = "yo-nahss", ipa = "Y OW1 N AA1 S"),
    "leon" = list(standard = "layohn", premium = "lay-ohn", ipa = "L EY1 AA0 N"),
    "paul" = list(standard = "powl", premium = "powl", ipa = "P AW1 L"),
    "noah" = list(standard = "noahh", premium = "no-ahh", ipa = "N OW1 AA1"),

    # Common Female Names
    "anna" = list(standard = "ahnah", premium = "ah-nah", ipa = "AA1 N AA0"),
    "maria" = list(standard = "mahreeah", premium = "mah-ree-ah", ipa = "M AA1 R IY0 AA0"),
    "ursula" = list(standard = "oorzoolah", premium = "oor-zoo-lah", ipa = "UH1 R S UW0 L AA0"),
    "monika" = list(standard = "moneekah", premium = "mo-nee-kah", ipa = "M OW1 N IY0 K AA0"),
    "karin" = list(standard = "kahreen", premium = "kah-reen", ipa = "K AA1 R IY1 N"),
    "petra" = list(standard = "peytrah", premium = "pey-trah", ipa = "P EY1 T R AA0"),
    "sabine" = list(standard = "zahbeeneh", premium = "zah-bee-neh", ipa = "Z AA1 B IY0 N EH0"),
    "christine" = list(standard = "kristeeneh", premium = "kris-tee-neh", ipa = "K R IH1 S T IY0 N EH0"),
    "gabriele" = list(standard = "gahbreeyayleh", premium = "gah-bree-ay-leh", ipa = "G AA1 B R IY0 EY1 L EH0"),
    "susanne" = list(standard = "zoozahneh", premium = "zoo-zah-neh", ipa = "Z UW1 Z AA0 N EH0"),
    "andrea" = list(standard = "ahndrayah", premium = "ahn-dray-ah", ipa = "AA1 N D R EY1 AA0"),
    "heike" = list(standard = "hykeh", premium = "hy-keh", ipa = "HH AY1 K EH0"),
    "nicole" = list(standard = "neekoleh", premium = "nee-ko-leh", ipa = "N IY1 K OW0 L EH0"),
    "claudia" = list(standard = "klowdyah", premium = "klow-dyah", ipa = "K L AW1 D IY0 AA0"),
    "stefanie" = list(standard = "shtefahneeh", premium = "shteh-fah-nee", ipa = "SH T EH1 F AA0 N IY0"),
    "julia" = list(standard = "yoolyah", premium = "yoo-lyah", ipa = "Y UW1 L Y AA0"),
    "katharina" = list(standard = "kahtahreenah", premium = "kah-tah-ree-nah", ipa = "K AA1 T AA0 R IY0 N AA0"),
    "lisa" = list(standard = "leezah", premium = "lee-zah", ipa = "L IY1 Z AA0"),
    "sarah" = list(standard = "zahrah", premium = "zah-rah", ipa = "Z AA1 R AA0"),
    "laura" = list(standard = "lowrah", premium = "low-rah", ipa = "L AW1 R AA0"),
    "marie" = list(standard = "mahreeh", premium = "mah-ree", ipa = "M AA1 R IY1"),
    "sophie" = list(standard = "zofeeh", premium = "zo-fee", ipa = "Z OW1 F IY1"),
    "emma" = list(standard = "emmah", premium = "em-mah", ipa = "EH1 M AA0"),
    "hannah" = list(standard = "hahnah", premium = "hah-nah", ipa = "HH AA1 N AA0"),
    "mia" = list(standard = "meeah", premium = "mee-ah", ipa = "M IY1 AA0")
  )

  # Check dictionary first
  if (!is.null(german_dictionary[[result]])) {
    dict_entry <- german_dictionary[[result]]
    dict_entry$from_dictionary <- TRUE
    return(dict_entry)
  }

  # Pattern-based rules for other German names
  result_standard <- result
  result_premium <- result

  german_patterns_standard <- list(
    "sch" = "sh", "ch" = "kh", "ß" = "ss",
    "ä" = "eh", "ö" = "er", "ü" = "oo",
    "ei" = "eye", "ie" = "ee", "eu" = "oy"
  )

  german_patterns_premium <- list(
    "sch" = "sh", "ch" = "kh", "ß" = "ss",
    "ä" = "eh", "ö" = "er", "ü" = "oo",
    "ei" = "eye", "ie" = "ee", "eu" = "oy"
  )

  for (pattern in names(german_patterns_standard)[order(nchar(names(german_patterns_standard)), decreasing = TRUE)]) {
    result_standard <- gsub(pattern, german_patterns_standard[[pattern]], result_standard, ignore.case = TRUE)
    result_premium <- gsub(pattern, german_patterns_premium[[pattern]], result_premium, ignore.case = TRUE)
  }

  # For pattern-based names, don't generate fake CMU - it produces bad results
  # Let ElevenLabs use the phonetic respelling as plain text instead
  return(list(standard = result_standard, premium = result_premium, ipa = NULL, from_dictionary = FALSE))
}

# Portuguese phonetic rules (Brazilian focus)
# Returns BOTH standard and premium voice optimized spellings
apply_portuguese_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE PORTUGUESE NAME DICTIONARY (Brazilian Portuguese)
  portuguese_dictionary <- list(
    # Common Male Names
    "joão" = list(standard = "zhowow", premium = "zhow-ow", ipa = "ZH W AW1"),
    "joao" = list(standard = "zhowow", premium = "zhow-ow", ipa = "ZH W AW1"),
    "josé" = list(standard = "zhoozay", premium = "zhoo-zay", ipa = "ZH OW0 Z EY1"),
    "jose" = list(standard = "zhoozay", premium = "zhoo-zay", ipa = "ZH OW0 Z EY1"),
    "francisco" = list(standard = "frahnseeskoo", premium = "frahn-sees-koo", ipa = "F R AA0 N S IY1 S K OW0"),
    "antónio" = list(standard = "ahntoneeoo", premium = "ahn-to-nee-oo", ipa = "AA0 N T OW1 N Y OW0"),
    "antonio" = list(standard = "ahntoneeoo", premium = "ahn-to-nee-oo", ipa = "AA0 N T OW1 N Y OW0"),
    "carlos" = list(standard = "kahrloos", premium = "kahr-loos", ipa = "K AA1 R L OW0 S"),
    "paulo" = list(standard = "powloo", premium = "pow-loo", ipa = "P AW1 L OW0"),
    "pedro" = list(standard = "pedroo", premium = "ped-roo", ipa = "P EY1 D R OW0"),
    "lucas" = list(standard = "lookahss", premium = "loo-kahss", ipa = "L UW1 K AA0 S"),
    "gabriel" = list(standard = "gahbreeyel", premium = "gah-bree-yel", ipa = "G AA0 B R IY1 EH0 L"),
    "rafael" = list(standard = "hahfahyel", premium = "hah-fah-yel", ipa = "HH AA0 F AA1 EH0 L"),
    "miguel" = list(standard = "meegel", premium = "mee-gel", ipa = "M IY1 G EH0 L"),
    "mateus" = list(standard = "mahtayooss", premium = "mah-tay-ooss", ipa = "M AA0 T EY1 UW0 S"),
    "felipe" = list(standard = "feleepee", premium = "fe-lee-pee", ipa = "F EH0 L IY1 P EH0"),
    "bruno" = list(standard = "broonoo", premium = "broo-noo", ipa = "B R UW1 N OW0"),
    "andré" = list(standard = "ahndray", premium = "ahn-dray", ipa = "AA0 N D R EY1"),
    "andre" = list(standard = "ahndray", premium = "ahn-dray", ipa = "AA0 N D R EY1"),
    "diego" = list(standard = "deeaygoo", premium = "dee-ay-goo", ipa = "D IY0 EY1 G OW0"),
    "fernando" = list(standard = "fernahndoo", premium = "fer-nahn-doo", ipa = "F EH0 R N AA1 N D OW0"),
    "ricardo" = list(standard = "heekahdoo", premium = "hee-kahr-doo", ipa = "HH IY0 K AA1 R D OW0"),
    "eduardo" = list(standard = "aydwahdoo", premium = "ay-dwahr-doo", ipa = "EH0 D UW0 AA1 R D OW0"),
    "gustavo" = list(standard = "gooshtahvoo", premium = "goosh-tah-voo", ipa = "G UW0 S T AA1 V OW0"),
    "rodrigo" = list(standard = "hoodreegoo", premium = "hoo-dree-goo", ipa = "HH OW0 D R IY1 G OW0"),
    "daniel" = list(standard = "dahneeyel", premium = "dah-nee-yel", ipa = "D AA0 N Y EH1 L"),
    "leonardo" = list(standard = "layonahrdoo", premium = "lay-o-nahr-doo", ipa = "L EY0 OW0 N AA1 R D OW0"),
    "marcelo" = list(standard = "mahrseloo", premium = "mahr-se-loo", ipa = "M AA0 R S EY1 L OW0"),
    "vitor" = list(standard = "veetorh", premium = "vee-torh", ipa = "V IY1 T OR0"),

    # Common Female Names
    "maria" = list(standard = "mahreeah", premium = "mah-ree-ah", ipa = "M AA0 R IY1 AA0"),
    "ana" = list(standard = "ahnah", premium = "ah-nah", ipa = "AA1 N AA0"),
    "francisca" = list(standard = "frahnseeskah", premium = "frahn-sees-kah", ipa = "F R AA0 N S IY1 S K AA0"),
    "isabel" = list(standard = "eezahbel", premium = "ee-zah-bel", ipa = "IY0 Z AA0 B EH1 L"),
    "beatriz" = list(standard = "bayahtreesh", premium = "bay-ah-treesh", ipa = "B EY0 AA0 T R IY1 S"),
    "sofia" = list(standard = "sofeeyah", premium = "so-fee-yah", ipa = "S OW0 F IY1 AA0"),
    "laura" = list(standard = "lowrah", premium = "low-rah", ipa = "L AW1 R AA0"),
    "mariana" = list(standard = "mahreeyahnah", premium = "mah-ree-yah-nah", ipa = "M AA0 R IY0 AA1 N AA0"),
    "júlia" = list(standard = "zhoolyah", premium = "zhoo-lyah", ipa = "ZH UW1 L Y AA0"),
    "julia" = list(standard = "zhoolyah", premium = "zhoo-lyah", ipa = "ZH UW1 L Y AA0"),
    "camila" = list(standard = "kahmeelah", premium = "kah-mee-lah", ipa = "K AA0 M IY1 L AA0"),
    "fernanda" = list(standard = "fernahndah", premium = "fer-nahn-dah", ipa = "F EH0 R N AA1 N D AA0"),
    "juliana" = list(standard = "zhoolee'ahnah", premium = "zhoo-lee-ah-nah", ipa = "ZH UW0 L Y AA1 N AA0"),
    "carla" = list(standard = "kahrlah", premium = "kahr-lah", ipa = "K AA1 R L AA0"),
    "patricia" = list(standard = "pahtreeseeah", premium = "pah-tree-see-ah", ipa = "P AA0 T R IY1 S Y AA0"),
    "amanda" = list(standard = "ahmahdah", premium = "ah-mahn-dah", ipa = "AA0 M AA1 N D AA0"),
    "bianca" = list(standard = "beeahkah", premium = "bee-ahn-kah", ipa = "B IY0 AA1 N K AA0"),
    "gabriela" = list(standard = "gahbreeyaylah", premium = "gah-bree-ay-lah", ipa = "G AA0 B R IY0 EH1 L AA0"),
    "larissa" = list(standard = "lahreessah", premium = "lah-ree-ssah", ipa = "L AA0 R IY1 S AA0"),
    "leticia" = list(standard = "leteeseeah", premium = "le-tee-see-ah", ipa = "L EH0 T IY1 S Y AA0"),
    "letícia" = list(standard = "leteeseeah", premium = "le-tee-see-ah", ipa = "L EH0 T IY1 S Y AA0"),
    "carolina" = list(standard = "kahroleenah", premium = "kah-ro-lee-nah", ipa = "K AA0 R OW0 L IY1 N AA0"),
    "vitoria" = list(standard = "veetoryah", premium = "vee-tor-yah", ipa = "V IY0 T OR1 Y AA0"),
    "vitória" = list(standard = "veetoryah", premium = "vee-tor-yah", ipa = "V IY0 T OR1 Y AA0"),
    "alice" = list(standard = "ahleesee", premium = "ah-lee-see", ipa = "AA0 L IY1 S IY0"),
    "helena" = list(standard = "aylaynah", premium = "ay-lay-nah", ipa = "EH0 L EY1 N AA0"),
    "manuela" = list(standard = "mahnwaylah", premium = "mahn-way-lah", ipa = "M AA0 N UW0 EH1 L AA0"),
    "valentina" = list(standard = "vahlaynteenah", premium = "vah-layn-tee-nah", ipa = "V AA0 L EH0 N T IY1 N AA0")
  )

  # Check dictionary first
  if (!is.null(portuguese_dictionary[[result]])) {
    dict_entry <- portuguese_dictionary[[result]]
    dict_entry$from_dictionary <- TRUE
    return(dict_entry)
  }

  # Pattern-based rules for other Portuguese names
  result_standard <- result
  result_premium <- result

  portuguese_patterns_standard <- list(
    "nh" = "ny", "lh" = "ly", "ão" = "ow", "ã" = "ahn",
    "õe" = "oynsh", "õ" = "ohn", "ch" = "sh",
    "j" = "zh", "ge" = "zheh", "gi" = "zhee",
    "ç" = "ss", "x" = "sh", "z" = "z"
  )

  portuguese_patterns_premium <- list(
    "nh" = "ny", "lh" = "ly", "ão" = "ow", "ã" = "ahn",
    "õe" = "oynsh", "õ" = "ohn", "ch" = "sh",
    "j" = "zh", "ge" = "zheh", "gi" = "zhee",
    "ç" = "ss", "x" = "sh", "z" = "z"
  )

  for (pattern in names(portuguese_patterns_standard)[order(nchar(names(portuguese_patterns_standard)), decreasing = TRUE)]) {
    result_standard <- gsub(pattern, portuguese_patterns_standard[[pattern]], result_standard, ignore.case = TRUE)
    result_premium <- gsub(pattern, portuguese_patterns_premium[[pattern]], result_premium, ignore.case = TRUE)
  }

  # For pattern-based names, don't generate fake CMU - it produces bad results
  # Let ElevenLabs use the phonetic respelling as plain text instead
  return(list(standard = result_standard, premium = result_premium, ipa = NULL, from_dictionary = FALSE))
}

# Japanese phonetic rules (Romaji)
# Returns BOTH standard and premium voice optimized spellings
apply_japanese_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE JAPANESE NAME DICTIONARY (Romanized)
  japanese_dictionary <- list(
    # Common Male Names
    "hiroshi" = list(standard = "heeroashee", premium = "hee-ro-shee", ipa = "HH IY1 R OW0 SH IY0"),
    "takeshi" = list(standard = "tahkayshee", premium = "tah-keh-shee", ipa = "T AA1 K EH0 SH IY0"),
    "kenji" = list(standard = "kenjee", premium = "ken-jee", ipa = "K EH1 N JH IY0"),
    "satoshi" = list(standard = "sahtoshee", premium = "sah-to-shee", ipa = "S AA1 T OW0 SH IY0"),
    "takashi" = list(standard = "tahkahshee", premium = "tah-kah-shee", ipa = "T AA1 K AA0 SH IY0"),
    "yuki" = list(standard = "yookee", premium = "yoo-kee", ipa = "Y UW1 K IY0"),
    "koji" = list(standard = "kojee", premium = "ko-jee", ipa = "K OW1 JH IY0"),
    "ryota" = list(standard = "reeotah", premium = "ree-o-tah", ipa = "R Y OW1 T AA0"),
    "daiki" = list(standard = "dyeekee", premium = "dye-kee", ipa = "D AY1 K IY0"),
    "haruto" = list(standard = "hahrooto", premium = "hah-roo-to", ipa = "HH AA1 R UW0 T OW0"),
    "yuto" = list(standard = "yooto", premium = "yoo-to", ipa = "Y UW1 T OW0"),
    "sota" = list(standard = "sohtah", premium = "soh-tah", ipa = "S OW1 T AA0"),
    "kaito" = list(standard = "kyeeto", premium = "kye-to", ipa = "K AY1 T OW0"),
    "riku" = list(standard = "reekoo", premium = "ree-koo", ipa = "R IY1 K UW0"),
    "hayato" = list(standard = "hahyahto", premium = "hah-yah-to", ipa = "HH AA1 Y AA0 T OW0"),
    "taro" = list(standard = "tahroh", premium = "tah-roh", ipa = "T AA1 R OW0"),
    "ichiro" = list(standard = "eecheeroh", premium = "ee-chee-roh", ipa = "IY1 CH IY0 R OW0"),
    "jiro" = list(standard = "jeeroh", premium = "jee-roh", ipa = "JH IY1 R OW0"),
    "shota" = list(standard = "shohtah", premium = "shoh-tah", ipa = "SH OW1 T AA0"),
    "kenta" = list(standard = "kentah", premium = "ken-tah", ipa = "K EH1 N T AA0"),
    "masato" = list(standard = "mahsahto", premium = "mah-sah-to", ipa = "M AA1 S AA0 T OW0"),
    "naoki" = list(standard = "nowkee", premium = "now-kee", ipa = "N AA1 OW0 K IY0"),
    "yusuke" = list(standard = "yooskay", premium = "yoos-keh", ipa = "Y UW1 S K EH0"),
    "daisuke" = list(standard = "dyeeskay", premium = "dye-skeh", ipa = "D AY1 S K EH0"),
    "kazuki" = list(standard = "kahzookee", premium = "kah-zoo-kee", ipa = "K AA1 Z UW0 K IY0"),

    # Common Female Names
    "sakura" = list(standard = "sahkoorahh", premium = "sah-koo-rah", ipa = "S AA1 K UW0 R AA0"),
    "hana" = list(standard = "hahnah", premium = "hah-nah", ipa = "HH AA1 N AA0"),
    "aiko" = list(standard = "eyekoh", premium = "eye-koh", ipa = "AY1 K OW0"),
    "yui" = list(standard = "yooee", premium = "yoo-ee", ipa = "Y UW1 IY0"),
    "rin" = list(standard = "reen", premium = "reen", ipa = "R IY1 N"),
    "mio" = list(standard = "meeoh", premium = "mee-oh", ipa = "M IY1 OW0"),
    "ayaka" = list(standard = "ahyahkah", premium = "ah-yah-kah", ipa = "AA1 Y AA0 K AA0"),
    "haruka" = list(standard = "hahrookah", premium = "hah-roo-kah", ipa = "HH AA1 R UW0 K AA0"),
    "nanami" = list(standard = "nahnahmee", premium = "nah-nah-mee", ipa = "N AA1 N AA0 M IY0"),
    "misaki" = list(standard = "meesahkee", premium = "mee-sah-kee", ipa = "M IY1 S AA0 K IY0"),
    "yuna" = list(standard = "yoonah", premium = "yoo-nah", ipa = "Y UW1 N AA0"),
    "akari" = list(standard = "ahkaree", premium = "ah-kah-ree", ipa = "AA1 K AA0 R IY0"),
    "hinata" = list(standard = "heenahta", premium = "hee-nah-tah", ipa = "HH IY1 N AA0 T AA0"),
    "mei" = list(standard = "may", premium = "may", ipa = "M EY1"),
    "saki" = list(standard = "sahkee", premium = "sah-kee", ipa = "S AA1 K IY0"),
    "miyu" = list(standard = "meeyoo", premium = "mee-yoo", ipa = "M IY1 Y UW0"),
    "riko" = list(standard = "reekoh", premium = "ree-koh", ipa = "R IY1 K OW0"),
    "kana" = list(standard = "kahnah", premium = "kah-nah", ipa = "K AA1 N AA0"),
    "emi" = list(standard = "emmee", premium = "em-mee", ipa = "EH1 M IY0"),
    "kaori" = list(standard = "kahohree", premium = "kah-oh-ree", ipa = "K AA1 OW0 R IY0"),
    "natsuki" = list(standard = "nahtsookee", premium = "naht-soo-kee", ipa = "N AA1 T S K IY0"),
    "asuka" = list(standard = "ahsookah", premium = "ah-soo-kah", ipa = "AA1 S K AA0"),
    "haru" = list(standard = "hahroo", premium = "hah-roo", ipa = "HH AA1 R UW0")
  )

  # Check dictionary first
  if (!is.null(japanese_dictionary[[result]])) {
    dict_entry <- japanese_dictionary[[result]]
    dict_entry$from_dictionary <- TRUE
    return(dict_entry)
  }

  # Pattern-based rules for other Japanese names
  result_standard <- result
  result_premium <- result

  japanese_patterns_standard <- list(
    "shi" = "shee", "chi" = "chee", "tsu" = "tsoo",
    "fu" = "foo", "ji" = "jee", "zu" = "zoo",
    "o" = "oh", "u" = "oo", "e" = "eh",
    "a" = "ah", "i" = "ee"
  )

  japanese_patterns_premium <- list(
    "shi" = "shee", "chi" = "chee", "tsu" = "tsoo",
    "fu" = "foo", "ji" = "jee", "zu" = "zoo",
    "o" = "oh", "u" = "oo", "e" = "eh",
    "a" = "ah", "i" = "ee"
  )

  for (pattern in names(japanese_patterns_standard)[order(nchar(names(japanese_patterns_standard)), decreasing = TRUE)]) {
    result_standard <- gsub(pattern, japanese_patterns_standard[[pattern]], result_standard, ignore.case = TRUE)
    result_premium <- gsub(pattern, japanese_patterns_premium[[pattern]], result_premium, ignore.case = TRUE)
  }

  # For pattern-based names, don't generate fake CMU - it produces bad results
  # Let ElevenLabs use the phonetic respelling as plain text instead
  return(list(standard = result_standard, premium = result_premium, ipa = NULL, from_dictionary = FALSE))
}

# Russian phonetic rules (transliterated)
# Returns BOTH standard and premium voice optimized spellings
apply_russian_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE RUSSIAN NAME DICTIONARY (Transliterated)
  russian_dictionary <- list(
    # Common Male Names
    "aleksandr" = list(standard = "ahleksahndr", premium = "ah-lek-sahndr", ipa = "AA1 L EH0 K S AA1 N D R"),
    "dmitry" = list(standard = "dmeeetree", premium = "dmee-tree", ipa = "D M IY1 T R IY1"),
    "sergey" = list(standard = "sergay", premium = "ser-gay", ipa = "S ER1 G EY1"),
    "andrey" = list(standard = "ahndray", premium = "ahn-dray", ipa = "AA1 N D R EY1"),
    "ivan" = list(standard = "eevahn", premium = "ee-vahn", ipa = "IY1 V AA1 N"),
    "mikhail" = list(standard = "meekaheel", premium = "mee-kah-eel", ipa = "M IY1 K AA0 IY1 L"),
    "nikolai" = list(standard = "neekolye", premium = "nee-ko-lye", ipa = "N IY1 K OW0 L AY1"),
    "vladimir" = list(standard = "vlahdeemeer", premium = "vlah-dee-meer", ipa = "V L AA1 D IY0 M IY1 R"),
    "pavel" = list(standard = "pahvel", premium = "pah-vel", ipa = "P AA1 V EH1 L"),
    "alexey" = list(standard = "ahleksay", premium = "ah-lek-say", ipa = "AA1 L EH0 K S EY1"),
    "artem" = list(standard = "ahrtyem", premium = "ahr-tyem", ipa = "AA1 R T Y AO1 M"),
    "maxim" = list(standard = "mahkseem", premium = "mahk-seem", ipa = "M AA1 K S IY1 M"),
    "kirill" = list(standard = "keereel", premium = "kee-reel", ipa = "K IY1 R IY1 L"),
    "anton" = list(standard = "ahnton", premium = "ahn-ton", ipa = "AA1 N T AO1 N"),
    "yegor" = list(standard = "yegor", premium = "ye-gor", ipa = "Y EH1 G AO1 R"),
    "denis" = list(standard = "deneess", premium = "de-neess", ipa = "D EH1 N IY1 S"),
    "oleg" = list(standard = "ohleg", premium = "oh-leg", ipa = "OW1 L EH1 G"),
    "viktor" = list(standard = "veektorr", premium = "veek-torr", ipa = "V IY1 K T AO1 R"),
    "roman" = list(standard = "rohmahn", premium = "roh-mahn", ipa = "R OW1 M AA1 N"),
    "ruslan" = list(standard = "roosslahn", premium = "rooss-lahn", ipa = "R UW1 S L AA1 N"),
    "vladislav" = list(standard = "vlahdisslav", premium = "vlah-diss-lav", ipa = "V L AA1 D IY0 S L AA1 V"),
    "igor" = list(standard = "eegorr", premium = "ee-gorr", ipa = "IY1 G AO1 R"),
    "konstantin" = list(standard = "konstahntteen", premium = "kon-stahn-teen", ipa = "K AO1 N S T AA1 N T IY1 N"),
    "ilya" = list(standard = "eelyah", premium = "eel-yah", ipa = "IY1 L Y AA0"),
    "evgeny" = list(standard = "yevgennee", premium = "yev-gen-nee", ipa = "Y EH1 V G EY1 N IY1"),

    # Common Female Names
    "anna" = list(standard = "ahnah", premium = "ah-nah", ipa = "AA1 N AA0"),
    "maria" = list(standard = "mahreeah", premium = "mah-ree-ah", ipa = "M AA1 R IY0 AA0"),
    "elena" = list(standard = "yelaynah", premium = "ye-lay-nah", ipa = "EH1 L EH0 N AA0"),
    "olga" = list(standard = "olgah", premium = "ol-gah", ipa = "OW1 L G AA0"),
    "irina" = list(standard = "ireenah", premium = "ee-ree-nah", ipa = "IY1 R IY0 N AA0"),
    "tatiana" = list(standard = "tahtyahnah", premium = "tah-tyah-nah", ipa = "T AA1 T Y AA0 N AA0"),
    "natalia" = list(standard = "nahtahlyah", premium = "nah-tah-lyah", ipa = "N AA1 T AA0 L Y AA0"),
    "yulia" = list(standard = "yoolyah", premium = "yoo-lyah", ipa = "Y UW1 L Y AA0"),
    "ekaterina" = list(standard = "yekahtereenah", premium = "ye-kah-tee-ree-nah", ipa = "Y EH1 K AA0 T EH0 R IY0 N AA0"),
    "svetlana" = list(standard = "svetlahnah", premium = "svet-lah-nah", ipa = "S V EH1 T L AA0 N AA0"),
    "anastasia" = list(standard = "ahnahstahseeah", premium = "ah-nah-stah-see-ah", ipa = "AA1 N AA0 S T AA0 S Y AA0"),
    "daria" = list(standard = "dahreeah", premium = "dah-ree-ah", ipa = "D AA1 R Y AA0"),
    "ksenia" = list(standard = "ksenyah", premium = "ksen-yah", ipa = "K S EH1 N Y AA0"),
    "victoria" = list(standard = "veektoryah", premium = "veek-tor-yah", ipa = "V IY1 K T AO1 R Y AA0"),
    "polina" = list(standard = "poleenah", premium = "po-lee-nah", ipa = "P OW1 L IY0 N AA0"),
    "elizaveta" = list(standard = "yeeleezahvehtah", premium = "yee-lee-zah-veh-tah", ipa = "EH1 L IY0 Z AA0 V EH0 T AA0"),
    "alina" = list(standard = "ahleenah", premium = "ah-lee-nah", ipa = "AA1 L IY0 N AA0"),
    "sofia" = list(standard = "sofeeah", premium = "so-fee-ah", ipa = "S OW1 F IY0 AA0"),
    "veronika" = list(standard = "vehroneekah", premium = "veh-ro-nee-kah", ipa = "V EH1 R OW0 N IY0 K AA0"),
    "margarita" = list(standard = "mahrgahreehtah", premium = "mahr-gah-ree-tah", ipa = "M AA1 R G AA0 R IY0 T AA0"),
    "galina" = list(standard = "gahleenah", premium = "gah-lee-nah", ipa = "G AA1 L IY0 N AA0"),
    "lyudmila" = list(standard = "lyoodmeelah", premium = "lyood-mee-lah", ipa = "L Y UW1 D M IY0 L AA0"),
    "valentina" = list(standard = "vahleenteenah", premium = "vah-leen-tee-nah", ipa = "V AA1 L EH0 N T IY0 N AA0"),
    "nina" = list(standard = "neenah", premium = "nee-nah", ipa = "N IY1 N AA0"),
    "larisa" = list(standard = "lahreesah", premium = "lah-ree-sah", ipa = "L AA1 R IY0 S AA0")
  )

  # Check dictionary first
  if (!is.null(russian_dictionary[[result]])) {
    dict_entry <- russian_dictionary[[result]]
    dict_entry$from_dictionary <- TRUE
    return(dict_entry)
  }

  # Pattern-based rules for other Russian names
  result_standard <- result
  result_premium <- result

  russian_patterns_standard <- list(
    "kh" = "kh", "zh" = "zh", "ch" = "ch", "sh" = "sh",
    "ya" = "yah", "ye" = "yeh", "yo" = "yoh", "yu" = "yoo",
    "iy" = "ee", "ey" = "ay", "oy" = "oy"
  )

  russian_patterns_premium <- list(
    "kh" = "kh", "zh" = "zh", "ch" = "ch", "sh" = "sh",
    "ya" = "yah", "ye" = "yeh", "yo" = "yoh", "yu" = "yoo",
    "iy" = "ee", "ey" = "ay", "oy" = "oy"
  )

  for (pattern in names(russian_patterns_standard)[order(nchar(names(russian_patterns_standard)), decreasing = TRUE)]) {
    result_standard <- gsub(pattern, russian_patterns_standard[[pattern]], result_standard, ignore.case = TRUE)
    result_premium <- gsub(pattern, russian_patterns_premium[[pattern]], result_premium, ignore.case = TRUE)
  }

  # For pattern-based names, don't generate fake CMU - it produces bad results
  # Let ElevenLabs use the phonetic respelling as plain text instead
  return(list(standard = result_standard, premium = result_premium, ipa = NULL, from_dictionary = FALSE))
}

# Hebrew phonetic rules (transliterated)
# Returns BOTH standard and premium voice optimized spellings
apply_hebrew_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE HEBREW NAME DICTIONARY (Transliterated)
  hebrew_dictionary <- list(
    # Common Male Names
    "david" = list(standard = "dahveed", premium = "dah-veed", ipa = "D AA1 V IY0 D"),
    "daniel" = list(standard = "dahneeyel", premium = "dah-nee-yel", ipa = "D AA1 N Y EH0 L"),
    "michael" = list(standard = "meekahyel", premium = "mee-kah-yel", ipa = "M IY1 K AA0 EH0 L"),
    "jonathan" = list(standard = "yonahtahn", premium = "yo-nah-tahn", ipa = "Y OW1 N AA0 T AA0 N"),
    "yonatan" = list(standard = "yonahtahn", premium = "yo-nah-tahn", ipa = "Y OW0 N AA1 T AA0 N"),
    "benjamin" = list(standard = "benyahmeen", premium = "ben-yah-meen", ipa = "B EH1 N Y AA0 M IY0 N"),
    "joshua" = list(standard = "yehohshooah", premium = "ye-hoh-shoo-ah", ipa = "Y EH1 HH OW0 SH UW0 AA0"),
    "yehoshua" = list(standard = "yehohshooah", premium = "ye-hoh-shoo-ah", ipa = "Y EH1 HH OW0 SH UW0 AA0"),
    "jacob" = list(standard = "yahahkov", premium = "yah-ah-kov", ipa = "Y AA1 AA0 K OW0 V"),
    "yaakov" = list(standard = "yahahkov", premium = "yah-ah-kov", ipa = "Y AA1 AA0 K OW0 V"),
    "samuel" = list(standard = "shmooayel", premium = "shmoo-el", ipa = "SH M UW1 EH0 L"),
    "shmuel" = list(standard = "shmooayel", premium = "shmoo-el", ipa = "SH M UW1 EH0 L"),
    "isaac" = list(standard = "yeetskhahk", premium = "yeets-khahk", ipa = "Y IH1 T S K AA0 K"),
    "yitzhak" = list(standard = "yeetskhahk", premium = "yeets-khahk", ipa = "Y IH1 T S K AA0 K"),
    "joseph" = list(standard = "yohsef", premium = "yoh-sef", ipa = "Y OW1 S EH0 F"),
    "yosef" = list(standard = "yohsef", premium = "yoh-sef", ipa = "Y OW1 S EH0 F"),
    "avi" = list(standard = "ahvee", premium = "ah-vee", ipa = "AA1 V IY0"),
    "ariel" = list(standard = "ahreeyel", premium = "ah-ree-yel", ipa = "AA1 R IY0 EH0 L"),
    "eli" = list(standard = "aylee", premium = "ay-lee", ipa = "EY1 L IY0"),
    "noam" = list(standard = "nohahm", premium = "noh-ahm", ipa = "N OW1 AA0 M"),
    "eitan" = list(standard = "aytahn", premium = "ay-tahn", ipa = "EY1 T AA0 N"),
    "uri" = list(standard = "ooree", premium = "oo-ree", ipa = "UW1 R IY0"),
    "gideon" = list(standard = "gidohn", premium = "gi-dohn", ipa = "G IY1 D OW0 N"),
    "omer" = list(standard = "ohmer", premium = "oh-mer", ipa = "OW1 M ER0"),
    "levi" = list(standard = "layvee", premium = "lay-vee", ipa = "L EY1 V IY0"),
    "asher" = list(standard = "ahsher", premium = "ah-sher", ipa = "AA1 SH ER0"),
    "aaron" = list(standard = "ahharohn", premium = "ah-hah-rohn", ipa = "AA1 R AH0 N"),
    "aharon" = list(standard = "ahharohn", premium = "ah-hah-rohn", ipa = "AA1 R AH0 N"),
    "moshe" = list(standard = "mohsheh", premium = "moh-sheh", ipa = "M OW1 SH EH0"),
    "shimon" = list(standard = "sheemohn", premium = "shee-mohn", ipa = "SH IY1 M OW0 N"),
    "reuven" = list(standard = "rehoovayn", premium = "reh-oo-vayn", ipa = "R EH1 UW0 V EY0 N"),
    "nadav" = list(standard = "nahdahv", premium = "nah-dahv", ipa = "N AA1 D AA0 V"),

    # Common Female Names
    "sarah" = list(standard = "sahrah", premium = "sah-rah", ipa = "S AA1 R AA0"),
    "rachel" = list(standard = "rahkhel", premium = "rah-khel", ipa = "R AA1 K EH0 L"),
    "leah" = list(standard = "layah", premium = "lay-ah", ipa = "L EY1 AA0"),
    "miriam" = list(standard = "meeryahm", premium = "meer-yahm", ipa = "M IY1 R Y AA0 M"),
    "hannah" = list(standard = "khahnahh", premium = "khah-nah", ipa = "HH AA1 N AA0"),
    "esther" = list(standard = "ester", premium = "es-ter", ipa = "EH1 S T ER0"),
    "tamar" = list(standard = "tahmahr", premium = "tah-mahr", ipa = "T AA1 M AA0 R"),
    "deborah" = list(standard = "devorahh", premium = "de-vo-rah", ipa = "D EH1 B OW0 R AA0"),
    "ruth" = list(standard = "root", premium = "root", ipa = "R UW1 T"),
    "naomi" = list(standard = "nahomee", premium = "nah-o-mee", ipa = "N AA1 OW0 M IY0"),
    "maya" = list(standard = "mahyah", premium = "mah-yah", ipa = "M AY1 Y AA0"),
    "noa" = list(standard = "nohah", premium = "noh-ah", ipa = "N OW1 AA0"),
    "shira" = list(standard = "sheerah", premium = "shee-rah", ipa = "SH IY1 R AA0"),
    "yael" = list(standard = "yahyel", premium = "yah-yel", ipa = "Y AA1 EH0 L"),
    "talia" = list(standard = "tahlyah", premium = "tah-lyah", ipa = "T AA1 L Y AA0"),
    "michal" = list(standard = "meekhahl", premium = "mee-khahl", ipa = "M IY1 K AA0 L"),
    "avigail" = list(standard = "ahveegahyeel", premium = "ah-vee-gah-yeel", ipa = "AA1 V IY0 G AY0 IY0 L"),
    "liora" = list(standard = "leeohrah", premium = "lee-oh-rah", ipa = "L IY1 OW0 R AA0"),
    "adina" = list(standard = "ahdeenah", premium = "ah-dee-nah", ipa = "AA1 D IY0 N AA0"),
    "rina" = list(standard = "reenah", premium = "ree-nah", ipa = "R IY1 N AA0"),
    "chaya" = list(standard = "khahyah", premium = "khah-yah", ipa = "K AY1 Y AA0"),
    "batya" = list(standard = "bahtyah", premium = "baht-yah", ipa = "B AA1 T Y AA0"),
    "rivka" = list(standard = "reevkah", premium = "reev-kah", ipa = "R IY1 V K AA0"),
    "dina" = list(standard = "deenah", premium = "dee-nah", ipa = "D IY1 N AA0"),
    "eliana" = list(standard = "ehleeahnah", premium = "eh-lee-ah-nah", ipa = "EH1 L IY0 AA0 N AA0")
  )

  # Check dictionary first
  if (!is.null(hebrew_dictionary[[result]])) {
    dict_entry <- hebrew_dictionary[[result]]
    dict_entry$from_dictionary <- TRUE
    return(dict_entry)
  }

  # Pattern-based rules for other Hebrew names
  result_standard <- result
  result_premium <- result

  hebrew_patterns_standard <- list(
    "kh" = "kh", "ch" = "kh", "tz" = "ts",
    "sh" = "sh", "th" = "t"
  )

  hebrew_patterns_premium <- list(
    "kh" = "kh", "ch" = "kh", "tz" = "ts",
    "sh" = "sh", "th" = "t"
  )

  for (pattern in names(hebrew_patterns_standard)[order(nchar(names(hebrew_patterns_standard)), decreasing = TRUE)]) {
    result_standard <- gsub(pattern, hebrew_patterns_standard[[pattern]], result_standard, ignore.case = TRUE)
    result_premium <- gsub(pattern, hebrew_patterns_premium[[pattern]], result_premium, ignore.case = TRUE)
  }

  # For pattern-based names, don't generate fake CMU - it produces bad results
  # Let ElevenLabs use the phonetic respelling as plain text instead
  return(list(standard = result_standard, premium = result_premium, ipa = NULL, from_dictionary = FALSE))
}

# Korean phonetic rules
# Returns BOTH standard and premium voice optimized spellings
apply_korean_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE KOREAN NAME DICTIONARY
  # Romanized Korean names with proper phonetics
  korean_dictionary <- list(
    # Common Male Names
    "kim" = list(standard = "kim", premium = "kim", ipa = "K IY1 M"),
    "park" = list(standard = "pahrk", premium = "pahrk", ipa = "B AA1 K"),
    "ji" = list(standard = "jee", premium = "jee", ipa = "JH IY1"),
    "min" = list(standard = "min", premium = "min", ipa = "M IY1 N"),
    "jun" = list(standard = "joon", premium = "joon", ipa = "JH UW1 N"),
    "sung" = list(standard = "soong", premium = "soong", ipa = "S UW1 NG"),
    "hyun" = list(standard = "hyun", premium = "hyun", ipa = "HH Y UW1 N"),
    "joon" = list(standard = "joon", premium = "joon", ipa = "JH UW1 N"),
    "seung" = list(standard = "soong", premium = "soong", ipa = "S UW1 NG"),
    "dong" = list(standard = "dong", premium = "dong", ipa = "D AO1 NG"),
    "young" = list(standard = "yung", premium = "yung", ipa = "Y UW1 NG"),
    "jin" = list(standard = "jin", premium = "jin", ipa = "JH IY1 N"),
    "ho" = list(standard = "hoh", premium = "hoh", ipa = "HH OW1"),
    "soo" = list(standard = "soo", premium = "soo", ipa = "S UW1"),
    "tae" = list(standard = "tay", premium = "tay", ipa = "T EY1"),
    "kyung" = list(standard = "kyung", premium = "kyung", ipa = "K Y UW1 NG"),
    "woo" = list(standard = "woo", premium = "woo", ipa = "W UW1"),
    "sang" = list(standard = "sahng", premium = "sahng", ipa = "S AA1 NG"),
    "jae" = list(standard = "jay", premium = "jay", ipa = "JH EY1"),
    "myung" = list(standard = "myung", premium = "myung", ipa = "M Y UW1 NG"),
    "chul" = list(standard = "chool", premium = "chool", ipa = "CH UW1 L"),
    "hwan" = list(standard = "hwahn", premium = "hwahn", ipa = "HH W AA1 N"),
    "yong" = list(standard = "yong", premium = "yong", ipa = "Y AO1 NG"),
    "il" = list(standard = "eel", premium = "eel", ipa = "IY1 L"),
    "chang" = list(standard = "chahng", premium = "chahng", ipa = "CH AA1 NG"),

    # Common Female Names
    "hye" = list(standard = "hyeh", premium = "hyeh", ipa = "HH Y EH1"),
    "mi" = list(standard = "mee", premium = "mee", ipa = "M IY1"),
    "seo" = list(standard = "suh", premium = "suh", ipa = "S AH1"),
    "yoo" = list(standard = "yoo", premium = "yoo", ipa = "Y UW1"),
    "eun" = list(standard = "uhn", premium = "uhn", ipa = "UW1 N"),
    "sun" = list(standard = "soon", premium = "soon", ipa = "S UW1 N"),
    "jung" = list(standard = "jong", premium = "jong", ipa = "JH UW1 NG"),
    "hee" = list(standard = "hee", premium = "hee", ipa = "HH IY1"),
    "su" = list(standard = "soo", premium = "soo", ipa = "S UW1"),
    "hwa" = list(standard = "hwah", premium = "hwah", ipa = "HH W AA1"),
    "sook" = list(standard = "sook", premium = "sook", ipa = "S UW1 K"),
    "yeon" = list(standard = "yuhn", premium = "yuhn", ipa = "Y AO1 N"),
    "ae" = list(standard = "ay", premium = "ay", ipa = "EY1"),
    "na" = list(standard = "nah", premium = "nah", ipa = "N AA1"),
    "ok" = list(standard = "ok", premium = "ok", ipa = "OW1 K"),
    "ran" = list(standard = "rahn", premium = "rahn", ipa = "R AA1 N"),
    "kyoo" = list(standard = "kyoo", premium = "kyoo", ipa = "K Y UW1"),
    "ja" = list(standard = "jah", premium = "jah", ipa = "JH AA1"),
    "soon" = list(standard = "soon", premium = "soon", ipa = "S UW1 N")
  )

  # Check dictionary first
  if (!is.null(korean_dictionary[[result]])) {
    dict_entry <- korean_dictionary[[result]]
    dict_entry$from_dictionary <- TRUE
    return(dict_entry)
  }

  # Pattern-based rules for other Korean names
  result_standard <- result
  result_premium <- result

  korean_patterns_standard <- list(
    "eu" = "uh",
    "eo" = "uh",
    "ae" = "eh",
    "oe" = "weh",
    "ui" = "wee"
  )

  korean_patterns_premium <- list(
    "eu" = "uh",
    "eo" = "uh",
    "ae" = "eh",
    "oe" = "weh",
    "ui" = "wee"
  )

  for (pattern in names(korean_patterns_standard)[order(nchar(names(korean_patterns_standard)), decreasing = TRUE)]) {
    result_standard <- gsub(pattern, korean_patterns_standard[[pattern]], result_standard, ignore.case = TRUE)
    result_premium <- gsub(pattern, korean_patterns_premium[[pattern]], result_premium, ignore.case = TRUE)
  }

  # For pattern-based names, don't generate fake CMU - it produces bad results
  # Let ElevenLabs use the phonetic respelling as plain text instead
  return(list(standard = result_standard, premium = result_premium, ipa = NULL, from_dictionary = FALSE))
}

# Arabic phonetic rules
# Returns BOTH standard and premium voice optimized spellings
apply_arabic_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE ARABIC NAME DICTIONARY
  # Romanized Arabic names with proper phonetics
  arabic_dictionary <- list(
    # Common Male Names
    "muhammad" = list(standard = "moohahmmad", premium = "moo-hah-mad", ipa = "M UW1 HH AA0 M AA1 D"),
    "mohammed" = list(standard = "moohahmmad", premium = "moo-hah-mad", ipa = "M UW1 HH AA0 M AA1 D"),
    "ahmed" = list(standard = "ahhmad", premium = "ah-mad", ipa = "AA1 M EH0 D"),
    "ahmad" = list(standard = "ahhmad", premium = "ah-mad", ipa = "AA1 M EH0 D"),
    "ali" = list(standard = "ahlee", premium = "ah-lee", ipa = "AA1 L IY0"),
    "omar" = list(standard = "ohmar", premium = "oh-mar", ipa = "OW1 M AA0 R"),
    "umar" = list(standard = "oomar", premium = "oo-mar", ipa = "OW1 M AA0 R"),
    "hassan" = list(standard = "hahsahn", premium = "hah-sahn", ipa = "HH AA1 S AA0 N"),
    "hussein" = list(standard = "hoosayn", premium = "hoo-sayn", ipa = "HH UW1 S EY0 N"),
    "khalid" = list(standard = "kahleed", premium = "kah-leed", ipa = "K AA1 L IY0 D"),
    "abdullah" = list(standard = "abdoollah", premium = "ab-dool-lah", ipa = "AA0 B D UW1 L AA0"),
    "ibrahim" = list(standard = "ibrahheem", premium = "ib-rah-heem", ipa = "IY1 B R AA0 HH IY0 M"),
    "youssef" = list(standard = "yoosef", premium = "yoo-sef", ipa = "Y UW1 S EH0 F"),
    "yousef" = list(standard = "yoosef", premium = "yoo-sef", ipa = "Y UW1 S EH0 F"),
    "kareem" = list(standard = "kareem", premium = "ka-reem", ipa = "K AA1 R IY0 M"),
    "karim" = list(standard = "kareem", premium = "ka-reem", ipa = "K AA1 R IY0 M"),
    "tariq" = list(standard = "tahreek", premium = "tah-reek", ipa = "T AA1 R IY0 K"),
    "rashid" = list(standard = "rahsheed", premium = "rah-sheed", ipa = "R AA1 SH IY0 D"),
    "samir" = list(standard = "sahmeer", premium = "sah-meer", ipa = "S AA1 M IY0 R"),
    "faisal" = list(standard = "fysal", premium = "fy-sal", ipa = "F AY1 S AA0 L"),
    "hamza" = list(standard = "hamzah", premium = "ham-zah", ipa = "HH AA1 M Z AA0"),
    "walid" = list(standard = "wahleed", premium = "wah-leed", ipa = "W AA1 L IY0 D"),
    "malik" = list(standard = "mahlik", premium = "mah-lik", ipa = "M AA1 L IY0 K"),
    "mustafa" = list(standard = "moostahfah", premium = "moos-tah-fah", ipa = "M UW1 S T AA0 F AA0"),
    "nasir" = list(standard = "nahseer", premium = "nah-seer", ipa = "N AA1 S ER0"),

    # Common Female Names
    "fatima" = list(standard = "fahteemah", premium = "fah-tee-mah", ipa = "F AA1 T IY0 M AA0"),
    "aisha" = list(standard = "aheeshah", premium = "ah-ee-shah", ipa = "AY1 SH AA0"),
    "ayesha" = list(standard = "ahyeshah", premium = "ah-ye-shah", ipa = "AY1 SH AA0"),
    "zainab" = list(standard = "zaynab", premium = "zay-nab", ipa = "Z AY1 N AA0 B"),
    "maryam" = list(standard = "mahryam", premium = "mah-ryam", ipa = "M AA1 R Y AA0 M"),
    "mariam" = list(standard = "mahryam", premium = "mah-ryam", ipa = "M AA1 R Y AA0 M"),
    "layla" = list(standard = "laylah", premium = "lay-lah", ipa = "L EY1 L AA0"),
    "leila" = list(standard = "laylah", premium = "lay-lah", ipa = "L EY1 L AA0"),
    "amina" = list(standard = "ahmeenah", premium = "ah-mee-nah", ipa = "AA1 M IY0 N AA0"),
    "sara" = list(standard = "sahrah", premium = "sah-rah", ipa = "S AA1 R AA0"),
    "sarah" = list(standard = "sahrah", premium = "sah-rah", ipa = "S AA1 R AA0"),
    "nour" = list(standard = "noor", premium = "noor", ipa = "N UW1 R"),
    "nur" = list(standard = "noor", premium = "noor", ipa = "N UW1 R"),
    "hana" = list(standard = "hahnah", premium = "hah-nah", ipa = "HH AA1 N AA0"),
    "salma" = list(standard = "sahlmah", premium = "sahl-mah", ipa = "S AA1 L M AA0"),
    "yasmin" = list(standard = "yasmeen", premium = "yas-meen", ipa = "Y AA1 S M IY0 N"),
    "jasmine" = list(standard = "jasmeen", premium = "jas-meen", ipa = "Y AA1 S M IY0 N"),
    "huda" = list(standard = "hoodah", premium = "hoo-dah", ipa = "HH UW1 D AA0"),
    "dina" = list(standard = "deenah", premium = "dee-nah", ipa = "D IY1 N AA0"),
    "rania" = list(standard = "rahnyah", premium = "rah-nyah", ipa = "R AA1 N IY0 AA0"),
    "nadia" = list(standard = "nahdyah", premium = "nah-dyah", ipa = "N AA1 D IY0 AA0"),
    "noura" = list(standard = "noorah", premium = "noo-rah", ipa = "N UW1 R AA0"),
    "malak" = list(standard = "mahlahk", premium = "mah-lahk", ipa = "M AA1 L AA0 K"),
    "rana" = list(standard = "rahnah", premium = "rah-nah", ipa = "R AA1 N AA0"),
    "lina" = list(standard = "leenah", premium = "lee-nah", ipa = "L IY1 N AA0")
  )

  # Check dictionary first
  if (!is.null(arabic_dictionary[[result]])) {
    dict_entry <- arabic_dictionary[[result]]
    dict_entry$from_dictionary <- TRUE
    return(dict_entry)
  }

  # Pattern-based rules for other Arabic names
  result_standard <- result
  result_premium <- result

  arabic_patterns_standard <- list(
    "kh" = "k",
    "gh" = "g",
    "aa" = "ah",
    "ee" = "ee",
    "oo" = "oo",
    "dh" = "th"
  )

  arabic_patterns_premium <- list(
    "kh" = "k",
    "gh" = "g",
    "aa" = "ah",
    "ee" = "ee",
    "oo" = "oo",
    "dh" = "th"
  )

  for (pattern in names(arabic_patterns_standard)[order(nchar(names(arabic_patterns_standard)), decreasing = TRUE)]) {
    result_standard <- gsub(pattern, arabic_patterns_standard[[pattern]], result_standard, ignore.case = TRUE)
    result_premium <- gsub(pattern, arabic_patterns_premium[[pattern]], result_premium, ignore.case = TRUE)
  }

  # For pattern-based names, don't generate fake CMU - it produces bad results
  # Let ElevenLabs use the phonetic respelling as plain text instead
  return(list(standard = result_standard, premium = result_premium, ipa = NULL, from_dictionary = FALSE))
}

# Greek phonetic rules
# Returns BOTH standard and premium voice optimized spellings
apply_greek_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE GREEK NAME DICTIONARY
  # Each entry: standard = browser TTS optimized, premium = ElevenLabs optimized
  greek_dictionary <- list(
    # Common Male Names
    "giannis" = list(standard = "yawnis", premium = "yah-nis", ipa = "Y AA1 N IY0 S"),
    "yannis" = list(standard = "yawnis", premium = "yah-nis", ipa = "Y AA1 N IY0 S"),
    "yiannis" = list(standard = "yawnis", premium = "yah-nis", ipa = "Y AA1 N IY0 S"),
    "ioannis" = list(standard = "yoawnis", premium = "yo-ah-nis", ipa = "Y OW1 AA0 N IY0 S"),
    "giorgos" = list(standard = "yorgos", premium = "yor-gos", ipa = "Y AO1 R G OW0 S"),
    "georgios" = list(standard = "yoryos", premium = "yor-yos", ipa = "Y AO1 R Y OW0 S"),
    "george" = list(standard = "yorgay", premium = "yor-gay", ipa = "Y AO1 R G OW0 S"),
    "yorgos" = list(standard = "yorgos", premium = "yor-gos", ipa = "Y AO1 R G OW0 S"),
    "dimitris" = list(standard = "deemeetris", premium = "dee-mee-tris", ipa = "D IY1 M IY0 T R IY0 S"),
    "dimitrios" = list(standard = "deemeetrios", premium = "dee-mee-tree-os", ipa = "D IY1 M IY0 T R IY0 S"),
    "nikos" = list(standard = "neekos", premium = "nee-kos", ipa = "N IY1 K OW0 S"),
    "nikolaos" = list(standard = "neekohlahos", premium = "nee-koh-lah-os", ipa = "N IY1 K OW0 L AA0 S"),
    "kostas" = list(standard = "kohstas", premium = "koh-stas", ipa = "K AO1 S T AA0 S"),
    "konstantinos" = list(standard = "konstahndinos", premium = "kon-stan-dee-nos", ipa = "K AA1 N S T AA0 N T IY0 N OW0 S"),
    "andreas" = list(standard = "ahndreyahs", premium = "ahn-drey-ahs", ipa = "AA1 N D R EH0 AA0 S"),
    "stavros" = list(standard = "stahvros", premium = "stah-vros", ipa = "S T AA1 V R OW0 S"),
    "christos" = list(standard = "hreestos", premium = "hree-stos", ipa = "K R IY1 S T OW0 S"),
    "vasilis" = list(standard = "vahseelees", premium = "vah-see-lees", ipa = "V AA1 S IY0 L IY0 S"),
    "vasileios" = list(standard = "vahseelayos", premium = "vah-see-lay-os", ipa = "V AA1 S IY0 L IY0 S"),
    "panagiotis" = list(standard = "panahyotis", premium = "pah-nah-yo-tis", ipa = "P AA1 N AA0 Y OW0 T IY0 S"),
    "alexandros" = list(standard = "ahlexahndros", premium = "ah-lex-ahn-dros", ipa = "AA1 L EH0 K S AA0 N D R OW0 S"),
    "spiros" = list(standard = "speeros", premium = "spee-ros", ipa = "S P IY1 R OW0 S"),
    "spyros" = list(standard = "speeros", premium = "spee-ros", ipa = "S P IY1 R OW0 S"),
    "petros" = list(standard = "petros", premium = "pet-ros", ipa = "P EH1 T R OW0 S"),
    "michalis" = list(standard = "meekahlis", premium = "mee-kah-lis", ipa = "M IY1 K AA0 L IY0 S"),
    "thanasis" = list(standard = "thahnahsis", premium = "thah-nah-sis", ipa = "TH AA1 N AA0 S IY0 S"),
    "takis" = list(standard = "tahkis", premium = "tah-kis", ipa = "T AA1 K IY0 S"),

    # Common Female Names
    "maria" = list(standard = "mahreeah", premium = "mah-ree-ah", ipa = "M AA1 R IY0 AA0"),
    "eleni" = list(standard = "elehnee", premium = "eh-leh-nee", ipa = "EH1 L EH0 N IY0"),
    "katerina" = list(standard = "kahtereena", premium = "kah-teh-ree-nah", ipa = "K AA1 T EH0 R IY0 N AA0"),
    "aikaterini" = list(standard = "ehkahtereeni", premium = "eh-kah-teh-ree-nee", ipa = "K AA1 T EH0 R IY0 N AA0"),
    "sofia" = list(standard = "sofeea", premium = "so-fee-ah", ipa = "S OW1 F IY0 AA0"),
    "sophia" = list(standard = "sofeea", premium = "so-fee-ah", ipa = "S OW1 F IY0 AA0"),
    "georgia" = list(standard = "yoryah", premium = "yor-yah", ipa = "Y AO1 R Y AA0"),
    "christina" = list(standard = "hreesteena", premium = "hree-stee-nah", ipa = "K R IY1 S T IY0 N AA0"),
    "despina" = list(standard = "despeena", premium = "des-pee-nah", ipa = "D EH1 S P IY0 N AA0"),
    "ioanna" = list(standard = "yoahna", premium = "yo-ah-nah", ipa = "Y OW1 AA0 N AA0"),
    "athena" = list(standard = "ahthehnah", premium = "ah-theh-nah", ipa = "AA1 TH EH0 N AA0"),
    "athina" = list(standard = "ahtheenah", premium = "ah-thee-nah", ipa = "AA1 TH EH0 N AA0"),
    "anastasia" = list(standard = "ahnahstahseeah", premium = "ah-nah-stah-see-ah", ipa = "AA1 N AA0 S T AA0 S IY0 AA0"),
    "alexandra" = list(standard = "ahlexahndrah", premium = "ah-lex-ahn-drah", ipa = "AA1 L EH0 K S AA0 N D R AA0"),
    "anna" = list(standard = "ahnah", premium = "ah-nah", ipa = "AA1 N AA0"),
    "dimitra" = list(standard = "deemeetrah", premium = "dee-mee-trah", ipa = "D IY1 M IY0 T R AA0"),
    "evangelia" = list(standard = "evahngelya", premium = "eh-vahn-gel-yah", ipa = "EH1 V AA0 N JH EH0 L IY0 AA0"),
    "vasiliki" = list(standard = "vahseeleekee", premium = "vah-see-lee-kee", ipa = "V AA1 S IY0 L IY0 K IY0"),
    "angeliki" = list(standard = "ahnjeliki", premium = "ahn-jel-ik-i", ipa = "AA1 N JH EH0 L IY0 K IY0"),
    "konstantina" = list(standard = "konstahndina", premium = "kon-stan-dee-nah", ipa = "K AA1 N S T AA0 N T IY0 N AA0"),
    "panagiota" = list(standard = "panahyota", premium = "pah-nah-yo-tah", ipa = "P AA1 N AA0 Y OW0 T AA0"),
    "penelope" = list(standard = "penelopee", premium = "pe-nel-o-pee", ipa = "P EH1 N EH0 L OW0 P IY0"),
    "zoe" = list(standard = "zoh-ee", premium = "zoh-ee", ipa = "Z OW1 IY0"),
    "calliope" = list(standard = "kahleeopee", premium = "kah-lee-o-pee", ipa = "K AA1 L IY0 OW0 P IY0"),
    "paraskevi" = list(standard = "parahskevee", premium = "pah-rah-skeh-vee", ipa = "P AA1 R AA0 S K EH0 V IY0")
  )

  # Check dictionary first
  if (!is.null(greek_dictionary[[result]])) {
    dict_entry <- greek_dictionary[[result]]
    dict_entry$from_dictionary <- TRUE
    return(dict_entry)
  }

  # Pattern-based rules for other Greek names
  result_standard <- result
  result_premium <- result

  greek_patterns_standard <- list(
    "giannis" = "yawnis",
    "gia" = "yah",
    "gio" = "yo",
    "gi" = "yee",
    "ge" = "yeh",
    "ch" = "h",
    "th" = "th",
    "ph" = "f",
    "eu" = "ef",
    "ou" = "oo",
    "ei" = "ee",
    "ai" = "eh"
  )

  greek_patterns_premium <- list(
    "giannis" = "yah-nis",
    "gia" = "yah",
    "gio" = "yo",
    "gi" = "yee",
    "ge" = "yeh",
    "ch" = "h",
    "th" = "th",
    "ph" = "f",
    "eu" = "ef",
    "ou" = "oo",
    "ei" = "ee",
    "ai" = "eh"
  )

  for (pattern in names(greek_patterns_standard)[order(nchar(names(greek_patterns_standard)), decreasing = TRUE)]) {
    result_standard <- gsub(pattern, greek_patterns_standard[[pattern]], result_standard, ignore.case = TRUE)
    result_premium <- gsub(pattern, greek_patterns_premium[[pattern]], result_premium, ignore.case = TRUE)
  }

  # For pattern-based names, don't generate fake CMU - it produces bad results
  # Let ElevenLabs use the phonetic respelling as plain text instead
  return(list(standard = result_standard, premium = result_premium, ipa = NULL, from_dictionary = FALSE))
}

# Function to provide phonetic pronunciation guides
get_pronunciation_guide <- function(name, origin = NULL) {
  # Convert to lowercase for processing
  name_lower <- tolower(trimws(name))

  # Track which method was used for transparency
  method_used <- "generic"
  dictionary_name <- NULL

  # PRIORITY 1: Check language-specific dictionaries first (if origin specified)
  origin_applied <- FALSE
  phonetic_result <- NULL

  if (!is.null(origin) && origin != "" && origin != "unknown") {
    phonetic_result <- switch(origin,
      "irish" = { origin_applied <- TRUE; apply_irish_phonetics(name_lower) },
      "nigerian" = { origin_applied <- TRUE; apply_nigerian_phonetics(name_lower) },
      "congolese" = { origin_applied <- TRUE; apply_congolese_phonetics(name_lower) },
      "indian" = { origin_applied <- TRUE; apply_indian_phonetics(name_lower) },
      "spanish" = { origin_applied <- TRUE; apply_spanish_phonetics(name_lower) },
      "greek" = { origin_applied <- TRUE; apply_greek_phonetics(name_lower) },
      "chinese" = { origin_applied <- TRUE; apply_chinese_phonetics(name_lower) },
      "vietnamese" = { origin_applied <- TRUE; apply_vietnamese_phonetics(name_lower) },
      "korean" = { origin_applied <- TRUE; apply_korean_phonetics(name_lower) },
      "arabic" = { origin_applied <- TRUE; apply_arabic_phonetics(name_lower) },
      "italian" = { origin_applied <- TRUE; apply_italian_phonetics(name_lower) },
      "french" = { origin_applied <- TRUE; apply_french_phonetics(name_lower) },
      "polish" = { origin_applied <- TRUE; apply_polish_phonetics(name_lower) },
      "german" = { origin_applied <- TRUE; apply_german_phonetics(name_lower) },
      "portuguese" = { origin_applied <- TRUE; apply_portuguese_phonetics(name_lower) },
      "japanese" = { origin_applied <- TRUE; apply_japanese_phonetics(name_lower) },
      "russian" = { origin_applied <- TRUE; apply_russian_phonetics(name_lower) },
      "hebrew" = { origin_applied <- TRUE; apply_hebrew_phonetics(name_lower) },
      "english" = { origin_applied <- "cmu"; name_lower },  # Flag for CMU lookup below
      # If custom origin entered, use generic rules
      name_lower
    )
  }

  # If origin rules were applied and returned dual phonetics
  if (origin_applied == TRUE && is.list(phonetic_result) && !is.null(phonetic_result$standard)) {
    # Dual phonetics returned from language function
    simple_standard <- toupper(phonetic_result$standard)
    simple_premium <- toupper(phonetic_result$premium)

    # Check if this came from dictionary or pattern-based
    if (!is.null(phonetic_result$from_dictionary) && phonetic_result$from_dictionary) {
      method_used <- "dictionary"
      dictionary_name <- paste0(toupper(substring(origin, 1, 1)), substring(origin, 2))
    } else {
      method_used <- "pattern"
      dictionary_name <- paste0(toupper(substring(origin, 1, 1)), substring(origin, 2))
    }

    # Dictionary provided CMU in ipa field
    if (!is.null(phonetic_result$ipa) && phonetic_result$ipa != "") {
      ipa_phonetic <- phonetic_result$ipa  # This is CMU Arpabet from dictionary
      ipa_notation <- arpabet_to_ipa(phonetic_result$ipa)  # Convert Arpabet to proper IPA
    } else {
      # Pattern-based - no reliable CMU available
      ipa_phonetic <- "CMU not available (pattern-based approximation - use phonetic respelling instead)"
      ipa_notation <- create_ipa_phonetic(name_lower)  # Fallback to transliteration
    }
  } else if (origin_applied == TRUE && is.character(phonetic_result)) {
    # Old-style single phonetic (other languages not yet updated)
    simple_standard <- toupper(phonetic_result)
    simple_premium <- toupper(phonetic_result)
    method_used <- "pattern"
    dictionary_name <- paste0(toupper(substring(origin, 1, 1)), substring(origin, 2))
    ipa_phonetic <- "CMU not available (pattern-based approximation - use phonetic respelling instead)"
    ipa_notation <- create_ipa_phonetic(name_lower)
  } else {
    # PRIORITY 2: Check CMU Pronouncing Dictionary for English names
    # (also triggered when origin="english" via origin_applied="cmu" flag)
    cmu_result <- cmu_lookup(name_lower)

    if (!is.null(cmu_result)) {
      # Found in CMU dictionary - use real CMU and respelling
      simple_standard <- toupper(cmu_result$respelling)
      simple_premium <- toupper(cmu_result$respelling)
      ipa_phonetic <- cmu_result$arpabet  # CMU Arpabet (the raw phonemes like "JH AA1 N")
      ipa_notation <- cmu_result$ipa  # IPA notation (already converted)
      method_used <- "dictionary"
      dictionary_name <- "CMU (English)"
    } else {
      # PRIORITY 3: Fallback to generic phonetic conversion
      generic <- create_simple_phonetic(name_lower)
      simple_standard <- generic
      simple_premium <- generic
      ipa_phonetic <- "CMU not available (generic approximation - use phonetic respelling instead)"
      ipa_notation <- create_ipa_phonetic(name_lower)  # Traditional IPA
      method_used <- "generic"
    }
  }

  return(list(
    simple_standard = simple_standard,
    simple_premium = simple_premium,
    ipa = ipa_phonetic,
    ipa_notation = ipa_notation,
    syllables = add_syllable_breaks(name_lower),
    method_used = method_used,
    dictionary_name = dictionary_name
  ))
}

# Function for simple phonetic guide (easy to read)
create_simple_phonetic <- function(name) {
  # Simple phonetic mappings
  phonetic_map <- list(
    # Vowels
    "a" = "AH", "e" = "EH", "i" = "EE", "o" = "OH", "u" = "OO",
    "ai" = "AY", "au" = "OW", "ea" = "EE", "ee" = "EE", "ie" = "EE",
    "oo" = "OO", "ou" = "OW", "ue" = "OO", "ui" = "OO",
    # Consonants and combinations
    "ch" = "CH", "sh" = "SH", "th" = "TH", "ph" = "F", "gh" = "G",
    "ng" = "NG", "nk" = "NK", "qu" = "KW", "x" = "KS", "z" = "Z",
    "j" = "J", "c" = "K", "g" = "G", "y" = "Y"
  )
  
  result <- name
  # Apply mappings (longer patterns first)
  for (pattern in names(phonetic_map)[order(nchar(names(phonetic_map)), decreasing = TRUE)]) {
    result <- gsub(pattern, phonetic_map[[pattern]], result, ignore.case = TRUE)
  }
  
  return(toupper(result))
}

# Function for IPA-style phonetic guide
create_ipa_phonetic <- function(name) {
  # IPA-style mappings
  ipa_map <- list(
    # Vowels
    "a" = "ä", "e" = "ɛ", "i" = "i", "o" = "oʊ", "u" = "u",
    "ai" = "aɪ", "au" = "aʊ", "ea" = "i", "ee" = "i", "ie" = "i",
    "oo" = "u", "ou" = "aʊ", "ue" = "u", "ui" = "u",
    # Consonants
    "ch" = "tʃ", "sh" = "ʃ", "th" = "θ", "ph" = "f", "gh" = "g",
    "ng" = "ŋ", "j" = "dʒ", "y" = "j", "z" = "z"
  )
  
  result <- name
  # Apply IPA mappings
  for (pattern in names(ipa_map)[order(nchar(names(ipa_map)), decreasing = TRUE)]) {
    result <- gsub(pattern, ipa_map[[pattern]], result, ignore.case = TRUE)
  }
  
  return(paste0("/", result, "/"))
}

# Function to convert phonetic respelling to CMU Arpabet
create_cmu_phonetic <- function(phonetic_text) {
  # Convert phonetic respelling (like "jahsreen") to CMU Arpabet
  # CMU format uses uppercase letters + stress numbers (0=unstressed, 1=primary, 2=secondary)

  result <- tolower(phonetic_text)
  output <- c()
  i <- 1

  # CMU phoneme mappings (from phonetic respelling patterns)
  while (i <= nchar(result)) {
    matched <- FALSE

    # Try 3-character patterns first
    if (i <= nchar(result) - 2) {
      three_char <- substr(result, i, i + 2)
      phoneme <- switch(three_char,
        "eer" = "IH1 R",
        "air" = "EH1 R",
        "ahr" = "AA1 R",
        "ohr" = "OR1",
        "oor" = "UW1 R",
        "igh" = "AY1",
        "aye" = "AY1",
        "eye" = "AY1",
        NULL
      )
      if (!is.null(phoneme)) {
        output <- c(output, phoneme)
        i <- i + 3
        matched <- TRUE
      }
    }

    # Try 2-character patterns
    if (!matched && i <= nchar(result) - 1) {
      two_char <- substr(result, i, i + 1)
      phoneme <- switch(two_char,
        "ee" = "IY1",
        "ea" = "IY1",
        "ay" = "EY1",
        "ai" = "EY1",
        "ey" = "EY1",
        "oh" = "OW1",
        "oo" = "UW1",
        "ow" = "AW1",
        "ou" = "AW1",
        "oy" = "OY1",
        "oi" = "OY1",
        "ah" = "AA1",
        "uh" = "AH1",
        "eh" = "EH1",
        "ih" = "IH1",
        "ch" = "CH",
        "sh" = "SH",
        "th" = "TH",
        "zh" = "ZH",
        "ng" = "NG",
        "nk" = "NG K",
        "ph" = "F",
        "gh" = "G",
        "qu" = "K W",
        NULL
      )
      if (!is.null(phoneme)) {
        output <- c(output, phoneme)
        i <- i + 2
        matched <- TRUE
      }
    }

    # Single character
    if (!matched) {
      char <- substr(result, i, i)
      phoneme <- switch(char,
        "a" = "AE1",
        "e" = "EH1",
        "i" = "IH1",
        "o" = "AA1",
        "u" = "AH1",
        "b" = "B",
        "c" = "K",
        "d" = "D",
        "f" = "F",
        "g" = "G",
        "h" = "HH",
        "j" = "JH",
        "k" = "K",
        "l" = "L",
        "m" = "M",
        "n" = "N",
        "p" = "P",
        "r" = "R",
        "s" = "S",
        "t" = "T",
        "v" = "V",
        "w" = "W",
        "x" = "K S",
        "y" = "Y",
        "z" = "Z",
        " " = NULL,  # Skip spaces
        "-" = NULL,  # Skip hyphens
        NULL
      )
      if (!is.null(phoneme)) {
        output <- c(output, phoneme)
      }
      i <- i + 1
    }
  }

  # Join phonemes with spaces
  return(paste(output, collapse = " "))
}

# Function to add syllable breaks
add_syllable_breaks <- function(name) {
  # Simple syllable detection
  syllables <- gsub("([aeiou])([bcdfghjklmnpqrstvwxyz])([aeiou])", "\\1-\\2\\3", name)
  syllables <- gsub("([bcdfghjklmnpqrstvwxyz])([aeiou])", "\\1\\2", syllables)
  return(toupper(syllables))
}

# Function to detect name origin with confidence scoring
# Returns list(origin = "indian", confidence = "high", display = "Indian (Hindi/Tamil/Punjabi)")
detect_name_origin <- function(name) {
  name_lower <- tolower(trimws(name))

  # PRIORITY 1: Check all dictionaries for exact match (100% confidence)
  # Check each dictionary by calling the phonetic function and seeing if it returns from_dictionary = TRUE

  # Try Irish
  irish_result <- apply_irish_phonetics(name_lower)
  if (!is.null(irish_result$from_dictionary) && irish_result$from_dictionary) {
    return(list(origin = "irish", confidence = "high", display = "Irish (Gaelic)"))
  }

  # Try Spanish
  spanish_result <- apply_spanish_phonetics(name_lower)
  if (!is.null(spanish_result$from_dictionary) && spanish_result$from_dictionary) {
    return(list(origin = "spanish", confidence = "high", display = "Spanish/Latin"))
  }

  # Try Nigerian
  nigerian_result <- apply_nigerian_phonetics(name_lower)
  if (!is.null(nigerian_result$from_dictionary) && nigerian_result$from_dictionary) {
    return(list(origin = "nigerian", confidence = "high", display = "Nigerian (Igbo/Yoruba/Hausa)"))
  }

  # Try Congolese
  congolese_result <- apply_congolese_phonetics(name_lower)
  if (!is.null(congolese_result$from_dictionary) && congolese_result$from_dictionary) {
    return(list(origin = "congolese", confidence = "high", display = "Congolese (DRC)"))
  }

  # Try Indian
  indian_result <- apply_indian_phonetics(name_lower)
  if (!is.null(indian_result$from_dictionary) && indian_result$from_dictionary) {
    return(list(origin = "indian", confidence = "high", display = "Indian (Hindi/Tamil/Punjabi)"))
  }

  # Try Greek
  greek_result <- apply_greek_phonetics(name_lower)
  if (!is.null(greek_result$from_dictionary) && greek_result$from_dictionary) {
    return(list(origin = "greek", confidence = "high", display = "Greek"))
  }

  # Try Chinese
  chinese_result <- apply_chinese_phonetics(name_lower)
  if (!is.null(chinese_result$from_dictionary) && chinese_result$from_dictionary) {
    return(list(origin = "chinese", confidence = "high", display = "Chinese (Mandarin)"))
  }

  # Try Vietnamese
  vietnamese_result <- apply_vietnamese_phonetics(name_lower)
  if (!is.null(vietnamese_result$from_dictionary) && vietnamese_result$from_dictionary) {
    return(list(origin = "vietnamese", confidence = "high", display = "Vietnamese"))
  }

  # Try Korean
  korean_result <- apply_korean_phonetics(name_lower)
  if (!is.null(korean_result$from_dictionary) && korean_result$from_dictionary) {
    return(list(origin = "korean", confidence = "high", display = "Korean"))
  }

  # Try Arabic
  arabic_result <- apply_arabic_phonetics(name_lower)
  if (!is.null(arabic_result$from_dictionary) && arabic_result$from_dictionary) {
    return(list(origin = "arabic", confidence = "high", display = "Arabic"))
  }

  # Try Italian
  italian_result <- apply_italian_phonetics(name_lower)
  if (!is.null(italian_result$from_dictionary) && italian_result$from_dictionary) {
    return(list(origin = "italian", confidence = "high", display = "Italian"))
  }

  # Try French
  french_result <- apply_french_phonetics(name_lower)
  if (!is.null(french_result$from_dictionary) && french_result$from_dictionary) {
    return(list(origin = "french", confidence = "high", display = "French"))
  }

  # Try Polish
  polish_result <- apply_polish_phonetics(name_lower)
  if (!is.null(polish_result$from_dictionary) && polish_result$from_dictionary) {
    return(list(origin = "polish", confidence = "high", display = "Polish"))
  }

  # Try German
  german_result <- apply_german_phonetics(name_lower)
  if (!is.null(german_result$from_dictionary) && german_result$from_dictionary) {
    return(list(origin = "german", confidence = "high", display = "German"))
  }

  # Try Portuguese
  portuguese_result <- apply_portuguese_phonetics(name_lower)
  if (!is.null(portuguese_result$from_dictionary) && portuguese_result$from_dictionary) {
    return(list(origin = "portuguese", confidence = "high", display = "Portuguese (Brazilian)"))
  }

  # Try Japanese
  japanese_result <- apply_japanese_phonetics(name_lower)
  if (!is.null(japanese_result$from_dictionary) && japanese_result$from_dictionary) {
    return(list(origin = "japanese", confidence = "high", display = "Japanese"))
  }

  # Try Russian
  russian_result <- apply_russian_phonetics(name_lower)
  if (!is.null(russian_result$from_dictionary) && russian_result$from_dictionary) {
    return(list(origin = "russian", confidence = "high", display = "Russian"))
  }

  # Try Hebrew
  hebrew_result <- apply_hebrew_phonetics(name_lower)
  if (!is.null(hebrew_result$from_dictionary) && hebrew_result$from_dictionary) {
    return(list(origin = "hebrew", confidence = "high", display = "Hebrew"))
  }

  # Check CMU Pronouncing Dictionary for English names
  cmu_result <- cmu_lookup(name_lower)
  if (!is.null(cmu_result)) {
    return(list(origin = "english", confidence = "high", display = "English"))
  }

  # PRIORITY 2: Pattern-based detection (medium-high confidence)

  # Indian patterns (very distinctive)
  if (grepl("preet$|deep$|jot$|inder$|singh$|kaur$|een$|leen$", name_lower)) {
    return(list(origin = "indian", confidence = "high", display = "Indian (Punjabi)"))
  }
  if (grepl("^sri|kumar$|krishna|lakshmi|patel$|gupta$|sharma$|^jai|^raj", name_lower)) {
    return(list(origin = "indian", confidence = "high", display = "Indian (Hindi/Tamil)"))
  }

  # Vietnamese patterns (very distinctive)
  if (grepl("^nguyen$|^linh$|^minh$|^anh$|^phuong$|^mai$|^thu$", name_lower)) {
    return(list(origin = "vietnamese", confidence = "high", display = "Vietnamese"))
  }

  # Irish patterns (very distinctive)
  if (grepl("siobh|saoirse|niamh|aoife|cillian|eoin|caoimhe|oisin", name_lower)) {
    return(list(origin = "irish", confidence = "high", display = "Irish (Gaelic)"))
  }
  if (grepl("^mc|^mac|^o'", name_lower)) {
    return(list(origin = "irish", confidence = "medium", display = "Irish"))
  }

  # Nigerian patterns
  if (grepl("chi|olu|ade|nkem|eze|ifeoma|ngozi|chiamaka", name_lower)) {
    return(list(origin = "nigerian", confidence = "medium", display = "Nigerian (Igbo/Yoruba)"))
  }

  # Arabic patterns
  if (grepl("^muhammad|^mohammed|^ahmad|^fatima|^aisha|^omar|^hassan|abdul", name_lower)) {
    return(list(origin = "arabic", confidence = "high", display = "Arabic"))
  }

  # Chinese patterns
  if (grepl("^wei$|^ming$|^li$|^yang$|^chen$|^wang$|^zhang$|^liu$", name_lower)) {
    return(list(origin = "chinese", confidence = "medium", display = "Chinese (Mandarin)"))
  }

  # Japanese patterns
  if (grepl("oshi$|ashi$|ito$|uki$|aki$|iko$|aya$|emi$|hiro|yuki|hana", name_lower)) {
    return(list(origin = "japanese", confidence = "medium", display = "Japanese"))
  }

  # Korean patterns
  if (grepl("^kim$|^park$|^ji$|^min$|^jun$|hyun|seung|young", name_lower)) {
    return(list(origin = "korean", confidence = "medium", display = "Korean"))
  }

  # Spanish patterns
  if (grepl("ez$|ño|ña$|ito$|ita$", name_lower)) {
    return(list(origin = "spanish", confidence = "medium", display = "Spanish/Latin"))
  }

  # Italian patterns
  if (grepl("llo$|lla$|cci|ggio|^giuseppe|^giovanni|^maria", name_lower)) {
    return(list(origin = "italian", confidence = "medium", display = "Italian"))
  }

  # French patterns
  if (grepl("ois$|oise$|ique$|ette$|^jean|^pierre|^marie", name_lower)) {
    return(list(origin = "french", confidence = "medium", display = "French"))
  }

  # German patterns
  if (grepl("sch|berg$|stein$|mann$|haus|^wolfgang|^hans", name_lower)) {
    return(list(origin = "german", confidence = "medium", display = "German"))
  }

  # Polish patterns
  if (grepl("ski$|ska$|cz|sz|rz|ł|ą|ę", name_lower)) {
    return(list(origin = "polish", confidence = "medium", display = "Polish"))
  }

  # Russian patterns
  if (grepl("ov$|ova$|sky$|sky$|evich$|ovich$", name_lower)) {
    return(list(origin = "russian", confidence = "medium", display = "Russian"))
  }

  # Portuguese patterns
  if (grepl("ão$|ões$|inho$|ilha$|^joão|^josé|^maria", name_lower)) {
    return(list(origin = "portuguese", confidence = "medium", display = "Portuguese"))
  }

  # Greek patterns
  if (grepl("oulos$|akis$|^giannis|^yannis|poul", name_lower)) {
    return(list(origin = "greek", confidence = "medium", display = "Greek"))
  }

  # Hebrew patterns
  if (grepl("^david|^sarah|^rachel|^jonathan|^benjamin|stein$|berg$", name_lower)) {
    return(list(origin = "hebrew", confidence = "low", display = "Hebrew"))
  }

  # No strong match found
  return(list(origin = "unknown", confidence = "none", display = "Unknown"))
}

# Define UI
ui <- dashboardPage(
  dashboardHeader(title = "Student Name Pronunciation Helper"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Name Lookup", tabName = "lookup", icon = icon("search")),
      menuItem("Saved Names", tabName = "saved", icon = icon("bookmark")),
      menuItem("Bulk Upload", tabName = "bulk_upload", icon = icon("upload")),
      menuItem("Settings", tabName = "settings", icon = icon("cog")),
      menuItem("Help", tabName = "help", icon = icon("question-circle"))
    )
  ),
  
  dashboardBody(
    # JavaScript for Web Speech API and audio playback
    tags$head(
      tags$script(HTML("
        // Global variable for speech speed
        var globalSpeechSpeed = 0.85;

        // Function to speak name using Web Speech API
        function speakName(text, speed) {
          if (typeof speed === 'undefined') speed = globalSpeechSpeed;

          // Check browser support
          if (!('speechSynthesis' in window)) {
            alert('Sorry, your browser does not support text-to-speech. Please try the Premium Voice option.');
            return false;
          }

          // Cancel any ongoing speech
          window.speechSynthesis.cancel();

          // Create utterance
          const utterance = new SpeechSynthesisUtterance(text);
          utterance.rate = speed;      // Speed (0.1 to 10)
          utterance.pitch = 1.0;       // Pitch (0 to 2)
          utterance.volume = 1.0;      // Volume (0 to 1)

          // Select preferred voice
          const voices = window.speechSynthesis.getVoices();
          const preferredVoice = voices.find(v =>
            v.name.includes('Samantha') ||   // macOS
            v.name.includes('Google') ||      // Chrome
            v.name.includes('Natural') ||     // Various
            v.name.includes('Premium')        // Various
          );
          if (preferredVoice) utterance.voice = preferredVoice;

          // Error handling
          utterance.onerror = function(event) {
            console.error('Speech synthesis error:', event);
            alert('Error playing pronunciation. Please try the Premium Voice option.');
          };

          // Speak
          window.speechSynthesis.speak(utterance);
          return true;
        }

        // Load voices (needed for some browsers)
        if ('speechSynthesis' in window) {
          window.speechSynthesis.onvoiceschanged = function() {
            window.speechSynthesis.getVoices();
          };
        }

        // Check browser support on page load
        $(document).ready(function() {
          if (!('speechSynthesis' in window)) {
            $('#speak_name').prop('disabled', true);
            $('#speak_name').after(
              '<p class=\"text-warning\" style=\"margin-top: 10px;\">⚠️ Your browser doesn\\'t support speech synthesis. Use Premium Voice instead.</p>'
            );
          }
        });

        // Note: #speak_name button is now handled by R observer
        // which sends the phonetic guide via sendCustomMessage

        // Handle play audio button clicks in saved names table
        // This will check for cached ElevenLabs audio first, then fall back to browser TTS
        $(document).on('click', '.play-saved-audio', function() {
          const rowIndex = $(this).data('row');
          const hasCache = $(this).data('has-cache');
          const phonetic = $(this).data('phonetic');

          // jQuery .data() auto-converts true string to boolean true, so check for both
          if (hasCache === true || hasCache === 'true') {
            // Tell R to play the cached audio
            Shiny.setInputValue('play_saved_audio_row', rowIndex, {priority: 'event'});
          } else {
            // No cached audio - use browser TTS directly
            if (phonetic) {
              speakName(phonetic, globalSpeechSpeed);
            }
          }
        });

        // Handle delete button clicks in saved names table
        $(document).on('click', '.delete-saved-name', function() {
          const rowIndex = $(this).data('row');
          if (confirm('Are you sure you want to delete this name?')) {
            Shiny.setInputValue('delete_saved_row', rowIndex, {priority: 'event'});
          }
        });

        // Toggle Keep Permanent flag for saved names
        $(document).on('click', '.toggle-permanent', function(e) {
          e.preventDefault();
          const rowIndex = $(this).data('row');
          Shiny.setInputValue('toggle_permanent_row', rowIndex, {priority: 'event'});
        });

        // Custom message handler for updating speech speed
        Shiny.addCustomMessageHandler('updateSpeechSpeed', function(speed) {
          globalSpeechSpeed = speed;
        });

        // Custom message handler for triggering speech from R
        Shiny.addCustomMessageHandler('speakName', function(message) {
          speakName(message.name, message.speed || globalSpeechSpeed);
        });

        // Custom message handler for playing audio from base64 data
        Shiny.addCustomMessageHandler('playAudioBase64', function(message) {
          const audio = new Audio('data:audio/mp3;base64,' + message.data);
          audio.play().catch(function(error) {
            console.error('Audio playback error:', error);
            alert('Error playing audio file. Please check your browser settings.');
          });
        });

        // Custom message handler for fallback to Standard Voice when cached audio unavailable
        Shiny.addCustomMessageHandler('playSavedNameFallback', function(message) {
          speakName(message.phonetic, globalSpeechSpeed);
        });
      "))
    ),

    tabItems(
      # Name lookup tab
      tabItem(tabName = "lookup",
              fluidRow(
                box(
                  title = "Enter Student Name", status = "primary", solidHeader = TRUE,
                  width = 12,
                  textInput("student_name", "Student Name:", placeholder = "Enter the name as spelled"),
                  selectizeInput("name_origin", "Name Origin (optional):",
                                choices = c(
                                  "Irish (Gaelic)" = "irish",
                                  "Nigerian (Igbo/Yoruba/Hausa)" = "nigerian",
                                  "Congolese (DRC)" = "congolese",
                                  "Indian (Hindi/Tamil/Punjabi)" = "indian",
                                  "Spanish" = "spanish",
                                  "Greek" = "greek",
                                  "Chinese (Mandarin)" = "chinese",
                                  "Italian" = "italian",
                                  "French" = "french",
                                  "German" = "german",
                                  "Polish" = "polish",
                                  "Vietnamese" = "vietnamese",
                                  "Arabic" = "arabic",
                                  "Japanese" = "japanese",
                                  "Korean" = "korean",
                                  "Portuguese" = "portuguese",
                                  "Russian" = "russian",
                                  "Hebrew" = "hebrew",
                                  "English" = "english",
                                  "Other/Unknown" = "unknown"
                                ),
                                selected = character(0),
                                options = list(
                                  create = TRUE,
                                  placeholder = "Auto-detect, or select/type origin..."
                                )),
                  uiOutput("origin_suggestion"),
                  actionButton("get_pronunciation", "Get Pronunciation", class = "btn-primary"),
                  br(), br(),
                  conditionalPanel(
                    condition = "input.get_pronunciation > 0",
                    h4("Pronunciation Guide:"),
                    uiOutput("pronunciation_output"),
                    h4("Possible Origin:"),
                    verbatimTextOutput("origin_output"),
                    h4("Pronunciation Tips:"),
                    verbatimTextOutput("tips_output"),
                    br(),

                    # Manual phonetic override
                    box(
                      title = "Custom Pronunciation (Optional)",
                      status = "warning",
                      solidHeader = TRUE,
                      width = 12,
                      collapsible = TRUE,
                      collapsed = TRUE,

                      helpText("Not happy with the automatic pronunciation? Type your own phonetic spelling below. This will be used for both voice types."),
                      textInput("phonetic_override", "Custom Pronunciation:",
                               placeholder = "e.g., 'seer-sha' or 'SH IH1 R SH AH0'"),
                      helpText("Use simple respellings like 'kill-ian' OR paste CMU Arpabet (e.g., 'K IH1 L IY0 AH0 N') from the pronunciation results below. ElevenLabs understands both formats. Leave blank to use automatic phonetics.")
                    ),
                    br(),

                    # Audio pronunciation controls
                    box(
                      title = "Audio Pronunciation",
                      status = "info",
                      solidHeader = TRUE,
                      width = 12,
                      collapsible = TRUE,

                      fluidRow(
                        column(6,
                          h5("Standard Voice (Free):"),
                          actionButton("speak_name", "Speak Name",
                                     class = "btn-info",
                                     icon = icon("volume-up")),
                          br(), br(),
                          sliderInput("speech_speed", "Pronunciation Speed:",
                                    min = 0.5, max = 1.5, value = 0.85, step = 0.05,
                                    width = "100%"),
                          helpText("Uses your browser's built-in voice. Instant and free.")
                        ),
                        column(6,
                          h5("ElevenLabs Premium (IPA):"),
                          actionButton("speak_premium", "Use ElevenLabs Premium",
                                     class = "btn-warning",
                                     icon = icon("microphone")),
                          br(), br(),
                          sliderInput("premium_speed", "Speed:",
                                    min = 0.5, max = 1.5, value = 1.0, step = 0.05,
                                    width = "100%"),
                          helpText("Uses ElevenLabs with IPA for accurate pronunciation. Configure API in Settings tab.")
                        )
                      )
                    ),
                    br(),

                    actionButton("save_name", "Save This Name", class = "btn-success"),
                    textInput("pronunciation_notes", "Add your own pronunciation notes:", 
                              placeholder = "e.g., 'Student confirmed it's pronounced...'")
                  )
                )
              )
      ),
      
      # Saved names tab
      tabItem(tabName = "saved",
              fluidRow(
                box(
                  title = "Saved Student Names", status = "success", solidHeader = TRUE,
                  width = 12,
                  DT::dataTableOutput("saved_names_table"),
                  br(),
                  downloadButton("download_saved_pdf", "Download as PDF", class = "btn-primary"),
                  downloadButton("download_saved_csv", "Download as CSV", class = "btn-info"),
                  actionButton("clear_saved", "Clear All Saved Names", class = "btn-warning")
                )
              )
      ),

      # Bulk Upload tab
      tabItem(tabName = "bulk_upload",
              fluidRow(
                # File Upload Box
                box(
                  title = "Upload Name List",
                  status = "info",
                  solidHeader = TRUE,
                  width = 6,

                  # File input widget
                  fileInput("bulk_file",
                            "Choose File (CSV, Excel, or TXT)",
                            accept = c(".csv", ".xlsx", ".xls", ".txt")),

                  # Instructions
                  helpText(
                    "CSV/Excel: First column = Names, Second column = Origin (optional)",
                    br(),
                    "TXT: One name per line",
                    br(),
                    "Example CSV: Name,Origin",
                    br(),
                    "Siobhan,Irish",
                    br(),
                    "José,Spanish"
                  ),

                  # Template download link
                  downloadLink("download_template", "Download Example CSV Template",
                               class = "btn btn-link btn-sm"),
                  br(), br(),

                  # Processing button
                  actionButton("process_bulk", "Process Names",
                               class = "btn-primary",
                               icon = icon("gears")),

                  # Status text
                  br(), br(),
                  uiOutput("bulk_status")
                ),

                # Results Preview Box
                box(
                  title = "Processed Names Preview",
                  status = "success",
                  solidHeader = TRUE,
                  width = 6,

                  # Preview table
                  DT::dataTableOutput("bulk_preview_table"),

                  br(),

                  # Action buttons (only show when data exists)
                  conditionalPanel(
                    condition = "output.bulk_has_results",
                    downloadButton("download_pdf", "Download PDF Guide",
                                   class = "btn-success"),
                    downloadButton("download_csv", "Download as CSV",
                                   class = "btn-success"),
                    br(), br(),
                    actionButton("save_bulk_to_saved", "Add All to Saved Names",
                                 class = "btn-info",
                                 icon = icon("bookmark")),
                    actionButton("clear_bulk_results", "Clear Results",
                                 class = "btn-warning",
                                 icon = icon("trash"))
                  )
                )
              )
      ),

      # Settings tab
      tabItem(tabName = "settings",
              fluidRow(
                box(
                  title = "ElevenLabs API Configuration", status = "warning", solidHeader = TRUE,
                  width = 12,

                  # Warning banner for shinyapps.io deployment
                  conditionalPanel(
                    condition = "typeof Shiny !== 'undefined'",
                    tags$script(HTML("
                      $(document).ready(function() {
                        // Detect if running on shinyapps.io
                        if (window.location.hostname.includes('shinyapps.io')) {
                          $('#shinyapps-warning').show();
                        } else {
                          $('#shinyapps-warning').hide();
                        }
                      });
                    ")),
                    div(id = "shinyapps-warning",
                        style = "background-color: #f8d7da; border: 2px solid #f5c6cb; border-radius: 4px; padding: 15px; margin-bottom: 20px; display: none;",
                      h4(style = "margin-top: 0; color: #721c24;", icon("exclamation-triangle"), " ElevenLabs Not Available on This Server"),
                      p(strong("This app is running on shinyapps.io, which does not support Python dependencies needed for ElevenLabs Premium.")),
                      p("✅ ", strong("Standard Voice (browser TTS) works perfectly"), " - no setup required!"),
                      p("❌ ElevenLabs Premium voice will not work on this server"),
                      p(strong("To use ElevenLabs Premium:"), " Download and run this app locally from ",
                        a("GitHub", href = "https://github.com/kenjd/student-name-pronunciation-helper", target = "_blank"),
                        ". Your API key will be saved and ElevenLabs will work perfectly on your local machine.")
                    )
                  ),

                  h4("Premium Voice Settings"),
                  p("To use the ElevenLabs Premium Voice with IPA pronunciation, you need to provide your API credentials."),
                  p(strong("Get your credentials from:"), a("ElevenLabs Dashboard", href = "https://elevenlabs.io/app/settings", target = "_blank")),
                  p(strong("Note:"), " Your credentials will be saved locally and automatically loaded when you restart the app."),

                  textInput("elevenlabs_api_key",
                           "ElevenLabs API Key:",
                           value = "",
                           placeholder = "sk_..."),

                  textInput("elevenlabs_voice_id",
                           "Voice ID:",
                           value = "",
                           placeholder = "Voice ID from ElevenLabs (e.g., 21m00Tcm4TlvDq8ikWAM)"),

                  p(strong("Recommended voices:")),
                  tags$ul(
                    tags$li("Any voice from ElevenLabs Voice Library"),
                    tags$li("Your own cloned voices"),
                    tags$li("Pre-made voices (Rachel, Domi, Bella, etc.)")
                  ),

                  p(strong("How it works:")),
                  tags$ul(
                    tags$li("The app sends IPA phonetics to ElevenLabs as plain text"),
                    tags$li("ElevenLabs pronounces names accurately using the IPA guide"),
                    tags$li("UTF-8 encoding ensures IPA special characters are preserved"),
                    tags$li("Works the same way as pasting IPA into the ElevenLabs website")
                  ),

                  hr(),
                  h4("Cost Information"),
                  tags$div(style = "background-color: #d4edda; border: 1px solid #c3e6cb; border-radius: 4px; padding: 10px; margin-bottom: 10px;",
                    tags$strong(style = "color: #155724;", "FREE TIER: 10,000 characters/month"),
                    tags$ul(
                      tags$li("Approximately 1,000 name pronunciations per month - completely FREE!"),
                      tags$li("No credit card required for free tier"),
                      tags$li("Perfect for most teachers - covers ~200 students reviewed 5x each")
                    )
                  ),
                  tags$p(tags$strong("If you exceed the free tier:")),
                  tags$ul(
                    tags$li("ElevenLabs charges approximately $15 per 1,000,000 characters"),
                    tags$li("For name pronunciation (avg 10 characters): ~$0.00015 per name"),
                    tags$li("Example: 2,000 names/month = 1,000 free + 1,000 paid = ~$0.15/month"),
                    tags$li("Heavy usage: ~$5-10/year even with large class sizes")
                  ),

                  hr(),
                  actionButton("save_settings", "Save Settings", class = "btn-success"),
                  actionButton("test_api", "Test API Connection", class = "btn-primary"),
                  actionButton("clear_cache", "Clear Audio Cache", class = "btn-warning"),
                  br(), br(),
                  textOutput("settings_save_result"),
                  textOutput("api_test_result"),
                  textOutput("cache_clear_result")
                )
              )
      ),

      # Help tab
      tabItem(tabName = "help",
              fluidRow(
                box(
                  title = "Help & FAQ", status = "info", solidHeader = TRUE,
                  width = 12,

                  # Critical Warning at Top
                  div(style = "background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin-bottom: 20px;",
                    h4(style = "margin-top: 0; color: #856404;", icon("exclamation-triangle"), " CRITICAL: The Student Is Always Right"),
                    p(strong("This app is a starting point, NOT the final authority."),
                      "Even common names have multiple valid pronunciations. Use this app to prepare, then ",
                      strong("ALWAYS ask your student how they pronounce their name."))
                  ),

                  p("Click any section below to expand:"),

                  # Quick Start Section
                  tags$details(
                    tags$summary(style = "cursor: pointer; font-size: 18px; font-weight: bold; color: #0275d8; margin-bottom: 10px;",
                                 icon("rocket"), " Quick Start (1-2 minutes)"),
                    div(style = "margin-left: 20px; margin-top: 10px;",
                      tags$ol(
                        tags$li(strong("Go to 'Name Lookup' tab"), " and enter a student's name"),
                        tags$li(strong("Select the name's origin"), " (Irish, Spanish, Chinese, Congolese, etc.) from the dropdown - this ", em("dramatically"), " improves accuracy!"),
                        tags$li(strong("Click 'Get Pronunciation'"), " to see phonetic guides"),
                        tags$li(strong("Listen with both voices:"), " Standard (browser) and Premium (ElevenLabs) to hear the difference"),
                        tags$li(strong("Save the name"), " for future reference - add notes if the student corrects you"),
                        tags$li(strong("Mark important names with the star icon"), " to keep them permanently")
                      ),
                      p(style = "margin-top: 10px; color: #666;", em("Tip: Selecting origin changes 'Siobhan' from 'SEE-OH-BAHN' (wrong) to 'SHIV-AWN' (correct)!"))
                    )
                  ),

                  tags$hr(),

                  # Common Questions Section
                  tags$details(
                    tags$summary(style = "cursor: pointer; font-size: 18px; font-weight: bold; color: #0275d8; margin-bottom: 10px;",
                                 icon("question-circle"), " Common Questions"),
                    div(style = "margin-left: 20px; margin-top: 10px;",

                      tags$details(style = "margin-bottom: 10px;",
                        tags$summary(style = "cursor: pointer; font-weight: bold;", "Why are the two pronunciations different?"),
                        p(style = "margin-left: 20px; margin-top: 5px;",
                          strong("Standard Voice"), " shows how you'd naturally pronounce it using English phonetic rules (often slightly wrong). ",
                          strong("ElevenLabs Premium"), " uses IPA for authentic pronunciation with sounds that don't exist in English. ",
                          "Use both to hear the gap and learn the correct pronunciation.")
                      ),

                      tags$details(style = "margin-bottom: 10px;",
                        tags$summary(style = "cursor: pointer; font-weight: bold;", "What if my student's name isn't in the dictionary?"),
                        p(style = "margin-left: 20px; margin-top: 5px;",
                          "1. Try selecting their name's origin - the app has pattern-based rules for 17+ languages.", br(),
                          "2. Use the ", strong("Custom Pronunciation"), " field to type your own phonetic spelling.", br(),
                          "3. Ask the student to pronounce it, write it phonetically, and save with notes.", br(),
                          "4. Consider contributing the name to the open-source project!")
                      ),

                      tags$details(style = "margin-bottom: 10px;",
                        tags$summary(style = "cursor: pointer; font-weight: bold;", "How do I mark names to keep forever?"),
                        p(style = "margin-left: 20px; margin-top: 5px;",
                          "Click the ", strong("star icon"), " next to any saved name. A gold star (★) means it's permanent and will survive when you click 'Clear All Saved Names' at semester end. ",
                          "Gray outline star (☆) means it's temporary. This lets you build a personal collection of frequently-used names across semesters.")
                      ),

                      tags$details(style = "margin-bottom: 10px;",
                        tags$summary(style = "cursor: pointer; font-weight: bold;", "Can I upload my whole class roster at once?"),
                        p(style = "margin-left: 20px; margin-top: 5px;",
                          strong("Yes!"), " Go to the ", strong("Bulk Upload"), " tab. Upload a CSV, Excel, or text file with student names (up to 200 at once). ",
                          "You can download an example template to see the format. The app will process all names and generate a printable PDF pronunciation guide.")
                      ),

                      tags$details(style = "margin-bottom: 10px;",
                        tags$summary(style = "cursor: pointer; font-weight: bold;", "What languages/origins are supported?"),
                        p(style = "margin-left: 20px; margin-top: 5px;",
                          strong("17 comprehensive dictionaries with 850+ verified names:"), br(),
                          "Irish, Spanish, Nigerian (Igbo/Yoruba/Hausa), Congolese (DRC), Indian (Hindi/Tamil/Punjabi), Greek, Chinese, Vietnamese, Korean, Arabic, Italian, French, Polish, German, Portuguese, Japanese, Russian, Hebrew, plus English via CMU dictionary.", br(), br(),
                          strong("Pattern-based support"), " for names not in dictionaries provides reasonable approximations for these same languages.")
                      ),

                      tags$details(style = "margin-bottom: 10px;",
                        tags$summary(style = "cursor: pointer; font-weight: bold;", "Do I need ElevenLabs Premium?"),
                        p(style = "margin-left: 20px; margin-top: 5px;",
                          strong("No!"), " The app works perfectly with just Standard Voice (browser TTS) - completely free and offline. ",
                          "ElevenLabs Premium adds higher accuracy with IPA support, but it's optional. Free tier includes 10,000 characters/month (~1,000 names).")
                      )
                    )
                  ),

                  tags$hr(),

                  # Troubleshooting Section
                  tags$details(
                    tags$summary(style = "cursor: pointer; font-size: 18px; font-weight: bold; color: #0275d8; margin-bottom: 10px;",
                                 icon("wrench"), " Troubleshooting"),
                    div(style = "margin-left: 20px; margin-top: 10px;",

                      tags$details(style = "margin-bottom: 10px;",
                        tags$summary(style = "cursor: pointer; font-weight: bold;", "No audio playing"),
                        tags$ul(style = "margin-left: 20px; margin-top: 5px;",
                          tags$li("Check your device volume is turned up"),
                          tags$li("Some browsers require user interaction before playing audio - click the button again"),
                          tags$li("For best results, use Chrome, Safari, or Edge"),
                          tags$li("Try the ElevenLabs Premium option if Standard Voice fails")
                        )
                      ),

                      tags$details(style = "margin-bottom: 10px;",
                        tags$summary(style = "cursor: pointer; font-weight: bold;", "ElevenLabs not working"),
                        tags$ul(style = "margin-left: 20px; margin-top: 5px;",
                          tags$li("Go to Settings tab and verify your API Key and Voice ID are correct"),
                          tags$li("Click 'Test Connection' to verify credentials"),
                          tags$li("Ensure you have an active internet connection"),
                          tags$li("Check your ElevenLabs account hasn't exceeded free tier limits"),
                          tags$li("Try clearing the audio cache in Settings")
                        )
                      ),

                      tags$details(style = "margin-bottom: 10px;",
                        tags$summary(style = "cursor: pointer; font-weight: bold;", "Wrong pronunciation / Not accurate enough"),
                        tags$ul(style = "margin-left: 20px; margin-top: 5px;",
                          tags$li(strong("Did you select the name's origin?"), " This is the #1 cause of wrong pronunciations"),
                          tags$li("Use the ", strong("Custom Pronunciation"), " field to override with your own phonetic spelling"),
                          tags$li("Ask the student directly and save their pronunciation in notes"),
                          tags$li("Remember: This is a starting point, not a perfect solution")
                        )
                      ),

                      tags$details(style = "margin-bottom: 10px;",
                        tags$summary(style = "cursor: pointer; font-weight: bold;", "Pagination keeps resetting when I click the star"),
                        p(style = "margin-left: 20px; margin-top: 5px;",
                          "This should be fixed in the latest version. If you're still experiencing this, try refreshing the app. ",
                          "The star toggle now uses a table proxy to preserve your current page position.")
                      )
                    )
                  ),

                  tags$hr(),

                  # Advanced Features Section
                  tags$details(
                    tags$summary(style = "cursor: pointer; font-size: 18px; font-weight: bold; color: #0275d8; margin-bottom: 10px;",
                                 icon("graduation-cap"), " Advanced Features"),
                    div(style = "margin-left: 20px; margin-top: 10px;",

                      tags$details(style = "margin-bottom: 10px;",
                        tags$summary(style = "cursor: pointer; font-weight: bold;", "Bulk Upload with CSV/Excel"),
                        div(style = "margin-left: 20px; margin-top: 5px;",
                          p("Upload entire class rosters at once (up to 200 names):"),
                          tags$ol(
                            tags$li("Go to ", strong("Bulk Upload"), " tab"),
                            tags$li("Download the example template CSV to see the format"),
                            tags$li("Prepare your file with columns: Name, Origin (optional)"),
                            tags$li("Upload CSV, Excel (.xlsx, .xls), or plain text file"),
                            tags$li("Click 'Process Names' to generate pronunciations"),
                            tags$li("Download as PDF for printing or CSV for gradebook integration"),
                            tags$li("Click 'Add All to Saved Names' to import them permanently")
                          )
                        )
                      ),

                      tags$details(style = "margin-bottom: 10px;",
                        tags$summary(style = "cursor: pointer; font-weight: bold;", "Generating PDF Pronunciation Guides"),
                        p(style = "margin-left: 20px; margin-top: 5px;",
                          "After bulk uploading names, click ", strong("Download PDF"), " to create a printable pronunciation guide with:",
                          tags$ul(
                            tags$li("Student names"),
                            tags$li("Phonetic pronunciation guides"),
                            tags$li("IPA notation"),
                            tags$li("Origin/Language"),
                            tags$li("Landscape format optimized for printing")
                          ),
                          "Perfect for keeping at your desk or sharing with substitute teachers!"
                        )
                      ),

                      tags$details(style = "margin-bottom: 10px;",
                        tags$summary(style = "cursor: pointer; font-weight: bold;", "Managing Permanent vs. Temporary Names"),
                        div(style = "margin-left: 20px; margin-top: 5px;",
                          p(strong("Strategy for semester transitions:")),
                          tags$ol(
                            tags$li("During the semester, save all student names normally (they default to temporary)"),
                            tags$li("Mark frequently-recurring names with the ", strong("star icon"), " (siblings, common names in your district, etc.)"),
                            tags$li("At semester end, click ", strong("Clear All Saved Names")),
                            tags$li("Temporary names are deleted, permanent names stay"),
                            tags$li("Start fresh next semester with your curated permanent collection")
                          ),
                          p(style = "color: #666;", em("This gives you autonomy - no need to wait for dictionary updates!"))
                        )
                      ),

                      tags$details(style = "margin-bottom: 10px;",
                        tags$summary(style = "cursor: pointer; font-weight: bold;", "Custom Pronunciation Override"),
                        p(style = "margin-left: 20px; margin-top: 5px;",
                          "Use the ", strong("Custom Pronunciation"), " field on the Name Lookup tab to override automatic pronunciations. ",
                          "Type your own phonetic spelling (like 'AH-bee-OONG' for Abiung) and it will work with both Standard and Premium voices. ",
                          "Perfect for unique names or when students correct you.")
                      ),

                      tags$details(style = "margin-bottom: 10px;",
                        tags$summary(style = "cursor: pointer; font-weight: bold;", "Audio Caching & Performance"),
                        p(style = "margin-left: 20px; margin-top: 5px;",
                          "ElevenLabs audio is automatically cached to reduce API costs. Once you've generated pronunciation for a name, it's saved locally. ",
                          "If you need to clear the cache (e.g., to regenerate with better phonetics), go to ", strong("Settings → Clear Audio Cache"), ". ",
                          "Cached audio for saved names is preserved automatically.")
                      )
                    )
                  ),

                  tags$hr(),

                  # Best Practices Footer
                  div(style = "background-color: #d1ecf1; border-left: 4px solid #17a2b8; padding: 15px; margin-top: 20px;",
                    h4(style = "margin-top: 0; color: #0c5460;", icon("lightbulb"), " Best Practices"),
                    tags$ul(
                      tags$li("Ask students to pronounce their names on the first day"),
                      tags$li("Write down the pronunciation phonetically in your own words"),
                      tags$li("Practice saying the names out loud before class"),
                      tags$li("Use the Custom Pronunciation field to save student corrections"),
                      tags$li("Don't be afraid to ask for clarification - students appreciate the effort!"),
                      tags$li("Mark frequently-used names with the star icon to build your personal collection")
                    )
                  )
                )
              )
      )
    )
  )
)

# Define server logic
server <- function(input, output, session) {

  # Configuration file for storing API credentials
  config_file <- file.path(getwd(), ".elevenlabs_config.rds")

  # Load saved credentials if they exist
  if (file.exists(config_file)) {
    tryCatch({
      saved_config <- readRDS(config_file)
      updateTextInput(session, "elevenlabs_api_key", value = saved_config$api_key)
      updateTextInput(session, "elevenlabs_voice_id", value = saved_config$voice_id)
    }, error = function(e) {
      # Config file exists but can't be read - ignore and use defaults
    })
  }

  # File for persisting saved names across sessions
  saved_names_file <- file.path(getwd(), ".saved_names.rds")

  # Initialize saved names data structure
  initial_saved_names <- data.frame(
    Name = character(0),
    Syllables = character(0),
    Simple_Phonetic = character(0),
    Origin = character(0),
    Notes = character(0),
    Date_Added = character(0),
    Audio_Path = character(0),  # Path to cached ElevenLabs audio
    Keep_Permanent = logical(0),  # Flag for names that survive "Clear All"
    stringsAsFactors = FALSE
  )

  # Load saved names from file if it exists
  if (file.exists(saved_names_file)) {
    tryCatch({
      loaded_data <- readRDS(saved_names_file)
      # Backward compatibility: Add Audio_Path column if it doesn't exist in old saved data
      if (!"Audio_Path" %in% names(loaded_data)) {
        loaded_data$Audio_Path <- as.character(rep("", nrow(loaded_data)))
      }
      # Backward compatibility: Remove CMU_Arpabet column if it exists in old saved data
      if ("CMU_Arpabet" %in% names(loaded_data)) {
        loaded_data$CMU_Arpabet <- NULL
      }
      # Backward compatibility: Add Keep_Permanent column if it doesn't exist in old saved data
      if (!"Keep_Permanent" %in% names(loaded_data)) {
        loaded_data$Keep_Permanent <- rep(FALSE, nrow(loaded_data))
      }
      initial_saved_names <- loaded_data
    }, error = function(e) {
      # File exists but can't be read - use empty data frame
      cat("Warning: Could not load saved names:", e$message, "\n")
    })
  }

  # Reactive values to store saved names and current pronunciation
  saved_names <- reactiveValues(data = initial_saved_names)

  # Store current phonetic guide for audio pronunciation
  current_phonetic <- reactiveValues(
    simple_standard = NULL,
    simple_premium = NULL,
    syllables = NULL,
    ipa = NULL,  # IPA phonetic for ElevenLabs
    override = NULL  # Manual override if user provides one
  )

  # Store bulk upload results
  bulk_results <- reactiveValues(
    data = NULL,
    has_data = FALSE
  )

  # Store detected origin suggestion
  detected_origin <- reactiveVal(NULL)

  # Track if user manually selected origin (don't override their choice)
  user_selected_origin <- reactiveVal(FALSE)
  first_name_entered <- reactiveVal(FALSE)

  # Trigger for saved names table refresh (increment to force re-render)
  # Used to prevent pagination reset when only updating specific rows via proxy
  saved_names_refresh_trigger <- reactiveVal(0)

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  # Save saved names to file for persistence across sessions
  save_saved_names_to_file <- function() {
    tryCatch({
      saveRDS(saved_names$data, saved_names_file)
    }, error = function(e) {
      cat("Error saving names to file:", e$message, "\n")
    })
  }

  # ============================================================================
  # BULK UPLOAD HELPER FUNCTIONS
  # ============================================================================

  # Parse uploaded file (CSV, Excel, or TXT)
  parse_bulk_file <- function(file_path, file_type) {
    tryCatch({
      if (file_type == "csv") {
        # CSV parsing
        df <- read.csv(file_path, stringsAsFactors = FALSE, strip.white = TRUE)

        # Validate structure
        if (ncol(df) == 0) {
          return(list(success = FALSE, error = "CSV file is empty"))
        }

        # First column is names, second (if exists) is origin, third (if exists) is notes
        names_col <- df[, 1]
        origin_col <- if (ncol(df) >= 2) df[, 2] else rep(NA, nrow(df))
        notes_col <- if (ncol(df) >= 3) df[, 3] else rep(NA, nrow(df))

      } else if (file_type %in% c("xlsx", "xls")) {
        # Excel parsing
        df <- readxl::read_excel(file_path, col_names = TRUE)
        df <- as.data.frame(df, stringsAsFactors = FALSE)

        if (ncol(df) == 0) {
          return(list(success = FALSE, error = "Excel file is empty"))
        }

        names_col <- df[, 1]
        origin_col <- if (ncol(df) >= 2) df[, 2] else rep(NA, nrow(df))
        notes_col <- if (ncol(df) >= 3) df[, 3] else rep(NA, nrow(df))

      } else if (file_type == "txt") {
        # Plain text parsing
        lines <- readLines(file_path, warn = FALSE)
        lines <- lines[nchar(trimws(lines)) > 0]  # Remove empty lines

        if (length(lines) == 0) {
          return(list(success = FALSE, error = "Text file is empty"))
        }

        names_col <- trimws(lines)
        origin_col <- rep(NA, length(lines))
        notes_col <- rep(NA, length(lines))

      } else {
        return(list(success = FALSE, error = "Unsupported file format"))
      }

      # Clean and validate names
      names_col <- trimws(as.character(names_col))
      origin_col <- trimws(as.character(origin_col))
      notes_col <- trimws(as.character(notes_col))
      origin_col[origin_col == "NA" | origin_col == ""] <- NA
      notes_col[notes_col == "NA" | notes_col == ""] <- NA

      # Remove rows with empty names
      valid_rows <- nchar(names_col) > 0 & !is.na(names_col)
      names_col <- names_col[valid_rows]
      origin_col <- origin_col[valid_rows]
      notes_col <- notes_col[valid_rows]

      if (length(names_col) == 0) {
        return(list(success = FALSE, error = "No valid names found in file"))
      }

      # Limit to reasonable number
      if (length(names_col) > 200) {
        return(list(
          success = FALSE,
          error = "Too many names (max 200). Please split into smaller batches."
        ))
      }

      return(list(
        success = TRUE,
        names = names_col,
        origins = origin_col,
        notes = notes_col
      ))

    }, error = function(e) {
      return(list(
        success = FALSE,
        error = paste("Error reading file:", e$message)
      ))
    })
  }

  # Process bulk names and generate pronunciations
  process_bulk_names <- function(names_vector, origins_vector = NULL, notes_vector = NULL) {

    n_names <- length(names_vector)

    # Initialize results data frame
    results <- data.frame(
      Name = character(n_names),
      Origin = character(n_names),
      Simple_Phonetic = character(n_names),
      IPA = character(n_names),
      Syllables = character(n_names),
      Method = character(n_names),
      Notes = character(n_names),
      stringsAsFactors = FALSE
    )

    # Process each name
    for (i in seq_along(names_vector)) {
      name <- names_vector[i]
      origin_input <- if (!is.null(origins_vector)) origins_vector[i] else NA

      # Auto-detect if no origin provided
      if (is.na(origin_input) || origin_input == "") {
        detected <- detect_name_origin(name)
        origin_to_use <- detected$origin
        origin_display <- detected$display
      } else {
        # Normalize origin input to match app's origin codes
        origin_to_use <- tolower(trimws(origin_input))
        origin_display <- origin_input

        # Validate: If origin doesn't match any known language, auto-detect instead
        known_origins <- c("irish", "spanish", "nigerian", "indian", "greek", "chinese",
                          "vietnamese", "korean", "arabic", "italian", "french", "polish",
                          "german", "portuguese", "japanese", "russian", "hebrew", "english")
        if (!origin_to_use %in% known_origins) {
          # Unknown origin value - auto-detect the correct language
          detected <- detect_name_origin(name)
          origin_to_use <- detected$origin
          origin_display <- detected$display
        }
      }

      # Get pronunciation guide
      pron <- tryCatch({
        get_pronunciation_guide(name, origin = origin_to_use)
      }, error = function(e) {
        # Fallback to generic if error
        list(
          simple_standard = toupper(name),
          syllables = name,
          ipa_notation = "",
          method_used = "error",
          dictionary_name = "Error processing"
        )
      })

      # Store results
      results$Name[i] <- name
      results$Origin[i] <- origin_display
      results$Simple_Phonetic[i] <- pron$simple_standard
      results$IPA[i] <- if (!is.null(pron$ipa_notation)) pron$ipa_notation else ""
      results$Syllables[i] <- pron$syllables

      # Method indicator
      method_text <- switch(pron$method_used,
        "dictionary" = paste0("\u2713 ", pron$dictionary_name),
        "pattern" = paste0("\u26A0 ", pron$dictionary_name),
        "generic" = "Generic",
        "error" = "Error"
      )
      results$Method[i] <- method_text

      # Store notes if provided
      note <- if (!is.null(notes_vector) && i <= length(notes_vector)) notes_vector[i] else NA
      results$Notes[i] <- if (!is.na(note)) note else ""
    }

    return(results)
  }

  # ============================================================================
  # OBSERVERS
  # ============================================================================

  observeEvent(input$name_origin, {
    # Only count as "user selected" if they entered a name first
    # This prevents Shiny's auto-select from blocking detection
    if (first_name_entered() && !is.null(input$name_origin) && input$name_origin != "") {
      user_selected_origin(TRUE)
    }
  }, ignoreInit = TRUE)

  # Reset when name changes
  observeEvent(input$student_name, {
    if (!is.null(input$student_name) && nchar(trimws(input$student_name)) > 0) {
      if (!first_name_entered()) {
        # First name entry - clear any default dropdown value
        first_name_entered(TRUE)
        updateSelectizeInput(session, "name_origin", selected = character(0))
      }
    }
    user_selected_origin(FALSE)
    # Clear custom pronunciation for new name (prevents carryover)
    updateTextInput(session, "phonetic_override", value = "")
  })

  # Auto-detect and auto-select origin when name changes
  observe({
    name <- input$student_name

    # Don't auto-detect if user manually selected
    if (user_selected_origin()) {
      detected_origin(NULL)
      return()
    }

    if (!is.null(name) && nchar(trimws(name)) >= 3) {
      detection <- detect_name_origin(name)

      # Auto-select if high confidence (dictionary match or very distinctive pattern)
      if (!is.null(detection) && detection$confidence == "high") {
        updateSelectizeInput(session, "name_origin", selected = detection$origin)
        detected_origin(NULL)  # Don't show suggestion if we auto-selected
      } else if (!is.null(detection) && detection$confidence != "none") {
        # Show clickable suggestion for medium/low confidence
        detected_origin(detection)
      } else {
        # Can't detect - auto-select "unknown"
        updateSelectizeInput(session, "name_origin", selected = "unknown")
        detected_origin(NULL)
      }
    } else {
      detected_origin(NULL)
    }
  })

  # Render origin suggestion
  output$origin_suggestion <- renderUI({
    detection <- detected_origin()

    if (!is.null(detection) && detection$confidence != "none") {
      # Show suggestion with confidence indicator
      confidence_color <- switch(detection$confidence,
        "high" = "green",
        "medium" = "orange",
        "low" = "gray",
        "gray"
      )

      confidence_icon <- switch(detection$confidence,
        "high" = "✓",
        "medium" = "~",
        "low" = "?",
        "?"
      )

      tagList(
        br(),
        div(
          style = paste0("padding: 10px; background-color: #f0f0f0; border-left: 4px solid ", confidence_color, "; margin-bottom: 10px;"),
          strong(paste0(confidence_icon, " Suggested origin: ")),
          span(style = paste0("color: ", confidence_color, ";"), detection$display),
          br(),
          actionLink("apply_suggestion", "Click to apply this suggestion", style = "font-size: 12px;")
        )
      )
    }
  })

  # Apply suggested origin when user clicks the link
  observeEvent(input$apply_suggestion, {
    detection <- detected_origin()
    if (!is.null(detection)) {
      updateSelectizeInput(session, "name_origin", selected = detection$origin)
      detected_origin(NULL)  # Clear suggestion after applying
    }
  })

  # Helper function: Validate name for speech
  validate_name_for_speech <- function(name) {
    name <- trimws(name)

    # Check if empty
    if (nchar(name) == 0) {
      return(list(valid = FALSE, message = "Please enter a name"))
    }

    # Check length
    if (nchar(name) > 50) {
      return(list(valid = FALSE, message = "Name is too long (max 50 characters)"))
    }

    # Allow letters, spaces, hyphens, apostrophes, and accented characters
    if (!grepl("^[\\p{L}\\s'\\-]+$", name, perl = TRUE)) {
      return(list(valid = FALSE, message = "Name contains unsupported characters"))
    }

    return(list(valid = TRUE))
  }

  # Helper function: Get cached audio file path
  get_cached_audio <- function(name, phonetic = NULL, speed = 1.0) {
    # Create cache directory in app directory (permanent, survives restarts)
    audio_cache_dir <- file.path(getwd(), ".audio_cache")
    if (!dir.exists(audio_cache_dir)) {
      dir.create(audio_cache_dir, showWarnings = FALSE, recursive = TRUE)
    }

    # Create hash of name + phonetic + speed for consistent filename
    # This ensures different pronunciations and speeds don't collide
    cache_key <- paste0(tolower(trimws(name)), "_", phonetic, "_", sprintf("%.2f", speed))
    # Use digest if available, otherwise use simple hash
    if (requireNamespace("digest", quietly = TRUE)) {
      cache_hash <- digest::digest(cache_key, algo = "md5")
    } else {
      # Fallback: use R's internal hash
      cache_hash <- as.character(abs(as.integer(charToRaw(cache_key)[1])))
    }

    cache_file <- file.path(audio_cache_dir, paste0(cache_hash, ".mp3"))

    if (file.exists(cache_file)) {
      return(list(cached = TRUE, path = cache_file))
    }

    return(list(cached = FALSE, path = cache_file))
  }

  # Helper function: Manage cache size to prevent unbounded growth
  # Keeps newest files up to max_files limit, deletes oldest
  manage_cache_size <- function(max_files = 50) {
    audio_cache_dir <- file.path(getwd(), ".audio_cache")
    if (!dir.exists(audio_cache_dir)) return()

    cache_files <- list.files(audio_cache_dir, full.names = TRUE)

    if (length(cache_files) > max_files) {
      # Sort by modification time (oldest first)
      file_info <- file.info(cache_files)
      file_info$path <- rownames(file_info)
      file_info <- file_info[order(file_info$mtime), ]

      # Delete oldest files to bring count down to max_files
      files_to_delete <- file_info$path[1:(length(cache_files) - max_files)]
      unlink(files_to_delete)
    }
  }

  # Helper function: Generate premium audio using ElevenLabs API with phonetic respelling
  generate_premium_audio <- function(name, phonetic_text, api_key, voice_id, speed = 1.0, ipa = NULL) {
    tryCatch({
      # Validate API credentials
      if (is.null(api_key) || api_key == "" || is.na(api_key)) {
        return(list(
          success = FALSE,
          error = "ElevenLabs API key not set. Please configure in Settings tab."
        ))
      }

      if (is.null(voice_id) || voice_id == "" || is.na(voice_id)) {
        return(list(
          success = FALSE,
          error = "ElevenLabs voice ID not set. Please configure in Settings tab."
        ))
      }

      # Find Python executable dynamically (supports deployment to servers)
      # Relies on Python being in system PATH (works with requirements.txt on shinyapps.io)
      python_cmd <- Sys.which("python3")
      if (python_cmd == "" || python_cmd == "python3") {
        # Try python if python3 not found
        python_cmd <- Sys.which("python")
      }

      # If Python still not found, return error
      if (python_cmd == "" || python_cmd == "python") {
        return(list(
          success = FALSE,
          error = "Python not available. ElevenLabs Premium requires Python 3. Use Standard Voice instead, or install Python on your system."
        ))
      }

      # Path to Python script
      py_script <- file.path(
        getwd(),
        "speak_name.py"
      )

      # Check if Python script exists
      if (!file.exists(py_script)) {
        return(list(
          success = FALSE,
          error = "Python script not found. Please ensure speak_name.py is in the app directory."
        ))
      }

      # Check cache first (cache now works for all speeds since speed is in cache key)
      cache_result <- get_cached_audio(name, phonetic_text, speed)
      if (cache_result$cached) {
        return(list(
          success = TRUE,
          audio_path = cache_result$path,
          cached = TRUE
        ))
      }

      # Call Python script with phonetic respelling and API credentials
      # Arguments: name, phonetic_text, api_key, voice_id, output_path, speed, ipa
      # Set PYTHONIOENCODING to ensure UTF-8 handling for special characters
      result <- system2(
        python_cmd,  # Use dynamically detected Python
        args = c(
          shQuote(py_script),
          shQuote(name),
          shQuote(phonetic_text),
          shQuote(api_key),
          shQuote(voice_id),
          shQuote(cache_result$path),
          as.character(speed),
          if (!is.null(ipa)) shQuote(ipa) else shQuote("")
        ),
        stdout = TRUE,
        stderr = TRUE,
        env = c("PYTHONIOENCODING=utf-8")
      )

      # Parse JSON result
      json_result <- tryCatch({
        jsonlite::fromJSON(paste(result, collapse = ""))
      }, error = function(e) {
        list(success = FALSE, error = paste("Failed to parse Python output:", paste(result, collapse = " ")))
      })

      if (json_result$success) {
        # Manage cache size to prevent unbounded growth
        manage_cache_size(50)

        return(list(
          success = TRUE,
          audio_path = json_result$audio_path,
          cached = FALSE
        ))
      } else {
        return(list(
          success = FALSE,
          error = json_result$error
        ))
      }
    }, error = function(e) {
      return(list(
        success = FALSE,
        error = paste("Error calling Python script:", e$message)
      ))
    })
  }

  # Get pronunciation when button is clicked
  observeEvent(input$get_pronunciation, {
    req(input$student_name)

    name <- input$student_name
    # Get selected origin from dropdown/input
    selected_origin <- input$name_origin

    # Generate pronunciation guide with origin-specific rules
    pronunciation_guide <- get_pronunciation_guide(name, origin = selected_origin)

    # Store phonetic guides for audio pronunciation
    current_phonetic$simple_standard <- pronunciation_guide$simple_standard
    current_phonetic$simple_premium <- pronunciation_guide$simple_premium
    current_phonetic$syllables <- pronunciation_guide$syllables
    current_phonetic$ipa <- pronunciation_guide$ipa

    output$pronunciation_output <- renderUI({
      # Create method indicator
      method_indicator <- switch(pronunciation_guide$method_used,
        "dictionary" = paste0("✓ Found in ", pronunciation_guide$dictionary_name, " Dictionary"),
        "pattern" = paste0("⚠ Using ", pronunciation_guide$dictionary_name, " pattern-based rules (not in dictionary)"),
        "generic" = "⚠ Using generic phonetics (no origin selected)"
      )

      # Create inline "Use" button that directly populates Custom Pronunciation field
      copy_button_html <- function(text_to_copy) {
        # HTML-escape the text for the data attribute
        safe_text <- gsub("\"", "&quot;", text_to_copy)
        # Directly set the Custom Pronunciation field value (id="phonetic_override")
        onclick_handler <- "document.getElementById('phonetic_override').value = this.getAttribute('data-text'); this.innerHTML='✓'; setTimeout(() => this.innerHTML='Use', 2000);"
        sprintf("<button onclick=\"%s\" data-text=\"%s\" class=\"btn btn-xs btn-success\" style=\"margin-left: 8px; padding: 1px 5px; font-size: 10px;\">Use</button>",
                onclick_handler, safe_text)
      }

      # Build everything as pure HTML for compact inline rendering
      tags$pre(
        style = "background-color: #f5f5f5; padding: 10px; border-radius: 4px; font-family: monospace; white-space: pre-wrap; line-height: 1.4;",
        HTML(paste0(
          "Original name:\n",
          name, "\n",
          "Method: ", method_indicator, "\n\n",
          "With syllable breaks:\n",
          pronunciation_guide$syllables, "\n\n",
          "--- Phonetics for Audio ---\n\n",
          "For Standard Voice (Browser TTS):\n",
          pronunciation_guide$simple_standard, "\n\n",
          "For ElevenLabs Premium:\n",
          pronunciation_guide$simple_premium, "\n\n",
          "--- Phonetic Notations (for Reference) ---\n\n",
          "CMU Arpabet: ", pronunciation_guide$ipa, copy_button_html(pronunciation_guide$ipa), "\n",
          "IPA Notation: ", pronunciation_guide$ipa_notation, copy_button_html(pronunciation_guide$ipa_notation),
          "\n\nℹ️ Click 'Use' button to apply CMU or IPA to 'Custom Pronunciation' if you need to override. ",
          "ElevenLabs understands both simple respelling (e.g., 'seer-sha') and CMU Arpabet (e.g., 'S IH1 R SH AH0').",
          "\n\nPhonetic Key:\n",
          "AW = 'aw' in 'dawn'  |  EH = 'e' in 'bet'  |  EE = 'ee' in 'see'\n",
          "OH = 'o' in 'go'  |  OO = 'oo' in 'moon'  |  AY = 'ay' in 'say'\n",
          "OW = 'ow' in 'cow'  |  CH = 'ch' in 'chair'  |  SH = 'sh' in 'shop'\n",
          "Stress: 1=primary, 0=unstressed, 2=secondary"
        ))
      )
    })

    output$origin_output <- renderText({
      if (!is.null(selected_origin) && selected_origin != "" && selected_origin != "unknown") {
        # Show the selected origin
        origin_labels <- c(
          "irish" = "Irish (Gaelic)",
          "spanish" = "Spanish",
          "nigerian" = "Nigerian (Igbo/Yoruba/Hausa)",
          "indian" = "Indian (Hindi/Sanskrit)",
          "greek" = "Greek",
          "chinese" = "Chinese (Mandarin)",
          "vietnamese" = "Vietnamese",
          "korean" = "Korean",
          "arabic" = "Arabic",
          "italian" = "Italian",
          "french" = "French",
          "german" = "German",
          "polish" = "Polish",
          "japanese" = "Japanese",
          "portuguese" = "Portuguese",
          "russian" = "Russian",
          "hebrew" = "Hebrew",
          "english" = "English"
        )
        display_origin <- origin_labels[selected_origin]
        if (is.na(display_origin)) {
          # Custom origin entered
          paste("Custom origin:", selected_origin)
        } else {
          paste("Selected origin:", display_origin)
        }
      } else {
        # Fallback to auto-detection if no origin selected
        detected <- detect_name_origin(name)
        if (detected$confidence != "none") {
          confidence_label <- switch(detected$confidence,
            "high" = "✓ High confidence",
            "medium" = "~ Medium confidence",
            "low" = "? Low confidence",
            ""
          )
          paste("Auto-detected:", detected$display, paste0("(", confidence_label, ")"), "\n(Tip: Select an origin manually for guaranteed accuracy)")
        } else {
          "Origin: Unknown\n(Could not auto-detect - please select origin manually if known)"
        }
      }
    })
    
    output$tips_output <- renderText({
      tips <- paste(
        "• Use the syllable breaks to practice: say each part separately, then together",
        "• The simple phonetic guide uses common English sounds",
        "• The IPA guide (/like this/) is more precise for linguists",
        "• Try saying it slowly first, then at normal speed",
        "• Remember: this is an approximation - ask the student for confirmation!",
        "• Practice saying it out loud several times",
        sep = "\n"
      )
      tips
    })
  })

  # Standard voice pronunciation observer
  observeEvent(input$speak_name, {
    req(input$student_name)

    # Check if phonetic guide has been generated
    if (is.null(current_phonetic$simple_standard)) {
      showNotification("Please click 'Get Pronunciation' first", type = "warning")
      return()
    }

    # Determine which phonetic to use: override or auto-generated
    phonetic_to_use <- if (!is.null(input$phonetic_override) && input$phonetic_override != "") {
      input$phonetic_override  # Use manual override
    } else {
      current_phonetic$simple_standard  # Use auto-generated for standard voice
    }

    # Validate phonetic text
    validation <- validate_name_for_speech(phonetic_to_use)
    if (!validation$valid) {
      showNotification(validation$message, type = "error")
      return()
    }

    # Send phonetic guide to JavaScript for pronunciation
    session$sendCustomMessage(
      "speakName",
      list(name = phonetic_to_use, speed = input$speech_speed)
    )
  })

  # Premium voice pronunciation observer
  observeEvent(input$speak_premium, {
    req(input$student_name)

    # Check if phonetic guide has been generated
    if (is.null(current_phonetic$ipa)) {
      showNotification("Please click 'Get Pronunciation' first", type = "warning")
      return()
    }

    # Get student name
    name <- input$student_name

    # Check for manual override first, otherwise use auto-generated respelling
    if (!is.null(input$phonetic_override) && input$phonetic_override != "") {
      # User provided custom phonetic - use it for ElevenLabs
      phonetic_text <- input$phonetic_override
    } else {
      # Use respelling as fallback if IPA fails
      # But IPA will be preferred by the Python script when available
      phonetic_text <- current_phonetic$simple_premium
    }

    # Validate phonetic text
    if (is.null(phonetic_text) || phonetic_text == "") {
      showNotification("Phonetic pronunciation not available", type = "error")
      return()
    }

    # Get API credentials from settings
    api_key <- input$elevenlabs_api_key
    voice_id <- input$elevenlabs_voice_id

    # Show loading indicator
    showNotification("Generating ElevenLabs pronunciation...",
                     type = "message",
                     id = "premium_loading",
                     duration = NULL)

    # Generate audio using respelling phonetics for ElevenLabs API
    result <- generate_premium_audio(
      name = name,
      phonetic_text = phonetic_text,
      api_key = api_key,
      voice_id = voice_id,
      speed = input$premium_speed,
      ipa = current_phonetic$ipa
    )

    # Remove loading notification
    removeNotification("premium_loading")

    if (result$success) {
      # Read audio file and convert to base64
      audio_data <- base64enc::base64encode(result$audio_path)

      # Send to JavaScript for playback
      session$sendCustomMessage(
        "playAudioBase64",
        list(data = audio_data, format = "mp3")
      )

      # Show success message
      cache_msg <- if (!is.null(result$cached) && result$cached) " (cached)" else ""
      showNotification(
        paste0("Playing premium pronunciation", cache_msg),
        type = "message"
      )
    } else {
      showNotification(
        paste("Premium voice error:", result$error),
        type = "error",
        duration = 10
      )
    }
  })

  # Speed control observer
  observeEvent(input$speech_speed, {
    # Update JavaScript global speed variable
    session$sendCustomMessage("updateSpeechSpeed", input$speech_speed)
  })

  # Save name to the list
  observeEvent(input$save_name, {
    req(input$student_name)

    # Use tryCatch to handle any errors gracefully
    tryCatch({
      name <- input$student_name
      selected_origin <- input$name_origin

      # Use the stored phonetic guide (already generated with origin-specific rules)
      # or regenerate if somehow missing
      if (is.null(current_phonetic$simple_standard)) {
        pronunciation_guide <- get_pronunciation_guide(name, origin = selected_origin)
      } else {
        # Use the stored values, prioritizing override if provided
        phonetic_for_save <- if (!is.null(input$phonetic_override) && input$phonetic_override != "") {
          input$phonetic_override  # Use manual override
        } else {
          current_phonetic$simple_standard  # Use standard phonetic
        }

        pronunciation_guide <- list(
          simple = phonetic_for_save,
          syllables = current_phonetic$syllables,
          ipa = ""  # Will be regenerated if needed
        )
      }

      # Get origin display text
      origin_display <- if (!is.null(selected_origin) && selected_origin != "" && selected_origin != "unknown") {
        origin_labels <- c(
          "irish" = "Irish (Gaelic)",
          "spanish" = "Spanish",
          "nigerian" = "Nigerian (Igbo/Yoruba/Hausa)",
          "indian" = "Indian (Hindi/Sanskrit)",
          "greek" = "Greek",
          "chinese" = "Chinese (Mandarin)",
          "vietnamese" = "Vietnamese",
          "korean" = "Korean",
          "arabic" = "Arabic",
          "italian" = "Italian",
          "french" = "French",
          "german" = "German",
          "polish" = "Polish",
          "japanese" = "Japanese",
          "portuguese" = "Portuguese",
          "russian" = "Russian",
          "hebrew" = "Hebrew",
          "english" = "English"
        )
        display <- origin_labels[selected_origin]
        if (is.na(display)) selected_origin else display
      } else {
        detected <- detect_name_origin(name)
        if (detected$confidence != "none") {
          detected$display
        } else {
          "Unknown"
        }
      }

      notes <- if(is.null(input$pronunciation_notes) || input$pronunciation_notes == "") {
        ""
      } else {
        input$pronunciation_notes
      }

      # Pre-cache ElevenLabs audio if API credentials are configured
      audio_path <- ""
      audio_notification <- ""

      api_key <- input$elevenlabs_api_key
      voice_id <- input$elevenlabs_voice_id

      if (!is.null(api_key) && api_key != "" && !is.na(api_key) &&
          !is.null(voice_id) && voice_id != "" && !is.na(voice_id)) {

        # Generate and cache ElevenLabs audio for this name
        # Use the same phonetic that Premium Voice button uses

        # Check for manual override first, otherwise use premium phonetic
        phonetic_for_cache <- if (!is.null(input$phonetic_override) && input$phonetic_override != "") {
          input$phonetic_override  # Use manual override
        } else {
          current_phonetic$simple_premium  # Use PREMIUM phonetic (not standard!)
        }

        # Use the IPA notation if available
        ipa_for_audio <- if (!is.null(current_phonetic$ipa) && current_phonetic$ipa != "") {
          current_phonetic$ipa
        } else {
          NULL
        }

        audio_result <- generate_premium_audio(
          name = name,
          phonetic_text = phonetic_for_cache,
          api_key = api_key,
          voice_id = voice_id,
          speed = 1.0,
          ipa = ipa_for_audio
        )

        if (audio_result$success) {
          audio_path <- audio_result$audio_path
          audio_notification <- if (audio_result$cached) {
            " (audio already cached)"
          } else {
            " with ElevenLabs audio!"
          }
        } else {
          audio_notification <- " (audio generation failed - will use Standard Voice)"
        }
      } else {
        audio_notification <- " (configure ElevenLabs in Settings for better audio)"
      }

      # Determine which phonetic to save (same as what was cached)
      phonetic_to_save <- if (!is.null(input$phonetic_override) && input$phonetic_override != "") {
        input$phonetic_override  # Use manual override
      } else {
        current_phonetic$simple_premium  # Use PREMIUM phonetic for consistency
      }

      # Create new row with proper handling
      new_row <- data.frame(
        Name = as.character(name),
        Syllables = as.character(pronunciation_guide$syllables),
        Simple_Phonetic = as.character(phonetic_to_save),
        Origin = as.character(origin_display),
        Notes = as.character(notes),
        Date_Added = as.character(Sys.Date()),
        Audio_Path = as.character(audio_path),
        Keep_Permanent = FALSE,  # New names default to temporary (not permanent)
        stringsAsFactors = FALSE
      )

      # Add to saved names
      if(nrow(saved_names$data) == 0) {
        saved_names$data <- new_row
      } else {
        # MIGRATION: Add Audio_Path column to existing data if it doesn't exist
        if (!"Audio_Path" %in% names(saved_names$data)) {
          # Properly initialize as character vector with no width limit
          saved_names$data$Audio_Path <- as.character(rep("", nrow(saved_names$data)))
        }
        # Use rbind with make.row.names=FALSE and stringsAsFactors=FALSE to avoid issues
        saved_names$data <- rbind(saved_names$data, new_row, stringsAsFactors = FALSE, make.row.names = FALSE)
      }

      # Persist to file
      save_saved_names_to_file()

      # Trigger table refresh (full re-render needed for new row)
      saved_names_refresh_trigger(saved_names_refresh_trigger() + 1)

      # Clear inputs
      updateTextInput(session, "student_name", value = "")
      updateTextInput(session, "pronunciation_notes", value = "")

      showNotification(paste0("Name saved successfully", audio_notification), type = "message")
      
    }, error = function(e) {
      showNotification(paste("Error saving name:", e$message), type = "error")
    })
  })
  
  # Display saved names table
  output$saved_names_table <- DT::renderDataTable({
    # Depend on refresh trigger instead of data directly (prevents pagination reset)
    saved_names_refresh_trigger()

    # Use isolate to prevent reactive dependency on saved_names$data
    # This allows us to update data via proxy without triggering full re-render
    table_data <- isolate({
      if (nrow(saved_names$data) > 0) {
        saved_names$data
      } else {
        saved_names$data
      }
    })

    # Create copy of data and add Audio and Delete columns with buttons
    if (nrow(table_data) > 0) {

      # Backward compatibility: Add Audio_Path column if it doesn't exist (for old saved names)
      if (!"Audio_Path" %in% names(table_data)) {
        table_data$Audio_Path <- as.character(rep("", nrow(table_data)))
      }

      # Create audio buttons - use cached audio if available, otherwise fall back to browser TTS
      table_data$Audio <- mapply(function(row_index, name, phonetic, audio_path) {
        paste0('<button class="btn btn-sm btn-primary play-saved-audio" data-row="',
               row_index - 1,  # DT uses 0-based indexing
               '" data-name="', name,
               '" data-phonetic="', phonetic,
               '" data-has-cache="', ifelse(audio_path != "" && !is.na(audio_path), "true", "false"),
               '" style="padding: 2px 8px;"><i class="fa fa-volume-up"></i></button>')
      }, 1:nrow(table_data), table_data$Name, table_data$Simple_Phonetic, table_data$Audio_Path, USE.NAMES = FALSE)

      # Add "Keep Permanent" star icon column
      table_data$Keep <- mapply(function(row_index, is_permanent) {
        icon_class <- ifelse(is_permanent, "fa-star", "fa-star-o")  # Solid vs outline
        icon_color <- ifelse(is_permanent, "gold", "gray")
        paste0('<button class="btn btn-sm toggle-permanent" data-row="',
               row_index - 1,  # DT uses 0-based indexing
               '" style="padding: 2px 8px; background: transparent; border: none;">',
               '<i class="fa ', icon_class, '" style="color: ', icon_color, '; font-size: 16px;"></i>',
               '</button>')
      }, 1:nrow(table_data), table_data$Keep_Permanent, USE.NAMES = FALSE)

      # Add Delete column with delete buttons
      table_data$Delete <- sapply(1:nrow(table_data), function(i) {
        paste0('<button class="btn btn-sm btn-danger delete-saved-name" data-row="',
               i - 1,  # DT uses 0-based indexing
               '" style="padding: 2px 8px;"><i class="fa fa-trash"></i></button>')
      })

      # Remove Audio_Path and Keep_Permanent from display (internal use only, replaced by Keep icon)
      table_data <- table_data[, !names(table_data) %in% c("Audio_Path", "Keep_Permanent")]
    } else {
      table_data <- saved_names$data
    }

    DT::datatable(
      table_data,
      escape = FALSE,  # Allow HTML in Audio and Delete columns
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        columnDefs = list(
          list(
            targets = ncol(table_data) - 3,  # Audio column
            orderable = FALSE,  # Don't allow sorting on Audio column
            width = '60px'
          ),
          list(
            targets = ncol(table_data) - 2,  # Keep column
            orderable = FALSE,  # Don't allow sorting on Keep column
            width = '60px'
          ),
          list(
            targets = ncol(table_data) - 1,  # Delete column
            orderable = FALSE,  # Don't allow sorting on Delete column
            width = '60px'
          )
        )
      ),
      rownames = FALSE
    )
  })

  # Save ElevenLabs settings
  observeEvent(input$save_settings, {
    api_key <- input$elevenlabs_api_key
    voice_id <- input$elevenlabs_voice_id

    # Validate inputs
    if (is.null(api_key) || api_key == "" || is.na(api_key)) {
      output$settings_save_result <- renderText("Error: Please enter your ElevenLabs API key")
      return()
    }

    if (is.null(voice_id) || voice_id == "" || is.na(voice_id)) {
      output$settings_save_result <- renderText("Error: Please enter a voice ID")
      return()
    }

    # Save credentials to file
    tryCatch({
      config <- list(
        api_key = api_key,
        voice_id = voice_id,
        saved_date = Sys.time()
      )
      saveRDS(config, config_file)

      output$settings_save_result <- renderText(paste(
        "✓ Settings saved successfully!",
        "Your credentials will be automatically loaded next time.",
        sep = "\n"
      ))
    }, error = function(e) {
      output$settings_save_result <- renderText(paste(
        "✗ Error saving settings:",
        e$message,
        sep = "\n"
      ))
    })
  })

  # Test ElevenLabs API connection
  observeEvent(input$test_api, {
    api_key <- input$elevenlabs_api_key
    voice_id <- input$elevenlabs_voice_id

    # Validate inputs
    if (is.null(api_key) || api_key == "" || is.na(api_key)) {
      output$api_test_result <- renderText("Error: Please enter your ElevenLabs API key")
      return()
    }

    if (is.null(voice_id) || voice_id == "" || is.na(voice_id)) {
      output$api_test_result <- renderText("Error: Please enter a voice ID")
      return()
    }

    output$api_test_result <- renderText("Testing API connection...")

    # Test with a simple name
    test_result <- generate_premium_audio(
      name = "Test",
      phonetic_text = "test",
      api_key = api_key,
      voice_id = voice_id,
      speed = 1.0,
      ipa = NULL
    )

    if (test_result$success) {
      output$api_test_result <- renderText(paste(
        "✓ Success! API connection working.",
        "Voice ID and API key are valid.",
        "You can now use ElevenLabs Premium pronunciation.",
        sep = "\n"
      ))
    } else {
      output$api_test_result <- renderText(paste(
        "✗ API Test Failed:",
        test_result$error,
        "\nPlease check your API key and voice ID.",
        sep = "\n"
      ))
    }
  })

  # Clear audio cache (managed cache + orphan files)
  # SMART CLEAR: Preserves audio for saved names, only deletes temporary lookup cache
  observeEvent(input$clear_cache, {
    # Use permanent cache directory (same as get_cached_audio)
    audio_cache_dir <- file.path(getwd(), ".audio_cache")

    file_count <- 0
    preserved_count <- 0

    # Get list of audio files currently used by saved names (protect these!)
    protected_files <- c()
    if (nrow(saved_names$data) > 0) {
      protected_files <- saved_names$data$Audio_Path
      protected_files <- protected_files[!is.na(protected_files) & protected_files != ""]
    }

    # Clear permanent cache directory (but preserve saved names audio)
    if (dir.exists(audio_cache_dir)) {
      cache_files <- list.files(audio_cache_dir, full.names = TRUE)

      for (file in cache_files) {
        if (file %in% protected_files) {
          # This file is used by a saved name - keep it!
          preserved_count <- preserved_count + 1
        } else {
          # This is orphaned cache or temporary lookup - delete it
          unlink(file)
          file_count <- file_count + 1
        }
      }
    }

    output$cache_clear_result <- renderText(paste(
      "✓ Cache cleared successfully!",
      paste0("Deleted ", file_count, " temporary cached audio files."),
      if (preserved_count > 0) paste0("Preserved ", preserved_count, " saved name audio files.") else "",
      "Next pronunciation will generate fresh audio.",
      sep = "\n"
    ))
  })

  # Clear all saved names
  observeEvent(input$clear_saved, {
    showModal(modalDialog(
      title = "Confirm Clear All",
      "Are you sure you want to clear all saved names? This action cannot be undone.",
      footer = tagList(
        modalButton("Cancel"),
        actionButton("confirm_clear", "Yes, Clear All", class = "btn-danger")
      )
    ))
  })
  
  # Confirm clear action
  observeEvent(input$confirm_clear, {
    # Count names being cleared vs kept
    total_count <- nrow(saved_names$data)
    permanent_count <- sum(saved_names$data$Keep_Permanent)
    cleared_count <- total_count - permanent_count

    if (permanent_count > 0) {
      # Keep only permanent names
      saved_names$data <- saved_names$data[saved_names$data$Keep_Permanent == TRUE, ]
      save_saved_names_to_file()

      # Trigger table refresh (full re-render needed)
      saved_names_refresh_trigger(saved_names_refresh_trigger() + 1)

      removeModal()
      showNotification(
        paste("Cleared", cleared_count, "temporary names. Kept", permanent_count, "permanent names."),
        type = "warning",
        duration = 5
      )
    } else {
      # No permanent names - clear everything (original behavior)
      saved_names$data <- data.frame(
        Name = character(0),
        Syllables = character(0),
        Simple_Phonetic = character(0),
        CMU_Arpabet = character(0),
        Origin = character(0),
        Notes = character(0),
        Date_Added = character(0),
        Audio_Path = character(0),
        Keep_Permanent = logical(0),
        stringsAsFactors = FALSE
      )
      save_saved_names_to_file()

      # Trigger table refresh (full re-render needed)
      saved_names_refresh_trigger(saved_names_refresh_trigger() + 1)

      removeModal()
      showNotification("All saved names cleared.", type = "warning")
    }
  })

  # Play cached audio for saved names
  observeEvent(input$play_saved_audio_row, {
    row_index <- input$play_saved_audio_row + 1  # Convert from 0-based to 1-based indexing

    if (nrow(saved_names$data) > 0 && row_index <= nrow(saved_names$data)) {
      # Backward compatibility: Check if Audio_Path column exists
      audio_path <- if ("Audio_Path" %in% names(saved_names$data)) {
        saved_names$data$Audio_Path[row_index]
      } else {
        ""
      }

      phonetic <- saved_names$data$Simple_Phonetic[row_index]
      name <- saved_names$data$Name[row_index]

      # If we have a cached audio file, play it
      if (!is.null(audio_path) && audio_path != "" && !is.na(audio_path) && file.exists(audio_path)) {
        tryCatch({
          # Read audio file and convert to base64
          audio_data <- base64enc::base64encode(audio_path)

          # Send to JavaScript for playback
          session$sendCustomMessage(
            "playAudioBase64",
            list(data = audio_data, format = "mp3")
          )
        }, error = function(e) {
          # If there's an error reading cached audio, fall back to Standard Voice via JavaScript
          session$sendCustomMessage(
            "playSavedNameFallback",
            list(phonetic = phonetic)
          )
          showNotification(
            paste("Cached audio unavailable, using Standard Voice for", name),
            type = "warning",
            duration = 2
          )
        })
      } else {
        # No cached audio - fall back to Standard Voice via JavaScript
        session$sendCustomMessage(
          "playSavedNameFallback",
          list(phonetic = phonetic)
        )
      }
    }
  })

  # Delete individual saved name row
  observeEvent(input$delete_saved_row, {
    row_index <- input$delete_saved_row + 1  # Convert from 0-based to 1-based indexing

    if (nrow(saved_names$data) > 0 && row_index <= nrow(saved_names$data)) {
      deleted_name <- saved_names$data$Name[row_index]
      saved_names$data <- saved_names$data[-row_index, ]

      # Persist to file
      save_saved_names_to_file()

      # Trigger table refresh (full re-render needed for deleted row)
      saved_names_refresh_trigger(saved_names_refresh_trigger() + 1)

      showNotification(
        paste("Deleted:", deleted_name),
        type = "message",
        duration = 3
      )
    }
  })

  # Toggle "Keep Permanent" flag for a saved name
  observeEvent(input$toggle_permanent_row, {
    row_index <- input$toggle_permanent_row + 1  # Convert from 0-based to 1-based indexing

    if (nrow(saved_names$data) > 0 && row_index <= nrow(saved_names$data)) {
      # Toggle the flag
      current_value <- saved_names$data$Keep_Permanent[row_index]
      saved_names$data$Keep_Permanent[row_index] <- !current_value

      # Persist immediately
      save_saved_names_to_file()

      # Use DT proxy to update table without resetting pagination
      proxy <- DT::dataTableProxy('saved_names_table')

      # Rebuild table data with updated buttons (same logic as renderDataTable)
      table_data <- saved_names$data

      # Backward compatibility: Add Audio_Path column if it doesn't exist
      if (!"Audio_Path" %in% names(table_data)) {
        table_data$Audio_Path <- as.character(rep("", nrow(table_data)))
      }

      # Create audio buttons
      table_data$Audio <- mapply(function(row_index, name, phonetic, audio_path) {
        paste0('<button class="btn btn-sm btn-primary play-saved-audio" data-row="',
               row_index - 1,
               '" data-name="', name,
               '" data-phonetic="', phonetic,
               '" data-has-cache="', ifelse(audio_path != "" && !is.na(audio_path), "true", "false"),
               '" style="padding: 2px 8px;"><i class="fa fa-volume-up"></i></button>')
      }, 1:nrow(table_data), table_data$Name, table_data$Simple_Phonetic, table_data$Audio_Path, USE.NAMES = FALSE)

      # Add Keep Permanent star icon column
      table_data$Keep <- mapply(function(row_index, is_permanent) {
        icon_class <- ifelse(is_permanent, "fa-star", "fa-star-o")
        icon_color <- ifelse(is_permanent, "gold", "gray")
        paste0('<button class="btn btn-sm toggle-permanent" data-row="',
               row_index - 1,
               '" style="padding: 2px 8px; background: transparent; border: none;">',
               '<i class="fa ', icon_class, '" style="color: ', icon_color, '; font-size: 16px;"></i>',
               '</button>')
      }, 1:nrow(table_data), table_data$Keep_Permanent, USE.NAMES = FALSE)

      # Add Delete column
      table_data$Delete <- sapply(1:nrow(table_data), function(i) {
        paste0('<button class="btn btn-sm btn-danger delete-saved-name" data-row="',
               i - 1,
               '" style="padding: 2px 8px;"><i class="fa fa-trash"></i></button>')
      })

      # Remove internal columns
      table_data <- table_data[, !names(table_data) %in% c("Audio_Path", "Keep_Permanent")]

      # Replace data while preserving pagination state
      DT::replaceData(proxy, table_data, resetPaging = FALSE, rownames = FALSE)

      # Show notification
      name <- saved_names$data$Name[row_index]
      if (saved_names$data$Keep_Permanent[row_index]) {
        showNotification(
          paste("Marked", name, "as permanent (will survive Clear All)"),
          type = "message",
          duration = 3
        )
      } else {
        showNotification(
          paste("Unmarked", name, "(will be cleared with Clear All)"),
          type = "message",
          duration = 3
        )
      }
    }
  })

  # ============================================================================
  # BULK UPLOAD OBSERVERS
  # ============================================================================

  # Observer for file upload and processing
  observeEvent(input$process_bulk, {
    req(input$bulk_file)

    # Show progress
    withProgress(message = 'Processing names...', value = 0, {

      # Get file info
      file_info <- input$bulk_file
      file_path <- file_info$datapath
      file_ext <- tolower(tools::file_ext(file_info$name))

      # Parse file
      incProgress(0.2, detail = "Reading file")
      parsed <- parse_bulk_file(file_path, file_ext)

      if (!parsed$success) {
        output$bulk_status <- renderUI({
          tags$div(
            class = "alert alert-danger",
            icon("exclamation-triangle"),
            " Error: ", parsed$error
          )
        })
        bulk_results$has_data <- FALSE
        return()
      }

      # Process names
      incProgress(0.3, detail = paste("Processing", length(parsed$names), "names"))

      results_df <- process_bulk_names(parsed$names, parsed$origins, parsed$notes)

      incProgress(0.9, detail = "Finalizing")

      # Store results
      bulk_results$data <- results_df
      bulk_results$has_data <- TRUE

      # Success message
      output$bulk_status <- renderUI({
        tags$div(
          class = "alert alert-success",
          icon("check-circle"),
          sprintf(" Successfully processed %d names!", nrow(results_df))
        )
      })
    })
  })

  # Render preview table
  output$bulk_preview_table <- DT::renderDataTable({
    req(bulk_results$data)

    DT::datatable(
      bulk_results$data,
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        dom = 'frtip'
      ),
      rownames = FALSE
    )
  })

  # Output flag for conditional panel
  output$bulk_has_results <- reactive({
    bulk_results$has_data
  })
  outputOptions(output, "bulk_has_results", suspendWhenHidden = FALSE)

  # Download PDF handler
  output$download_pdf <- downloadHandler(
    filename = function() {
      paste0("name_pronunciation_guide_", Sys.Date(), ".pdf")
    },

    content = function(file) {
      req(bulk_results$data)

      tryCatch({
        # Create PDF with Cairo device for proper Unicode/IPA support
        cairo_pdf(file, width = 11, height = 8.5, family = "sans")  # Letter size landscape

        # Title
        grid.newpage()
        grid.text(
          "Student Name Pronunciation Guide",
          x = 0.5, y = 0.95,
          gp = gpar(fontsize = 20, fontface = "bold")
        )

        grid.text(
          paste("Generated:", Sys.Date()),
          x = 0.5, y = 0.91,
          gp = gpar(fontsize = 10, col = "gray40")
        )

        # Prepare table data
        table_data <- bulk_results$data[, c("Name", "Simple_Phonetic", "IPA", "Origin", "Notes")]
        colnames(table_data) <- c("Student Name", "Phonetic Guide", "IPA Notation", "Origin/Language", "Notes")

        # Create table using gridExtra
        table_grob <- gridExtra::tableGrob(
          table_data,
          rows = NULL,
          theme = gridExtra::ttheme_default(
            base_size = 10,
            core = list(
              fg_params = list(hjust = 0, x = 0.1),
              bg_params = list(fill = c("white", "gray95"))
            ),
            colhead = list(
              fg_params = list(fontface = "bold"),
              bg_params = list(fill = "steelblue", col = "white")
            )
          )
        )

        # Draw table
        grid.draw(table_grob)

        # Footer note
        grid.text(
          "Remember: Always ask students how they prefer their name pronounced!",
          x = 0.5, y = 0.05,
          gp = gpar(fontsize = 9, fontface = "italic", col = "gray40")
        )

        dev.off()

      }, error = function(e) {
        showNotification(
          paste("Error generating PDF:", e$message),
          type = "error",
          duration = 10
        )
      })
    }
  )

  # Download CSV handler
  output$download_csv <- downloadHandler(
    filename = function() {
      paste0("name_pronunciation_guide_", Sys.Date(), ".csv")
    },

    content = function(file) {
      req(bulk_results$data)

      tryCatch({
        # Prepare data for CSV
        csv_data <- bulk_results$data[, c("Name", "Simple_Phonetic", "IPA", "Origin", "Notes")]
        colnames(csv_data) <- c("Student Name", "Phonetic Guide", "IPA Notation", "Origin/Language", "Notes")

        # Write CSV
        write.csv(csv_data, file, row.names = FALSE)

      }, error = function(e) {
        showNotification(
          paste("Error generating CSV:", e$message),
          type = "error",
          duration = 10
        )
      })
    }
  )

  # Download template CSV handler
  output$download_template <- downloadHandler(
    filename = function() {
      "name_list_template.csv"
    },

    content = function(file) {
      # Create sample template data
      template_data <- data.frame(
        Name = c("Siobhan", "José", "Wei", "Nguyen", "Giuseppe"),
        Origin = c("Irish", "Spanish", "Chinese", "Vietnamese", "Italian"),
        Notes = c("Prefers 'Shiv'", "Pronounces it Spanish way", "Goes by 'William'", "First name, not last", "Prefers 'Joe'"),
        stringsAsFactors = FALSE
      )

      # Write to CSV
      write.csv(template_data, file, row.names = FALSE)
    }
  )

  # Download Saved Names as PDF
  output$download_saved_pdf <- downloadHandler(
    filename = function() {
      paste0("saved_names_", Sys.Date(), ".pdf")
    },

    content = function(file) {
      req(nrow(saved_names$data) > 0)

      tryCatch({
        # Create PDF with Cairo device for proper Unicode/IPA support
        cairo_pdf(file, width = 11, height = 8.5, family = "sans")  # Letter size landscape

        # Title
        grid.newpage()
        grid.text(
          "Saved Student Names - Pronunciation Guide",
          x = 0.5, y = 0.95,
          gp = gpar(fontsize = 20, fontface = "bold")
        )

        grid.text(
          paste("Generated:", Sys.Date()),
          x = 0.5, y = 0.91,
          gp = gpar(fontsize = 10, col = "gray40")
        )

        # Prepare table data
        table_data <- saved_names$data[, c("Name", "Simple_Phonetic", "Origin", "Notes")]
        colnames(table_data) <- c("Student Name", "Phonetic Guide", "Origin/Language", "Notes")

        # Create table using gridExtra
        table_grob <- gridExtra::tableGrob(
          table_data,
          rows = NULL,
          theme = gridExtra::ttheme_default(
            base_size = 10,
            core = list(
              fg_params = list(hjust = 0, x = 0.1),
              bg_params = list(fill = c("white", "gray95"))
            ),
            colhead = list(
              fg_params = list(fontface = "bold"),
              bg_params = list(fill = "steelblue", col = "white")
            )
          )
        )

        # Draw table
        grid.draw(table_grob)

        # Footer note
        grid.text(
          "Remember: Always ask students how they prefer their name pronounced!",
          x = 0.5, y = 0.05,
          gp = gpar(fontsize = 9, fontface = "italic", col = "gray40")
        )

        dev.off()

      }, error = function(e) {
        showNotification(
          paste("Error generating PDF:", e$message),
          type = "error",
          duration = 10
        )
      })
    }
  )

  # Download Saved Names as CSV
  output$download_saved_csv <- downloadHandler(
    filename = function() {
      paste0("saved_names_", Sys.Date(), ".csv")
    },

    content = function(file) {
      req(nrow(saved_names$data) > 0)

      tryCatch({
        # Prepare data for CSV
        csv_data <- saved_names$data[, c("Name", "Simple_Phonetic", "Origin", "Notes", "Date_Added")]
        colnames(csv_data) <- c("Student Name", "Phonetic Guide", "Origin/Language", "Notes", "Date Added")

        # Write CSV
        write.csv(csv_data, file, row.names = FALSE)

      }, error = function(e) {
        showNotification(
          paste("Error generating CSV:", e$message),
          type = "error",
          duration = 10
        )
      })
    }
  )

  # Observer for saving bulk results to Saved Names
  observeEvent(input$save_bulk_to_saved, {
    req(bulk_results$data)

    tryCatch({
      results <- bulk_results$data
      added_count <- 0
      audio_cached_count <- 0

      # Check if ElevenLabs is configured
      api_key <- input$elevenlabs_api_key
      voice_id <- input$elevenlabs_voice_id
      has_elevenlabs <- !is.null(api_key) && api_key != "" && !is.na(api_key) &&
                        !is.null(voice_id) && voice_id != "" && !is.na(voice_id)

      # Show progress bar
      withProgress(message = 'Saving names...', value = 0, {
        total_names <- nrow(results)

        # Convert to saved_names format
        for (i in 1:nrow(results)) {
          # Update progress
          incProgress(1/total_names, detail = paste("Processing", results$Name[i]))

          # Use notes from bulk upload if provided, otherwise blank
          notes_value <- if (!is.null(results$Notes[i]) && results$Notes[i] != "") {
            results$Notes[i]
          } else {
            ""
          }

          new_row <- data.frame(
            Name = as.character(results$Name[i]),
            Syllables = as.character(results$Syllables[i]),
            Simple_Phonetic = as.character(results$Simple_Phonetic[i]),
            Origin = as.character(results$Origin[i]),
            Notes = as.character(notes_value),
            Date_Added = as.character(Sys.Date()),
            Audio_Path = "",  # Will be populated if audio is cached
            Keep_Permanent = FALSE,  # Bulk uploads default to temporary
            stringsAsFactors = FALSE
          )

          # Check for duplicates
          if (nrow(saved_names$data) > 0) {
            existing_names <- tolower(saved_names$data$Name)
            if (tolower(new_row$Name) %in% existing_names) {
              # Skip duplicate
              next
            }
          }

          # Pre-cache ElevenLabs audio if configured
          if (has_elevenlabs) {
            audio_result <- tryCatch({
              generate_premium_audio(
                name = results$Name[i],
                phonetic_text = results$Simple_Phonetic[i],
                api_key = api_key,
                voice_id = voice_id,
                speed = 1.0,
                ipa = if (!is.null(results$IPA[i]) && results$IPA[i] != "") results$IPA[i] else NULL
              )
            }, error = function(e) {
              list(success = FALSE)
            })

            if (!is.null(audio_result) && audio_result$success) {
              new_row$Audio_Path <- audio_result$audio_path
              audio_cached_count <- audio_cached_count + 1
            }
          }

          # Add to saved names
          if (nrow(saved_names$data) == 0) {
            saved_names$data <- new_row
          } else {
            # MIGRATION: Add Audio_Path column to existing data if it doesn't exist
            if (!"Audio_Path" %in% names(saved_names$data)) {
              # Properly initialize as character vector with no width limit
              saved_names$data$Audio_Path <- as.character(rep("", nrow(saved_names$data)))
            }
            # Use rbind with make.row.names=FALSE and stringsAsFactors=FALSE to avoid issues
            saved_names$data <- rbind(saved_names$data, new_row, stringsAsFactors = FALSE, make.row.names = FALSE)
          }
          added_count <- added_count + 1
        }
      })

      # Persist to file
      save_saved_names_to_file()

      # Trigger table refresh (full re-render needed for new rows)
      saved_names_refresh_trigger(saved_names_refresh_trigger() + 1)

      # Show completion notification
      audio_msg <- if (has_elevenlabs) {
        paste0(" (", audio_cached_count, " with ElevenLabs audio)")
      } else {
        " (configure ElevenLabs in Settings for better audio)"
      }

      showNotification(
        paste0("Added ", added_count, " names to Saved Names", audio_msg, " - duplicates skipped"),
        type = "message",
        duration = 5
      )

    }, error = function(e) {
      showNotification(
        paste("Error saving names:", e$message),
        type = "error"
      )
    })
  })

  # Observer for clearing bulk upload results
  observeEvent(input$clear_bulk_results, {
    # Reset bulk results
    bulk_results$data <- NULL
    bulk_results$has_data <- FALSE

    # Clear status message
    output$bulk_status <- renderUI({
      NULL
    })

    # Show notification
    showNotification(
      "Bulk upload results cleared. Ready for new upload.",
      type = "message",
      duration = 3
    )
  })
}

# Run the application
shinyApp(ui = ui, server = server)