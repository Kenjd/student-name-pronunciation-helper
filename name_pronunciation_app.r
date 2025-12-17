

# Required Libraries
library(shiny)
library(shinydashboard)
library(DT)
library(jsonlite)
library(base64enc)  # For encoding audio files

# Language-specific phonetic conversion functions

# Irish (Gaelic) phonetic rules
# Returns BOTH standard and premium voice optimized spellings
apply_irish_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE IRISH NAME DICTIONARY
  # Each entry: standard = browser TTS optimized, premium = Fish Audio optimized
  # Standard: natural flow, minimal hyphens | Premium: clear syllable breaks

  irish_dictionary <- list(
    # Common Female Names
    "siobhan" = list(standard = "shevawn", premium = "she-vawn", ipa = "ʃɪˈvɔːn"),
    "saoirse" = list(standard = "seersha", premium = "seer-sha", ipa = "ˈsɪərʃə"),
    "niamh" = list(standard = "neev", premium = "neev"),
    "aoife" = list(standard = "eefa", premium = "ee-fa"),
    "caoimhe" = list(standard = "keeva", premium = "kee-va"),
    "sinead" = list(standard = "shinaid", premium = "shi-nade"),
    "roisin" = list(standard = "rosheen", premium = "ro-sheen"),
    "aisling" = list(standard = "ashling", premium = "ash-ling"),
    "ciara" = list(standard = "keera", premium = "keer-a"),
    "grainne" = list(standard = "grawnye", premium = "grawn-ya"),
    "orla" = list(standard = "orla", premium = "or-la"),
    "maeve" = list(standard = "mayve", premium = "mayve"),
    "brigid" = list(standard = "breejid", premium = "bree-jid"),
    "eimear" = list(standard = "eemer", premium = "ee-mer"),
    "clodagh" = list(standard = "cloda", premium = "klo-da"),
    "mairead" = list(standard = "maraid", premium = "ma-raid"),
    "nuala" = list(standard = "noola", premium = "noo-la"),
    "oonagh" = list(standard = "oona", premium = "oo-na"),
    "deirdre" = list(standard = "deerdra", premium = "deer-dra"),
    "sorcha" = list(standard = "sorka", premium = "sor-ka"),
    "treasa" = list(standard = "trassa", premium = "tras-sa"),
    "fionnuala" = list(standard = "finnoola", premium = "fin-noo-la"),
    "sadhbh" = list(standard = "sive", premium = "sive"),
    "orlaith" = list(standard = "orla", premium = "or-la"),
    "meadhbh" = list(standard = "mayve", premium = "mayve"),
    "brid" = list(standard = "breed", premium = "breed"),
    "siofra" = list(standard = "sheefra", premium = "shee-fra"),
    "laoise" = list(standard = "leesha", premium = "lee-sha"),
    "muireann" = list(standard = "mweerun", premium = "mweer-an"),

    # Common Male Names
    "cian" = list(standard = "keeun", premium = "kee-an"),
    "eoin" = list(standard = "owen", premium = "oh-in"),
    "tadgh" = list(standard = "tieg", premium = "tie-g"),
    "tadhg" = list(standard = "tieg", premium = "tie-g"),
    "oisin" = list(standard = "usheen", premium = "uh-sheen"),
    "niall" = list(standard = "nile", premium = "nile"),
    "padraig" = list(standard = "pawdrig", premium = "paw-drig"),
    "seamus" = list(standard = "shaymuss", premium = "shay-mus"),
    "ciaran" = list(standard = "keerun", premium = "keer-an"),
    "darragh" = list(standard = "darra", premium = "dar-ra"),
    "ronan" = list(standard = "ronan", premium = "ro-nan"),
    "colm" = list(standard = "collum", premium = "col-um"),
    "cathal" = list(standard = "cahal", premium = "ka-hal"),
    "fionn" = list(standard = "finn", premium = "finn"),
    "cormac" = list(standard = "cormack", premium = "cor-mack"),
    "donal" = list(standard = "donal", premium = "do-nal"),
    "fergal" = list(standard = "fergul", premium = "fer-gal"),
    "killian" = list(standard = "killian", premium = "kill-ian"),
    "lorcan" = list(standard = "lorkan", premium = "lor-kan"),
    "micheal" = list(standard = "meehawl", premium = "mee-hawl"),
    "ruairi" = list(standard = "rory", premium = "rory"),
    "ruaidri" = list(standard = "rory", premium = "rory"),
    "sean" = list(standard = "shawn", premium = "shawn"),
    "declan" = list(standard = "decklan", premium = "deck-lan"),
    "aidan" = list(standard = "ayden", premium = "ay-den"),
    "brendan" = list(standard = "brendan", premium = "bren-dan"),
    "conor" = list(standard = "conner", premium = "con-ner"),
    "liam" = list(standard = "leeam", premium = "lee-am"),
    "fiachra" = list(standard = "feekra", premium = "fee-kra"),
    "diarmuid" = list(standard = "deermid", premium = "deer-mid"),
    "eoghan" = list(standard = "owen", premium = "oh-an"),
    "donnacha" = list(standard = "dunnaka", premium = "dun-na-ka"),
    "cillian" = list(standard = "killian", premium = "kill-ian", ipa = "ˈkɪliən")
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

  return(list(standard = result_standard, premium = result_premium, from_dictionary = FALSE))
}

# Nigerian phonetic rules (Igbo, Yoruba, Hausa)
# Returns BOTH standard and premium voice optimized spellings
apply_nigerian_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE NIGERIAN NAME DICTIONARY
  # Covers Igbo, Yoruba, and Hausa names
  nigerian_dictionary <- list(
    # Igbo Names (Female)
    "chioma" = list(standard = "chyohma", premium = "chyoh-ma", ipa = "tʃjɔma"),
    "adaeze" = list(standard = "adayzay", premium = "a-day-zay", ipa = "adaeze"),
    "chiamaka" = list(standard = "chyahmaka", premium = "chyah-ma-ka", ipa = "tʃjamaka"),
    "chinwe" = list(standard = "cheenweh", premium = "cheen-weh", ipa = "tʃinwe"),
    "ngozi" = list(standard = "engohzee", premium = "en-goh-zee", ipa = "ŋɔzi"),
    "ifeoma" = list(standard = "eefeohma", premium = "ee-feh-oh-ma", ipa = "ifeɔma"),
    "uchenna" = list(standard = "oochayna", premium = "oo-chen-na", ipa = "utʃena"),
    "chidinma" = list(standard = "cheedeenma", premium = "chee-deen-ma", ipa = "tʃidinma"),
    "obioma" = list(standard = "obeohma", premium = "oh-bee-oh-ma", ipa = "ɔbjɔma"),
    "amara" = list(standard = "amara", premium = "a-ma-ra", ipa = "amara"),
    "ebele" = list(standard = "ehbehleh", premium = "eh-beh-leh", ipa = "ebele"),
    "nkechi" = list(standard = "enkaychee", premium = "en-kay-chee", ipa = "ŋketʃi"),
    "adanna" = list(standard = "adahna", premium = "a-dah-na", ipa = "adana"),
    "ifunanya" = list(standard = "eefoonanya", premium = "ee-foo-nan-ya", ipa = "ifunanja"),

    # Igbo Names (Male)
    "chukwudi" = list(standard = "chookwoodee", premium = "chook-woo-dee", ipa = "tʃukwudi"),
    "chukwuemeka" = list(standard = "chookwooaymeka", premium = "chook-woo-ay-me-ka", ipa = "tʃukwuemeka"),
    "chibuike" = list(standard = "cheebueekey", premium = "chee-boo-ee-kay", ipa = "tʃibuike"),
    "emeka" = list(standard = "aymeka", premium = "ay-me-ka", ipa = "emeka"),
    "nnamdi" = list(standard = "namdee", premium = "nam-dee", ipa = "nːamdi"),
    "obinna" = list(standard = "obeena", premium = "oh-bee-na", ipa = "ɔbina"),
    "ikenna" = list(standard = "eekena", premium = "ee-ken-na", ipa = "ikena"),
    "chinedu" = list(standard = "cheenaydoo", premium = "chee-nay-doo", ipa = "tʃinedu"),
    "kelechi" = list(standard = "kelaychee", premium = "keh-lay-chee", ipa = "keletʃi"),
    "onyekachi" = list(standard = "onyehkachee", premium = "on-yeh-ka-chee", ipa = "ɔɲekatʃi"),

    # Yoruba Names (Female)
    "adeola" = list(standard = "ahdayohla", premium = "ah-day-oh-la", ipa = "adeɔla"),
    "oluwaseun" = list(standard = "ohloowashaw", premium = "oh-loo-wa-shay", ipa = "ɔluwaʃeun"),
    "ayodele" = list(standard = "ahyohdaylay", premium = "ah-yoh-day-lay", ipa = "ajɔdele"),
    "olufunke" = list(standard = "ohloofoonkay", premium = "oh-loo-foon-kay", ipa = "ɔlufunke"),
    "titilayo" = list(standard = "teeteelahyoh", premium = "tee-tee-lah-yoh", ipa = "titilajɔ"),
    "abimbola" = list(standard = "abeembohla", premium = "ah-beem-boh-la", ipa = "abimbɔla"),
    "folake" = list(standard = "fohlahkay", premium = "foh-lah-kay", ipa = "fɔlake"),
    "yetunde" = list(standard = "yehtoonday", premium = "yeh-toon-day", ipa = "jetunde"),

    # Yoruba Names (Male)
    "oluwaseyi" = list(standard = "ohloowashayee", premium = "oh-loo-wa-shay-ee", ipa = "ɔluwaʃeji"),
    "olumide" = list(standard = "ohloomeeday", premium = "oh-loo-mee-day", ipa = "ɔlumide"),
    "babatunde" = list(standard = "babatoonday", premium = "ba-ba-toon-day", ipa = "babatunde"),
    "oluwafemi" = list(standard = "ohloowafaymee", premium = "oh-loo-wa-fay-mee", ipa = "ɔluwafemi"),
    "adekunle" = list(standard = "ahdaykoonlay", premium = "ah-day-koon-lay", ipa = "adekunle"),
    "temitope" = list(standard = "tehmehtohpay", premium = "teh-mee-toh-pay", ipa = "temitɔpe"),
    "adewale" = list(standard = "ahdaywalay", premium = "ah-day-wa-lay", ipa = "adewale"),

    # Hausa Names
    "aisha" = list(standard = "eyeesha", premium = "eye-ee-sha", ipa = "aiʃa"),
    "fatima" = list(standard = "fahteema", premium = "fah-tee-ma", ipa = "fatima"),
    "zainab" = list(standard = "zaynahb", premium = "zay-nab", ipa = "zainab"),
    "halima" = list(standard = "hahleema", premium = "hah-lee-ma", ipa = "halima"),
    "muhammad" = list(standard = "moohammad", premium = "moo-ha-mad", ipa = "muhamːad"),
    "ibrahim" = list(standard = "ibraheam", premium = "ib-ra-heem", ipa = "ibrahim"),
    "usman" = list(standard = "oosman", premium = "oos-man", ipa = "usman"),
    "abdullahi" = list(standard = "abdoolahee", premium = "ab-doo-lah-hee", ipa = "abdulːahi")
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

  return(list(standard = result_standard, premium = result_premium, from_dictionary = FALSE))
}

# Indian phonetic rules (Hindi, Tamil, Telugu, Punjabi, Sanskrit)
# Returns BOTH standard and premium voice optimized spellings
apply_indian_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE INDIAN NAME DICTIONARY
  # Covers Hindi, Tamil, Telugu, Punjabi, and Sanskrit origin names
  indian_dictionary <- list(
    # Hindi/Sanskrit Names (Female)
    "priya" = list(standard = "preeya", premium = "pree-ya", ipa = "prijɑː"),
    "ananya" = list(standard = "uhnunya", premium = "uh-nun-ya", ipa = "ənənjɑː"),
    "kavya" = list(standard = "kahvya", premium = "kahv-ya", ipa = "kɑːvjɑː"),
    "diya" = list(standard = "deeya", premium = "dee-ya", ipa = "diːjɑː"),
    "ishita" = list(standard = "isheetah", premium = "ish-ee-tah", ipa = "iʃitɑː"),
    "aanya" = list(standard = "aanya", premium = "aan-ya", ipa = "ɑːnjɑː"),
    "siya" = list(standard = "seeya", premium = "see-ya", ipa = "siːjɑː"),
    "pari" = list(standard = "paree", premium = "pa-ree", ipa = "pɑriː"),
    "anaya" = list(standard = "uhnaya", premium = "uh-na-ya", ipa = "ənɑjɑː"),
    "saanvi" = list(standard = "sahnvee", premium = "sahn-vee", ipa = "sɑːnviː"),
    "navya" = list(standard = "nahvya", premium = "nahv-ya", ipa = "nɑvjɑː"),
    "riya" = list(standard = "reeya", premium = "ree-ya", ipa = "riːjɑː"),
    "aaradhya" = list(standard = "arahdhya", premium = "aa-rahd-hya", ipa = "ɑːrɑdʰjɑː"),
    "myra" = list(standard = "myra", premium = "my-ra", ipa = "mairɑː"),
    "kiara" = list(standard = "keeara", premium = "kee-aa-ra", ipa = "kiːɑːrɑː"),
    "aditi" = list(standard = "uhditee", premium = "uh-di-tee", ipa = "əditiː"),
    "nisha" = list(standard = "neeshuh", premium = "nee-sha", ipa = "niːʃɑː"),
    "pooja" = list(standard = "poojah", premium = "poo-jah", ipa = "puːdʒɑː"),
    "sneha" = list(standard = "snayha", premium = "snay-ha", ipa = "sneːhɑː"),
    "shreya" = list(standard = "shrayah", premium = "shray-ah", ipa = "ʃrejɑː"),

    # Hindi/Sanskrit Names (Male)
    "aarav" = list(standard = "ahrahv", premium = "aa-rahv", ipa = "ɑːrɑv"),
    "arjun" = list(standard = "arjoon", premium = "ar-joon", ipa = "ɑrdʒun"),
    "rohan" = list(standard = "rohun", premium = "ro-hun", ipa = "roːhən"),
    "aditya" = list(standard = "uhditya", premium = "uh-dit-ya", ipa = "əditjɑː"),
    "ishaan" = list(standard = "eeshahn", premium = "ee-shaan", ipa = "iːʃɑːn"),
    "vivaan" = list(standard = "vivahn", premium = "vi-vaan", ipa = "vivɑːn"),
    "ayaan" = list(standard = "eyahn", premium = "ay-aan", ipa = "əjɑːn"),
    "aryan" = list(standard = "ahryan", premium = "ahr-yan", ipa = "ɑːrjən"),
    "reyansh" = list(standard = "rayunsh", premium = "ray-unsh", ipa = "rejənʃ"),
    "shaurya" = list(standard = "shaurya", premium = "shaur-ya", ipa = "ʃɔːrjɑː"),
    "atharv" = list(standard = "uhtuhrv", premium = "uh-tuhrv", ipa = "ətʰərv"),
    "vihaan" = list(standard = "veehahn", premium = "vee-haan", ipa = "viːhɑːn"),
    "arnav" = list(standard = "ahrnuv", premium = "ahr-nuv", ipa = "ɑrnəv"),
    "sai" = list(standard = "sigh", premium = "sigh", ipa = "saːi"),
    "krishna" = list(standard = "krishnuh", premium = "krish-na", ipa = "krɪʃnə"),
    "dev" = list(standard = "dave", premium = "dave", ipa = "deːv"),
    "raj" = list(standard = "rahj", premium = "rahj", ipa = "rɑːdʒ"),
    "aniket" = list(standard = "uhneekayt", premium = "uh-nee-kayt", ipa = "ənikeːt"),
    "rahul" = list(standard = "rahool", premium = "ra-hool", ipa = "rɑhuːl"),
    "amit" = list(standard = "uhmeet", premium = "uh-meet", ipa = "əmit"),

    # Tamil Names
    "arun" = list(standard = "ahroon", premium = "ah-roon", ipa = "ərun"),
    "deepak" = list(standard = "deepuhk", premium = "dee-puhk", ipa = "diːpək"),
    "ganesh" = list(standard = "guhnaysh", premium = "guh-naysh", ipa = "gəneːʃ"),
    "karthik" = list(standard = "kartik", premium = "kar-tik", ipa = "kɑrtik"),
    "lakshmi" = list(standard = "lukshmi", premium = "luksh-mi", ipa = "ləkʃmiː"),
    "meera" = list(standard = "meera", premium = "mee-ra", ipa = "miːrɑː"),
    "selvi" = list(standard = "selvee", premium = "sel-vee", ipa = "selviː"),
    "tamil" = list(standard = "tahmil", premium = "tah-mil", ipa = "təmil"),

    # Telugu Names
    "srinivas" = list(standard = "shreeneevahs", premium = "shree-nee-vahs", ipa = "ʃriːnivɑːs"),
    "venkat" = list(standard = "venkaht", premium = "ven-kaht", ipa = "veŋkət"),
    "ramya" = list(standard = "rahmya", premium = "rahm-ya", ipa = "rɑmjɑː"),
    "suresh" = list(standard = "suraysh", premium = "su-raysh", ipa = "sureːʃ"),

    # Punjabi Names
    "harpreet" = list(standard = "harpreet", premium = "har-preet", ipa = "hərpriːt"),
    "gurpreet" = list(standard = "gurpreet", premium = "gur-preet", ipa = "gʊrpriːt"),
    "simran" = list(standard = "simrun", premium = "sim-run", ipa = "sɪmrən"),
    "jaspreet" = list(standard = "jaspreet", premium = "jas-preet", ipa = "dʒəspriːt"),
    "manpreet" = list(standard = "manpreet", premium = "man-preet", ipa = "mənpriːt"),
    "navjot" = list(standard = "navjote", premium = "nav-jote", ipa = "nəvdʒoːt"),
    "kuldeep" = list(standard = "kuldeep", premium = "kul-deep", ipa = "kʊldiːp")
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

  return(list(standard = result_standard, premium = result_premium, from_dictionary = FALSE))
}

# Spanish/Latin phonetic rules
# Returns BOTH standard and premium voice optimized spellings
apply_spanish_phonetics <- function(name) {
  result <- tolower(name)

  # COMPREHENSIVE SPANISH/LATIN NAME DICTIONARY
  # Covers Spanish, Mexican, and Latin American names
  spanish_dictionary <- list(
    # Female Names
    "maría" = list(standard = "mahreeah", premium = "mah-ree-ah", ipa = "maˈɾi.a"),
    "maria" = list(standard = "mahreeah", premium = "mah-ree-ah", ipa = "maˈɾi.a"),
    "sofía" = list(standard = "sofeea", premium = "so-fee-ah", ipa = "soˈfi.a"),
    "sofia" = list(standard = "sofeea", premium = "so-fee-ah", ipa = "soˈfi.a"),
    "isabella" = list(standard = "eesahbehya", premium = "ee-sah-beh-yah", ipa = "isaˈβe.ʎa"),
    "valentina" = list(standard = "vahlenteena", premium = "vah-len-tee-nah", ipa = "balenˈti.na"),
    "camila" = list(standard = "kahmeela", premium = "kah-mee-lah", ipa = "kaˈmi.la"),
    "lucía" = list(standard = "looseea", premium = "loo-see-ah", ipa = "luˈθi.a"),
    "lucia" = list(standard = "looseea", premium = "loo-see-ah", ipa = "luˈθi.a"),
    "martina" = list(standard = "marteena", premium = "mar-tee-nah", ipa = "maɾˈti.na"),
    "elena" = list(standard = "ehlehnah", premium = "eh-leh-nah", ipa = "eˈle.na"),
    "valeria" = list(standard = "vahlehreeah", premium = "vah-leh-ree-ah", ipa = "baˈle.ɾja"),
    "daniela" = list(standard = "dahnyehlah", premium = "dah-nyeh-lah", ipa = "daˈnje.la"),
    "gabriela" = list(standard = "gahbreehlah", premium = "gah-bree-eh-lah", ipa = "gaβɾiˈe.la"),
    "victoria" = list(standard = "veektohreeah", premium = "veek-toh-ree-ah", ipa = "bikˈto.ɾja"),
    "emilia" = list(standard = "ehmeelyah", premium = "eh-mee-lyah", ipa = "eˈmi.lja"),
    "carmen" = list(standard = "karmen", premium = "kar-men", ipa = "ˈkaɾ.men"),
    "ana" = list(standard = "ahnah", premium = "ah-nah", ipa = "ˈa.na"),
    "rosa" = list(standard = "rohsah", premium = "roh-sah", ipa = "ˈro.sa"),
    "catalina" = list(standard = "kahtahleena", premium = "kah-tah-lee-nah", ipa = "kataˈli.na"),
    "guadalupe" = list(standard = "gwadahloopay", premium = "gwa-dah-loo-pay", ipa = "gwaðaˈlu.pe"),
    "ximena" = list(standard = "heemehnah", premium = "hee-meh-nah", ipa = "xiˈme.na"),
    "jimena" = list(standard = "heemehnah", premium = "hee-meh-nah", ipa = "xiˈme.na"),

    # Male Names
    "josé" = list(standard = "hoseh", premium = "ho-seh", ipa = "xoˈse"),
    "jose" = list(standard = "hoseh", premium = "ho-seh", ipa = "xoˈse"),
    "juan" = list(standard = "hwahn", premium = "hwahn", ipa = "xwan"),
    "carlos" = list(standard = "karlohs", premium = "kar-lohs", ipa = "ˈkaɾ.los"),
    "miguel" = list(standard = "meegell", premium = "mee-gell", ipa = "miˈɣel"),
    "diego" = list(standard = "deeaygo", premium = "dee-ay-go", ipa = "ˈdje.ɣo"),
    "santiago" = list(standard = "sahntyahgo", premium = "sahn-tyah-go", ipa = "sanˈtja.ɣo"),
    "mateo" = list(standard = "mahtayo", premium = "mah-tay-o", ipa = "maˈte.o"),
    "sebastián" = list(standard = "sehbahstyahn", premium = "seh-bahs-tyahn", ipa = "seβasˈtjan"),
    "sebastian" = list(standard = "sehbahstyahn", premium = "seh-bahs-tyahn", ipa = "seβasˈtjan"),
    "alejandro" = list(standard = "ahlehhandroe", premium = "ah-leh-han-dro", ipa = "aleˈxan.dɾo"),
    "manuel" = list(standard = "mahnwell", premium = "mahn-well", ipa = "maˈnwel"),
    "antonio" = list(standard = "ahntoenyoe", premium = "ahn-toe-nyo", ipa = "anˈto.njo"),
    "francisco" = list(standard = "frahnseeskoe", premium = "frahn-sees-ko", ipa = "fɾanˈθis.ko"),
    "javier" = list(standard = "havyehr", premium = "hav-yehr", ipa = "xaˈβjeɾ"),
    "rafael" = list(standard = "rafahell", premium = "rah-fah-ell", ipa = "rafaˈel"),
    "daniel" = list(standard = "dahnyell", premium = "dah-nyell", ipa = "daˈnjel"),
    "gabriel" = list(standard = "gahbreeell", premium = "gah-bree-ell", ipa = "gaβɾiˈel"),
    "fernando" = list(standard = "fernahndo", premium = "fer-nahn-do", ipa = "feɾˈnan.do"),
    "ricardo" = list(standard = "reekardo", premium = "ree-kar-do", ipa = "riˈkaɾ.ðo"),
    "andrés" = list(standard = "ahndrays", premium = "ahn-drays", ipa = "anˈdɾes"),
    "andres" = list(standard = "ahndrays", premium = "ahn-drays", ipa = "anˈdɾes"),
    "pablo" = list(standard = "pahblo", premium = "pah-blo", ipa = "ˈpa.βlo"),
    "luis" = list(standard = "looees", premium = "loo-ees", ipa = "ˈlu.is"),
    "jorge" = list(standard = "horhay", premium = "hor-hay", ipa = "ˈxoɾ.xe"),
    "pedro" = list(standard = "paydro", premium = "pay-dro", ipa = "ˈpe.ðɾo"),
    "ramón" = list(standard = "rahmohn", premium = "rah-mohn", ipa = "raˈmon"),
    "ramon" = list(standard = "rahmohn", premium = "rah-mohn", ipa = "raˈmon")
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

  return(list(standard = result_standard, premium = result_premium, from_dictionary = FALSE))
}

# Chinese (Pinyin) phonetic rules
apply_chinese_phonetics <- function(name) {
  result <- name
  chinese_patterns <- list(
    "xi" = "shee", "qi" = "chee", "zh" = "j", "q" = "ch",
    "x" = "sh", "c" = "ts", "zh" = "j"
  )
  for (pattern in names(chinese_patterns)[order(nchar(names(chinese_patterns)), decreasing = TRUE)]) {
    result <- gsub(pattern, chinese_patterns[[pattern]], result, ignore.case = TRUE)
  }
  return(result)
}

# Italian phonetic rules
apply_italian_phonetics <- function(name) {
  result <- name
  italian_patterns <- list(
    "ghi" = "ghee", "ghe" = "gay", "chi" = "kee", "che" = "kay",
    "gia" = "jah", "gio" = "joh", "gi" = "jee",
    "gna" = "nyah", "gne" = "nyeh", "gni" = "nyee", "gno" = "nyoh",
    "gli" = "lyee", "glia" = "lyah", "glio" = "lyoh",
    "sc" = "sh", "z" = "ts"
  )
  for (pattern in names(italian_patterns)[order(nchar(names(italian_patterns)), decreasing = TRUE)]) {
    result <- gsub(pattern, italian_patterns[[pattern]], result, ignore.case = TRUE)
  }
  return(result)
}

# French phonetic rules
apply_french_phonetics <- function(name) {
  result <- name
  french_patterns <- list(
    "eau" = "oh", "ou" = "oo", "eu" = "uh", "oi" = "wah",
    "ç" = "s", "ch" = "sh", "gn" = "ny",
    "ille" = "ee", "eille" = "ay",
    "ain" = "an", "ein" = "an", "ien" = "yan"
  )
  for (pattern in names(french_patterns)[order(nchar(names(french_patterns)), decreasing = TRUE)]) {
    result <- gsub(pattern, french_patterns[[pattern]], result, ignore.case = TRUE)
  }
  return(result)
}

# Polish phonetic rules
apply_polish_phonetics <- function(name) {
  result <- name
  polish_patterns <- list(
    "cz" = "ch", "sz" = "sh", "rz" = "zh", "ż" = "zh", "ź" = "zh",
    "ł" = "w", "ć" = "ch", "ń" = "ny", "ś" = "sh"
  )
  for (pattern in names(polish_patterns)[order(nchar(names(polish_patterns)), decreasing = TRUE)]) {
    result <- gsub(pattern, polish_patterns[[pattern]], result, ignore.case = TRUE)
  }
  return(result)
}

# German phonetic rules
apply_german_phonetics <- function(name) {
  result <- name
  german_patterns <- list(
    "sch" = "sh", "ch" = "kh", "ß" = "ss",
    "ä" = "eh", "ö" = "er", "ü" = "oo",
    "ei" = "eye", "ie" = "ee", "eu" = "oy"
  )
  for (pattern in names(german_patterns)[order(nchar(names(german_patterns)), decreasing = TRUE)]) {
    result <- gsub(pattern, german_patterns[[pattern]], result, ignore.case = TRUE)
  }
  return(result)
}

# Function to provide phonetic pronunciation guides
get_pronunciation_guide <- function(name, origin = NULL) {
  # Convert to lowercase for processing
  name_lower <- tolower(trimws(name))

  # Track which method was used for transparency
  method_used <- "generic"
  dictionary_name <- NULL

  # Check if origin-specific rules should be applied
  origin_applied <- FALSE
  phonetic_result <- NULL

  if (!is.null(origin) && origin != "" && origin != "unknown") {
    phonetic_result <- switch(origin,
      "irish" = { origin_applied <- TRUE; apply_irish_phonetics(name_lower) },
      "nigerian" = { origin_applied <- TRUE; apply_nigerian_phonetics(name_lower) },
      "indian" = { origin_applied <- TRUE; apply_indian_phonetics(name_lower) },
      "spanish" = { origin_applied <- TRUE; apply_spanish_phonetics(name_lower) },
      "chinese" = { origin_applied <- TRUE; name_lower },
      "italian" = { origin_applied <- TRUE; name_lower },
      "french" = { origin_applied <- TRUE; name_lower },
      "polish" = { origin_applied <- TRUE; name_lower },
      "german" = { origin_applied <- TRUE; name_lower },
      # If custom origin entered, use generic rules
      name_lower
    )
  }

  # If origin rules were applied and returned dual phonetics
  if (origin_applied && is.list(phonetic_result) && !is.null(phonetic_result$standard)) {
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

    # Check if dictionary provided IPA
    if (!is.null(phonetic_result$ipa)) {
      ipa_phonetic <- phonetic_result$ipa
    } else {
      ipa_phonetic <- create_ipa_phonetic(name_lower)
    }
  } else if (origin_applied && is.character(phonetic_result)) {
    # Old-style single phonetic (other languages not yet updated)
    simple_standard <- toupper(phonetic_result)
    simple_premium <- toupper(phonetic_result)
    method_used <- "pattern"
    dictionary_name <- paste0(toupper(substring(origin, 1, 1)), substring(origin, 2))
    ipa_phonetic <- create_ipa_phonetic(name_lower)
  } else {
    # Use generic phonetic conversion for both
    generic <- create_simple_phonetic(name_lower)
    simple_standard <- generic
    simple_premium <- generic
    method_used <- "generic"
    ipa_phonetic <- create_ipa_phonetic(name_lower)
  }

  return(list(
    simple_standard = simple_standard,
    simple_premium = simple_premium,
    ipa = ipa_phonetic,
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

# Function to add syllable breaks
add_syllable_breaks <- function(name) {
  # Simple syllable detection
  syllables <- gsub("([aeiou])([bcdfghjklmnpqrstvwxyz])([aeiou])", "\\1-\\2\\3", name)
  syllables <- gsub("([bcdfghjklmnpqrstvwxyz])([aeiou])", "\\1\\2", syllables)
  return(toupper(syllables))
}

# Function to detect possible name origin
detect_origin <- function(name) {
  name_lower <- tolower(name)
  
  # Very basic origin detection based on common patterns
  if (grepl("[qx]", name_lower) && grepl("[aeiou]", name_lower)) {
    return("Possibly Chinese/East Asian")
  } else if (grepl("^[aeiou].*[aeiou]$", name_lower)) {
    return("Possibly Italian/Spanish")
  } else if (grepl("sch|tz|berg", name_lower)) {
    return("Possibly German")
  } else if (grepl("ov$|ova$|ski$|sky$", name_lower)) {
    return("Possibly Slavic")
  } else if (grepl("^mc|^mac", name_lower)) {
    return("Possibly Irish/Scottish")
  } else if (grepl("singh|kumar|patel", name_lower)) {
    return("Possibly Indian")
  } else if (grepl("ez$|ez |ez-", name_lower)) {
    return("Possibly Spanish")
  } else {
    return("Origin unclear")
  }
}

# Define UI
ui <- dashboardPage(
  dashboardHeader(title = "Student Name Pronunciation Helper"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Name Lookup", tabName = "lookup", icon = icon("search")),
      menuItem("Saved Names", tabName = "saved", icon = icon("bookmark")),
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

        // Shiny event listener for saved names speaker buttons
        $(document).on('click', '.speak-saved', function() {
          const name = $(this).data('name');
          if (name) {
            speakName(name, globalSpeechSpeed);
          }
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
                                  "Indian (Hindi/Tamil/Punjabi)" = "indian",
                                  "Spanish" = "spanish",
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
                                  "Greek" = "greek",
                                  "Other/Unknown" = "unknown"
                                ),
                                selected = NULL,
                                options = list(
                                  create = TRUE,
                                  placeholder = "Select or type an origin..."
                                )),
                  actionButton("get_pronunciation", "Get Pronunciation", class = "btn-primary"),
                  br(), br(),
                  conditionalPanel(
                    condition = "input.get_pronunciation > 0",
                    h4("Pronunciation Guide:"),
                    verbatimTextOutput("pronunciation_output"),
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
                      textInput("phonetic_override", "Manual Phonetic Override:",
                               placeholder = "e.g., 'seer-sha' or IPA like 'kɪliən'"),
                      helpText("For Standard Voice: use simple spellings like 'kill-ian'. For ElevenLabs Premium: you can use IPA characters. Leave blank to use automatic phonetics.")
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
                  actionButton("clear_saved", "Clear All Saved Names", class = "btn-warning")
                )
              )
      ),

      # Settings tab
      tabItem(tabName = "settings",
              fluidRow(
                box(
                  title = "ElevenLabs API Configuration", status = "warning", solidHeader = TRUE,
                  width = 12,
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
                  title = "How to Use This App", status = "info", solidHeader = TRUE,
                  width = 12,
                  h4("Purpose:"),
                  p("This app helps you learn the pronunciation of student names by providing phonetic guides and origin information."),
                  
                  h4("How it works:"),
                  tags$ol(
                    tags$li("Enter a student's name in the 'Name Lookup' tab"),
                    tags$li(strong("IMPORTANT:"), " Select the name's origin (Irish, Spanish, Chinese, etc.) from the dropdown for accurate pronunciation. You can also type in custom origins not in the list."),
                    tags$li("Click 'Get Pronunciation' to see a phonetic guide"),
                    tags$li("Use the audio pronunciation buttons to hear the name spoken"),
                    tags$li("Review the origin and pronunciation tips"),
                    tags$li("Add your own notes (especially if the student corrects you)"),
                    tags$li("Save the name for future reference")
                  ),
                  
                  h4("Important Notes:"),
                  tags$ul(
                    tags$li(strong("Selecting an origin dramatically improves accuracy!"), " For example, 'Siobhan' with Irish origin → 'SHIV-AWN' (correct), but without origin → 'SEE-OH-BAHN' (incorrect)"),
                    tags$li("The app applies language-specific phonetic rules based on the selected origin (Irish, Spanish, Chinese, Italian, French, Polish, German, and more)"),
                    tags$li("This app provides approximations - always ask students for the correct pronunciation"),
                    tags$li("The phonetic guide uses English sounds and may not capture all nuances"),
                    tags$li("Different cultures may pronounce the same spelling differently"),
                    tags$li("Use this as a starting point, not a definitive answer")
                  ),

                  h4("Audio Pronunciation Features:"),
                  tags$ul(
                    tags$li(strong("Standard Voice:"), " Uses your browser's built-in text-to-speech. Free, instant, and works offline. Voice quality depends on your browser and operating system."),
                    tags$li(strong("ElevenLabs Premium:"), " Uses ElevenLabs AI with IPA for highly accurate pronunciation. Sends IPA as plain text, just like pasting it on the ElevenLabs website. Requires API key (configure in Settings tab). Small cost per pronunciation (~$0.00015 per name)."),
                    tags$li(strong("Speed Control:"), " Adjust the pronunciation speed (0.5x to 1.5x) to help with difficult names or practice."),
                    tags$li(strong("Saved Names:"), " Click the speaker icon next to any saved name to hear it pronounced again.")
                  ),

                  h4("Troubleshooting Audio:"),
                  tags$ul(
                    tags$li("If Standard Voice doesn't work, try the ElevenLabs Premium option"),
                    tags$li("Ensure your device volume is turned up"),
                    tags$li("Some browsers may require user interaction before playing audio"),
                    tags$li("ElevenLabs Premium requires API credentials (Settings tab) and internet connection"),
                    tags$li("For best results with Standard Voice, use Chrome, Safari, or Edge"),
                    tags$li("If ElevenLabs fails, check your API key and voice ID in Settings tab"),
                    tags$li("ElevenLabs sends IPA phonetics as plain text - ensure your name's IPA is accurate")
                  ),

                  h4("Best Practices:"),
                  tags$ul(
                    tags$li("Ask students to pronounce their names on the first day"),
                    tags$li("Write down the pronunciation phonetically in your own words"),
                    tags$li("Practice saying the names out loud"),
                    tags$li("Don't be afraid to ask for clarification - students appreciate the effort!")
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

  # Reactive values to store saved names and current pronunciation
  saved_names <- reactiveValues(data = data.frame(
    Name = character(0),
    Syllables = character(0),
    Simple_Phonetic = character(0),
    IPA_Phonetic = character(0),
    Origin = character(0),
    Notes = character(0),
    Date_Added = character(0),
    stringsAsFactors = FALSE
  ))

  # Store current phonetic guide for audio pronunciation
  current_phonetic <- reactiveValues(
    simple_standard = NULL,
    simple_premium = NULL,
    syllables = NULL,
    ipa = NULL,  # IPA phonetic for ElevenLabs
    override = NULL  # Manual override if user provides one
  )

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
  get_cached_audio <- function(name, phonetic = NULL) {
    # Create cache directory in temp
    audio_cache_dir <- file.path(tempdir(), "name_audio_cache")
    if (!dir.exists(audio_cache_dir)) {
      dir.create(audio_cache_dir, showWarnings = FALSE, recursive = TRUE)
    }

    # Create hash of name AND phonetic for consistent filename
    # This ensures different pronunciations of the same name don't collide
    cache_key <- paste0(tolower(trimws(name)), "_", phonetic)
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

  # Helper function: Generate premium audio using ElevenLabs API with SSML phonemes
  generate_premium_audio <- function(name, ipa_phonetic, api_key, voice_id, speed = 1.0) {
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

      # Check cache first (only use cache if speed is default 1.0)
      cache_result <- get_cached_audio(name, ipa_phonetic)
      if (cache_result$cached && abs(speed - 1.0) < 0.01) {
        return(list(
          success = TRUE,
          audio_path = cache_result$path,
          cached = TRUE
        ))
      }

      # Call Python script with IPA phonetic and API credentials
      # Arguments: name, ipa_phonetic, api_key, voice_id, output_path, speed
      # Set PYTHONIOENCODING to ensure UTF-8 handling for IPA characters
      result <- system2(
        "/opt/miniconda3/bin/python3",
        args = c(
          shQuote(py_script),
          shQuote(name),
          shQuote(ipa_phonetic),
          shQuote(api_key),
          shQuote(voice_id),
          shQuote(cache_result$path),
          as.character(speed)
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

    output$pronunciation_output <- renderText({
      # Create method indicator
      method_indicator <- switch(pronunciation_guide$method_used,
        "dictionary" = paste0("✓ Found in ", pronunciation_guide$dictionary_name, " Dictionary"),
        "pattern" = paste0("⚠ Using ", pronunciation_guide$dictionary_name, " pattern-based rules (not in dictionary)"),
        "generic" = "⚠ Using generic phonetics (no origin selected)"
      )

      paste(
        "Original name:", name,
        paste0("Method: ", method_indicator),
        "\nWith syllable breaks:", pronunciation_guide$syllables,
        "\n\n--- Phonetics for Audio ---",
        "\nFor Standard Voice (Browser TTS):", pronunciation_guide$simple_standard,
        "\nFor ElevenLabs Premium (IPA):", pronunciation_guide$ipa,
        "\n\nNote: ElevenLabs receives the IPA phonetic as plain text for accurate pronunciation.",
        "\n\nPhonetic Key:",
        "AH = 'a' in 'father'  |  EH = 'e' in 'bet'  |  EE = 'ee' in 'see'",
        "OH = 'o' in 'go'  |  OO = 'oo' in 'moon'  |  AY = 'ay' in 'say'",
        "OW = 'ow' in 'cow'  |  CH = 'ch' in 'chair'  |  SH = 'sh' in 'shop'",
        sep = "\n"
      )
    })

    output$origin_output <- renderText({
      if (!is.null(selected_origin) && selected_origin != "" && selected_origin != "unknown") {
        # Show the selected origin
        origin_labels <- c(
          "irish" = "Irish (Gaelic)",
          "spanish" = "Spanish",
          "chinese" = "Chinese (Mandarin)",
          "italian" = "Italian",
          "indian" = "Indian (Hindi/Sanskrit)",
          "french" = "French",
          "german" = "German",
          "polish" = "Polish",
          "vietnamese" = "Vietnamese",
          "arabic" = "Arabic",
          "japanese" = "Japanese",
          "korean" = "Korean",
          "portuguese" = "Portuguese",
          "russian" = "Russian",
          "greek" = "Greek"
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
        detected <- detect_origin(name)
        paste("Auto-detected:", detected, "\n(Tip: Select an origin for better phonetic accuracy)")
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

    # Check for manual override first, otherwise use auto-generated IPA
    if (!is.null(input$phonetic_override) && input$phonetic_override != "") {
      # User provided custom phonetic - use it for ElevenLabs
      ipa_phonetic <- input$phonetic_override
    } else {
      # Use auto-generated IPA phonetic
      ipa_phonetic <- current_phonetic$ipa
    }

    # Validate IPA phonetic
    if (is.null(ipa_phonetic) || ipa_phonetic == "") {
      showNotification("IPA phonetic not available", type = "error")
      return()
    }

    # Get API credentials from settings
    api_key <- input$elevenlabs_api_key
    voice_id <- input$elevenlabs_voice_id

    # Show loading indicator
    showNotification("Generating ElevenLabs pronunciation with IPA...",
                     type = "message",
                     id = "premium_loading",
                     duration = NULL)

    # Generate audio using IPA phonetic with ElevenLabs API
    result <- generate_premium_audio(
      name = name,
      ipa_phonetic = ipa_phonetic,
      api_key = api_key,
      voice_id = voice_id,
      speed = input$premium_speed
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
          "chinese" = "Chinese (Mandarin)",
          "italian" = "Italian",
          "indian" = "Indian (Hindi/Sanskrit)",
          "french" = "French",
          "german" = "German",
          "polish" = "Polish",
          "vietnamese" = "Vietnamese",
          "arabic" = "Arabic",
          "japanese" = "Japanese",
          "korean" = "Korean",
          "portuguese" = "Portuguese",
          "russian" = "Russian",
          "greek" = "Greek"
        )
        display <- origin_labels[selected_origin]
        if (is.na(display)) selected_origin else display
      } else {
        detect_origin(name)
      }

      notes <- if(is.null(input$pronunciation_notes) || input$pronunciation_notes == "") {
        "No additional notes"
      } else {
        input$pronunciation_notes
      }

      # Create new row with proper handling
      new_row <- data.frame(
        Name = as.character(name),
        Syllables = as.character(pronunciation_guide$syllables),
        Simple_Phonetic = as.character(pronunciation_guide$simple),
        IPA_Phonetic = as.character(pronunciation_guide$ipa),
        Origin = as.character(origin_display),
        Notes = as.character(notes),
        Date_Added = as.character(Sys.Date()),
        stringsAsFactors = FALSE
      )
      
      # Add to saved names
      if(nrow(saved_names$data) == 0) {
        saved_names$data <- new_row
      } else {
        saved_names$data <- rbind(saved_names$data, new_row)
      }
      
      # Clear inputs
      updateTextInput(session, "student_name", value = "")
      updateTextInput(session, "pronunciation_notes", value = "")
      
      showNotification("Name saved successfully!", type = "message")
      
    }, error = function(e) {
      showNotification(paste("Error saving name:", e$message), type = "error")
    })
  })
  
  # Display saved names table
  output$saved_names_table <- DT::renderDataTable({
    # Create copy of data and add Audio column with speaker buttons
    if (nrow(saved_names$data) > 0) {
      table_data <- saved_names$data
      # Use the phonetic guide (Simple_Phonetic column) for audio pronunciation
      table_data$Audio <- mapply(function(name, phonetic) {
        paste0('<button class="btn btn-sm btn-primary speak-saved" data-name="',
               phonetic,  # Use phonetic guide instead of original name
               '" style="padding: 2px 8px;"><i class="fa fa-volume-up"></i></button>')
      }, table_data$Name, table_data$Simple_Phonetic, USE.NAMES = FALSE)
    } else {
      table_data <- saved_names$data
    }

    DT::datatable(
      table_data,
      escape = FALSE,  # Allow HTML in Audio column
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        columnDefs = list(
          list(
            targets = ncol(table_data) - 1,  # Audio column
            orderable = FALSE,  # Don't allow sorting on Audio column
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
      ipa_phonetic = "tɛst",
      api_key = api_key,
      voice_id = voice_id,
      speed = 1.0
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

  # Clear audio cache
  observeEvent(input$clear_cache, {
    audio_cache_dir <- file.path(tempdir(), "name_audio_cache")

    if (dir.exists(audio_cache_dir)) {
      # Count files before deletion
      cache_files <- list.files(audio_cache_dir, full.names = TRUE)
      file_count <- length(cache_files)

      # Delete all cache files
      tryCatch({
        unlink(audio_cache_dir, recursive = TRUE)

        output$cache_clear_result <- renderText(paste(
          "✓ Cache cleared successfully!",
          paste0("Deleted ", file_count, " cached audio files."),
          "Next pronunciation will generate fresh audio.",
          sep = "\n"
        ))
      }, error = function(e) {
        output$cache_clear_result <- renderText(paste(
          "✗ Error clearing cache:",
          e$message,
          sep = "\n"
        ))
      })
    } else {
      output$cache_clear_result <- renderText("Cache is already empty.")
    }
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
    saved_names$data <- data.frame(
      Name = character(0),
      Syllables = character(0),
      Simple_Phonetic = character(0),
      IPA_Phonetic = character(0),
      Origin = character(0),
      Notes = character(0),
      Date_Added = character(0),
      stringsAsFactors = FALSE
    )
    removeModal()
    showNotification("All saved names cleared.", type = "warning")
  })
}

# Run the application
shinyApp(ui = ui, server = server)