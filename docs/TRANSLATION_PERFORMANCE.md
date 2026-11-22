# Translation recovery and fast mode (2026-11-21)

Desktop only: Argos local, no text sent to external services. Original books are not edited.

- Completed chapter results are atomically stored in a profile-scoped checkpoint directory under runtime/translation/checkpoints. Same exact exported input, language pair, model identity/version, settings and mode resume automatically. SHA-256 detects corrupt checkpoint content. Cache is retained for recovery; disk usage should be monitored. The old worker cannot recover already translated in-memory chapters.
- The pause button stops the current worker. The in-flight chapter can be repeated; earlier chapters remain. A 20-minute progress watchdog replaces the ineffective whole-book timeout.
- First 20 chapters creates a separate clearly labeled partial copy. Later full translation with identical mode/input uses those checkpoints; reading progress is not automatically migrated from the preview. The full reader is not yet dynamically updated during a job.
- Fast mode is opt-out in the dialog and only batches direct Argos 1.11.0 CPU models using the same beam and decoding parameters via CTranslate2. Other routes and runtime failures fall back to the serial engine. No promise of identical output or linguistic quality.
- Destruking, i7-12700H, Argos 1.11.0/CT2 4.8.5, EN->PT, same 40 real text fragments: 6.355s baseline, 2.798s batch (4 threads), exact 40/40. Three complete chapters (2,738/10,748/20,267 chars): original 5.130/15.298/30.977s, batch 2.759/8.864/18.147s; exact match 1/3. No linguistic review; corpus contents not committed. This is not a 4,616-chapter benchmark.
- GPU visible but CUDA execution fails because cublas64_12.dll cannot load. No global CUDA changes. Keep CPU default. CTS integration remains separate and not implemented.
- Test worker with python tool/test_argos_bridge.py (no translation models needed). Flutter tests, analyze, and CI still required before production.
