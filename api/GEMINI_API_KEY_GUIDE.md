# How to Get a Google Gemini API Key

This guide will help you obtain a Google Gemini API key for generating flashcard descriptions.

## Steps to Generate API Key

### 1. Go to Google AI Studio

1. Navigate to [Google AI Studio](https://aistudio.google.com/)
2. Sign in with your Google account

### 2. Create API Key

1. Once logged in, click on **"Get API Key"** button (usually in the top right or center of the page)
2. You'll be prompted to either:
   - **Create API key in new project** (recommended for first-time setup)
   - **Create API key in existing project** (if you already have a Google Cloud project)
3. Select your preferred option
4. The API key will be generated and displayed

### 3. Copy and Store Your API Key

⚠️ **Important**: Copy the API key immediately - it will only be shown once!

The API key will look something like:
```
AIzaSyAbCdEfGhIjKlMnOpQrStUvWxYz1234567
```

### 4. Add to Your Environment

**For Local Development:**

1. Open or create the `.env` file in the `api/` directory
2. Add the following line:
```bash
GOOGLE_GEMINI_API_KEY=your_api_key_here
```

Replace `your_api_key_here` with the actual API key you copied.

**For Railway/Production:**

1. Go to your Railway project dashboard
2. Select your API service
3. Go to the **Variables** tab
4. Click **New Variable**
5. Add:
   - **Name**: `GOOGLE_GEMINI_API_KEY`
   - **Value**: (paste your API key)
6. Click **Add**

### 5. Verify Setup

The API will automatically read the key from the environment variable. You can verify it's working by:

1. Starting your API server
2. Generating a flashcard - descriptions should be automatically generated
3. Check the logs for: `DescriptionService initialized. API key present: True`

## Free Tier & Pricing

- Google offers a **free tier** with generous limits for Gemini API
- For 10,000 descriptions, estimated cost is approximately **$0.45 - $2.50** depending on the model
- See [Google AI Pricing](https://ai.google.dev/pricing) for current rates

## Security Notes

- ⚠️ **Never commit your API key to git** - make sure `.env` is in `.gitignore`
- ⚠️ **Don't share your API key publicly**
- ⚠️ **Rotate your key** if you suspect it's been compromised

## Troubleshooting

**"API key not configured" error:**
- Make sure the `.env` file is in the `api/` directory
- Verify the variable name is exactly `GOOGLE_GEMINI_API_KEY` (case-sensitive in some systems)
- Restart your API server after adding the key

**"Description generation failed" error:**
- Check that your API key is valid and active
- Verify you have quota/credits available in Google AI Studio
- Check the API logs for specific error messages

## Additional Resources

- [Google AI Studio](https://aistudio.google.com/)
- [Gemini API Documentation](https://ai.google.dev/docs)
- [Gemini API Pricing](https://ai.google.dev/pricing)

