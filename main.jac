import from .core { TaskItem, ingest_task, list_tasks, resolve_task }

import "./style.css";

# 4. Full-Stack Client GUI Component
def:pub app -> JsxElement {
    has tasks: list[TaskItem] = [];
    has note_input: str = "";
    has min_prio: str = "1";
    has loading: bool = False;
    has status_msg: str = "";

    can with entry {
        refresh_tasks();
    }

    async def refresh_tasks {
        result = root spawn list_tasks(min_priority=int(min_prio));
        if result.reports {
            tasks = result.reports;
        } else {
            tasks = [];
        }
    }

    async def handle_submit {
        if not note_input.strip() {
            return;
        }
        loading = True;
        status_msg = "Synthesizing LLM triage & mutating graph...";
        try {
            result = root spawn ingest_task(raw_note=note_input);
            if result.reports and len(result.reports) > 0 {
                tasks = [result.reports[0]] + tasks;
            }
            note_input = "";
            status_msg = "";
        } except Exception as e {
            status_msg = f"Error: {e}";
        }
        loading = False;
    }

    async def handle_resolve(tid: str) {
        root spawn resolve_task(task_id=tid);
        refresh_tasks();
    }

    def handle_note_input(e: ChangeEvent) {
        note_input = e.target.value;
    }

    def handle_note_key(e: KeyboardEvent) {
        if e.key == "Enter" {
            handle_submit();
        }
    }

    def handle_filter_change(e: ChangeEvent) {
        min_prio = e.target.value;
        refresh_tasks();
    }

    return <div className="container">
        <div className="header">
            <h1>Research & Engineering Triage Engine</h1>
            <p>Object-Spatial Graph Memory + Meaning-Typed AI (by llm)</p>
        </div>

        <div className="input-card">
            <input
                type="text"
                placeholder="Enter a research note or bug (e.g., 'Fix exploding gradients in MCMC sampler')..."
                value={note_input}
                onChange={handle_note_input}
                onKeyDown={handle_note_key}
            />
            <button
                className="btn-primary"
                disabled={loading}
                onClick={lambda { handle_submit(); }}
            >
                {("Triaging..." if loading else "Triage & Persist")}
            </button>
        </div>

        {(<p style={{"color": "#38bdf8"}}>{status_msg}</p> if status_msg else None)}

        <div className="filter-bar">
            <span>Active Graph Nodes: <strong>{len(tasks)}</strong></span>
            <div>
                <label>Min Priority Filter: </label>
                <select
                    value={min_prio}
                    onChange={handle_filter_change}
                >
                    <option value="1">1+ (All Tasks)</option>
                    <option value="3">3+ (Medium & High)</option>
                    <option value="4">4+ (Critical Only)</option>
                </select>
            </div>
        </div>

        <div>
            {[
                <div key={t.id} className="task-card">
                    <div>
                        <div>
                            <span className="badge">{t.category}</span>
                            <span className={("badge priority-high" if t.priority >= 4 else "badge")}>
                                Priority {t.priority}/5
                            </span>
                        </div>
                        <h3 style={{"margin": "0.6rem 0 0.25rem", "fontSize": "1.05rem"}}>{t.note}</h3>
                        <div className="next-step">
                            <strong>AI Next Action:</strong> {t.next_step}
                        </div>
                    </div>
                    <button
                        className="btn-resolve"
                        onClick={lambda { handle_resolve(t.id); }}
                    >
                        Resolve
                    </button>
                </div>
                for t in tasks
            ]}
        </div>
    </div>;
}
