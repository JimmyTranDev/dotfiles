---
name: tool-google-cloud-tts
description: Google Cloud Text-to-Speech patterns covering voice selection, SSML, audio encoding, batch synthesis, rate limiting, quota management, and cost optimization
---

## Setup

```ts
import { TextToSpeechClient } from '@google-cloud/text-to-speech';

const client = new TextToSpeechClient();
// Uses GOOGLE_APPLICATION_CREDENTIALS env var or explicit credentials
```

## Basic Synthesis

```ts
const [response] = await client.synthesizeSpeech({
  input: { text: 'Hello world' },
  voice: { languageCode: 'en-US', name: 'en-US-Wavenet-D' },
  audioConfig: { audioEncoding: 'MP3' },
});

// response.audioContent is a Buffer
await fs.writeFile('output.mp3', response.audioContent, 'binary');
```

## Voice Selection

### Voice Types (by quality/cost)

| Type | Quality | Cost per 1M chars |
|------|---------|-------------------|
| Standard | Basic | $4 |
| WaveNet | High | $16 |
| Neural2 | Higher | $16 |
| Studio | Highest | $160 |
| Journey | Conversational | $16-160 |

### Voice Naming Convention
`{languageCode}-{type}-{letter}` e.g., `en-US-Wavenet-D`, `fr-FR-Neural2-A`

### List Available Voices

```ts
const [result] = await client.listVoices({ languageCode: 'en' });
result.voices.forEach(voice => {
  console.log(voice.name, voice.ssmlGender, voice.languageCodes);
});
```

## SSML

```ts
const input = {
  ssml: `<speak>
    <prosody rate="slow" pitch="+2st">Hello</prosody>
    <break time="500ms"/>
    <emphasis level="strong">world</emphasis>
  </speak>`
};
```

### Common SSML Tags

| Tag | Purpose | Example |
|-----|---------|---------|
| `<break>` | Pause | `<break time="300ms"/>` |
| `<prosody>` | Rate/pitch/volume | `<prosody rate="90%" pitch="-2st">` |
| `<emphasis>` | Stress | `<emphasis level="moderate">` |
| `<say-as>` | Interpret as | `<say-as interpret-as="date">2024-01-15</say-as>` |
| `<phoneme>` | Pronunciation | `<phoneme alphabet="ipa" ph="ˈhɛloʊ">hello</phoneme>` |

## Audio Config

```ts
const audioConfig = {
  audioEncoding: 'MP3',        // MP3, LINEAR16, OGG_OPUS, MULAW, ALAW
  speakingRate: 1.0,           // 0.25 to 4.0
  pitch: 0.0,                  // -20.0 to 20.0 semitones
  volumeGainDb: 0.0,           // -96.0 to 16.0
  sampleRateHertz: 24000,      // Optional, depends on encoding
  effectsProfileId: ['small-bluetooth-speaker-class-device'],  // Audio profile
};
```

## Rate Limiting and Quotas

| Limit | Default | Notes |
|-------|---------|-------|
| Requests per minute | 1000 | Can be increased via quota request |
| Characters per request | 5000 (text), 5000 (SSML) | Hard limit |
| Concurrent requests | ~100 | Varies by project |

### Handling 429 / RESOURCE_EXHAUSTED

```ts
async function synthesizeWithRetry(request, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await client.synthesizeSpeech(request);
    } catch (error) {
      if (error.code === 8 || error.code === 429) {
        const delay = Math.min(1000 * Math.pow(2, i), 30000);
        await new Promise(r => setTimeout(r, delay));
        continue;
      }
      throw error;
    }
  }
  throw new Error('Max retries exceeded');
}
```

## Batch Processing Pattern

```ts
async function generateBatch(items: VocabItem[], languageCode: string) {
  const voice = getRandomWavenetVoice(languageCode);

  for (const item of items) {
    await synthesizeAndSave(item.word, voice, `words/${item.word}.mp3`);
    await synthesizeAndSave(item.sentence, voice, `sentences/${item.word}.mp3`);
    await delay(100);  // Rate limiting buffer
  }
}
```

## Cost Optimization

- Use Standard voices for drafts/testing, WaveNet for production
- Cache audio files — don't regenerate unchanged text
- Skip existing files (check before synthesis)
- Batch by language to reuse voice config
- Use shorter SSML (remove unnecessary tags)
- Monitor usage in Cloud Console → APIs & Services → TTS

## Credential Validation

```ts
async function validateCredentials(): Promise<boolean> {
  try {
    await client.listVoices({ languageCode: 'en' });
    return true;
  } catch {
    return false;
  }
}
```
