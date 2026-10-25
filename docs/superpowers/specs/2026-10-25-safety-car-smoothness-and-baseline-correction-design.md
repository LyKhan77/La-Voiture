# Safety Car smoothness and baseline correction

User authorized planning and execution after observing shaking and reviewing regulatory gaps. This supersedes conflicting details in the original Langkah 5 handoff. Godot 4.7.2 / typed GDScript; no dependencies, track geometry, driver roster, or generated-asset changes.

## Intended result

SC moves continuously through pit merge and peel-off, with camera following the same presented pose. Keep deterministic 20 Hz simulation and existing world `step(delta)` interface. Store previous/current SC coordinates at simulation ticks and interpolate them with the same accumulator alpha as the race cars. Use actual presentation delta and trajectory heading. No simulation change merely to hide jitter.

Deployment remains physical from the pit ramp. Unwrapped `s` is an arc-distance reference, not an SC race lap. Remove the SC position teleport ahead of the leader. Before the leader is collected, SC slows to allow pickup; any nonleader between SC and leader may pass SC only under its green signal, without racing other cars. This minimal pickup permission prevents a deadlock when SC merges in mid-pack; full lapped-car unlap procedures remain out of scope.

The SC period cannot end until its minimum incident hold expires, the track is clear of uncleared retirements/spins, the leader has reached SC and the remaining on-track field forms a queue. Queue gaps <=10 car lengths (46m), excluding cars pitting/retired/finished. Reuse current AI pace controls for controlled rolling restart. A short exhibition uses one minimum SC leader lap; actual safety/queue conditions can extend it. No mandatory F1 two-lap rule is implied.

On withdrawal, amber OFF; green is only pickup pass permission. `IN THIS LAP` is announced only when that lap's complete pit approach is still ahead. SC peels off and waits within pit asphalt. At GREEN, each car remains unable to race/overtake until it individually crosses its scheduled restart control line. A caution present at the start of the final lap, without a completed pit withdrawal enabling restart at that line, ends under caution; no GREEN at the chequered flag.

## Verification and limits

Meaningful failing tests before fixes: render movement at 30/60/120 Hz, no 20Hz freeze pattern; first-frame spawn; route yaw; camera relative stability; actual delta; pickup bypass signal; uncleared incident and incomplete queue block withdrawal; late withdrawal call; individual restart and no-overtake enforcement; caution finish; renewed incident.

Run all existing 34 suites (extend existing SC suite rather than create another), real native 1080p/High 20-car race to podium/HQ, fresh images and a motion recording when local tooling supports it, zero orphan check, measured performance with no concurrent headless suite. Preserve historical evidence. Report actual performance rather than assuming jitter repair closes the previously failed 60FPS gate.

Reference: FIA 2026 F1 Section B Sporting, Issue09, 01-Oct-2026, B5.13.1–B5.13.8: https://api.fia.com/system/files/documents/fia_2026_f1_regulations_-_section_b_sporting_-_iss_09_-_2026-10-01.pdf . This is an indie baseline adaptation, not full F1 homologation.
