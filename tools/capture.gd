# Runs the game, starts the race, saves screenshots at set times, then quits.
# Needs a real window (not --headless) so there is something to capture.
#
# Usage:
#   godot --path . -s res://tools/capture.gd -- --out=<folder> --times=0,2,5,10
# Options:
#   --betting       stay in the betting round instead of starting the race
#   --bet=RED:200   place a bet for the local player before the race starts
extends SceneTree

func _initialize():
	var out_dir = ProjectSettings.globalize_path("user://captures")
	var times = [0.0, 2.0, 5.0, 10.0]
	var start = true
	var bet = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
		elif arg.begins_with("--times="):
			times = Array(arg.trim_prefix("--times=").split(",")).map(func(t): return float(t))
		elif arg == "--betting":
			start = false
		elif arg.begins_with("--bet="):
			bet = arg.trim_prefix("--bet=")
	DirAccess.make_dir_recursive_absolute(out_dir)

	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	# The scene isn't ready until the main loop runs its first frame
	await process_frame
	if bet:
		var parts = bet.split(":")
		var session = root.get_node("RaceSession")
		session.place_bet(session.LOCAL_PLAYER_ID, Racer.DotColor[parts[0].to_upper()], int(parts[1]))
	if start:
		game.start_race()

	var elapsed = 0.0
	for t in times:
		if t > elapsed:
			await create_timer(t - elapsed).timeout
			elapsed = t
		await RenderingServer.frame_post_draw
		var path = out_dir.path_join("t%05.1fs.png" % t)
		root.get_texture().get_image().save_png(path)
		print("Saved ", path)

	quit()
