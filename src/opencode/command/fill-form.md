---
name: fill-form
description: Fill web forms using Browser MCP tools and profile data from ~/Programming/JimmyTranDev/profile/data
---

Usage: /fill-form $ARGUMENTS

Fill out the web form described below using Browser MCP tools and the user's profile data.

$ARGUMENTS

1. **Read profile data** from `~/Programming/JimmyTranDev/profile/data/` to gather known information:
   - `resume-private.yaml` — name, email, phone, location, experience, education, skills, awards
   - `resume-public.yaml` — same as private without sensitive contact details
   - `linkedin.md` — LinkedIn-formatted profile, headline, about, experience
   - `github.md` — GitHub profile content, tech stack, project descriptions
   - `website.ts` — portfolio data: about, skills, projects, experience, education, awards
   - `misc.md` — catch-all for previously answered questions
   - `~/Downloads/Jimmy_Tran_CV.pdf` — latest resume PDF for file upload fields

2. **Navigate** to the target URL using `Browser_navigate` (if a URL is provided in the arguments)

3. **Snapshot** the page using `Browser_snapshot` to get the accessibility tree — always do this before interacting

4. **Match form fields to data** — map each field to the appropriate profile data value using this lookup order:
   - Check `resume-private.yaml` first for personal details (name, email, phone, location)
   - Check `website.ts` and `linkedin.md` for professional content (summaries, descriptions)
   - Check `misc.md` for previously answered questions
   - If the data is not found in any file, **ask the user**

5. **Fill fields in order** — work top to bottom:
   - Text inputs: click to focus, then type. Select all first if replacing existing text
   - Dropdowns: click to open, snapshot to see options, click the target option
   - Date pickers: type date directly into input; fall back to calendar widget clicks
   - Checkboxes / radio buttons: click to toggle or select
   - File uploads: cannot automate via Browser MCP — tell the user to upload `~/Downloads/Jimmy_Tran_CV.pdf` manually if a resume is needed

6. **Handle multi-step flows** — after clicking Next/Continue/Submit, take a new snapshot before filling the next page

7. **Save new answers** — if the user provided any new data not already in the profile files, append it to `~/Programming/JimmyTranDev/profile/data/misc.md` under the appropriate heading:

```markdown
## Heading

- Field Name: value
```

8. **Verify completion** — take a final snapshot or screenshot to confirm the form was submitted

Important:
- Always snapshot before interacting with any page
- Never guess at page structure or data — inspect and look up first
- Do not store or log sensitive data (passwords, SSNs, credit cards) in output
- Flag CAPTCHAs to the user — cannot automate these
- Only perform actions the user explicitly requested
