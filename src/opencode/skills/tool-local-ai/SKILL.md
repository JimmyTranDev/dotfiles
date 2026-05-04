---
name: tool-local-ai
description: Local AI model setup with Ollama and LM Studio for use with OpenCode, covering installation, model selection, configuration, and performance expectations
---

## When to Use Local vs Cloud

| Use Local | Use Cloud |
|-----------|-----------|
| Privacy-sensitive code (credentials, proprietary logic) | Complex multi-file refactoring |
| Offline development (flights, poor connectivity) | Large codebase analysis |
| Quick Q&A and small edits | Code review and auditing |
| Reducing API costs for high-volume tasks | Tasks requiring latest model capabilities |
| Experimentation and learning | Production-critical changes |

## Ollama (Primary)

### Installation

```bash
brew install ollama
ollama serve
```

### Recommended Models

| Model | Size | Use Case | RAM Needed |
|-------|------|----------|------------|
| `qwen2.5-coder:7b` | 4.7GB | Fast coding tasks, completions | 8GB |
| `qwen2.5-coder:32b` | 19GB | Complex coding, refactoring | 32GB |
| `deepseek-coder-v2:16b` | 9GB | Balanced coding performance | 16GB |
| `codellama:13b` | 7GB | General code generation | 16GB |
| `llama3.1:8b` | 4.7GB | General purpose, chat | 8GB |
| `llama3.1:70b` | 40GB | High-quality reasoning | 64GB |

### Pull and Run

```bash
ollama pull qwen2.5-coder:7b
ollama run qwen2.5-coder:7b
```

### OpenCode Configuration

Add to `opencode.json`:
```json
{
  "provider": {
    "ollama": {
      "type": "openai",
      "baseUrl": "http://localhost:11434/v1"
    }
  },
  "model": {
    "local": {
      "provider": "ollama",
      "model": "qwen2.5-coder:7b"
    }
  }
}
```

### Ollama API

| Endpoint | Purpose |
|----------|---------|
| `http://localhost:11434/v1/chat/completions` | Chat completions (OpenAI-compatible) |
| `http://localhost:11434/api/tags` | List installed models |
| `http://localhost:11434/api/show` | Model info |

## LM Studio (Alternative)

### Installation

Download from [lmstudio.ai](https://lmstudio.ai) or:
```bash
brew install --cask lm-studio
```

### Setup

1. Open LM Studio
2. Search and download a model (e.g., `TheBloke/CodeLlama-13B-GGUF`)
3. Go to "Local Server" tab
4. Load the model and start server (default: `http://localhost:1234/v1`)

### OpenCode Configuration

```json
{
  "provider": {
    "lmstudio": {
      "type": "openai",
      "baseUrl": "http://localhost:1234/v1"
    }
  },
  "model": {
    "local": {
      "provider": "lmstudio",
      "model": "loaded-model-name"
    }
  }
}
```

## Performance Expectations

| Hardware | 7B Model | 13B Model | 32B+ Model |
|----------|----------|-----------|------------|
| M1/M2 8GB | ~20 tok/s | Slow/OOM | No |
| M1/M2 16GB | ~30 tok/s | ~15 tok/s | Slow |
| M1 Pro/Max 32GB | ~40 tok/s | ~25 tok/s | ~10 tok/s |
| M2 Ultra 64GB+ | ~50 tok/s | ~35 tok/s | ~20 tok/s |

### CPU-Only (No GPU)

- Expect 2-5x slower than Apple Silicon unified memory
- Stick to 7B models or smaller
- Use GGUF Q4_K_M quantization for best speed/quality balance
- Set `OLLAMA_NUM_THREADS` to match physical core count

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Ollama not responding | `ollama serve` or `brew services start ollama` |
| Model too slow | Use smaller model or higher quantization |
| Out of memory | Use smaller model, close other apps, or use Q4 quantization |
| Port conflict | Change port: `OLLAMA_HOST=0.0.0.0:11435 ollama serve` |
| LM Studio model not loading | Check RAM requirements, try smaller quantization |
