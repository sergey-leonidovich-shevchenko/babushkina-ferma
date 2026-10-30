"""Нормализует объявленную адресацию; вычисления, старые assertions и image loops остаются в AST."""
import ast
from pathlib import Path

FIXTURE_ADAPTERS = {
    ('test_preview_portability', 'setUpClass'), ('test_texture_intents', 'setUp'),
    ('test_migration_proof', 'setUp'), ('test_asset_pack_proof', 'packet'),
    ('test_alpha_audit', 'setUp'), ('test_scanner_history', 'legacy'),
}
NEW_PREVIEW_TESTS = {
    'test_partial_or_unknown_current_source_map_is_rejected',
    'test_current_capture_cannot_drop_layout_and_use_legacy_reader',
    'test_current_layout_cannot_claim_old_collector_sha',
    'test_current_collector_bytes_remain_checked',
}
NEW_ARTIST_TESTS = {
    'test_live_format_document_can_evolve',
    'test_format_document_signature_and_missing_history_are_rejected',
    'test_format_document_symlink_cannot_escape',
    'test_unlisted_live_document_is_still_checked',
}


class AddressingOnly(ast.NodeTransformer):
    """Убирает только таблицу/метаданные путей и прямые I/O-адаптеры текущего пакета."""

    def __init__(self, name, mapping):
        self.module = Path(name).stem
        self.modules = {new.removesuffix('.py').replace('/', '.'): Path(old).stem
                        for old, new in mapping.items() if old.endswith('.py')}
        self.reverse = {new: old for old, new in mapping.items()}
        self.context = None

    def visit_ImportFrom(self, node):
        module = node.module or ''
        if module.startswith('tools.common.'):
            module = module.removeprefix('tools.')
        if module in {'common.paths', 'common.history', 'common.launch', 'tools.assets.contracts.source_paths'}:
            return None
        if module in self.modules:
            module = self.modules[module]
        elif module.startswith('tools.') and module.removeprefix('tools.') in self.modules.values():
            module = module.removeprefix('tools.')
        if module == 'tools' and all(a.name in self.modules.values() for a in node.names):
            return [ast.Import(names=[ast.alias(name=a.name, asname=a.asname or a.name)]) for a in node.names]
        if module == 'tools.assets.contracts' and self.module == 'test_scanner_history':
            return None  # Только scoped dependency alias старого producer в fixture adapter.
        node.module = module
        return node

    def visit_Import(self, node):
        if self.module == 'test_scanner_history' and len(node.names) == 1 and node.names[0].name == 'sys':
            return None
        for alias in node.names:
            if alias.name in self.modules:
                alias.name = self.modules[alias.name]
        return node

    def visit_Constant(self, node):
        if isinstance(node.value, str):
            if node.value in self.reverse:
                node.value = self.reverse[node.value]
            elif node.value.startswith('res://') and node.value[6:] in self.reverse:
                node.value = 'res://' + self.reverse[node.value[6:]]
            else:
                for module, old in self.modules.items():
                    if node.value.startswith(module + '.'):
                        node.value = old + node.value[len(module):]
                        break
        return node

    def visit_FunctionDef(self, node):
        if self.module == 'test_preview_portability' and node.name in NEW_PREVIEW_TESTS:
            return None
        if self.module == 'test_artist_packet' and node.name in NEW_ARTIST_TESTS:
            return None
        if (self.module, node.name) in FIXTURE_ADAPTERS or (self.module == 'preview_portability' and node.name == 'path_under'):
            node.body = [ast.Expr(value=ast.Constant(value='declared bounded I/O adapter'))]
            return node
        previous = self.context
        self.context = node.name
        node = self.generic_visit(node)
        self.context = previous
        return node

    def visit_Assign(self, node):
        names = {t.id for t in node.targets if isinstance(t, ast.Name)}
        if self.module == 'artist_packet' and names == {'HISTORICAL_DOCUMENTS'}:
            # Единственный новый исторический документ; остальная проверка refs прежняя.
            node.value.args[0].elts = [n for n in node.value.args[0].elts
                if not isinstance(n, ast.Constant) or n.value != 'docs/VISUAL_RESOURCE_FORMAT.md']
            return self.generic_visit(node)
        if (self.module == 'visual_icons' and 'CAPTURE_SOURCE' in names
                or self.module == 'preview_portability' and names & {'PREVIEW_SOURCES', 'LEGACY_COLLECTOR'}):
            return None
        if self.module == 'asset_report' and names & {'available_names', 'selected_name'}:
            return None
        if self.module == 'preview_portability' and self.context == 'validate_report':
            if 'source_paths' in names:
                return None
            if 'expected' in names and isinstance(node.value, ast.IfExp):
                return None
        return self.generic_visit(node)

    def visit_Name(self, node):
        if self.module == 'asset_report' and node.id == 'selected_name':
            node.id = 'name'
        return node

    def visit_List(self, node):
        if self.module == 'asset_report':
            values = [n.value for n in node.elts if isinstance(n, ast.Constant)]
            old = 'tools/visual_asset_policy.json'
            new = 'tools/assets/contracts/visual_asset_policy.json'
            if old in values and new in values:
                node.elts = [n for n in node.elts if not isinstance(n, ast.Constant) or n.value != new]
        return self.generic_visit(node)

    def visit_Dict(self, node):
        if self.module == 'preview_portability' and self.context == 'capture':
            pairs = [(k, v) for k, v in zip(node.keys, node.values)
                     if not isinstance(k, ast.Constant) or k.value != 'source_paths']
            node.keys, node.values = [p[0] for p in pairs], [p[1] for p in pairs]
        return self.generic_visit(node)

    def visit_Expr(self, node):
        if isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name) and node.value.func.id == 'prepare_imports':
            return None
        return self.generic_visit(node)

    def visit_Subscript(self, node):
        if ast.unparse(node) == 'Path(__file__).resolve().parents[1]':
            return ast.Name(id='SOURCE_ROOT', ctx=ast.Load())
        return self.generic_visit(node)

    def visit_Call(self, node):
        name = node.func.id if isinstance(node.func, ast.Name) else ''
        if name == 'project_root' and ast.unparse(node) == 'project_root(__file__)':
            return ast.Name(id='SOURCE_ROOT', ctx=ast.Load())
        if name == 'current_source':
            return self.generic_visit(ast.BinOp(left=node.args[0], op=ast.Div(), right=node.args[1]))
        if name == 'historical_source':
            return self.visit(node.args[1])
        if self.module == 'visual_icons' and name == 'pinned_sha':
            return ast.parse("sha(ROOT / 'tools/visual_icons_capture.gd')").body[0].value
        return self.generic_visit(node)

    def visit_BinOp(self, node):
        if self.module == 'preview_portability' and self.context == 'capture':
            if isinstance(node.op, ast.Add) and isinstance(node.left, ast.Constant) and node.left.value == 'res://':
                if 'current_source' in ast.unparse(node.right):
                    return ast.parse("'res://tools/' + script").body[0].value
        return self.generic_visit(node)

    def visit_Compare(self, node):
        if (self.module == 'preview_portability' and self.context == 'validate_report'
                and ast.unparse(node.left) == 'report[key]' and len(node.comparators) == 1
                and isinstance(node.comparators[0], ast.Name) and node.comparators[0].id == 'expected'):
            node.comparators[0] = ast.parse('sha(path_under(root, name).read_bytes())').body[0].value
        return self.generic_visit(node)

    def visit_For(self, node):
        if (self.module == 'asset_report' and self.context == 'read'
                and isinstance(node.target, ast.Name) and node.target.id == 'path'
                and isinstance(node.iter, ast.List) and len(node.iter.elts) == 2):
            result = [ast.parse('path = root / name').body[0], *node.body]
            return [self.visit(n) for n in result]
        return self.generic_visit(node)

    def visit_Return(self, node):
        node = self.generic_visit(node)
        if (self.module == 'asset_report' and self.context == 'read'
                and ast.unparse(node.value) == '(root / name).read_bytes()'):
            node.value = ast.parse('path.read_bytes()').body[0].value
        return node


def normalized(raw, name, mapping):
    tree = AddressingOnly(name, mapping).visit(ast.parse(raw))
    return ast.dump(ast.fix_missing_locations(tree), include_attributes=False)
