// Every team radio call the GT sim can send, matched by regex and spoken in a short form
// (FASE 6). `pattern` is matched against the exact text the sim pushes (PCRE, so it works in
// Godot's RegEx too); numbers and car codes that vary are dropped from the spoken line, so the
// banner shows the full text while the voice stays brisk. Order matters: the first match wins.
// Sources: scripts/gt/gt_driving.gd, gt_contacts.gd, gt_race.gd, gt_weather.gd.

export const VOICES = {
	engineer: { voice: "bm_lewis", speed: 1.05 },
	driver: { voice: "am_eric", speed: 1.05 },
};

// Every driver line is rendered once per driver voice, so each driver keeps one voice and two
// teammates never share one. Casting per field slot lives in RadioVoice.DRIVER_VOICES (Godot);
// this list must hold every voice used there. The id suffix keeps the older clips: am_eric has
// none, af_bella is "_f" (the first female cast), the rest add "_<name>".
export const DRIVER_VOICES = {
	am_eric: "", af_bella: "_f",
	am_michael: "_michael", am_fenrir: "_fenrir", am_puck: "_puck", bm_george: "_george",
	af_heart: "_heart", bf_emma: "_emma",
};
export const DRIVER_SPEED = 1.05;

const COMPOUNDS = ["SOFT", "MEDIUM", "HARD", "INTERMEDIATE", "WET"];
const SECTOR_WORD = { 1: "one", 2: "two", 3: "three" };
const lines = [];

function add(id, speaker, pattern, spoken) {
	if (speaker !== "driver") {
		lines.push({ id, speaker, pattern, spoken });
		return;
	}
	for (const [voice, suffix] of Object.entries(DRIVER_VOICES)) lines.push({ id: `${id}${suffix}`, speaker, pattern, spoken, voice });
}
const word = (compound) => compound.toLowerCase();

// --- engineer ------------------------------------------------------------------------------
add("eng_chequered_p1", "engineer", "^Chequered flag! P1\\. Solid job today\\.$", "Chequered flag! P one. Solid job today.");
add("eng_chequered_p2", "engineer", "^Chequered flag! P2\\. Solid job today\\.$", "Chequered flag! P two. Solid job today.");
add("eng_chequered_p3", "engineer", "^Chequered flag! P3\\. Solid job today\\.$", "Chequered flag! P three. Solid job today.");
add("eng_chequered", "engineer", "^Chequered flag! P\\d+\\. Solid job today\\.$", "Chequered flag! Solid job today.");
add("eng_passing", "engineer", "^Passing \\w+! Excellent drive\\.$", "Great move! Excellent drive.");
add("eng_ecu_limp", "engineer", "^ECU Limp Mode active! Conserve what's left to reach the pit box!$", "E C U limp mode active! Conserve what's left to reach the pit box!");
add("eng_fuel_critical", "engineer", "^Fuel critical! Switch to CONSERVE immediately or we won't see the chequered flag!$", "Fuel critical! Switch to conserve immediately, or we won't see the chequered flag!");
add("eng_good_stop_wing", "engineer", "^Good stop: [\\d.]+s\\. Wing replaced, Out now, watch pit exit\\.$", "Good stop. Wing replaced. Out now, watch pit exit.");
add("eng_good_stop", "engineer", "^Good stop: [\\d.]+s\\. Out now, watch pit exit\\.$", "Good stop. Out now, watch pit exit.");
add("eng_drs_on", "engineer", "^Race Control: DRS has been ENABLED\\.$", "Race Control. D R S has been enabled.");
add("eng_drs_off_wet", "engineer", "^Race Control: DRS DISABLED - WET TRACK\\.$", "Race Control. D R S disabled. Wet track.");
add("eng_drs_off_safety", "engineer", "^Race Control: DRS DISABLED - SAFETY PROTOCOL\\.$", "Race Control. D R S disabled. Safety protocol.");
for (const c of COMPOUNDS) {
	add(`eng_box_${word(c)}`, "engineer", `^Box this lap, confirm ${c} tyres\\.$`, `Box this lap, confirm ${word(c)} tyres.`);
}
add("eng_affirmative", "engineer", "^Affirmative, executing .+\\.$", "Affirmative, executing.");
// Strategy desk calls (decide_strategy) and hybrid tactic cards (_check_hybrid_tactics).
add("eng_strat_rain_wet", "engineer", "^Heavy rain on track \\(\\d+% water\\)\\. Suggest box this lap for WET tyres\\.$", "Heavy rain on track. Suggest box this lap for wet tyres.");
add("eng_strat_damp_inter", "engineer", "^Track is damp \\(\\d+% water\\)\\. Suggest box this lap for INTERMEDIATE tyres\\.$", "Track is damp. Suggest box this lap for intermediate tyres.");
for (const c of ["HARD", "SOFT", "MEDIUM"]) {
	add(`eng_strat_drying_${word(c)}`, "engineer", `^Track drying rapidly \\(\\d+% water\\)\\. Suggest box this lap for ${c} tyres\\.$`, `Track is drying fast. Suggest box this lap for ${word(c)} tyres.`);
}
for (const c of ["HARD", "MEDIUM", "SOFT", "INTERMEDIATE", "WET"]) {
	add(`eng_strat_wear_${word(c)}`, "engineer", `^Tyre wear critical \\(\\d+%\\)\\. Suggest box this lap for ${c} tyres\\.$`, `Tyre wear is critical. Suggest box this lap for ${word(c)} tyres.`);
}
// FASE 32 mandatory stop (GtRace._check_stop_reminders and the stop-window suggestion of GtRace.decide_strategy).
add("eng_mandatory_window", "engineer", "^Mandatory stop window is open\\. Suggest box this lap for \\w+ tyres\\.$", "Mandatory stop window is open. Suggest box this lap.");
add("eng_mandatory_closing", "engineer", "^Window closes in two laps\\. Box now\\.$", "Window closes in two laps. Box now.");
add("eng_fuel_short_box", "engineer", "^Fuel is short\\. Box this lap for fuel\\.$", "Fuel is short. Box this lap for fuel.");
// FASE 32 radio round: what the rules do to the player's cars (GtRace._check_player_calls, _announce_missed_window,
// note_stop_completed, mark_finished and GtStewards._decide).
add("eng_window_missed", "engineer", "^Window missed\\. \\+\\d+ seconds will be added at the flag\\.$", "Window missed. A time penalty will be added at the flag.");
add("eng_window_open_info", "engineer", "^Mandatory stop window is open\\.$", "Mandatory stop window is open.");
add("eng_stop_counts", "engineer", "^Stop counts\\. Mandatory stop complete\\.$", "Stop counts. Mandatory stop complete.");
add("eng_stop_not_counted", "engineer", "^That stop does not count toward the mandatory stop\\.$", "That stop does not count toward the mandatory stop.");
add("eng_last_lap", "engineer", "^Last lap\\. Bring it home\\.$", "Last lap. Bring it home.");
add("eng_steward_penalty", "engineer", "^Steward penalty: \\+\\d+ seconds\\. Serve it in the pit box or it is added at the flag\\.$", "Steward penalty. Serve it in the pit box, or it is added at the flag.");
add("eng_battery_low", "engineer", "^Battery is low\\. Switch ERS to HARVEST to recharge\\.$", "Battery is low. Switch E R S to harvest to recharge.");
add("eng_penalty_note", "engineer", "^Penalty added for the missed mandatory stop: \\+\\d+ seconds\\. The classification will change\\.$", "Penalty added for the missed mandatory stop. The final classification will change.");
// FASE 19 strategist calls (GtRace._strategy_call_text).
add("eng_strat_easing_inter", "engineer", "^Rain easing \\(\\d+% water\\)\\. Suggest box this lap for INTERMEDIATE tyres\\.$", "The rain is easing. Suggest box this lap for intermediate tyres.");
add("eng_strat_cooking", "engineer", "^The (INTERMEDIATE|WET) tyres are cooking on the dry line\\. Box now for \\w+ tyres\\.$", "The rain tyres are cooking on the dry line. Box now, box now!");
for (const c of ["HARD", "SOFT", "MEDIUM", "INTERMEDIATE", "WET"]) {
	add(`eng_tactic_sc_${word(c)}`, "engineer", `^Safety Car deployed! Cheap pit stop window open\\. Suggest box for ${c} tyres\\.$`, `Safety car deployed! Cheap pit stop window open. Suggest box for ${word(c)} tyres.`);
	add(`eng_tactic_vsc_${word(c)}`, "engineer", `^Virtual Safety Car deployed! Cheap pit stop window open\\. Suggest box for ${c} tyres\\.$`, `Virtual safety car deployed! Cheap pit stop window open. Suggest box for ${word(c)} tyres.`);
}
// MANUAL without COACH: the engineer reports the facts and advises nothing (GtRace.suggest_tactic `info`).
add("eng_info_weather", "engineer", "^Track water \\d+%, forecast \\d+% next lap\\.$", "Weather update. Track water and the forecast are on your screen.");
add("eng_info_wear", "engineer", "^Tyre wear at \\d+%\\.$", "Tyre wear is high.");
add("eng_info_temps", "engineer", "^Tyre temps at \\d+ C\\.$", "Tyre temps are high.");
add("eng_info_wing", "engineer", "^Front wing aero damage at \\d+%\\.$", "Front wing aero damage.");
add("eng_info_sc", "engineer", "^Safety Car deployed\\. Tyre wear \\d+%\\.$", "Safety car deployed.");
add("eng_info_vsc", "engineer", "^Virtual Safety Car deployed\\. Tyre wear \\d+%\\.$", "Virtual safety car deployed.");
add("eng_tactic_wing", "engineer", "^Front wing aero damage \\(\\d+%\\)\\. Suggest box this lap to replace wing and tyres\\.$", "Front wing aero damage. Suggest box this lap to replace the wing and tyres.");
add("eng_tactic_full_wet", "engineer", "^Standing water critical \\(\\d+%\\)\\. Suggest box immediately for Full WET tyres!$", "Standing water is critical. Suggest box immediately for full wet tyres!");
add("eng_tactic_inter", "engineer", "^Track damp \\(\\d+% water\\)\\. Suggest box for Intermediate tyres\\.$", "Track is damp. Suggest box for intermediate tyres.");
for (const c of ["HARD", "MEDIUM", "SOFT"]) {
	add(`eng_tactic_dry_${word(c)}`, "engineer", `^Track is dry \\(.+\\)\\. Switch to ${c} slicks!$`, `Track is dry. Switch to ${word(c)} slicks!`);
}
for (const c of ["HARD", "SOFT"]) {
	add(`eng_tactic_wear_${word(c)}`, "engineer", `^Tyre wear at \\d+%\\. Suggest box for ${c} tyres\\.$`, `Tyre wear is high. Suggest box for ${word(c)} tyres.`);
}
add("eng_tactic_temps", "engineer", "^Tyre temps critical \\(\\d+ C\\)\\. Suggest switching pace to LIGHT to cool tyres\\.$", "Tyre temps are critical. Suggest switching pace to light to cool the tyres.");
add("eng_tactic_slipstream", "engineer", "^DRS slipstream behind \\w+ \\(.+\\)! Deploy OVERTAKE ERS to pass\\?$", "D R S slipstream, he's right ahead! Deploy overtake E R S to pass?");
// Weather radar (GtWeather advisories).
add("eng_weather_alert", "engineer", "^Weather radar alert: .+ hitting the circuit! Track water \\d+%, track temp \\d+ C\\.$", "Weather radar alert! Rain is hitting the circuit.");
add("eng_weather_incoming", "engineer", "^Radar update: rain front approaching in about 1 lap \\(wind \\d+ km/h\\)\\. Prepare INTERMEDIATE tyres\\.$", "Radar update: rain front approaching in about one lap. Prepare intermediate tyres.");
add("eng_weather_dry_line", "engineer", "^Dry racing line has formed \\(.+\\)\\. Slick crossover window is OPEN!$", "Dry racing line has formed. Slick crossover window is open!");
// The same radar news without the engineer's advice (MANUAL without COACH).
add("eng_weather_incoming_info", "engineer", "^Radar update: rain front approaching in about 1 lap \\(wind \\d+ km/h\\)\\.$", "Radar update: rain front approaching in about one lap.");
add("eng_weather_dry_line_info", "engineer", "^Dry racing line has formed \\(.+\\)\\.$", "Dry racing line has formed.");
// Race incidents relayed to the player's engineer (GtContacts).
for (const n of [1, 2, 3]) {
	add(`eng_yellow_contact_${n}`, "engineer", `^Yellow Flag Sector ${n}\\. Contact between \\w+ and \\w+\\.$`, `Yellow flag, sector ${SECTOR_WORD[n]}. Contact on track.`);
}
add("eng_sc_stopped", "engineer", "^Safety Car deployed! \\w+ is stopped on track\\. Cheap pit stop window open!$", "Safety car deployed! A car is stopped on track. Cheap pit stop window open!");
for (const n of [1, 2, 3]) {
	add(`eng_yellow_spin_${n}`, "engineer", `^Yellow Flag Sector ${n}\\. Car #\\d+ \\(\\w+\\) spun out\\.$`, `Yellow flag, sector ${SECTOR_WORD[n]}. A car has spun out.`);
}
for (const n of [1, 2, 3]) {
	add(`eng_vsc_${n}`, "engineer", `^Virtual Safety Car deployed! Debris in Sector ${n}\\. Reduce delta\\.$`, `Virtual safety car deployed! Debris in sector ${SECTOR_WORD[n]}. Reduce delta.`);
}
add("eng_sc_wall", "engineer", "^Safety Car deployed! #\\d+ \\(\\w+\\) heavily in the wall\\. Cheap pit stop window open!$", "Safety car deployed! A car is heavily in the wall. Cheap pit stop window open!");
// The marshals have cleared a wreck as the safety car comes in (GtRace._start_wreck_evacuation, FASE 11 Langkah 6).
for (const n of [1, 2, 3]) {
	add(`eng_track_clear_${n}`, "engineer", `^Track clear in Sector ${n}\\. Recovery complete, Safety Car in this lap\\.$`, `Track clear in sector ${SECTOR_WORD[n]}. Recovery complete, safety car in this lap.`);
}

// --- driver --------------------------------------------------------------------------------
// High-drama wheel-to-wheel calls (FASE 8.4): GtDriving.announce_pass / announce_ers_boost, the tyre
// cliff in _wear_and_fuel and GtContacts.announce_rub.
add("drv_pass_made", "driver", "^Pass made on \\w+! Clean move down the inside!$", "Pass made! Clean move down the inside!");
add("drv_lost_spot", "driver", "^Lost the spot to \\w+! Defending now!$", "Lost the spot, defending now!");
add("drv_ers_boost", "driver", "^Deploying ERS boost! Maximum attack!$", "Deploying E R S boost! Maximum attack!");
add("drv_tyres_cooked", "driver", "^Tyres are cooked! Rear is sliding everywhere!$", "Tyres are cooked! Rear is sliding everywhere!");
add("drv_touched_telemetry", "driver", "^We touched with \\w+! Check the telemetry!$", "We touched! Check the telemetry!");
add("drv_touched", "driver", "^We touched with \\w+! Front wing damage!$", "We touched! Front wing damage!");
add("drv_spun_contact", "driver", "^I spun after contact with \\w+! Tyres cooked!$", "I spun after contact! Tyres are cooked!");
add("drv_heavy_crash", "driver", "^Heavy crash! I'm out of the race, suspension sheared off!$", "Heavy crash! I'm out of the race, suspension sheared off!");
for (const sector of [1, 2, 3]) {
	const turn = sector * 4 + 1;
	add(`drv_lost_rear_${turn}`, "driver", `^I lost the rear at Turn ${turn}! Spun out, tyres flat-spotted!$`, `I lost the rear at turn ${turn}! Spun out, tyres flat-spotted!`);
}
add("drv_barrier", "driver", "^Hit the barrier! Front wing is broken, handling like a boat!$", "Hit the barrier! Front wing is broken, handling like a boat!");
add("drv_massive_crash", "driver", "^Massive crash! I'm into the wall, car is destroyed!$", "Massive crash! I'm into the wall, car is destroyed!");
add("drv_oversteer", "driver", "^Had a snap of oversteer! Lost some time\\.$", "Had a snap of oversteer! Lost some time.");
add("drv_engine_died", "driver", "^Engine died! No fuel, no fuel! I'm stopping on the grass!$", "Engine died! No fuel, no fuel! I'm stopping on the grass!");
add("drv_puncture", "driver", "^Puncture! The tyre has delaminated!$", "Puncture! The tyre has delaminated!");
add("drv_blowout", "driver", "^I'm spinning! Tyre blew out on the high speed section!$", "I'm spinning! Tyre blew out on the high speed section!");
add("drv_suspension", "driver", "^Suspension has snapped from the flat tyre! I can't steer, retiring the car!$", "Suspension has snapped from the flat tyre! I can't steer, retiring the car!");

// The driver's spoken acknowledgements of the engineer's calls (GtRadioReplies.driver_ack); two wordings for the common ones.
add("drv_ack_box_a", "driver", "^Copy, box this lap\\.$", "Copy, box this lap.");
add("drv_ack_box_b", "driver", "^Understood, coming in\\.$", "Understood, coming in.");
add("drv_ack_last_a", "driver", "^Last lap, copy\\. Bringing it home\\.$", "Last lap, copy. Bringing it home.");
add("drv_ack_last_b", "driver", "^Copy\\. Everything I have left\\.$", "Copy. Everything I have left.");
add("drv_ack_fuel", "driver", "^Copy, fuel is tight\\. Coming in\\.$", "Copy, fuel is tight. Coming in.");
add("drv_ack_missed", "driver", "^Understood\\. We take the penalty\\.$", "Understood. We take the penalty.");
add("drv_ack_stop_ok", "driver", "^Copy, the stop counts\\.$", "Copy, the stop counts.");
add("drv_ack_stop_no", "driver", "^Understood\\. I need another stop\\.$", "Understood. I need another stop.");
add("drv_ack_steward", "driver", "^Copy\\. I will serve it in the pits\\.$", "Copy. I will serve it in the pits.");
add("drv_ack_battery", "driver", "^Copy, harvesting\\.$", "Copy, harvesting.");
add("drv_ack_penalty_note", "driver", "^Understood\\. I should have boxed\\.$", "Understood. I should have boxed.");
add("drv_finish_win", "driver", "^Yes! We did it! Thank you, team!$", "Yes! We did it! Thank you, team!");
add("drv_finish_podium", "driver", "^Podium! Great job, everyone!$", "Podium! Great job, everyone!");
add("drv_finish_other", "driver", "^Chequered flag\\. Good effort, team\\.$", "Chequered flag. Good effort, team.");

export const LINES = lines;
