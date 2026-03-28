# Efficient Agent Instructions for Large Codebases

## Goal
Enable the agent to perform multi-file feature work (e.g., UI changes, logic updates) without loading the entire codebase into context, thus minimizing token usage while ensuring correctness.

## Instructions for the Agent

1. **Never load the entire workspace or all files into context.**
   - Do not read all project files by default.
   - Avoid including large, unrelated files unless explicitly required.

2. **Always start with targeted search:**
   - Use project search (by filename, class, function, or keywords) to locate relevant files and code regions for the user's request.
   - Only read and load the minimal code needed to understand and implement the requested change.

3. **For feature requests (e.g., UI/UX changes, new logic):**
   - Identify all files/components that may be affected (e.g., password input, registration form, user model).
   - Read only those files and only the relevant sections (functions, classes, or components) required for the change.
   - If unsure, ask the user for the filename or location, or use search to find it.

4. **For multi-step or cross-file changes:**
   - Repeat the search-and-read process for each step (e.g., add eye icon to password field, then add password confirmation field).
   - Do not keep unrelated code in context between steps.

5. **When writing or editing code:**
   - Make changes only in the files/sections you have loaded.
   - If a change requires knowledge of another file, search and load only that file/section.

6. **Summarize and confirm:**
   - After making changes, summarize what was changed and in which files.
   - Optionally, ask the user to review or confirm before proceeding to the next step.

7. **If you encounter missing context:**
   - Pause and ask the user for clarification or the location of the relevant code.
   - Do not guess by loading large amounts of code.

## Example Workflow

User request: "I need to add eye icon to my password column that user can see password when they type it. Also we should make that user types pass two times when he's creating account."

- Search for files/components related to registration and password input.
- Read only the registration form and password input code.
- Implement the eye icon toggle in the password field.
- Add a second password input for confirmation.
- Update validation logic (read only the relevant validation code).
- Summarize changes and ask for user review.

---

**Summary:**
- Only search and read what is needed for the task.
- Never load the whole codebase.
- Confirm with the user if unsure.
- This keeps token usage minimal and work efficient.
