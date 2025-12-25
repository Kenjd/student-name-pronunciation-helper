#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
speak_name.py - Generate pronunciation audio for a name using ElevenLabs TTS
Called from R Shiny app via system2()

Usage:
    python3 speak_name.py "Name" "Phonetic_Text" api_key voice_id [output_path] [speed]

Phonetic_Text: Clean respelling (e.g., "shuh-KEEL") or IPA if properly formatted
Returns JSON with success status and audio file path
"""

import sys
import json
import requests
import tempfile
from pathlib import Path

# Ensure UTF-8 encoding for proper IPA character handling
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')
if sys.stderr.encoding != 'utf-8':
    sys.stderr.reconfigure(encoding='utf-8')

# ElevenLabs API Configuration
# User should set this via environment variable or update it here
ELEVENLABS_API_KEY = ""  # Will be passed as argument or set as env var
ELEVENLABS_VOICE_ID = ""  # Will be passed as argument or set as env var
ELEVENLABS_MODEL = "eleven_turbo_v2"  # Turbo v2 with IPA support (NOT v2.5)

def generate_name_audio(name, phonetic_text, output_path=None, speed=1.0, api_key=None, voice_id=None, ipa=None):
    """
    Generate audio pronunciation for a name using ElevenLabs API

    Args:
        name: The name to pronounce
        phonetic_text: Phonetic respelling (e.g., "shuh-KEEL") or IPA
        output_path: Optional path for output file (default: temp file)
        speed: Speech speed multiplier (0.5 to 1.5, default: 1.0)
        api_key: ElevenLabs API key
        voice_id: ElevenLabs voice ID

    Returns:
        dict: JSON-serializable result with success, audio_path, and size
    """

    # Validate inputs
    if not api_key:
        return {
            "success": False,
            "error": "ElevenLabs API key not provided"
        }

    if not voice_id:
        return {
            "success": False,
            "error": "ElevenLabs voice ID not provided"
        }

    # API endpoint
    url = f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"

    # If IPA/CMU is provided, use SSML phoneme tag for accurate pronunciation
    # ElevenLabs recommends CMU Arpabet over IPA for better consistency
    # Otherwise, use clean phonetic respelling
    if (ipa and ipa.strip() and
        ipa != "IPA not available" and
        not ipa.startswith("CMU not available") and
        ipa.strip() != ""):
        ipa_clean = ipa.strip().strip('/')
        # Detect if it's CMU Arpabet (contains numbers 0-2 and uppercase) or IPA
        if any(char in ipa_clean for char in ['0', '1', '2']) and ipa_clean.replace(' ', '').isupper():
            # CMU Arpabet format (recommended by ElevenLabs)
            # Format: <phoneme alphabet='cmu-arpabet' ph='CMU_HERE'>OriginalName</phoneme>
            text_to_speak = f"<phoneme alphabet='cmu-arpabet' ph='{ipa_clean}'>{name}</phoneme>"
        else:
            # IPA format (fallback)
            # Format: <phoneme alphabet='ipa' ph='IPA_HERE'>OriginalName</phoneme>
            text_to_speak = f"<phoneme alphabet='ipa' ph='{ipa_clean}'>{name}</phoneme>"
    else:
        # Fallback to phonetic respelling (plain text - ElevenLabs will interpret naturally)
        phonetic_clean = phonetic_text.strip().strip('/')
        text_to_speak = phonetic_clean

    # Prepare payload
    payload = {
        "text": text_to_speak,
        "model_id": ELEVENLABS_MODEL,
        "voice_settings": {
            "stability": 0.5,
            "similarity_boost": 0.75,
            "style": 0.0,
            "use_speaker_boost": True
        }
    }

    # Headers with authentication
    headers = {
        "Accept": "audio/mpeg",
        "Content-Type": "application/json",
        "xi-api-key": api_key
    }

    try:
        # Make API request
        response = requests.post(
            url,
            headers=headers,
            json=payload,
            timeout=30
        )

        # Check for errors
        if response.status_code != 200:
            error_msg = f"API error {response.status_code}"
            try:
                error_detail = response.json().get("detail", {})
                if isinstance(error_detail, dict):
                    error_msg = f"{error_msg}: {error_detail.get('message', response.text[:200])}"
                else:
                    error_msg = f"{error_msg}: {error_detail}"
            except:
                error_msg = f"{error_msg}: {response.text[:200]}"
            return {
                "success": False,
                "error": error_msg
            }

        # Validate output path (R always provides this, fallback removed to prevent orphan files)
        if not output_path or not output_path.strip():
            return {
                "success": False,
                "error": "Output path must be provided by calling application"
            }

        # Save audio file
        with open(output_path, "wb") as f:
            f.write(response.content)

        return {
            "success": True,
            "audio_path": output_path,
            "size": len(response.content)
        }

    except requests.exceptions.Timeout:
        return {
            "success": False,
            "error": "Request timeout - please try again"
        }
    except requests.exceptions.ConnectionError:
        return {
            "success": False,
            "error": "Connection error - check your internet connection"
        }
    except Exception as e:
        return {
            "success": False,
            "error": f"Unexpected error: {str(e)}"
        }

def main():
    """Main entry point for command-line usage"""
    # Check arguments
    if len(sys.argv) < 5:
        result = {
            "success": False,
            "error": "Usage: python3 speak_name.py \"Name\" \"Phonetic_Text\" api_key voice_id [output_path] [speed] [ipa]"
        }
        print(json.dumps(result))
        sys.exit(1)

    # Parse arguments
    name = sys.argv[1]
    phonetic_text = sys.argv[2]
    api_key = sys.argv[3]
    voice_id = sys.argv[4]
    output_path = sys.argv[5] if len(sys.argv) > 5 else None
    speed = float(sys.argv[6]) if len(sys.argv) > 6 else 1.0
    ipa = sys.argv[7] if len(sys.argv) > 7 else None

    # Validate name and phonetic text
    if not name or not name.strip():
        result = {
            "success": False,
            "error": "Name cannot be empty"
        }
        print(json.dumps(result))
        sys.exit(1)

    if not phonetic_text or not phonetic_text.strip():
        result = {
            "success": False,
            "error": "Phonetic text cannot be empty"
        }
        print(json.dumps(result))
        sys.exit(1)

    # Generate audio
    result = generate_name_audio(name, phonetic_text, output_path, speed, api_key, voice_id, ipa)

    # Output JSON result
    print(json.dumps(result))

    # Exit with appropriate code
    sys.exit(0 if result["success"] else 1)

if __name__ == "__main__":
    main()
