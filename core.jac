# Server-side triage backend: semantic types, LLM ability, graph, and walkers.
# Plain .jac with no JSX -> server placement by inference (see jac-fullstack-patterns).
# Commit new changes to the graph and report structured data to the client for UI rendering.

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
