---
name: strategy-career
description: Resume tailoring, cover letter structure, LinkedIn optimization, ATS keywords, interview prep, portfolio review, and application tracking
---

## Review Process

### 1. Gather Context

Determine target role, industry, career level, geography, and primary goal. Ask if not provided. Use context clues from materials and state assumptions.

### 2. Analyze Systematically

Read everything before suggesting. Look for: missed opportunities, weak framing (responsibilities vs accomplishments), quantification gaps, keyword gaps, narrative gaps, redundancy, vague claims.

### What to Review

| Material | Focus Areas |
|----------|-------------|
| Resume/CV | Achievement framing, quantification, ATS keywords, structure, consistency, length |
| LinkedIn | Headline optimization, About section hooks, experience storytelling, skills strategy, discoverability |
| Cover Letter | Opening hooks, company-specific personalization, value proposition, structure |
| Portfolio/Website | Project selection/ordering, case study structure, branding consistency |
| Data Files | YAML, TypeScript, Markdown source files that generate profiles — review the content within |

### 3. Deliver Structured Feedback

```
## Overall Assessment
[2-3 sentences + Score: X/10]

## Top 3 High-Impact Changes
1. **[Change]** — [Why + what to do]

## Strengths
- [Specific patterns to keep]

## Section-by-Section Review
### [Section]
**Current:** [Quote]
**Issue:** [Problem]
**Suggested:** [Exact rewrite]

## ATS & Keyword Analysis (resumes/LinkedIn only)
## Consistency Check
## Action Items (priority-ordered)
```

### Review Principles

- Direct, honest, constructive — tough coach, not cheerleader
- Every criticism paired with a specific rewrite
- Never fabricate achievements or credentials
- Enhance the user's voice — never replace it
- Reference their specific content — no generic advice
- Focus on content when content is the bottleneck, not cosmetics

---

## Resume Tailoring

### Priority Order for Resume Sections

| Priority | Section | Rule |
|----------|---------|------|
| 1 | Professional Summary | 2-3 sentences targeting the specific role |
| 2 | Experience | Reorder by relevance to posting, not chronology |
| 3 | Skills | Mirror exact keywords from the job posting |
| 4 | Projects | Include only if directly relevant to the role |
| 5 | Education | Lead with this only if < 2 years experience |

### Bullet Point Formula

```
[Strong Action Verb] + [What You Did] + [Quantified Result] + [Tech/Method Used]

"Architected real-time notification system serving 500K daily active users using WebSockets and Redis pub/sub"
"Reduced CI pipeline duration by 62% (18min to 7min) by parallelizing test suites and implementing build caching"
"Led migration of 3 legacy monoliths to microservices, eliminating 4hrs/week of manual deployment overhead"
```

### Action Verb Tiers

| Tier | Verbs | Use When |
|------|-------|----------|
| Leadership | Spearheaded, Drove, Pioneered, Championed | You initiated and owned the outcome |
| Architecture | Architected, Designed, Engineered, Built | You made key technical decisions |
| Improvement | Optimized, Streamlined, Accelerated, Reduced | You improved an existing system |
| Delivery | Delivered, Shipped, Launched, Deployed | You completed and released work |
| Collaboration | Partnered, Mentored, Coordinated, Facilitated | You worked across teams |

### Quantification Strategies

When exact numbers aren't available:

| Instead Of | Write |
|------------|-------|
| No metrics at all | "Reduced load time significantly" -> estimate: "Reduced load time by ~40%" |
| Unknown user count | Use team/company size: "used by engineering team of 30+" |
| No revenue data | Use proxy: "serving 10K+ monthly active users" |
| Unknown time savings | Estimate: "saving approximately 5 hours/week of manual work" |

---

## ATS Optimization

### Keyword Extraction Process

1. Copy the full job posting text
2. Extract exact phrases for: required skills, preferred skills, tools, methodologies, soft skills
3. Categorize by frequency (mentioned 3+ times = critical, 2 times = important, 1 time = include if relevant)
4. Use the exact phrasing from the posting, not synonyms

### ATS-Safe Formatting

| Do | Don't |
|----|-------|
| Use standard section headers (Experience, Education, Skills) | Use creative headers (Where I've Been, My Toolbox) |
| Plain text bullet points | Tables, columns, graphics |
| Standard fonts | Custom fonts or icons |
| Spell out acronyms once: "Continuous Integration/Continuous Deployment (CI/CD)" | Assume ATS knows acronyms |
| .pdf or .docx format | .pages, images, or heavily designed PDFs |

### Keyword Placement Strategy

| Location | Impact |
|----------|--------|
| Professional Summary | Highest — ATS often weights the top |
| Job titles and headers | High — exact title matches score well |
| Bullet points in Experience | High — contextual usage scores better than keyword stuffing |
| Skills section | Medium — good for hard skill matching |
| Education/Certifications | Lower — but critical for required credentials |

---

## Cover Letters

### Opening Hook Patterns

| Pattern | Example |
|---------|---------|
| Lead with a result | "After reducing API response times by 73% at [Company], I'm drawn to [Target]'s mission to..." |
| Company insight | "Your recent launch of [Product] signals a shift toward [Direction] — exactly the challenge I've spent 3 years solving at..." |
| Shared connection | "After speaking with [Name] on your team about [Topic], I'm excited about the [Role] opportunity..." |
| Industry problem | "[Industry] loses $X billion annually to [Problem]. At [Company], I built the system that solved this for..." |

### Body Structure

```
Paragraph 1 (Hook + Why This Company): 2-3 sentences connecting you to their specific mission/product/challenge
Paragraph 2 (Top Achievement): Your most relevant achievement with numbers, mapped to their #1 requirement
Paragraph 3 (Second Angle): Demonstrate breadth — leadership, culture fit, or a different technical dimension
Paragraph 4 (Close): Fit signal + specific CTA ("I'd welcome 30 minutes to discuss how my experience with X can help Y")
```

### Cover Letter Anti-Patterns

| Never Write | Instead Write |
|-------------|---------------|
| "I am writing to express my interest in..." | [Lead with a result or insight] |
| "I believe I would be a great fit..." | [Show fit through specific evidence] |
| "As you can see from my resume..." | [Don't reference the resume, stand alone] |
| "I am a hard worker and team player" | [Prove it with a specific example] |
| "Please find attached..." | [End with value + CTA, not logistics] |

---

## LinkedIn

**Headline**: [Title] | [Differentiator] | [Key Skills] — treat it like SEO

**About**: Hook in first 2 lines (before "see more"), then what you do, achievements with numbers, what you want, CTA

**vs Resume**: Longer, conversational, first-person, include personality

---

## Interview Preparation

### STAR Method Structure

```
Situation: Set the scene in 1-2 sentences (company, team, context)
Task: What was your specific responsibility or challenge?
Action: What did YOU do? (Use "I", not "we" — be specific about your contribution)
Result: Quantified outcome + what you learned or what changed
```

### Common Question Categories

| Category | Example Questions | Prep Strategy |
|----------|-------------------|---------------|
| Behavioral | "Tell me about a time you..." | Prepare 8-10 STAR stories covering: conflict, failure, leadership, ambiguity, deadline pressure |
| Technical | "How would you design..." | Practice system design for the company's domain |
| Role-Specific | "How do you approach X?" | Map your methodology to their tech stack/process |
| Culture | "Why this company?" | Research: recent blog posts, product launches, engineering talks, company values |
| Reverse | "What questions do you have?" | Prepare 5+ questions showing genuine research |

### Questions to Ask the Interviewer

| Type | Example |
|------|---------|
| Role clarity | "What does a successful first 90 days look like in this role?" |
| Team dynamics | "How does the team handle disagreements on technical decisions?" |
| Growth signal | "What's the biggest technical challenge the team is facing right now?" |
| Culture probe | "How do you balance shipping speed with code quality?" |
| Strategy | "Where do you see this product/team heading in the next year?" |

---

## Application Tracking

### Status Pipeline

```
Identified -> Researched -> Materials Tailored -> Applied -> Follow-Up Sent -> Phone Screen -> Technical Interview -> Final Round -> Offer
```

### Follow-Up Timing

| Event | Follow-Up | Channel |
|-------|-----------|---------|
| Application submitted | 5-7 business days | Email to hiring manager or recruiter |
| After phone screen | Same day or next morning | Thank-you email referencing specific discussion point |
| After technical interview | Within 24 hours | Thank-you to each interviewer with personalized detail |
| After final round | Within 24 hours | Thank-you + reiterate enthusiasm with specific reasons |
| No response to follow-up | 7-10 business days | One final polite check-in, then move on |

---

## Regional Conventions

| Region | Resume Length | Photo | Format | Key Differences |
|--------|-------------|-------|--------|-----------------|
| US/Canada | 1 page (<10yr exp) | Never | "Resume" | No age, marital status, or personal details |
| UK | 2 pages OK | Rarely | "CV" | Include nationality/visa status if relevant |
| EU/Nordics | 2 pages OK | Common | "CV" | Include languages spoken, sometimes nationality |
| Remote/Global | 1-2 pages | Optional | Either | Emphasize timezone flexibility, async communication, remote tooling |
