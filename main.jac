import "./styles.css";

# 1. Define Semantic Meaning Types for the LLM
enum Category {
    LITERATURE_REVIEW,
    DATA_PIPELINE,
    MODEL_TRAINING,
    BUG_FIX
}

obj TriageAssessment {
    has category: Category;
    has priority_score: int;
    has actionable_next_step: str;
}

sem TriageAssessment.priority_score = "Urgency score from 1 (lowest) to 5 (critical blocker)";
sem TriageAssessment.actionable_next_step = "A concrete, 1-sentence technical next action";

"""Analyze a raw engineering or research note and return a structured triage assessment."""
def evaluate_note(raw_note: str) -> TriageAssessment by llm();


# 2. Define the Persistent Spatial Graph Node & Shared UI Data Model
node TaskNode {
    has raw_note: str;
    has category: str;
    has priority: int;
    has next_step: str;
    has resolved: bool = False;
}

obj TaskItem {
    has id: str;
    has note: str;
    has category: str;
    has priority: int;
    has next_step: str;
}


# 3. Define Server Walkers (Backend Graph + AI Handlers)
walker:pub ingest_task {
    has raw_note: str;

    can process with Root entry {
        assessment = evaluate_note(self.raw_note);

        task = TaskNode(
            raw_note=self.raw_note,
            category=assessment.category.name,
            priority=assessment.priority_score,
            next_step=assessment.actionable_next_step
        );
        here ++> task;

        report TaskItem(
            id=jid(task),
            note=task.raw_note,
            category=task.category,
            priority=task.priority,
            next_step=task.next_step
        );
    }
}

walker:pub list_tasks {
    has min_priority: int = 1;

    can traverse_root with Root entry {
        visit [-->][?:TaskNode];
    }

    can collect with TaskNode entry {
        if here.priority >= self.min_priority and not here.resolved {
            report TaskItem(
                id=jid(here),
                note=here.raw_note,
                category=here.category,
                priority=here.priority,
                next_step=here.next_step
            );
        }
    }
}

walker:pub resolve_task {
    has task_id: str;

    can traverse_root with Root entry {
        visit [-->][?:TaskNode];
    }

    can mark_done with TaskNode entry {
        if jid(here) == self.task_id {
            here.resolved = True;
            report {"resolved_id": self.task_id};
        }
    }
}


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

    def refresh_tasks {
        result = root spawn list_tasks(min_priority=int(min_prio));
        if result.reports {
            tasks = result.reports;
        } else {
            tasks = [];
        }
    }

    def handle_submit {
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

    def handle_resolve(tid: str) {
        root spawn resolve_task(task_id=tid);
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
                onChange={lambda (e: any) { note_input = e.target.value; }}
                onKeyDown={lambda (e: any) {
                    if e.key == "Enter" { handle_submit(); }
                }}
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
                    onChange={lambda (e: any) {
                        min_prio = e.target.value;
                        refresh_tasks();
                    }}
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