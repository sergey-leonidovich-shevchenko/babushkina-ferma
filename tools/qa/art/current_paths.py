"""Разделяет прежние логические имена proof и текущие физические пути art-standard."""
from pathlib import Path, PurePosixPath
from types import MappingProxyType

_NAMES = (
    'test_visual_density.py', 'test_visual_edges.py', 'test_visual_light.py', 'test_visual_modules.py',
    'test_visual_palette.py', 'test_visual_perspective.py', 'test_visual_reuse.py', 'test_visual_scale.py',
    'visual_density.py', 'visual_density_capture.gd', 'visual_density_capture.gd.uid',
    'visual_edges.py', 'visual_light.py', 'visual_light_capture.gd', 'visual_modules.py',
    'visual_modules_capture.gd', 'visual_palette.py', 'visual_perspective.py',
    'visual_perspective_export.gd', 'visual_perspective_export.gd.uid', 'visual_reuse.py',
    'visual_reuse_capture.gd', 'visual_reuse_sources.gd', 'visual_scale.py',
    'visual_scale_capture.gd', 'visual_scale_capture.gd.uid',
)
MOVED_PATHS = MappingProxyType({'tools/' + name: 'tools/qa/art/' + name for name in _NAMES})


def _relative(name: str) -> str:
    """Логическое имя не может выводить текущий collector за границы проекта."""
    if (not isinstance(name, str) or not name or PurePosixPath(name).is_absolute()
            or PurePosixPath(name).as_posix() != name or '..' in name.split('/')
            or '.git' in name.split('/') or '\\' in name or ':' in name or '\0' in name):
        raise ValueError('unsafe source name')
    return name


def source_path(root: Path, name: str) -> Path:
    """Только свежий collector разрешает старое имя в физическое место принятого переноса."""
    root = Path(root).resolve()
    path = root / MOVED_PATHS.get(_relative(name), name)
    if not path.resolve().is_relative_to(root):
        raise ValueError('source outside project')
    return path


def captured_paths(names) -> dict[str, str]:
    """Записывает адреса только перемещённых членов, сохраняя исходные ключи sources."""
    return {name: MOVED_PATHS[name] for name in names if _relative(name) in MOVED_PATHS}


def recorded_paths(names, reported) -> dict[str, str]:
    """Старый proof допускает пустую карту; новая карта обязана точно совпадать с известной."""
    expected = captured_paths(names)
    if (type(reported) is not dict or any(type(k) is not str or type(v) is not str for k, v in reported.items())
            or reported not in ({}, expected)):
        raise ValueError('unrecognized source path mapping')
    return dict(reported)
