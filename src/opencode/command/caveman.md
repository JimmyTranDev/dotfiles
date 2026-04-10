---
name: caveman
description: Activate caveman mode to cut ~75% of output tokens while keeping full technical accuracy
---

Load the **caveman** skill and activate caveman communication mode.

If user provides an intensity level argument ($ARGUMENTS), use that level. Otherwise default to **full**.

Valid levels: `lite`, `full`, `ultra`, `wenyan-lite`, `wenyan`, `wenyan-ultra`.

After loading the skill, confirm activation in caveman-speak at the selected level. Example:

- lite: "Caveman mode active (lite). Responses will be concise but grammatically complete."
- full: "Caveman mode on. Level: full. Less word, same brain."
- ultra: "Caveman: ultra. Max compress."

To deactivate: user says "stop caveman" or "normal mode".
