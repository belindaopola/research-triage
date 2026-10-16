# Research & Engineering Triage Engine

A small full-stack app built with [Jac](https://www.jaseci.org/). You enter a research note or engineering bug report, an LLM classifies it, and the result is saved as a node in a graph. The UI lists open items, lets you filter them by priority, and lets you mark them resolved.

## Features

- **Automatic triage:** Each note is classified into a category, given a priority from 1 (lowest) to 5 (critical blocker), and assigned one concrete next action.
- **Categories:** `LITERATURE_REVIEW`, `DATA_PIPELINE`, `MODEL_TRAINING`, `BUG_FIX`
- **Graph storage:** Tasks are stored as nodes in Jac's object-spatial graph.
- **Priority filter:** Show all open tasks, medium and high (3+), or critical only (4+).
- **Resolve:** Mark a task done. It disappears from the list but stays in the graph.

## Project structure

| File | Purpose |
| --- | --- |
| `main.jac` | Client UI (React-style JSX) and layout |
| `core.jac` | Types, the LLM-backed `evaluate_note` function, graph node, and walkers |
| `style.css` | Dark theme styling |
| `jac.toml` | Project config, including the default LLM model |
| `AGENTS.md` | Notes for AI coding agents working in this project |

## Requirements

- [Jac](https://www.jaseci.org/) installed (`jac` on your PATH)
- An API key for the LLM provider configured in `jac.toml`. The default is Google Gemini, which needs a key from [Google AI Studio](https://aistudio.google.com/).

## Setup

1. Clone the repository and enter the project folder.

2. Set your API key as an environment variable. Do not put the key in the code or commit it.

   ```bash
   export GEMINI_API_KEY="your-key-here"
   ```

   To keep the key across sessions, add this line to your shell profile, or store it in a `.env` file listed in `.gitignore`.

3. Choose a model in `jac.toml`:

   ```toml
   [byllm.model]
   default_model = "gemini/gemini-3.8-flash"
   ```

   Use a current model name from your provider's model list. Model names change over time, and older ones may be retired.

4. Start the app:

   ```bash
   jac run --serve main.jac
   ```

5. Open http://localhost:8000 in your browser.

## Usage

1. Type a note in the input box, for example `Fix exploding gradients in MCMC sampler`.
2. Press **Enter** or click **Triage & Persist**.
3. Review the category, priority, and suggested next action on the new card.
4. Use the priority dropdown to filter the list.
5. Click **Resolve** when a task is done.

## How it works

1. `ingest_task` receives the note and calls `evaluate_note`.
2. `evaluate_note` is declared with `by llm()`, so byllm sends the note to the configured model and parses the response into a `TriageAssessment`.
3. A `TaskNode` is created and attached to the graph.
4. `list_tasks` returns unresolved tasks at or above the selected priority.
5. `resolve_task` marks a task as resolved.

## Troubleshooting

- **`API key not valid` or `key=None` in the logs:** The key isn't set in the environment the server runs in. Export it in the same terminal, then restart the server.
- **`404 ... no longer available`:** The model name in `jac.toml` is retired. Update it to a current model.
- **`503 ... high demand`:** The provider is overloaded. Wait and try again, or switch models.
- **Tasks disappear after restart:** Storage is tied to the running server. Check how your Jac version persists graph data before relying on it.

## Limitations

- Every note makes one LLM call, so each submission costs API usage.
- The LLM's output is not reviewed. A wrong category or priority is saved as returned.
- The app takes manual input only. It doesn't read files, email, or issue trackers.
- Each list or resolve request scans all task nodes, which will slow down with a large number of tasks.

## License

Absent
