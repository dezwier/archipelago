# How to Get Google Gemini API Key for Image Generation

## Step-by-Step Instructions

### 1. Go to Google AI Studio
Navigate to [Google AI Studio](https://aistudio.google.com/app/apikey) in your web browser.

### 2. Sign In
- Sign in with your Google account
- If you don't have a Google account, create one first

### 3. Create API Key
- Click on **"Create API Key"** or **"Get API Key"** button
- If prompted, select or create a Google Cloud project
- Your API key will be generated and displayed

### 4. Copy Your API Key
- **Important**: Copy the API key immediately - you won't be able to see it again!
- The API key will look something like: `AIzaSyAbCdEfGhIjKlMnOpQrStUvWxYz1234567`

### 5. Set the Environment Variable

#### Option A: Add to `.env` file (Recommended for local development)
Create or edit the `.env` file in the `api/` directory:

```bash
GOOGLE_GEMINI_API_KEY=your_api_key_here
```

#### Option B: Set as System Environment Variable

**On macOS/Linux:**
```bash
export GOOGLE_GEMINI_API_KEY="your_api_key_here"
```

**On Windows (PowerShell):**
```powershell
$env:GOOGLE_GEMINI_API_KEY="your_api_key_here"
```

**On Windows (Command Prompt):**
```cmd
set GOOGLE_GEMINI_API_KEY=your_api_key_here
```

#### Option C: For Production/Deployment
Set the environment variable in your deployment platform (Railway, Heroku, AWS, etc.) through their environment variable settings.

### 6. Verify the Setup
The endpoint will automatically use the Gemini API key if it's set. You can verify by:
- Checking that `GOOGLE_GEMINI_API_KEY` is in your environment variables
- Making a test request to the image generation endpoint

## Important Notes

### Pricing
- **Image generation requires a paid tier** of the Gemini API
- Free tier does not include image generation capabilities
- Check [Google AI Studio pricing](https://ai.google.dev/pricing) for current rates

### Security
- **Never commit your API key to version control** (Git)
- Add `.env` to your `.gitignore` file
- Keep your API key secure and don't share it publicly

### API Key Limits
- Each API key has usage limits based on your plan
- Monitor your usage in [Google AI Studio](https://aistudio.google.com/app/apikey)

## Troubleshooting

### "API key not configured" error
- Make sure the environment variable name is exactly `GOOGLE_GEMINI_API_KEY`
- Restart your API server after setting the environment variable
- Check that the `.env` file is in the correct location (`api/.env`)

### "Image generation not available" error
- Ensure you're on a paid tier (free tier doesn't support image generation)
- Verify your API key has the necessary permissions
- Check that you're using the correct model name

### Rate limiting errors
- You may have exceeded your API quota
- Check your usage in Google AI Studio
- Consider upgrading your plan if needed

## Video Tutorial
For a visual guide, you can watch: [How to Generate a Google Gemini API Key: Step-by-Step Guide](https://www.youtube.com/watch?v=o8iyrtQyrZM)
