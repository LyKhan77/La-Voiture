extends SceneTree

## The first radio card of a race used to cost 13-48 ms (shaping the font's glyphs and building the first draw lists),
## a hitch at the start of every race. The card now draws once with a full alphabet while hidden, so the first real call
## is cheap. The prewarm must leave no trace: card hidden again, original texts back, nothing "present".
## Run: godot --headless --path . -s res://tests/test_radio_cutin_prewarm.gd

const RadioScene := preload("res://scenes/pit_wall/anime_radio_cutin.tscn")

var failures: int = 0


func check(ok: bool, description: String) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var card: CanvasLayer = RadioScene.instantiate()
	root.add_child(card)
	await process_frame
	check(card.has_method("prewarm"), "the radio card can prewarm")
	if card.has_method("prewarm"):
		var speech_before: String = card.speech.text
		card.prewarm()
		check(card.banner.visible and not card.is_present(), "prewarm draws the card (offscreen) without presenting it")
		for _i: int in range(5):
			await process_frame
		check(not card.banner.visible and not card.is_present(), "the card is hidden again after the prewarm")
		check(card.speech.text == speech_before, "the card's text is back to what it was")
		# A real call that arrives mid-prewarm owns the card; the prewarm must not hide it.
		card.prewarm()
		card.play_radio(3, "REAL CALL", false, 5.0)
		for _i: int in range(5):
			await process_frame
		check(card.is_present() and card.banner.visible, "a call that arrives during the prewarm keeps the card up")
		# A card taken out of the tree mid-prewarm (the HUD is dropped at the end of a race) ends its prewarm cleanly.
		var leaving: CanvasLayer = RadioScene.instantiate()
		root.add_child(leaving)
		await process_frame
		leaving.prewarm()
		root.remove_child(leaving)
		for _i: int in range(4):
			await process_frame
		check(int(leaving.get("_prewarm_frames")) == 0, "a prewarm cut short by leaving the tree ends cleanly")
		leaving.free()
	card.queue_free()
	await process_frame
	quit(1 if failures else 0)
