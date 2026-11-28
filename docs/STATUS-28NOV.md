# Status of the 15 items, 28 Nov 2026 (honest)
- iPhone build 382: NOT uploaded. Workflow testflight.yml hard-codes old key 6T836KMTN7 and build 368; the GitHub token has only `repo` scope (no `workflow`), so it cannot be edited. Stopped as instructed.
- Item 1 crash: cause found in Android 2.3.0 notes - large photo decoded at full size ran the phone out of memory (Avatar.kt, fixed with downsampling, shipped in 2.3.x). Not proven on a phone: no emulator here (no KVM, no Java). Could not verify.
- Items 2, 9, 14: proven earlier on the real server.
- Items 3, 4, 15: work only while app is open; closed-app alerts need a server (not built).
- Items 5, 6, 7: proven earlier except iPhone.
- Item 8, 12: research done (RESEARCH-MCP-AND-WORKFORCE.md). App changes not done.
- Items 10, 11, 13: not built.
