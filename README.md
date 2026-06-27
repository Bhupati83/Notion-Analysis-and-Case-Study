# 📊 Notion — End-to-End Product & Business Analyst Portfolio

> A complete BA/PM portfolio project analysing Notion (B2B SaaS, $11B valuation) —
> from market research to a production-grade PRD — built to demonstrate real-world
> analyst skills for entry-level Product Analyst and Business Analyst roles.

---

## 🧭 Project Overview

| Attribute       | Detail                                      |
|-----------------|---------------------------------------------|
| **Company**     | Notion (notion.so)                          |
| **Industry**    | B2B SaaS — Workspace & Productivity         |
| **Valuation**   | $11 Billion (2026)                          |
| **Role Target** | Product Analyst / Business Analyst          |
| **Tools Used**  | SQL (PostgreSQL), MS Word, PowerPoint       |
| **Completed**   | June 2026                                   |

---

## ❓ The Business Problem

Notion's Plus plan ($10/user/month) churns at **4.2% per month** — more than double
the Business plan rate (1.8%) and nearly 10x the Enterprise rate (0.5%).

This means Notion loses approximately **$168 million in annual recurring revenue**
from users it has already acquired — a leaky bucket that caps mid-market growth
even while the company continuously acquires new free-to-paid conversions.

**Root cause identified:** Notion AI — the #1 retention driver (AI users churn 38% less)
— is locked behind the Business tier ($18/user/month), creating an 80% price jump
with no intermediate option. 34% of Plus churners cite this directly.

---

## 🗂️ Project Structure

```
notion-ba-pm-portfolio/
│
├── README.md
│
├── phase1-market-analysis/
│   └── Notion_Phase1_Business_Market_Analysis.docx
│
├── phase2-data-analysis/
│   ├── Notion_Phase2_Data_Analysis_Report.docx
│   └── Notion_Phase2_SQL_Analysis.sql
│
├── phase3-case-study/
│   └── Notion_Phase3_Case_Study.docx
│
├── phase4-prd/
│   └── Notion_Phase4_PRD.docx
│
└── phase5-executive-summary/
    └── Notion_Phase5_Executive_Deck.pptx
```

---

## 📁 Phase Breakdown

### Phase 1 — Market & Business Analysis
**File:** `phase1-market-analysis/Notion_Phase1_Business_Market_Analysis.docx`

A structured market analysis covering:
- Product overview, business model, and pricing tiers
- Market sizing using the bottom-up method (TAM $57B → SAM $18B → SOM $3–4B)
- Three user personas: Startup Operator, Enterprise IT Buyer, Individual Knowledge Worker
- Competitive matrix: Notion vs Confluence, ClickUp, Coda, Microsoft Loop, Obsidian
- Full SWOT analysis with data-backed points

---

### Phase 2 — Data Analysis & SQL
**Files:**
- `phase2-data-analysis/Notion_Phase2_Data_Analysis_Report.docx`
- `phase2-data-analysis/Notion_Phase2_SQL_Analysis.sql`

Data-driven insights across 6 sections with 18 SQL queries (PostgreSQL):

| Section | Focus |
|---------|-------|
| 1 | Key metrics snapshot (users, MRR, revenue growth with YoY%) |
| 2 | Churn analysis — monthly rate by plan, top churn reasons, cohort analysis |
| 3 | Feature adoption — stickiness score, AI vs non-AI churn correlation |
| 4 | Geographic analysis — ARPU gap, mobile vs desktop by region |
| 5 | Upgrade path — Plus → Business conversion rate vs industry benchmark |
| 6 | Executive dashboard — single query summarising all key metrics |

**SQL techniques used:**
`CTEs` · `Window Functions (LAG, RANK, FIRST_VALUE, SUM OVER)` · `LEFT JOINs`
`CASE WHEN` · `DATE_TRUNC` · `COALESCE` · `NULLIF` · `Subqueries` · `INTERVAL`

**Key findings:**
- Enterprise = 2% of users → 42% of revenue (ARPU 17.5× higher than Plus)
- Plus churn at 4.2%/month = ~$168M annual revenue leakage
- AI users churn 38% less — strongest predictor of retention
- Only 12% of Plus users upgrade to Business (vs 25% SaaS benchmark)
- APAC = 35% of users, 28% of revenue — mobile-first markets under-monetised

---

### Phase 3 — Case Study
**File:** `phase3-case-study/Notion_Phase3_Case_Study.docx`

A structured business case study using the analyst framework:

- **Problem statement** — specific, measurable, scoped
- **Root cause analysis** — 5 Whys applied to the primary driver
- **Three root causes identified:**
  1. Value gap — AI locked in Business tier
  2. Pricing gap — 80% price jump ($10 → $18) with no intermediate option
  3. Mobile gap — 38% mobile adoption despite 80%+ non-US (mobile-first) user base
- **Impact quantification** — $168M leakage modelled; opportunity sized at +$116M ARR
- **Three strategic recommendations** with effort/impact/timeline
- **OKR framework** with measurable key results
- **Risk assessment** — 4 risks with likelihood, impact, and mitigation

---

### Phase 4 — Product Requirements Document (PRD)
**File:** `phase4-prd/Notion_Phase4_PRD.docx`

A production-grade PRD for the recommended feature: **Notion AI for Plus Plan**
*(Internal codename: Project Amber)*

| Section | Content |
|---------|---------|
| Feature overview | One-line summary, background, strategic context |
| Goals & Non-goals | 5 measurable goals; explicit non-goals |
| User personas | Priya (Startup Designer) & Marcus (Engineering Manager) |
| User stories | US-01 to US-04 with full acceptance criteria |
| Functional requirements | FR-01 to FR-12 (entitlement, UI, AI scope) |
| Non-functional requirements | Performance, reliability, scalability, security, i18n, accessibility |
| Edge cases | 7 edge cases with defined resolution |
| Open questions | 5 open questions with owners and target dates |
| Success metrics | Primary KPIs + secondary health indicators + A/B test plan |
| Rollout plan | Alpha → Beta → GA → Mobile with go/no-go criteria |
| Rollback plan | Defined trigger conditions and sign-off process |
| Dependencies | 6 dependencies tracked by team and status |
| Risk register | 5 risks with likelihood, impact, and mitigation |

---

### Phase 5 — Executive Summary Deck
**File:** `phase5-executive-summary/Notion_Phase5_Executive_Deck.pptx`

A 9-slide recruiter-ready presentation with speaker notes:

| Slide | Content |
|-------|---------|
| 1 | Cover |
| 2 | Agenda — 5 phases at a glance |
| 3 | Market Analysis — stats, TAM/SAM/SOM, competitive table |
| 4 | Data Analysis — churn comparison cards, revenue distribution |
| 5 | Case Study — problem statement + 3 root causes |
| 6 | PRD Summary — 4 user stories + key constraints |
| 7 | Recommendations — R1/R2/R3 with impact and timeline |
| 8 | Success Metrics — OKR + KR table + A/B test approach |
| 9 | Portfolio summary — "5 phases. 1 coherent story." |

---

## 💡 Key Recommendations

| Priority | Recommendation | Timeline | Expected Impact |
|----------|---------------|----------|-----------------|
| P0 — Critical | Include Notion AI (20 req/day) in Plus plan | Q3 2026 | −1.5pp churn · +$40M ARR |
| P1 — High | Launch $14 Plus Pro mid-tier | Q4 2026 | −0.8pp churn · +$28M ARPU |
| P2 — Medium | Mobile overhaul for APAC markets | Q1–Q2 2027 | −1.0pp APAC churn · +$22M |

**Combined target:** Plus churn 4.2% → 2.5% · +$116M additional ARR · Plus NPS 28 → 38

---

## 🧠 Skills Demonstrated

| Skill | Where Used |
|-------|-----------|
| Market sizing (TAM/SAM/SOM) | Phase 1 |
| Competitive analysis | Phase 1 |
| User persona creation | Phase 1, Phase 4 |
| SQL data analysis (PostgreSQL) | Phase 2 |
| Churn & cohort analysis | Phase 2 |
| Revenue modelling | Phase 2, Phase 3 |
| Root cause analysis (5 Whys) | Phase 3 |
| Business case writing | Phase 3 |
| OKR definition | Phase 3, Phase 4 |
| PRD writing | Phase 4 |
| User story & acceptance criteria | Phase 4 |
| Edge case identification | Phase 4 |
| A/B test design | Phase 4 |
| Stakeholder presentation | Phase 5 |

---

## 📬 About

This project was built as part of a self-driven BA/PM portfolio to demonstrate
end-to-end analytical and product thinking skills for entry-level roles in B2B SaaS.

All data is simulated based on publicly available information about Notion
(press releases, analyst reports, community data) as of June 2026.
This project is for portfolio and educational purposes only.

---

*If you found this useful, feel free to ⭐ star the repo!*
