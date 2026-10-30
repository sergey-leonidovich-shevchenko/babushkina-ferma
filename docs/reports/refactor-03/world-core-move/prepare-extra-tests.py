"""Add real external-consumer controls to the private plan; product and accepted tests stay untouched."""
import hashlib
import json
from pathlib import Path

ROOT = Path('/Users/sergeyshevchenko/.codex/worktrees/refactor-03-isolated-qa/my farm')
PLAN = Path('/private/tmp/refactor03-world-plan377.json')
plan = json.loads(PLAN.read_text())
assert not plan.get('external_controls_added')


def producers(text):
    """Extend the same actual-producer harness with one inherited World-input consumer."""
    marker = 'from tools.assets.contracts.source_paths import current_source\n'
    assert text.count(marker) == 1
    text = text.replace(marker, 'import plant_depth_collect as plant_depth\nimport plant_depth_verify\n' + marker)
    old = 'lamp,street,trade,render_order]'
    assert text.count(old) == 1
    text = text.replace(old, 'lamp,street,trade,render_order,plant_depth]')
    old = "'village_lamp_capture.gd','village_street_capture.gd','village_trade_capture.gd','render_order_capture.gd']))"
    assert text.count(old) == 1
    text = text.replace(old, old.replace("'render_order_capture.gd'", "'render_order_capture.gd','plant_depth_capture.gd'"))
    old = 'trade:village_trade_verify,render_order:render_order}'
    assert text.count(old) == 1
    text = text.replace(old, 'trade:village_trade_verify,render_order:render_order,plant_depth:plant_depth_verify}')
    old = "            elif module is shadow:verifier.verify(report)\n"
    assert text.count(old) == 1
    text = text.replace(old, "            elif module is plant_depth:verifier.validate_source(output,'after',{'base_commit':base})\n" + old)
    marker = "if __name__=='__main__':unittest.main()"
    assert text.count(marker) == 1
    method = ('    def test_plant_depth_real_inputs_and_failed_fake_child(self):\n'
              '        """The external vegetation-depth collector preserves inherited World inputs and real child argv."""\n'
              '        self.producer(plant_depth)\n\n\n')
    return text.replace(marker, method + marker)


def history(text):
    """Use real archived before bytes in an actual canonical Git tree under foreign Git overrides."""
    marker = 'from tools.assets.contracts.source_paths import MOVED_PATHS\n'
    assert text.count(marker) == 1
    text = text.replace(marker, 'import plant_depth_verify as plant_depth\n' + marker)
    old = '        if module is motion:\n'
    assert text.count(old) == 1
    text = text.replace(old, '        if module in [motion,plant_depth]:\n')
    old = "                elif module is motion:result=module.validate_source(folder,'before')\n"
    assert text.count(old) == 1
    text = text.replace(old, old + "                elif module is plant_depth:\n"
        "                    changes=json.loads((render_order.ROOT/'docs/reports/visual-overhaul/vrender-006/changes.json').read_text())\n"
        "                    changes['base_commit']=source['base_commit']\n"
        "                    result=module.validate_source(folder,'before',changes)\n")
    old = '                        if module is motion:module.verify(report)\n'
    assert text.count(old) == 1
    text = text.replace(old, '                        if module in [motion,plant_depth]:module.verify(report)\n')
    marker = "if __name__=='__main__':unittest.main()"
    assert text.count(marker) == 1
    method = ('    def test_plant_depth_reads_new_git_alias_with_old_archive_keys(self):\n'
              '        """The real external reader binds inherited canonical World blobs to unchanged archive keys."""\n'
              '        plant_depth.git_blob.cache_clear()\n'
              '        try:self.check_reader(plant_depth)\n'
              '        finally:plant_depth.git_blob.cache_clear()\n\n\n')
    return text.replace(marker, method + marker)


for name, function, label in [
    ('tools/qa/world/test_world_producers.py', producers, 'producer14'),
    ('tools/qa/world/test_world_source_history.py', history, 'history13'),
]:
    before = (ROOT / name).read_text()
    assert plan['changes'][name]['before'] == before
    extended = function(before)
    after = function(plan['changes'][name]['after'])
    compile(extended, name, 'exec')
    compile(after, name, 'exec')
    private = Path('/private/tmp/refactor03-test-world-' + label + '-before377.py')
    assert not private.exists()
    private.write_text(extended)
    plan['changes'][name]['after'] = after
    plan['changes'][name]['after_SHA256'] = hashlib.sha256(after.encode()).hexdigest()
    plan.setdefault('external_control_test_source', {})[label] = {
        'private_before': str(private), 'before_SHA256': hashlib.sha256(extended.encode()).hexdigest(),
        'after_SHA256': hashlib.sha256(after.encode()).hexdigest(),
        'same_methods_assertions_except_address_imports': True,
    }
plan['external_controls_added'] = True
PLAN.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'private_plan_only': True, 'actual_producer_methods': 14,
                  'source_history_methods': 13, 'product_mutated': False}))
