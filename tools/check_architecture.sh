#!/bin/zsh
set -e

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

## Считает только исполняемые строки, чтобы русская документация не расходовала архитектурный лимит.
check_limit() {
	local file_path="$1"
	local limit="$2"
	local lines
	lines="$(awk 'NF && $0 !~ /^[[:space:]]*#/ { count += 1 } END { print count + 0 }' "$file_path")"
	if (( lines > limit )); then
		print -u2 -- "Architecture limit exceeded: $file_path has $lines lines (max $limit)"
		exit 1
	fi
}

check_limit scripts/game.gd 1100
check_limit scripts/game_core.gd 750
check_limit scripts/game_renderer.gd 450
check_limit scripts/game_context.gd 350
check_limit scripts/systems/level_editor_system.gd 420
check_limit scripts/editor/level_editor_document_store.gd 180
for module in scripts/core/*.gd; do
	check_limit "$module" 260
done
for module in scripts/presentation/*.gd; do
	check_limit "$module" 180
done
for suite in tests/suites/*_suite.gd; do
	check_limit "$suite" 350
done

python3 tools/bump_version.py --check
python3 tools/test_task_batch.py

if rg -n '^func draw_' scripts/game.gd >/dev/null; then
	print -u2 -- "Rendering leaked back into scripts/game.gd"
	exit 1
fi

python3 tools/check_documentation.py
python3 tools/test_documentation.py
python3 tools/test_world_sprite_manifest.py
python3 tools/check_world_sprite_manifest.py
python3 tools/test_optimization_audit.py
python3 tools/test_storage_perf.py
python3 tools/test_sprite_cleanup.py
python3 tools/check_sprite_cleanup.py
python3 tools/project_backlog.py
python3 tools/test_project_backlog.py
python3 tools/test_water_audit.py
python3 tools/visual_backlog.py
python3 tools/test_visual_backlog.py
python3 tools/test_visual_baseline.py
python3 tools/visual_hardware.py verify >/dev/null
python3 tools/test_visual_hardware.py
python3 tools/visual_motion.py verify >/dev/null
python3 tools/visual_motion.py verify-controls >/dev/null
python3 tools/test_visual_motion.py
python3 tools/visual_camera.py check
python3 tools/test_visual_camera.py
python3 tools/test_visual_static.py
python3 tools/visual_coordinates.py verify
python3 tools/test_visual_coordinates.py
python3 tools/camera_quantization.py verify >/dev/null
python3 tools/test_camera_quantization.py
python3 tools/presentation_pose.py verify >/dev/null
python3 tools/test_presentation_pose.py
python3 tools/reference_zoom.py verify >/dev/null
python3 tools/reference_zoom_perf.py verify >/dev/null
python3 tools/test_reference_zoom.py
python3 tools/test_perf_contract.py
python3 tools/perf_contract.py >/dev/null
python3 tools/perf_contract.py --controls --output docs/reports/visual-overhaul/vperf-001/controls >/dev/null
python3 tools/render_order.py >/dev/null
python3 tools/test_render_order.py
python3 tools/grass_methods.py all >/dev/null
python3 tools/test_grass_methods.py
python3 tools/ground_layers.py verify >/dev/null
python3 tools/test_ground_layers.py
python3 tools/meadow_verify.py >/dev/null
python3 tools/test_meadow_ground.py
python3 tools/ground_edge_verify.py >/dev/null
python3 tools/test_ground_edge.py
python3 tools/axial_road_verify.py >/dev/null
python3 tools/test_axial_road.py
python3 tools/road_network_verify.py >/dev/null
python3 tools/test_road_network.py
python3 tools/plaza_verify.py >/dev/null
python3 tools/test_plaza_ground.py
python3 tools/garden_verify.py >/dev/null
python3 tools/test_garden_soil.py
python3 tools/decoration_verify.py >/dev/null
python3 tools/test_decoration_rules.py
python3 tools/terrain_revision_verify.py >/dev/null
python3 tools/test_terrain_revision.py
python3 tools/ground_seasons_verify.py >/dev/null
python3 tools/test_ground_seasons.py
python3 tools/object_command_verify.py >/dev/null
python3 tools/test_object_command.py
python3 tools/village_bench_verify.py >/dev/null
python3 tools/test_village_bench.py
python3 tools/village_street_verify.py >/dev/null
python3 tools/test_village_street.py
python3 tools/village_board_verify.py >/dev/null
python3 tools/test_village_board.py
python3 tools/village_trade_verify.py >/dev/null
python3 tools/test_village_trade.py
python3 tools/pilot_static_audit.py >/dev/null
python3 tools/pilot_static_verify.py >/dev/null
python3 tools/test_pilot_static.py
python3 tools/pilot_pass_verify.py >/dev/null
python3 tools/test_pilot_pass.py
python3 tools/post_motion_verify.py >/dev/null
python3 tools/test_post_motion.py
python3 tools/plant_depth_verify.py >/dev/null
python3 tools/test_plant_depth.py
python3 tools/transient_save_verify.py >/dev/null
python3 tools/test_transient_save.py
python3 tools/foliage_root_verify.py >/dev/null
python3 tools/test_foliage_root.py
python3 tools/foliage_uv_verify.py >/dev/null
python3 tools/test_foliage_uv.py
python3 tools/foliage_wind_verify.py >/dev/null
python3 tools/test_foliage_wind.py
python3 tools/foliage_contact_verify.py >/dev/null
python3 tools/test_foliage_contact.py
python3 tools/foliage_speed_verify.py >/dev/null
python3 tools/test_foliage_speed.py
python3 tools/foliage_recovery_verify.py >/dev/null
python3 tools/test_foliage_recovery.py
python3 tools/shadow_inventory_verify.py >/dev/null
python3 tools/test_shadow_inventory.py
python3 tools/village_fence_verify.py >/dev/null
python3 tools/test_village_fence.py
python3 tools/village_lamp_verify.py >/dev/null
python3 tools/test_village_lamp.py
python3 tools/visual_scale.py verify
python3 tools/test_visual_scale.py
python3 tools/visual_palette.py
python3 tools/test_visual_palette.py
python3 tools/visual_perspective.py
python3 tools/test_visual_perspective.py
python3 tools/visual_edges.py
python3 tools/test_visual_edges.py
python3 tools/visual_density.py
python3 tools/test_visual_density.py
python3 tools/visual_light.py
python3 tools/test_visual_light.py
python3 tools/visual_modules.py
python3 tools/test_visual_modules.py
python3 tools/visual_reuse.py
python3 tools/test_visual_reuse.py
python3 tools/visual_icons.py
python3 tools/test_visual_icons.py
python3 tools/visual_pipeline.py
python3 tools/test_visual_pipeline.py
python3 tools/visual_resources.py
python3 tools/test_visual_resources.py
python3 tools/visual_sampling.py
python3 tools/test_visual_sampling.py
python3 tools/padded_atlases.py
python3 tools/test_padded_atlases.py
python3 tools/texture_intents.py
python3 tools/test_texture_intents.py
python3 tools/item_sizes.py
python3 tools/test_item_sizes.py
python3 tools/preview_portability.py
python3 tools/test_preview_portability.py
python3 tools/alpha_audit.py
python3 tools/test_alpha_audit.py
python3 tools/test_alpha_proof.py
python3 tools/slice_audit.py
python3 tools/test_slice_audit.py
python3 tools/test_slice_proof.py
python3 tools/asset_migration.py
python3 tools/test_asset_migration.py
python3 tools/test_migration_proof.py
python3 tools/asset_report.py
python3 tools/test_asset_report.py
python3 tools/test_asset_pack_proof.py
python3 tools/pilot_rollout.py
python3 tools/test_pilot_rollout.py
python3 tools/artist_packet.py
python3 tools/test_artist_packet.py
python3 tools/shore_kit.py
python3 tools/test_shore_kit.py
python3 tools/analyze_visual_baseline.py docs/reports/visual-overhaul/vbase-001/native >/dev/null
git diff --check
print -- "ARCHITECTURE: boundaries and whitespace are valid"
