# Local setup (Windows)

The Godot binary is NOT stored in the repository. Each developer sets the path locally.

1. Download Godot 4.5.1 stable (win64) and keep it anywhere outside the repo.
2. Set an environment variable (PowerShell, once; then reopen the terminal):
   `setx GODOT_BIN "<full path to Godot_v4.5.1-stable_win64.exe>"`
3. Open the project: run Godot, press Import, choose `project.godot` in the repo root.
4. Run tests headless: `powershell -File tools/run_tests.ps1`
5. Run the game: `powershell -File tools/run_game.ps1`

Notes for agents: never hardcode a path to Godot. Use `GODOT_BIN`. If it is not set, say so and stop; do not guess.
Cyrillic characters in the path can break some tools; if that happens, move Godot to a path with Latin letters only.
