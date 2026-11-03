# 🐦 Luna Stream 4K IPTV — Twitter / X Auto-Promoter Bot

This folder contains your complete **Twitter / X Auto-Promoter Bot** in its own separate project directory. It supports **both**:
1. **🌐 PC Browser Mode (Zero API Keys Needed):** Uses your logged-in X/Twitter browser on your Windows PC and automatically posts every 3 hours (or with 1 click).
2. **☁️ Official X Free Developer API Mode (PC or 24/7 Free Cloud via GitHub Actions):** Posts up to 8–17 tweets/day in the background even when your computer is turned off.

---

## 🚀 Option 1: Run on Your Windows PC (Takes 10 Seconds — No API Keys Needed!)

1. Make sure you are logged into your Twitter/X account at **[x.com](https://x.com)** in your default browser (Chrome, Edge, Brave, etc.).
2. Double-click **`Start-Luna-Twitter-Bot.bat`**.
3. Your **Luna Stream X Bot Control Panel** will open automatically at **`http://localhost:8090`**.
4. In the dashboard:
   - Click **`🌐 Post Now via Browser`** to test your first tweet immediately (it opens X with the pre-filled IPTV tweet, waits 7 seconds, and automatically presses `Ctrl+Enter` to publish it!).
   - Click **`▶️ Start 3-Hour Auto-Pilot`** in the top-right corner to have the bot automatically post a fresh, non-duplicate IPTV tweet every 3 hours (rotating your Netlify link `https://luna-4k-pass.netlify.app`, your main site `https://lunaentertainment.online`, and your direct WhatsApp `+44 7882 507089`).

---

## ☁️ Option 2: Run 24/7 in the Cloud (Even When Your PC is Turned Off)

Twitter/X provides a **100% Free Developer Tier** that allows posting up to **17 tweets every 24 hours** (~500 tweets/month) via API.

### Step 1: Get Your 4 Free X Developer Keys (3 Minutes)
1. Go to **[developer.x.com/en/portal/dashboard](https://developer.x.com/en/portal/dashboard)** and sign in with your X account.
2. Sign up for the **Free Tier** (if asked for a use-case description, write: *"Automated social media content scheduling and updates for my digital media brand."*).
3. In your Project App → click **Settings → User authentication settings → Set up**:
   - Set **App permissions** to **`Read and write`** (important!).
   - Set **Type of App** to **Web App, Automated App or Bot**.
   - Put `https://lunaentertainment.online` for both Callback URI and Website URL, then click **Save**.
4. Click the **Keys and tokens** tab at the top:
   - Under **Consumer Keys**, click **Regenerate** and copy your **`API Key`** and **`API Key Secret`**.
   - Under **Authentication Tokens**, click **Generate** next to **Access Token and Secret** (make sure it says *"Created with Read and Write permissions"*) and copy your **`Access Token`** and **`Access Token Secret`**.

### Step 2A: Use Those Keys in Your Desktop Dashboard
- Paste those 4 keys into the **🔑 Official X Free Developer API Keys** box at `http://localhost:8090`, switch Default Mode to **Official X Developer API v2**, and click **Save All Bot Settings**. Now the bot will post silently in the background without opening any browser tab!

### Step 2B: Or Run 24/7 on GitHub Actions (PC Can Be Turned Off!)
1. Create a **new Private Repository** on GitHub (e.g. `luna-twitter-bot`) and upload all files from this folder (including the `.github` folder).
2. In that GitHub repository, go to **Settings → Secrets and variables → Actions → New repository secret** and add these 4 secrets:
   - `X_API_KEY`
   - `X_API_SECRET`
   - `X_ACCESS_TOKEN`
   - `X_ACCESS_SECRET`
3. Click the **Actions** tab on GitHub → click **Luna Stream 24/7 Auto-Tweet Bot (Every 3 Hours)** → click **Run workflow**.
4. GitHub will now automatically post a fresh IPTV tweet **every 3 hours (8 tweets/day) 24/7 for free**!
