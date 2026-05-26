---
name: leetcode
description: Generate a LeetCode-style DSA problem, walk through solving it step-by-step, and save the solution to ~/notes
---

Usage: /leetcode [$ARGUMENTS]

Generate a realistic LeetCode-style data structures and algorithms problem, then guide the user through a structured solution. If `$ARGUMENTS` specifies a topic or difficulty, use it; otherwise pick a random problem.

## Output

Two tiers:

**Tier 1 (CLI output)**: Problem statement. Then each solution step is presented, the user answers, and you provide the model answer after each step. This is what the user sees interactively.

**Tier 2 (saved file)**: The full problem + solution written to `~/Programming/JimmyTranDev/notes/leetcode/<topic>/<YYYY-MM-DD>.md`. Create directories if they don't exist.

## Workflow

### 1. Select the problem

If `$ARGUMENTS` specifies a topic (e.g., "binary search", "graphs", "dynamic programming") and/or difficulty ("easy", "medium", "hard"), filter accordingly. If empty, randomly select a category and difficulty.

Problem pool by category:

**Arrays & Hashing**: Two Sum, Contains Duplicate, Valid Anagram, Group Anagrams, Top K Frequent Elements, Product of Array Except Self, Longest Consecutive Sequence, Encode and Decode Strings

**Two Pointers**: Valid Palindrome, 3Sum, Container With Most Water, Trapping Rain Water

**Sliding Window**: Longest Substring Without Repeating Characters, Longest Repeating Character Replacement, Minimum Window Substring, Sliding Window Maximum

**Stack**: Valid Parentheses, Min Stack, Evaluate Reverse Polish Notation, Generate Parentheses, Daily Temperatures, Car Fleet, Largest Rectangle in Histogram

**Binary Search**: Binary Search, Search in Rotated Sorted Array, Find Minimum in Rotated Sorted Array, Time Based Key-Value Store, Median of Two Sorted Arrays, Koko Eating Bananas

**Linked List**: Reverse Linked List, Merge Two Sorted Lists, Linked List Cycle, Reorder List, Remove Nth Node From End of List, LRU Cache, Merge K Sorted Lists

**Trees**: Invert Binary Tree, Maximum Depth of Binary Tree, Same Tree, Subtree of Another Tree, Lowest Common Ancestor of BST, Binary Tree Level Order Traversal, Validate Binary Search Tree, Kth Smallest Element in BST, Serialize and Deserialize Binary Tree, Construct Binary Tree from Preorder and Inorder

**Tries**: Implement Trie (Prefix Tree), Design Add and Search Words Data Structure, Word Search II

**Heap / Priority Queue**: Find Median from Data Stream, K Closest Points to Origin, Task Scheduler, Design Twitter

**Backtracking**: Subsets, Combination Sum, Permutations, Word Search, Letter Combinations of a Phone Number, N-Queens

**Graphs**: Number of Islands, Clone Graph, Pacific Atlantic Water Flow, Course Schedule, Graph Valid Tree, Number of Connected Components, Alien Dictionary, Cheapest Flights Within K Stops, Word Ladder

**Advanced Graphs**: Min Cost to Connect All Points, Swim in Rising Water, Network Delay Time (Dijkstra), Reconstruct Itinerary

**1-D DP**: Climbing Stairs, House Robber, House Robber II, Coin Change, Maximum Product Subarray, Longest Increasing Subsequence, Word Break, Palindromic Substrings, Decode Ways

**2-D DP**: Unique Paths, Longest Common Subsequence, Edit Distance, Regular Expression Matching, Burst Balloons, Distinct Subsequences

**Greedy**: Jump Game, Jump Game II, Maximum Subarray, Hand of Straights, Gas Station, Partition Labels, Merge Triplets to Form Target

**Intervals**: Insert Interval, Merge Intervals, Non-overlapping Intervals, Meeting Rooms, Meeting Rooms II, Minimum Interval to Include Each Query

**Math & Geometry**: Rotate Image, Spiral Matrix, Set Matrix Zeroes, Happy Number, Plus One, Pow(x, n), Multiply Strings

**Bit Manipulation**: Single Number, Counting Bits, Reverse Bits, Missing Number, Sum of Two Integers

### 2. Present the problem statement

Print a realistic LeetCode-style problem statement including:
- **Title**: problem name
- **Difficulty**: Easy / Medium / Hard (with time guide: 15-20 min / 30-45 min / 45-60 min)
- **Description**: clear problem statement with input/output format
- **Constraints**: size limits, time/memory complexity targets
- **Examples**: 2-3 example test cases with explanations

Then ask: "Ready to start solving?" with options: Yes, walk through it with me; Skip walkthrough, just save the solution; Pick a different problem.

### 3. Walk through the solution step-by-step

For each step, present the question, let the user answer (or skip), then provide the model answer.

**Step 1 — Understand & Clarify**
Ask: "What clarifying questions would you ask? What edge cases do you see?" After user answers, provide model clarifying questions: empty input, duplicate values, negative numbers, overflow, single element, null/undefined handling, expected behavior for invalid input.

**Step 2 — Brute Force Approach**
Ask: "What's the most straightforward brute force solution?" After user answers, show brute force: approach, time complexity, space complexity, code sketch.

**Step 3 — Optimize**
Ask: "How can you optimize? What patterns or data structures apply?" After user answers, walk through optimization: recognize the pattern (sliding window, two pointers, DP subproblem, graph traversal, etc.), derive the optimal algorithm, explain the intuition.

**Step 4 — Walk Through an Example**
Ask: "Walk through the optimal solution on one of the examples." After user answers, show a detailed step-by-step trace of the algorithm on a concrete example, showing intermediate state at each step.

**Step 5 — Code the Solution**
Ask: "Write the solution code." After user answers, provide clean, well-commented solution code in Python (or the language from `$ARGUMENTS` if specified). Include time and space complexity analysis.

**Step 6 — Test Cases**
Ask: "What test cases would you run?" After user answers, provide a test suite: base cases, edge cases, large inputs, edge of constraints, the given examples.

**Step 7 — Alternative Approaches**
Ask: "What other approaches could work? What are the tradeoffs?" After user answers, discuss alternative solutions: different data structures, iterative vs recursive, in-place vs extra memory, and their complexity tradeoffs.

### 4. Save the solution

Write the full problem + model solution to `~/Programming/JimmyTranDev/notes/leetcode/<category>/<YYYY-MM-DD>.md` with YAML frontmatter:

```yaml
---
title: <problem title>
category: <category>
difficulty: <easy|medium|hard>
complexity_time: <Big O>
complexity_space: <Big O>
date: <YYYY-MM-DD>
tags: [<pattern 1>, <pattern 2>]
---
```

The saved file structure:
- **Problem**: full statement with constraints and examples
- **Clarifying Questions**: edge cases and assumptions
- **Brute Force**: approach, complexity, code
- **Optimal Solution**: approach, intuition, complexity analysis, clean code
- **Walkthrough**: step-by-step trace on an example
- **Test Cases**: comprehensive test suite
- **Alternative Approaches**: other solutions with tradeoffs

At the end of CLI output, print: `Full solution saved to ~/Programming/JimmyTranDev/notes/leetcode/<category>/<YYYY-MM-DD>.md`

### 5. Offer next steps

- "Would you like to try another problem?" → restart from step 1
- "Done" → exit

## Rules

- Make problems realistic — match the style and quality of actual LeetCode problems
- Difficulty guide: Easy (solved with one clear pattern), Medium (combines 2 patterns or one non-obvious insight), Hard (multiple layered patterns or advanced algorithm)
- When user specifies a language in `$ARGUMENTS` (e.g., "typescript", "java", "python", "rust"), use that language for code samples
- Default to Python if no language specified (most readable for DSA)
- When the user skips a step, still show the model answer
- If the saved file already exists for the same date, overwrite it
- After saving the solution, commit and push the notes repo: `git -C ~/Programming/JimmyTranDev/notes add -A && git -C ~/Programming/JimmyTranDev/notes commit -m "leetcode(<problem>): solution <YYYY-MM-DD>" && git -C ~/Programming/JimmyTranDev/notes push`
