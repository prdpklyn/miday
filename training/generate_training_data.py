import json
from function_schema import MYDAY_FUNCTIONS

BASE_EXAMPLES = [
    {"input": "Schedule dentist tomorrow at 2pm", "output": "add_event", "args": {"title": "Dentist", "date": "tomorrow", "start_time": "14:00"}},
    {"input": "Meeting with John on Friday 3 to 4pm at the office", "output": "add_event", "args": {"title": "Meeting with John", "date": "Friday", "start_time": "15:00", "end_time": "16:00", "location": "the office"}},
    {"input": "Move the dentist to Thursday", "output": "reschedule_event", "args": {"event_ref": "dentist", "new_date": "Thursday"}},
    {"input": "Cancel my meeting with John", "output": "cancel_event", "args": {"event_ref": "meeting with John"}},
    {"input": "Remind me to call mom", "output": "add_task", "args": {"title": "Call mom"}},
    {"input": "Add high priority task to review the contract by Friday", "output": "add_task", "args": {"title": "Review the contract", "due_date": "Friday", "priority": "high"}},
    {"input": "I finished the report", "output": "complete_task", "args": {"task_ref": "report"}},
    {"input": "Push the contract review to next week", "output": "defer_task", "args": {"task_ref": "contract review", "new_date": "next week"}},
    {"input": "Remind me to bring insurance card for the dentist appointment", "output": "add_task", "args": {"title": "Bring insurance card", "linked_event": "dentist appointment"}},
    {"input": "Note ask about ultrasound schedule", "output": "create_note", "args": {"content": "Ask about ultrasound schedule"}},
    {"input": "Note for the John meeting discuss Q2 budget", "output": "create_note", "args": {"content": "Discuss Q2 budget", "linked_event": "John meeting"}},
    {"input": "Add to that note: make sure to ask about pricing", "output": "append_note", "args": {"note_ref": "last", "content": "Make sure to ask about pricing"}},
    {"input": "Find my notes about budget", "output": "search_notes", "args": {"query": "budget"}},
    {"input": "What's on my plate today", "output": "list_today", "args": {}},
    {"input": "Show me tomorrow's schedule", "output": "list_today", "args": {"include_tasks": False, "include_notes": False}},
    {"input": "What do I have with John", "output": "search_all", "args": {"query": "John"}},
]

TASK_VERBS = ["Add", "Create", "Remember to", "Remind me to", "Put down"]
TASK_TITLES = ["buy milk", "email Sarah", "book flight", "submit report", "call the bank", "renew passport"]
EVENT_VERBS = ["Schedule", "Book", "Add", "Set up"]
EVENT_TITLES = ["dentist", "team sync", "coffee with Alex", "project review", "therapy", "design review"]
NOTE_VERBS = ["Note", "Write down", "Remember", "Capture"]
NOTE_CONTENTS = ["follow up on invoice", "ask about timeline", "ideas for Q3 goals", "meeting summary", "client feedback"]
QUERY_PHRASES = ["What do I have", "Show me", "List", "Find"]
DATES = ["today", "tomorrow", "Friday", "next week", "Monday"]
TIMES = ["9am", "10am", "2pm", "3:30pm", "5pm"]


def build_output(function_name, args):
    args_json = ",".join([f"{k}:<escape>{json.dumps(v) if isinstance(v, list) else v}<escape>" for k, v in args.items()])
    return f"<start_function_call>call:{function_name}{{{args_json}}}<end_function_call>"


def generate_examples():
    examples = []
    for base in BASE_EXAMPLES:
        examples.append({"input": base["input"], "output": build_output(base["output"], base["args"])})
    for verb in TASK_VERBS:
        for title in TASK_TITLES:
            examples.append({"input": f"{verb} {title}", "output": build_output("add_task", {"title": title.title()})})
    for verb in EVENT_VERBS:
        for title in EVENT_TITLES:
            for date in DATES:
                for time in TIMES:
                    examples.append({"input": f"{verb} {title} {date} at {time}", "output": build_output("add_event", {"title": title.title(), "date": date, "start_time": time})})
    for verb in NOTE_VERBS:
        for content in NOTE_CONTENTS:
            examples.append({"input": f"{verb} {content}", "output": build_output("create_note", {"content": content.capitalize()})})
    for phrase in QUERY_PHRASES:
        for date in DATES:
            examples.append({"input": f"{phrase} {date}", "output": build_output("list_today", {"include_tasks": True, "include_notes": False})})
    return examples


def write_jsonl(examples, path):
    with open(path, "w", encoding="utf-8") as file:
        for example in examples:
            file.write(json.dumps(example) + "\n")


def main():
    examples = generate_examples()
    if len(examples) < 500:
        raise RuntimeError(f"Expected at least 500 examples, got {len(examples)}")
    write_jsonl(examples, "training_data.jsonl")
    print(f"Wrote {len(examples)} examples")
    print(f"Functions: {len(MYDAY_FUNCTIONS)}")


if __name__ == "__main__":
    main()
