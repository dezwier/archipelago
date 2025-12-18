# Google Cloud Text-to-Speech API Setup Guide

This guide explains how to set up Google Cloud Text-to-Speech API credentials for the lemma audio generation endpoint.

## Step 1: Create or Select a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. If you don't have a project, click **Create Project**
3. Enter a project name (e.g., "archipelago-tts")
4. Click **Create**

## Step 2: Enable the Text-to-Speech API

1. In your Google Cloud project, go to **APIs & Services** > **Library**
2. Search for "Cloud Text-to-Speech API"
3. Click on **Cloud Text-to-Speech API**
4. Click **Enable**

## Step 3: Create a Service Account

1. Go to **IAM & Admin** > **Service Accounts**
2. Click **Create Service Account**
3. Enter details:
   - **Service account name**: `archipelago-tts` (or any name you prefer)
   - **Service account ID**: Auto-generated (you can change it)
   - **Description**: "Service account for Archipelago TTS audio generation"
4. Click **Create and Continue**

## Step 4: Grant Permissions

1. In the **Grant this service account access to project** section:
   - Click **Select a role**
   - Search for and select: **Cloud Text-to-Speech API User**
   - Click **Add Another Role** (optional, for better access)
   - You can also add: **Service Account User** (if needed)
2. Click **Continue**
3. Click **Done** (skip optional steps)

## Step 5: Create and Download Service Account Key

1. Find your newly created service account in the list
2. Click on the service account name
3. Go to the **Keys** tab
4. Click **Add Key** > **Create new key**
5. Select **JSON** as the key type
6. Click **Create**
7. A JSON file will be downloaded to your computer (e.g., `archipelago-tts-xxxxx.json`)

**⚠️ IMPORTANT**: Keep this JSON file secure! It contains credentials that grant access to your Google Cloud resources.

## Step 6: Set Up Credentials

### For Local Development:

1. Store the JSON file in a secure location (e.g., `~/.config/gcloud/` or your project's `secrets/` directory)
2. Set the environment variable:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/service-account-key.json"
   ```
3. Or add it to your `.env` file (make sure `.env` is in `.gitignore`):
   ```
   GOOGLE_APPLICATION_CREDENTIALS=/path/to/your/service-account-key.json
   ```

### For Railway Deployment:

#### Option A: Using Base64 Encoded Credentials (Recommended for Railway)

This is the easiest method for Railway since it doesn't require file uploads:

1. Encode your JSON file to base64:
   ```bash
   # On macOS/Linux:
   cat service-account-key.json | base64 | tr -d '\n'
   
   # Or using Python:
   python3 -c "import base64; print(base64.b64encode(open('service-account-key.json', 'rb').read()).decode())"
   ```
   
   **Note**: Make sure to remove newlines from the output (the `tr -d '\n'` does this)

2. In Railway dashboard:
   - Go to your project
   - Go to **Variables** tab
   - Click **New Variable**
   - **Name**: `GOOGLE_APPLICATION_CREDENTIALS_JSON`
   - **Value**: Paste the entire base64-encoded string (no quotes needed)
   - Click **Add**

3. The code will automatically detect and use this credential method.

#### Option B: Using File Path (Alternative)

1. Upload the JSON file to your Railway volume:
   - Store it in the same volume as your assets (ASSETS_PATH)
   - Example: If `ASSETS_PATH=/data`, store it at `/data/credentials/google-tts-key.json`

2. In Railway Variables, add:
   - **Name**: `GOOGLE_APPLICATION_CREDENTIALS`
   - **Value**: `/data/credentials/google-tts-key.json` (full path to the file)

**Note**: Option A (base64) is recommended because it's simpler and doesn't require file management in Railway volumes.

## Step 7: Verify Setup

Test the endpoint:
```bash
curl -X POST "http://localhost:8000/api/v1/lemma-audio/generate" \
  -H "Content-Type: application/json" \
  -d '{"lemma_id": 1}'
```

## Pricing

Google Cloud Text-to-Speech API pricing (as of 2024):
- **Neural2 voices**: $16 per 1 million characters
- **Standard voices**: $4 per 1 million characters
- First 0-4 million characters per month: Free (for Neural2)

Check current pricing at: https://cloud.google.com/text-to-speech/pricing

## Troubleshooting

### Error: "Could not automatically determine credentials"

**Solution**: Make sure `GOOGLE_APPLICATION_CREDENTIALS` is set correctly:
```bash
echo $GOOGLE_APPLICATION_CREDENTIALS
```

### Error: "Permission denied" or "Access denied"

**Solution**: 
1. Verify the service account has the **Cloud Text-to-Speech API User** role
2. Make sure the Text-to-Speech API is enabled in your project
3. Check that billing is enabled (required for API usage)

### Error: "API not enabled"

**Solution**: 
1. Go to APIs & Services > Library
2. Search for "Cloud Text-to-Speech API"
3. Click **Enable**

## Alternative: Using API Key (Not Recommended)

Google Cloud Text-to-Speech API doesn't support simple API keys like Gemini. It requires service account credentials for security and proper access control.

## Security Best Practices

1. **Never commit the JSON key file to git** - Add it to `.gitignore`
2. **Use Railway secrets** - Store credentials as environment variables
3. **Rotate keys regularly** - Create new keys and delete old ones
4. **Limit permissions** - Only grant the minimum required roles
5. **Monitor usage** - Set up billing alerts in Google Cloud Console

