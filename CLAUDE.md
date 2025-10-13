# Claude Code Project Setup

## Version Control
* Whenever code changes are made, you must:
   1. Record a one-line description with emoji in korean of the change in `.commit_message.txt` with Edit Tool.
      - Read `.commit_message.txt` first, and then Edit.
      - Overwrite regardless of existing content.
      - If it was a git revert related operation, make the .commit_message.txt file empty.
   2. Create a git commit immediately after completing each task.
      - Use the message from `.commit_message.txt` as the commit message.
      - Run: `git add . && git commit -m "$(cat .commit_message.txt)"`
      - Always commit after completing a logical unit of work, not at the end of multiple tasks.
