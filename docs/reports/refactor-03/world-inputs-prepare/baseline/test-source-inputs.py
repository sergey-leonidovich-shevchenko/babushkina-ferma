"""Real Git/file-I/O controls for World input addressing; no fake native admission."""
from contextlib import redirect_stderr
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from tools.qa.world import source_inputs as inputs
from tools.qa.world import test_world_context as context_fixtures
from tools.common.git import git_environment
from tools.common.paths import project_root


class SourceInputsTests(unittest.TestCase):
    """Bind historical aliases to one actual commit while current paths never use stale legacy files."""
    git = context_fixtures.WorldContextTests.git
    repository = context_fixtures.WorldContextTests.repository
    foreign_context = context_fixtures.WorldContextTests.foreign_context
    logical='tools/object_command_collect.py'
    canonical='tools/qa/world/object_command_collect.py'

    def write(self, root, name, raw):
        """Create only a declared owned fixture input."""
        path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw);return path

    def commit(self, root, label):
        """Commit the real fixture index without borrowing global identity."""
        subprocess.run(['git','-C',str(root),'add','.'],env=git_environment(),check=True)
        subprocess.run(['git','-C',str(root),'-c','user.name=World inputs QA','-c','user.email=qa@example.invalid','commit','-qm',label],env=git_environment(),check=True)
        return self.git(root,'rev-parse','HEAD')

    def test_world_alias_table_matches_the_accepted_map(self):
        """The helper cannot invent a third World location or silently drop a planned source/UID."""
        root=project_root(context_fixtures.__file__)
        data=json.loads((root/'docs/reports/refactor-01/integration-1/migration-plan.json').read_text())
        expected={name:r['target']for name,r in data['assignments'].items()if r['family']=='world'and r['action']in{'move','move_uid_with_source'}}
        self.assertEqual(dict(inputs.WORLD_TARGETS),expected)
        self.assertEqual(len(expected),141)

    def test_old_and_new_alias_use_their_exact_commits(self):
        """Later canonical bytes cannot replace the prior legacy blob."""
        with tempfile.TemporaryDirectory(prefix='world immutable aliases ')as directory:
            root=self.repository(Path(directory).resolve()/'own project')
            old=self.write(root,self.logical,b'old immutable source\n');before=self.commit(root,'old')
            target=root/self.canonical;target.parent.mkdir(parents=True,exist_ok=True);old.rename(target)
            target.write_bytes(b'new immutable source\n');after=self.commit(root,'new')
            self.assertEqual(inputs.historical_bytes(root,before,self.logical),b'old immutable source\n')
            self.assertEqual(inputs.historical_bytes(root,after,self.logical),b'new immutable source\n')
            self.assertEqual(inputs.historical_result(root,after,self.logical).returncode,0)

    def test_art_and_generic_aliases_are_composed(self):
        """Real moved art/camera Git files remain readable under their original logical keys."""
        with tempfile.TemporaryDirectory(prefix='world composed maps ')as directory:
            root=self.repository(Path(directory).resolve()/'own project')
            for logical,physical in [('tools/visual_modules_capture.gd','tools/qa/art/visual_modules_capture.gd'),
                                     ('tools/presentation_pose.py','tools/qa/camera/presentation_pose.py')]:
                self.write(root,physical,logical.encode());self.write(root,logical,b'stale current legacy')
            # Current input resolves strict canonical. Delete stale legacy before committing historical aliases.
            for logical,physical in [('tools/visual_modules_capture.gd','tools/qa/art/visual_modules_capture.gd'),
                                     ('tools/presentation_pose.py','tools/qa/camera/presentation_pose.py')]:
                self.assertEqual(inputs.input_path(root,logical),root/physical)
                (root/logical).unlink()
            base=self.commit(root,'composed')
            for logical in ['tools/visual_modules_capture.gd','tools/presentation_pose.py']:
                self.assertEqual(inputs.historical_bytes(root,base,logical),logical.encode())

    def test_missing_current_canonical_never_falls_back(self):
        """A stale old file does not satisfy current input reads."""
        with tempfile.TemporaryDirectory(prefix='world no current fallback ')as directory:
            root=self.repository(Path(directory).resolve()/'own project')
            self.write(root,'tools/presentation_pose.py',b'stale only')
            selected=inputs.input_path(root,'tools/presentation_pose.py')
            self.assertEqual(selected,root/'tools/qa/camera/presentation_pose.py')
            with self.assertRaises(FileNotFoundError):selected.read_bytes()

    def test_missing_history_keeps_nonzero_and_check_output_failure(self):
        """Missing historical input returns nonzero; it never reads an uncommitted working file."""
        with tempfile.TemporaryDirectory(prefix='world missing history ')as directory:
            root=self.repository(Path(directory).resolve()/'own project');base=self.git(root,'rev-parse','HEAD')
            self.write(root,self.logical,b'uncommitted fallback forbidden')
            result=inputs.historical_result(root,base,self.logical)
            self.assertNotEqual(result.returncode,0);self.assertEqual(result.stdout,b'')
            with redirect_stderr(io.StringIO()),self.assertRaises(subprocess.CalledProcessError):inputs.historical_bytes(root,base,self.logical)

    def test_both_aliases_are_rejected_even_with_equal_bytes(self):
        """Ambiguity is a failure instead of a preferred path or optional-overlay omission."""
        with tempfile.TemporaryDirectory(prefix='world ambiguous source ')as directory:
            root=self.repository(Path(directory).resolve()/'own project')
            self.write(root,self.logical,b'same');self.write(root,self.canonical,b'same');base=self.commit(root,'ambiguous')
            with self.assertRaisesRegex(ValueError,'ambiguous'):inputs.historical_result(root,base,self.logical)

    def test_git_symlink_mode_is_not_a_regular_source(self):
        """The Git tree itself must hold a normal blob, even when no live symlink remains."""
        with tempfile.TemporaryDirectory(prefix='world git symlink ')as directory:
            root=self.repository(Path(directory).resolve()/'own project')
            target=root/self.canonical;target.parent.mkdir(parents=True,exist_ok=True);target.symlink_to('untracked-relative-target')
            base=self.commit(root,'symlink mode');target.unlink()
            with self.assertRaisesRegex(ValueError,'regular file'):inputs.historical_bytes(root,base,self.logical)

    def test_gitlink_is_not_a_regular_source(self):
        """A submodule-shaped tree entry cannot substitute for a source blob."""
        with tempfile.TemporaryDirectory(prefix='world gitlink source ')as directory:
            root=self.repository(Path(directory).resolve()/'own project');parent=self.git(root,'rev-parse','HEAD')
            subprocess.run(['git','-C',str(root),'update-index','--add','--cacheinfo','160000,'+parent+','+self.canonical],env=git_environment(),check=True)
            subprocess.run(['git','-C',str(root),'-c','user.name=World inputs QA','-c','user.email=qa@example.invalid','commit','-qm','gitlink'],env=git_environment(),check=True)
            base=self.git(root,'rev-parse','HEAD')
            with self.assertRaisesRegex(ValueError,'regular file'):inputs.historical_bytes(root,base,self.logical)

    def test_live_symlink_is_rejected_without_reading_it(self):
        """Historical dispatch must not traverse a planted working-tree alias."""
        with tempfile.TemporaryDirectory(prefix='world live symlink ')as directory:
            root=self.repository(Path(directory).resolve()/'own project')
            path=self.write(root,self.logical,b'committed');base=self.commit(root,'real source');path.unlink()
            outside=Path(directory)/'outside';outside.write_bytes(b'forbidden live bytes');path.symlink_to(outside)
            with self.assertRaises(ValueError):inputs.historical_bytes(root,base,self.logical)

    def test_tree_evidence_preserves_exact_git_show_bytes(self):
        """Only the explicit audit-tree route accepts a directory and retains its original header."""
        with tempfile.TemporaryDirectory(prefix='world tree evidence ')as directory:
            root=self.repository(Path(directory).resolve()/'own project');self.write(root,'docs/fixture/a.json',b'{}\n');base=self.commit(root,'tree evidence')
            expected=subprocess.check_output(['git','--no-replace-objects','-C',str(root),'show',base+':docs/fixture'],env=git_environment())
            self.assertEqual(inputs.historical_kind(root,base,'docs/fixture'),'tree')
            self.assertEqual(inputs.historical_bytes(root,base,'docs/fixture',allow_tree=True),expected)
            with self.assertRaises(ValueError):inputs.historical_bytes(root,base,'docs/fixture')

    def test_unsafe_paths_and_unpinned_refs_are_rejected(self):
        """Metadata cannot select traversal, Git internals, absolute paths or a mutable branch."""
        with tempfile.TemporaryDirectory(prefix='world unsafe history ')as directory:
            root=self.repository(Path(directory).resolve()/'own project');base=self.git(root,'rev-parse','HEAD')
            for name in ['../other','/tmp/external','.git/config','tools/../x','tools\\x','tools/x\n']:
                with self.subTest(name=name),self.assertRaises(ValueError):inputs.historical_result(root,base,name)
            for base in ['HEAD','main','--help','short','a'*39]:
                with self.subTest(base=base),self.assertRaises(ValueError):inputs.historical_result(root,base,self.logical)

    def test_text_stdout_retains_the_requested_type(self):
        """The replacement for text=True check_output returns the exact decoded UTF-8 content."""
        with tempfile.TemporaryDirectory(prefix='world text Git ')as directory:
            root=self.repository(Path(directory).resolve()/'own project');self.write(root,self.logical,'История\n'.encode());base=self.commit(root,'text')
            self.assertEqual(inputs.historical_bytes(root,base,self.logical,text=True),'История\n')
            self.assertEqual(inputs.historical_result(root,base,self.logical,text=True).stderr,'')

    def test_foreign_git_cannot_change_the_owned_read(self):
        """Actual foreign index/worktree/config overrides leave both repositories unchanged."""
        with tempfile.TemporaryDirectory(prefix='world foreign history ')as directory:
            root=self.repository(Path(directory).resolve()/'own project');self.write(root,self.canonical,b'own bytes');base=self.commit(root,'own')
            before={n:(root/'.git'/n).read_bytes()for n in['index','config']}
            with self.foreign_context():self.assertEqual(inputs.historical_bytes(root,base,self.logical),b'own bytes')
            for name,raw in before.items():self.assertEqual((root/'.git'/name).read_bytes(),raw)

    def test_borrowed_parent_git_is_rejected(self):
        """A nested folder cannot borrow its parent's history by looking like a project."""
        with tempfile.TemporaryDirectory(prefix='world borrowed history ')as directory:
            root=self.repository(Path(directory).resolve()/'own project');self.write(root,self.logical,b'parent bytes');base=self.commit(root,'parent')
            child=root/'nested project';child.mkdir()
            with self.assertRaisesRegex(ValueError,'own Git'):inputs.historical_bytes(child,base,self.logical)

    def test_registered_worktree_with_spaces_is_supported(self):
        """A genuine linked worktree passes its own backlink check and reads the same pinned blob."""
        with tempfile.TemporaryDirectory(prefix='world registered history ')as directory:
            root=self.repository(Path(directory).resolve()/'own project');self.write(root,self.logical,b'linked bytes');base=self.commit(root,'linked')
            linked=Path(directory).resolve()/'registered worktree with spaces'
            subprocess.run(['git','-C',str(root),'worktree','add','--quiet','--detach',str(linked),base],env=git_environment(),check=True)
            try:self.assertEqual(inputs.historical_bytes(linked,base,self.logical),b'linked bytes')
            finally:subprocess.run(['git','-C',str(root),'worktree','remove',str(linked)],env=git_environment(),check=True)

    def test_replace_refs_cannot_rewrite_the_pinned_source(self):
        """Ordinary Git sees the explicit fixture replacement; the history reader still sees the original."""
        with tempfile.TemporaryDirectory(prefix='world replaced history ')as directory:
            root=self.repository(Path(directory).resolve()/'own project');path=self.write(root,self.logical,b'original');before=self.commit(root,'original')
            path.write_bytes(b'replacement');after=self.commit(root,'replacement')
            subprocess.run(['git','-C',str(root),'replace',before,after],env=git_environment(),check=True)
            try:
                self.assertEqual(self.git(root,'show',before+':'+self.logical),'replacement')
                self.assertEqual(inputs.historical_bytes(root,before,self.logical),b'original')
            finally:subprocess.run(['git','-C',str(root),'replace','-d',before],env=git_environment(),check=True,stdout=subprocess.DEVNULL)


if __name__=='__main__':unittest.main()
