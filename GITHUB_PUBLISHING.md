# Publishing Your App to GitHub

This guide will walk you through publishing your Student Name Pronunciation Helper to GitHub for the first time.

---

## Prerequisites

- A GitHub account (free) - [Sign up here](https://github.com/signup) if you don't have one
- Git installed on your computer - [Download here](https://git-scm.com/downloads)
- Your app files ready in the `/Pronunciation` folder

---

## Step-by-Step Guide

### Step 1: Verify Your Files Are Ready

Before publishing, make sure you have these files in your folder:

```
/Pronunciation/
├── name_pronunciation_app.r      ✓ Main app
├── speak_name.py                 ✓ Python script
├── README.md                     ✓ Project overview
├── USAGE.md                      ✓ Usage instructions
├── CONTRIBUTING.md               ✓ Contribution guide
├── CHANGELOG.md                  ✓ Version history
├── LICENSE                       ✓ MIT License
└── .gitignore                    ✓ Protects credentials
```

**Important**: Make sure `.elevenlabs_config.rds` is NOT in this folder, or if it is, that `.gitignore` is working.

---

### Step 2: Open Terminal/Command Prompt

**On Mac**:
- Open Terminal (Applications → Utilities → Terminal)
- Navigate to your app folder:
  ```bash
  cd "/Users/kendafoe/Documents/r-workshop/R Projects 1/Pronunciation"
  ```

**On Windows**:
- Open Command Prompt or PowerShell
- Navigate to your app folder:
  ```cmd
  cd "C:\Users\YourName\Documents\r-workshop\R Projects 1\Pronunciation"
  ```

---

### Step 3: Initialize Git Repository

Run these commands one at a time:

```bash
# Initialize git in this folder
git init

# Check that .gitignore is working
git status
```

You should see a list of files. **Verify that `.elevenlabs_config.rds` is NOT listed**. If it is, stop and check your .gitignore file.

---

### Step 4: Make Your First Commit

```bash
# Add all files to staging
git add .

# Create your first commit
git commit -m "Initial release: Student Name Pronunciation Helper v1.0"
```

You should see a message like `7 files changed, 1200 insertions(+)`.

---

### Step 5: Create a GitHub Repository

1. Go to [github.com](https://github.com) and log in
2. Click the **+** icon in the top-right corner
3. Select **"New repository"**
4. Fill in the details:
   - **Repository name**: `student-name-pronunciation-helper` (or your preferred name)
   - **Description**: "A Shiny app to help teachers learn correct pronunciation of student names"
   - **Visibility**: Choose **Public** (so others can use it) or **Private**
   - **DO NOT** initialize with README (you already have one)
   - **DO NOT** add .gitignore (you already have one)
   - **DO NOT** choose a license (you already have one)
5. Click **"Create repository"**

---

### Step 6: Connect Local Folder to GitHub

GitHub will show you commands. Run these (replace `YOUR_USERNAME` with your actual GitHub username):

```bash
# Add GitHub as remote
git remote add origin https://github.com/YOUR_USERNAME/student-name-pronunciation-helper.git

# Rename branch to 'main' (GitHub's default)
git branch -M main

# Push your code to GitHub
git push -u origin main
```

You may be asked to log in to GitHub. Follow the prompts.

---

### Step 7: Verify Upload

1. Refresh your GitHub repository page
2. You should see all your files!
3. Click around to verify:
   - README.md displays nicely as the homepage
   - LICENSE file is detected (look for "MIT" badge)
   - .gitignore is there
   - `.elevenlabs_config.rds` is **NOT** there ✓

---

### Step 8: Update README with Your GitHub URL

Now that your repository is live, update the clone URL in README.md:

1. Open `README.md` in a text editor
2. Find this line (around line 143):
   ```bash
   git clone https://github.com/YOUR_USERNAME/pronunciation-helper.git
   ```
3. Replace with your actual URL:
   ```bash
   git clone https://github.com/YOUR_USERNAME/student-name-pronunciation-helper.git
   ```
4. Save the file
5. Commit and push the change:
   ```bash
   git add README.md
   git commit -m "Update clone URL in README"
   git push
   ```

---

### Step 9: Add Repository Topics (Optional but Recommended)

Make your repository easier to discover:

1. On your GitHub repository page, click the **gear icon** next to "About"
2. Add topics like:
   - `r`
   - `shiny`
   - `education`
   - `pronunciation`
   - `teachers`
   - `accessibility`
   - `names`
   - `ipa`
3. Click **"Save changes"**

---

### Step 10: Share Your Work!

Your app is now live! Share it with:

- **Direct link**: `https://github.com/YOUR_USERNAME/student-name-pronunciation-helper`
- **Twitter/X**: "Just released an open-source app to help teachers learn correct student name pronunciation! #RShiny #Education"
- **Reddit**: r/rstats, r/Teachers, r/datasets
- **Teaching communities** you're part of
- **LinkedIn**: Great portfolio piece!

---

## Making Future Updates

When you make changes to your app:

```bash
# See what changed
git status

# Add changed files
git add name_pronunciation_app.r

# Commit with a message
git commit -m "Add Spanish dictionary with 20 names"

# Push to GitHub
git push
```

---

## Common Issues & Solutions

### Issue: "Permission denied (publickey)"

**Solution**: Set up SSH keys or use HTTPS with personal access token
- [GitHub SSH Guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [GitHub PAT Guide](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)

### Issue: ".elevenlabs_config.rds accidentally committed"

**Solution**: Remove it from git history:
```bash
git rm --cached .elevenlabs_config.rds
git commit -m "Remove credentials file from tracking"
git push
```

Then regenerate your API key on ElevenLabs for security.

### Issue: "Git is not recognized as a command"

**Solution**: Install Git from [git-scm.com](https://git-scm.com/downloads)

### Issue: "Changes not showing on GitHub"

**Solution**: Make sure you pushed:
```bash
git push origin main
```

---

## GitHub Features to Explore

Once your repository is live:

1. **Enable Issues**: Let users report bugs or request features
   - Settings → Features → Check "Issues"

2. **Add a Description**: Make it show up in searches
   - Edit the "About" section on your repo homepage

3. **Create a Release**: Tag version 1.0
   - Releases → "Create a new release" → Tag: `v1.0.0`

4. **Add Screenshots**: People love visuals!
   - Create a `/screenshots` folder
   - Add images to README.md with:
     ```markdown
     ![App Screenshot](screenshots/main-interface.png)
     ```

5. **Star Your Own Repo**: Why not! You worked hard on it.

---

## Resources

- [GitHub Hello World Guide](https://guides.github.com/activities/hello-world/)
- [Git Basics](https://git-scm.com/book/en/v2/Getting-Started-Git-Basics)
- [Markdown Syntax](https://www.markdownguide.org/basic-syntax/)
- [Writing Good Commit Messages](https://chris.beams.io/posts/git-commit/)

---

## Congratulations! 🎉

You've just published your first app to GitHub! This is a great accomplishment, and your tool will help teachers create more inclusive classrooms.

Remember: Every bug report, star, or contribution from the community is a sign that your work is making a difference.

**Welcome to the open-source community!**
