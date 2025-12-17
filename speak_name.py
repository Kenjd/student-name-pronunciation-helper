#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
speak_name.py - Generate pronunciation audio for a name using ElevenLabs TTS with SSML Phonemes
Called from R Shiny app via system2()

Usage:
    python3 speak_name.py "Name" "IPA_Phonetic" api_key voice_id [output_path] [speed]

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
ELEVENLABS_MODEL = "eleven_turbo_v2_5"  # Fast, cost-effective, high-quality

def generate_name_audio(name, ipa_phonetic, output_path=None, speed=1.0, api_key=None, voice_id=None):
    """
    Generate audio pronunciation for a name using ElevenLabs API with SSML phonemes

    Args:
        name: The name to pronounce
        ipa_phonetic: IPA phonetic spelling (Unicode)
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

    # Clean IPA phonetic - remove slashes if present
    ipa_clean = ipa_phonetic.strip().strip('/')

    # Send IPA as plain text - ElevenLabs handles it better than SSML phoneme tags
    # Just send the IPA directly, like you would paste it on their website
    text_to_speak = ipa_clean

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

        # Create output path if not provided
        if output_path is None:
            # Use temp directory with hash of name for caching
            name_hash = str(hash(name.lower().strip()))
            output_path = str(Path(tempfile.gettempdir()) / f"name_{name_hash}.mp3")

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
            "error": "Usage: python3 speak_name.py \"Name\" \"IPA_Phonetic\" api_key voice_id [output_path] [speed]"
        }
        print(json.dumps(result))
        sys.exit(1)

    # Parse arguments
    name = sys.argv[1]
    ipa_phonetic = sys.argv[2]
    api_key = sys.argv[3]
    voice_id = sys.argv[4]
    output_path = sys.argv[5] if len(sys.argv) > 5 else None
    speed = float(sys.argv[6]) if len(sys.argv) > 6 else 1.0

    # Validate name and IPA
    if not name or not name.strip():
        result = {
            "success": False,
            "error": "Name cannot be empty"
        }
        print(json.dumps(result))
        sys.exit(1)

    if not ipa_phonetic or not ipa_phonetic.strip():
        result = {
            "success": False,
            "error": "IPA phonetic cannot be empty"
        }
        print(json.dumps(result))
        sys.exit(1)

    # Generate audio
    result = generate_name_audio(name, ipa_phonetic, output_path, speed, api_key, voice_id)

    # Output JSON result
    print(json.dumps(result))

    # Exit with appropriate code
    sys.exit(0 if result["success"] else 1)

if __name__ == "__main__":
    main()
