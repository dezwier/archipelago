# Setting Up Railway Volumes for Image Storage

Railway's filesystem is **ephemeral** - files written to disk are lost when the container restarts. To persist generated images, you need to use **Railway Volumes**.

## Step-by-Step Setup

### 1. Create a Volume in Railway

1. Go to your Railway project dashboard
2. Click on your service (the one running the API)
3. Click on the **"Volumes"** tab (or find it in the service settings)
4. Click **"New Volume"**
5. Give it a name (e.g., `assets-storage`)
6. Set the mount path (e.g., `/data/assets`)
7. Click **"Create"**

### 2. Set the Environment Variable

1. In your Railway service, go to the **"Variables"** tab
2. Add a new environment variable:
   - **Name**: `ASSETS_PATH`
   - **Value**: `/data/assets` (or whatever mount path you chose)
3. Save the variable

### 3. Redeploy Your Service

After creating the volume and setting the environment variable, Railway will automatically redeploy your service. The volume will be mounted at the specified path.

## How It Works

- When `ASSETS_PATH` is set, the API will save images to that path (the Railway volume)
- The volume persists across deployments and restarts
- Images are served via the `/assets` endpoint
- The volume path is mounted inside your container

## Alternative: Cloud Storage

If you prefer cloud storage instead of Railway volumes, you can:

1. **Use Google Cloud Storage** (since you're already using Google services)
2. **Use AWS S3**
3. **Use Cloudinary** or similar services

For cloud storage, you would need to:
- Upload images to the cloud storage service
- Store the cloud storage URL in the database
- Update the image serving logic to use cloud URLs

## Accessing the Railway Volume

### Using Railway CLI

1. **Install Railway CLI** (if not already installed):
   ```bash
   npm i -g @railway/cli
   # or
   brew install railway
   ```

2. **Login to Railway**:
   ```bash
   railway login
   ```

3. **Link to your project**:
   ```bash
   railway link
   ```

4. **Access the volume via shell**:
   ```bash
   railway shell
   ```
   Then navigate to your volume path (e.g., `/data/assets`)

5. **Copy files to/from the volume**:
   ```bash
   # Copy local file to Railway volume
   railway run cp /path/to/local/image.jpg /data/assets/123.jpg
   
   # Or use railway shell and then use standard commands
   railway shell
   # Inside the shell:
   ls /data/assets
   cp /path/to/local/image.jpg /data/assets/123.jpg
   ```

### Using the API Upload Endpoint

You can also upload images directly via the API:

1. **Upload via API endpoint** (recommended):
   ```bash
   curl -X POST "https://your-api.railway.app/api/v1/concept-image/upload/123" \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -F "file=@/path/to/local/image.jpg"
   ```

2. **Or use the generic upload endpoint**:
   ```bash
   curl -X POST "https://your-api.railway.app/api/v1/concept-image/upload" \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -F "file=@/path/to/local/image.jpg" \
     -F "concept_id=123"
   ```

The API will:
- Automatically resize images to 300x300
- Convert to JPEG format
- Save to the Railway volume (or local assets directory)
- Update the database record

## Verification

After setting up the volume:

1. Generate an image through the API
2. Check that the file exists in the volume (you can use Railway's CLI or check logs)
3. Verify the image is accessible at `/assets/{concept_id}.jpg`

## Troubleshooting

### Images still not persisting
- Verify the volume is mounted: Check Railway dashboard → Volumes tab
- Verify `ASSETS_PATH` is set correctly in environment variables
- Check logs for the assets directory path being used

### 404 errors when accessing images
- Ensure the volume mount path matches `ASSETS_PATH`
- Verify the static file mount in `main.py` is working
- Check that files are being saved to the correct location (check logs)

### Permission errors
- Railway volumes should have correct permissions automatically
- If issues persist, you may need to set permissions in your Dockerfile or startup script
