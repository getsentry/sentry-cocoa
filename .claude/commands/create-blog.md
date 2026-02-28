---
description: Generate an engineering blog post draft for sentry.engineering, auto-detect the repo, create a branch, write the file, and commit it.
---

You are helping a Sentry engineer write and publish a draft blog post for the engineering blog at https://sentry.engineering (repo: https://github.com/getsentry/sentry.engineering).

## Step 1 – Find the sentry.engineering repo

Try to locate the repo automatically before asking the user anything:

1. Check if the current working directory is the `sentry.engineering` repo by looking for `data/blog/` and `package.json` containing `"sentry.engineering"`.
2. Check the parent directory and sibling directories for a folder named `sentry.engineering` with the same structure.
3. Check common locations: `~/projects/sentry.engineering`, `~/code/sentry.engineering`, `~/dev/sentry.engineering`, `~/sentry.engineering`.

If found, confirm with the user:

> ✅ Found sentry.engineering repo at `<path>`. I'll write the post there — sound good?

If not found, ask:

> 📁 I couldn't find the sentry.engineering repo automatically. Please provide the local path to it (or press Enter to generate the MDX without saving it):

If the user skips the path, continue and just print the MDX output at the end instead of writing files.

## Step 2 – Gather inputs

Ask the user for all of the following at once:

1. **PRs / Branches / Features** – GitHub PR URLs, branch names, or a description of what was shipped. Multiple entries welcome.
2. **What to cover** – The story: the problem, the approach, interesting technical decisions or tradeoffs, any funny failures, and the outcome/impact.
3. **Tone** – `entertaining & witty` / `technical & deep-dive` / `storytelling` / `casual & approachable` (default: entertaining & witty)
4. **Target audience** – e.g. backend engineers, frontend engineers, general tech (default: software engineers)
5. **Author GitHub username** – to fill the `authors` frontmatter field

## Step 3 – Research

Use your available tools to gather more context:

- If PR URLs were provided, read their titles, descriptions, and linked issues from GitHub.
- If branch names were provided, try to find related commits or PRs.
- Look at changed files in the PRs to add technical depth to the post.
- Search the web or docs if the post involves a technical concept worth explaining clearly.

## Step 4 – Generate the blog post

Write a complete MDX blog post draft following the sentry.engineering format.

### Determine the slug and filename

- Generate a short, URL-friendly slug from the title, e.g. `sdk-performance-wins-q1`
- Use today's date for the filename: `YYYY-MM-DD-<slug>.mdx`

### Frontmatter

```mdx
---
title: '<engaging title>'
date: '<YYYY-MM-DD>'
tags: ['<relevant>', '<tags>']
draft: false
summary: '<one sentence that makes someone want to read this>'
authors: ['<github-username>']
---
```

### Content guidelines

- **Hook first** – Open with something punchy: a surprising stat, a relatable pain, a question, or a short anecdote.
- **Problem → Exploration → Solution** – Tell the story of what you were trying to do, what you tried, and how you got there. Dead ends are interesting too.
- **Show the code** – Include real or representative code snippets in fenced code blocks with the correct language tag.
- **Image placeholders** – Add `<!-- TODO: add screenshot/diagram of X here -->` wherever a visual would help. Be specific.
- **Human voice** – Write like a real engineer sharing war stories with a colleague, not a press release. Humor welcome.
- **Takeaways** – End with 2–3 concrete lessons learned or things readers can apply.
- **Length** – Aim for 600–1000 words of body content.

## Step 5 – Write files and create a branch

If the repo path is available:

### 5a – Check for author file

Check if `data/authors/<username>.md` exists in the repo.
If it doesn't, let the user know:

> ⚠️ No author file found for `<username>`. You'll need to create `data/authors/<username>.md` before publishing. Want me to generate a template for it?

If yes, create a minimal template:

```md
---
name: <username>
avatar: /images/authors/<username>.jpg
occupation: SDK Engineer
company: Sentry
github: https://github.com/<username>
---
```

### 5b – Create a git branch

Run the following from the repo root:

```bash
git checkout main && git pull origin main
git checkout -b blog/<slug>
```

If this fails, warn the user and continue without branching.

### 5c – Write the MDX file

Write the generated post to:

```
data/blog/<YYYY-MM-DD-slug>.mdx
```

### 5d – Create the image directory

Create the folder:

```
public/images/<slug>/
```

And add a `.gitkeep` so it's tracked by git.

### 5e – Commit

```bash
git add data/blog/<filename>.mdx public/images/<slug>/.gitkeep
git commit -m "blog: add draft post '<title>'"
```

Then tell the user:

> ✅ Done! Branch `blog/<slug>` created with your draft committed.

## Step 6 – Print next steps

```
## Next steps
- [ ] Add screenshots/diagrams to public/images/<slug>/
- [ ] Replace <!-- TODO --> placeholders with real images
- [ ] Run `npm start` in the repo to preview locally
- [ ] Push: git push origin blog/<slug>
- [ ] Open a PR on https://github.com/getsentry/sentry.engineering
- [ ] Optionally request a writing review before merging
```

If the repo was not found and the user skipped the path, print the full MDX content to the terminal instead so they can copy-paste it manually.
