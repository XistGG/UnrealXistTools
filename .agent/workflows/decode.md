---
description: Analyze usage of specific files across the workspace to understand dependencies and invocation patterns.
---

1.  **Identify Target Files**:
    -   Review the user's prompt to extract the list of filenames to be analyzed.
    -   If no files are specified, ask the user to provide them.

2.  **Inspect Source Definitions**:
    -   For each target file, use `view_file` to read its content.
    -   Focus on the `param(...)` block (for PowerShell) or main function entry points to understand the accepted arguments and expected inputs.
    -   Note down the required and optional parameters.

3.  **Search for References**:
    -   Use `grep_search` to find all occurrences of each target filename in the workspace.
    -   Search for the filename exactly, and if it's a script (e.g., `.ps1`), also search for its name without the extension if it might be called that way (though less common in PS without generic helpers).
    -   *Tip*: Use a broad query initially to capture all references.

4.  **Analyze Invocation Context**:
    -   For every search match found:
        -   Use `view_file` to read the specific lines of code where the file is referenced (e.g., +/- 5 lines).
        -   Analyze how the file is being invoked:
            -   **Arguments**: specific values or variables passed to the parameters.
            -   **Method**: `&` (call operator), `.` (dot-source), or direct execution.
            -   **Context**: Is it inside a loop? Condition? Pipeline?

5.  **Compile Usage Report**:
    -   Create a detailed Markdown report summarizing the findings.
    -   Structure the report by Target File.
    -   **Linking Requirement**:
        -   The report will be saved in `Docs/decode/`. Links to source files in the root must be prefixed with `../../`.
        -   Every mention of a **File** must be linked to its source location. Example: `[UEngine.ps1](../../UEngine.ps1)`.
        -   Every mention of a **Class** or **Function** must be linked to its definition if known.
    -   For each file, include:
        -   **Definition**: Summary of parameters/inputs.
        -   **Usages**: A table or list of files calling this target.
        -   **Invocation Details**: Code snippets demonstrating the exact calls being made, highlighting the arguments used.
        -   **Observations**: Any potential issues, hardcoded paths, or unusual patterns detected.

6.  **Save Report**:
    -   For each analyzed file, verify the report content is complete.
    -   Construct the save path: `Docs/decode/<TargetFilename>.md` (e.g., `Docs/decode/UEngine.ps1.md`).
    -   **Path Formatting**: When referencing the location of the file being analyzed (e.g., in the "Definition" section), use the path **relative to the workspace root** (e.g., `UEngine.ps1` or `Modules/UE.psm1`), NOT the absolute path.
    -   Use `write_to_file` to save the report to this path. Overwrite if it exists.

7.  **Render Report**:
    -   Return the full Markdown content of the report as the final response to the user.
