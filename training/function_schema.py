MYDAY_FUNCTIONS = [
    {
        "type": "function",
        "function": {
            "name": "add_event",
            "description": "Add a calendar event or appointment",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {"type": "string", "description": "Event title"},
                    "date": {"type": "string", "description": "Date (YYYY-MM-DD or relative like 'tomorrow')"},
                    "start_time": {"type": "string", "description": "Start time (HH:MM)"},
                    "end_time": {"type": "string", "description": "End time (HH:MM)"},
                    "location": {"type": "string", "description": "Location"},
                    "attendees": {"type": "array", "items": {"type": "string"}},
                },
                "required": ["title", "date", "start_time"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "reschedule_event",
            "description": "Move an event to a different time",
            "parameters": {
                "type": "object",
                "properties": {
                    "event_ref": {"type": "string", "description": "Reference to event (title or 'the meeting')"},
                    "new_date": {"type": "string"},
                    "new_time": {"type": "string"},
                },
                "required": ["event_ref"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "cancel_event",
            "description": "Cancel/delete an event",
            "parameters": {
                "type": "object",
                "properties": {
                    "event_ref": {"type": "string"},
                },
                "required": ["event_ref"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "add_task",
            "description": "Add a task or reminder",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {"type": "string", "description": "Task description"},
                    "due_date": {"type": "string", "description": "Due date"},
                    "due_time": {"type": "string", "description": "Due time for reminder"},
                    "priority": {"type": "string", "enum": ["low", "medium", "high"]},
                    "category": {"type": "string"},
                    "linked_event": {"type": "string", "description": "Reference to related event"},
                },
                "required": ["title"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "complete_task",
            "description": "Mark a task as done",
            "parameters": {
                "type": "object",
                "properties": {
                    "task_ref": {"type": "string"},
                },
                "required": ["task_ref"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "defer_task",
            "description": "Postpone a task",
            "parameters": {
                "type": "object",
                "properties": {
                    "task_ref": {"type": "string"},
                    "new_date": {"type": "string"},
                },
                "required": ["task_ref", "new_date"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "create_note",
            "description": "Create a quick note",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {"type": "string"},
                    "content": {"type": "string", "description": "Note content"},
                    "tags": {"type": "array", "items": {"type": "string"}},
                    "linked_event": {"type": "string"},
                    "linked_task": {"type": "string"},
                },
                "required": ["content"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "append_note",
            "description": "Add content to existing note",
            "parameters": {
                "type": "object",
                "properties": {
                    "note_ref": {"type": "string"},
                    "content": {"type": "string"},
                },
                "required": ["note_ref", "content"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "search_notes",
            "description": "Search notes by content or tags",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"},
                    "tags": {"type": "array", "items": {"type": "string"}},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "list_today",
            "description": "Show today's schedule, tasks, and notes",
            "parameters": {
                "type": "object",
                "properties": {
                    "include_schedule": {"type": "boolean", "default": True},
                    "include_tasks": {"type": "boolean", "default": True},
                    "include_notes": {"type": "boolean", "default": False},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "search_all",
            "description": "Search across schedule, tasks, and notes",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"},
                    "date_range": {"type": "string"},
                },
                "required": ["query"],
            },
        },
    },
]
