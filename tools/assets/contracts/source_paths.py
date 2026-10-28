"""Отделяет прежние логические имена tools от известных текущих физических адресов."""
from __future__ import annotations

from pathlib import Path, PurePosixPath
from types import MappingProxyType

# Принятые asset71/alpha-slicing19 и один перенесённый performance helper; metadata не выбирает таблицу.
MOVED_PATHS = MappingProxyType({'tools/perf_contract_collect.py': 'tools/qa/performance/perf_contract_collect.py',
 'tools/alpha_audit.py': 'tools/assets/alpha/alpha_audit.py',
 'tools/alpha_capture.gd': 'tools/assets/alpha/alpha_capture.gd',
 'tools/alpha_fixtures.py': 'tools/assets/alpha/alpha_fixtures.py',
 'tools/alpha_metrics.py': 'tools/assets/alpha/alpha_metrics.py',
 'tools/alpha_policy.json': 'tools/assets/alpha/alpha_policy.json',
 'tools/alpha_proof.py': 'tools/assets/alpha/alpha_proof.py',
 'tools/artist_packet.py': 'tools/build/artist_packet.py',
 'tools/asset_costs.py': 'tools/assets/contracts/asset_costs.py',
 'tools/asset_game_probe.gd': 'tools/assets/contracts/asset_game_probe.gd',
 'tools/asset_migration.py': 'tools/assets/migration/asset_migration.py',
 'tools/asset_pack.py': 'tools/build/asset_pack.py',
 'tools/asset_pack_probe.gd': 'tools/build/asset_pack_probe.gd',
 'tools/asset_provenance.json': 'tools/assets/contracts/asset_provenance.json',
 'tools/asset_report.py': 'tools/assets/contracts/asset_report.py',
 'tools/check_sprite_cleanup.py': 'tools/assets/contracts/check_sprite_cleanup.py',
 'tools/check_world_sprite_manifest.py': 'tools/assets/contracts/check_world_sprite_manifest.py',
 'tools/item_export_contract.gd': 'tools/assets/contracts/item_export_contract.gd',
 'tools/item_export_contract.gd.uid': 'tools/assets/contracts/item_export_contract.gd.uid',
 'tools/item_export_contract.py': 'tools/assets/contracts/item_export_contract.py',
 'tools/item_export_contract_review.gd': 'tools/assets/contracts/item_export_contract_review.gd',
 'tools/item_export_contract_review.gd.uid': 'tools/assets/contracts/item_export_contract_review.gd.uid',
 'tools/item_fingerprint_capture.gd': 'tools/assets/contracts/item_fingerprint_capture.gd',
 'tools/item_fingerprint_capture.gd.uid': 'tools/assets/contracts/item_fingerprint_capture.gd.uid',
 'tools/item_icon_contract_review.gd': 'tools/assets/contracts/item_icon_contract_review.gd',
 'tools/item_icon_contract_review.gd.uid': 'tools/assets/contracts/item_icon_contract_review.gd.uid',
 'tools/item_sizes.py': 'tools/assets/contracts/item_sizes.py',
 'tools/item_sizes_capture.gd': 'tools/assets/contracts/item_sizes_capture.gd',
 'tools/item_sizes_review.gd': 'tools/assets/contracts/item_sizes_review.gd',
 'tools/item_ui_fitter.gd': 'tools/assets/contracts/item_ui_fitter.gd',
 'tools/migration_capture.gd': 'tools/assets/migration/migration_capture.gd',
 'tools/migration_fixture.py': 'tools/assets/migration/migration_fixture.py',
 'tools/migration_inventory.py': 'tools/assets/migration/migration_inventory.py',
 'tools/migration_proof.py': 'tools/assets/migration/migration_proof.py',
 'tools/padded_atlas_capture.gd': 'tools/assets/contracts/padded_atlas_capture.gd',
 'tools/padded_atlas_review.gd': 'tools/assets/contracts/padded_atlas_review.gd',
 'tools/padded_atlases.py': 'tools/assets/contracts/padded_atlases.py',
 'tools/preview_portability.py': 'tools/assets/contracts/preview_portability.py',
 'tools/preview_portability_capture.gd': 'tools/assets/contracts/preview_portability_capture.gd',
 'tools/preview_portability_capture.gd.uid': 'tools/assets/contracts/preview_portability_capture.gd.uid',
 'tools/slice_audit.py': 'tools/assets/slicing/slice_audit.py',
 'tools/slice_capture.gd': 'tools/assets/slicing/slice_capture.gd',
 'tools/slice_catalogs.gd': 'tools/assets/slicing/slice_catalogs.gd',
 'tools/slice_export.gd': 'tools/assets/slicing/slice_export.gd',
 'tools/slice_legacy_capture.gd': 'tools/assets/slicing/slice_legacy_capture.gd',
 'tools/slice_metrics.py': 'tools/assets/slicing/slice_metrics.py',
 'tools/slice_policy.json': 'tools/assets/slicing/slice_policy.json',
 'tools/slice_proof.py': 'tools/assets/slicing/slice_proof.py',
 'tools/slice_review.gd': 'tools/assets/slicing/slice_review.gd',
 'tools/sprite_usage_review.gd': 'tools/assets/contracts/sprite_usage_review.gd',
 'tools/sprite_usage_review.gd.uid': 'tools/assets/contracts/sprite_usage_review.gd.uid',
 'tools/test_alpha_audit.py': 'tools/assets/alpha/test_alpha_audit.py',
 'tools/test_alpha_proof.py': 'tools/assets/alpha/test_alpha_proof.py',
 'tools/test_artist_packet.py': 'tools/build/test_artist_packet.py',
 'tools/test_asset_migration.py': 'tools/assets/migration/test_asset_migration.py',
 'tools/test_asset_pack_proof.py': 'tools/build/test_asset_pack_proof.py',
 'tools/test_asset_report.py': 'tools/assets/contracts/test_asset_report.py',
 'tools/test_item_export_contract.py': 'tools/assets/contracts/test_item_export_contract.py',
 'tools/test_item_sizes.py': 'tools/assets/contracts/test_item_sizes.py',
 'tools/test_migration_proof.py': 'tools/assets/migration/test_migration_proof.py',
 'tools/test_padded_atlases.py': 'tools/assets/contracts/test_padded_atlases.py',
 'tools/test_preview_portability.py': 'tools/assets/contracts/test_preview_portability.py',
 'tools/test_slice_audit.py': 'tools/assets/slicing/test_slice_audit.py',
 'tools/test_slice_proof.py': 'tools/assets/slicing/test_slice_proof.py',
 'tools/test_sprite_cleanup.py': 'tools/assets/contracts/test_sprite_cleanup.py',
 'tools/test_texture_intents.py': 'tools/assets/contracts/test_texture_intents.py',
 'tools/test_visual_icons.py': 'tools/assets/contracts/test_visual_icons.py',
 'tools/test_visual_pipeline.py': 'tools/assets/contracts/test_visual_pipeline.py',
 'tools/test_visual_resources.py': 'tools/assets/contracts/test_visual_resources.py',
 'tools/test_visual_sampling.py': 'tools/assets/contracts/test_visual_sampling.py',
 'tools/test_world_sprite_manifest.py': 'tools/assets/contracts/test_world_sprite_manifest.py',
 'tools/texture_data_probe.gd': 'tools/assets/contracts/texture_data_probe.gd',
 'tools/texture_data_room_capture.gd': 'tools/assets/contracts/texture_data_room_capture.gd',
 'tools/texture_intent_review.gd': 'tools/assets/contracts/texture_intent_review.gd',
 'tools/texture_intents.py': 'tools/assets/contracts/texture_intents.py',
 'tools/ui_portability_capture.gd': 'tools/assets/contracts/ui_portability_capture.gd',
 'tools/ui_portability_capture.gd.uid': 'tools/assets/contracts/ui_portability_capture.gd.uid',
 'tools/ui_portability_observer.gd': 'tools/assets/contracts/ui_portability_observer.gd',
 'tools/ui_portability_observer.gd.uid': 'tools/assets/contracts/ui_portability_observer.gd.uid',
 'tools/visual_asset_policy.json': 'tools/assets/contracts/visual_asset_policy.json',
 'tools/visual_icons.py': 'tools/assets/contracts/visual_icons.py',
 'tools/visual_icons_capture.gd': 'tools/assets/contracts/visual_icons_capture.gd',
 'tools/visual_pipeline.py': 'tools/assets/contracts/visual_pipeline.py',
 'tools/visual_pipeline_capture.gd': 'tools/assets/contracts/visual_pipeline_capture.gd',
 'tools/visual_pipeline_review.gd': 'tools/assets/contracts/visual_pipeline_review.gd',
 'tools/visual_resource_capture.gd': 'tools/assets/contracts/visual_resource_capture.gd',
 'tools/visual_resources.py': 'tools/assets/contracts/visual_resources.py',
 'tools/visual_resources_review.gd': 'tools/assets/contracts/visual_resources_review.gd',
 'tools/visual_sampling.py': 'tools/assets/contracts/visual_sampling.py',
 'tools/visual_sampling_capture.gd': 'tools/assets/contracts/visual_sampling_capture.gd',
 'tools/visual_sampling_review.gd': 'tools/assets/contracts/visual_sampling_review.gd'})


def _relative(name: str | Path) -> str:
    """Требует каноническое относительное имя, прежде чем читать путь или выбирать Git alias."""
    if isinstance(name, Path):
        name = name.as_posix()
    if (not isinstance(name, str) or not name or PurePosixPath(name).is_absolute()
            or PurePosixPath(name).as_posix() != name
            or any(part in {'.', '..', '.git'} for part in name.split('/'))
            or '\\' in name or any(ord(c) < 32 or ord(c) == 127 for c in name)):
        raise ValueError('unsafe source path')
    return name


def current_source(root: Path, logical: str | Path) -> Path:
    """Читает строго текущий адрес; оставшийся старый файл не служит fallback."""
    name = _relative(logical)
    root = Path(root).resolve(strict=True)
    if not root.is_dir():
        raise ValueError('source root must be a directory')
    physical = MOVED_PATHS.get(name, name)
    for relative in {name, physical}:
        path = root
        for part in relative.split('/'):
            path /= part
            if path.is_symlink():
                raise ValueError('unsafe source symlink')
    path = root / physical
    if not path.resolve().is_relative_to(root):
        raise ValueError('source outside root')
    return path


def historical_source(available: set[str], logical: str | Path) -> str:
    """Выбирает единственный старый/новый alias из дерева уже закреплённого Git commit."""
    name = _relative(logical)
    aliases = {name, MOVED_PATHS.get(name, name)}
    present = aliases.intersection(available)
    if not present:
        raise FileNotFoundError('historical source missing: ' + name)
    if len(present) != 1:
        raise ValueError('ambiguous historical source: ' + name)
    return present.pop()


def captured_paths(names: tuple[str, ...]) -> dict[str, str]:
    """Записывает известное размещение только для объявленного набора логических исходников."""
    return {name: MOVED_PATHS[name] for name in names}


def recorded_paths(names: tuple[str, ...], reported: object) -> dict[str, str]:
    """Legacy-пустота либо полная известная карта; metadata не может выбрать произвольный файл."""
    expected = captured_paths(names)
    if not isinstance(reported, dict) or reported not in ({}, expected):
        raise ValueError('invalid recorded source paths')
    return dict(reported)
